#!/usr/bin/env bash
set -euo pipefail

# Downloads report files (json + md) flagged by alarm state.
# Requires: reports JSON files locally OR REPORT_BUCKET env to sync first.
#
# Usage:
#   REPORT_BUCKET=taaops-ir-reports-015195098145 ./scripts/download_alarm_reports.sh
#   REPORTS_DIR=./reports/IR ./scripts/download_alarm_reports.sh
#   ALARM_STATE=ALARM ./scripts/download_alarm_reports.sh
#   ALARM_NAME_REGEX="manual-test" ./scripts/download_alarm_reports.sh
#   ALARM_SINCE_EPOCH=1700000000 ./scripts/download_alarm_reports.sh
#   ALARM_SEVERITY=critical ./scripts/download_alarm_reports.sh

REPORTS_DIR="${REPORTS_DIR:-./reports/IR}"
REPORT_BUCKET="${REPORT_BUCKET:-}"
REGION="${REGION:-us-west-2}"
ALARM_STATE="${ALARM_STATE:-ALARM}"
ALARM_NAME_REGEX="${ALARM_NAME_REGEX:-}"
ALARM_SINCE_EPOCH="${ALARM_SINCE_EPOCH:-}"
ALARM_UNTIL_EPOCH="${ALARM_UNTIL_EPOCH:-}"
ALARM_SEVERITY="${ALARM_SEVERITY:-}"

if [[ -n "$REPORT_BUCKET" ]]; then
  mkdir -p "$REPORTS_DIR"
  aws s3 sync "s3://$REPORT_BUCKET/reports/" "$REPORTS_DIR/" \
    --exclude "*" --include "*.json" --region "$REGION" >/dev/null
fi

if [[ ! -d "$REPORTS_DIR" ]]; then
  echo "ERROR: reports directory not found: $REPORTS_DIR"
  exit 1
fi

shopt -s nullglob
json_files=("$REPORTS_DIR"/*.json)
if [[ ${#json_files[@]} -eq 0 ]]; then
  echo "No report JSON files found in $REPORTS_DIR"
  exit 0
fi

match_files=()
if command -v jq >/dev/null 2>&1; then
  for f in "${json_files[@]}"; do
    if jq -e --arg state "$ALARM_STATE" \
      --arg name_re "$ALARM_NAME_REGEX" \
      --argjson since_epoch "${ALARM_SINCE_EPOCH:-null}" \
      --argjson until_epoch "${ALARM_UNTIL_EPOCH:-null}" \
      --arg severity "$ALARM_SEVERITY" \
      '
      def tstamp:
        (.alarm.StateChangeTime // .generated_at // "");
      def time_ok:
        if ($since_epoch == null and $until_epoch == null) then true
        else
          (tstamp | fromdateiso8601) as $ts |
          (if $since_epoch == null then true else $ts >= $since_epoch end) and
          (if $until_epoch == null then true else $ts <= $until_epoch end)
        end;
      def name_ok:
        if $name_re == "" then true
        else (.alarm.AlarmName // "") | test($name_re)
        end;
      def severity_ok:
        if $severity == "" then true
        else
          ((.alarm.Severity // .alarm.severity // "") | ascii_downcase) == ($severity | ascii_downcase) or
          ((.alarm.AlarmDescription // "") | test("(?i)severity[:= ]*" + $severity))
        end;
      (.alarm.NewStateValue==$state) and name_ok and time_ok and severity_ok
      ' "$f" >/dev/null 2>&1; then
      match_files+=("$f")
    fi
  done
else
  if [[ -n "$ALARM_NAME_REGEX" || -n "$ALARM_SINCE_EPOCH" || -n "$ALARM_UNTIL_EPOCH" || -n "$ALARM_SEVERITY" ]]; then
    echo "WARN: jq not found; name/time/severity filters require jq. Falling back to state only."
  fi
  while IFS= read -r line; do
    match_files+=("$line")
  done < <(grep -l "\"NewStateValue\": \"$ALARM_STATE\"" "${json_files[@]}" || true)
fi

if [[ ${#match_files[@]} -eq 0 ]]; then
  echo "No ${ALARM_STATE} reports found in $REPORTS_DIR"
  exit 0
fi

if [[ -z "$REPORT_BUCKET" ]]; then
  echo "${ALARM_STATE} reports (local):"
  printf '%s\n' "${match_files[@]}"
  exit 0
fi

echo "Downloading matching report pairs..."
for f in "${match_files[@]}"; do
  base="$(basename "$f" .json)"
  aws s3 cp "s3://$REPORT_BUCKET/reports/${base}.json" "$REPORTS_DIR/${base}.json" --region "$REGION"
  aws s3 cp "s3://$REPORT_BUCKET/reports/${base}.md" "$REPORTS_DIR/${base}.md" --region "$REGION"
done
