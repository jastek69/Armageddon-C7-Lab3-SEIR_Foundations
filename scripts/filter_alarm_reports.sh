#!/usr/bin/env bash
set -euo pipefail

# Finds report JSON files flagged by alarm state.
# Usage:
#   ./scripts/filter_alarm_reports.sh
#   REPORTS_DIR=./reports/IR ./scripts/filter_alarm_reports.sh
#   REPORT_BUCKET=taaops-ir-reports-015195098145 ./scripts/filter_alarm_reports.sh
#   ALARM_STATE=ALARM ./scripts/filter_alarm_reports.sh
#   ALARM_NAME_REGEX="manual-test" ./scripts/filter_alarm_reports.sh
#   ALARM_SINCE_EPOCH=1700000000 ./scripts/filter_alarm_reports.sh
#   ALARM_SEVERITY=critical ./scripts/filter_alarm_reports.sh

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
files=("$REPORTS_DIR"/*.json)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "No report JSON files found in $REPORTS_DIR"
  exit 0
fi

if command -v jq >/dev/null 2>&1; then
  for f in "${files[@]}"; do
    jq -e --arg state "$ALARM_STATE" \
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
      ' "$f" >/dev/null 2>&1 && echo "$f"
  done
else
  if [[ -n "$ALARM_NAME_REGEX" || -n "$ALARM_SINCE_EPOCH" || -n "$ALARM_UNTIL_EPOCH" || -n "$ALARM_SEVERITY" ]]; then
    echo "WARN: jq not found; name/time/severity filters require jq. Falling back to state only."
  fi
  grep -l "\"NewStateValue\": \"$ALARM_STATE\"" "${files[@]}" || true
fi
