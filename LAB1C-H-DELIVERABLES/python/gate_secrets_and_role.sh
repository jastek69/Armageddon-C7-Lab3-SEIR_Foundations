#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# gate_secrets_and_role.sh
#
# SEIR-style gate: verify
#   1) Secret exists (and optionally rotation)
#   2) EC2 has IAM instance profile attached
#   3) Resolve instance profile -> role
#   4) (If run on EC2) prove caller is the expected role
#   5) (If run on EC2) prove role can read secret (describe + optional get value)
#   6) Optional basic guardrails (wildcard secret policy)
#
# Outputs:
#   - human summary to stdout
#   - machine-readable gate_result.json
#
# Exit codes:
#   0 = PASS
#   2 = FAIL (one or more checks failed)
#   1 = ERROR (script execution or missing prerequisites)
#
# Safety notes:
#   - This script NEVER prints secret values.
#   - The optional secret-value read check only verifies access; it discards output.
# ============================================================

# ---------- Defaults (override via env or flags) ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/output}"
REGION="${REGION:-us-west-2}"
INSTANCE_ID="${INSTANCE_ID:-i-0cff400cc4f896081}"
SECRET_ID="${SECRET_ID:-taaops/lab/mysql}"
OUT_JSON="${OUT_JSON:-$OUTPUT_DIR/gate_secrets_and_role.json}"
WRITE_GATE_LOG="${WRITE_GATE_LOG:-true}"
GATE_LOG_DIR="${GATE_LOG_DIR:-LAB1-DELIVERABLES}"
GATE_LOG_FILE="${GATE_LOG_FILE:-$GATE_LOG_DIR/gate_checks.log}"

# toggles (default: strict but sane)
REQUIRE_ROTATION="${REQUIRE_ROTATION:-true}"          # true/false
CHECK_SECRET_POLICY_WILDCARD="${CHECK_SECRET_POLICY_WILDCARD:-true}"  # true/false
CHECK_SECRET_VALUE_READ="${CHECK_SECRET_VALUE_READ:-true}"           # true/false (run on EC2 only)
EXPECTED_ROLE_NAME="${EXPECTED_ROLE_NAME:-taaops-armageddon-lab1-asm-role}"           # optional; if blank, script resolves from instance profile

# ---------- Helpers ----------
now_utc() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

json_escape() {
  # Escape backslashes, quotes, newlines for JSON strings
  sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a;N;$!ba;s/\n/\\n/g'
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

failures=()
warnings=()
details=()

add_detail() { details+=("$1"); }
add_warning() { warnings+=("$1"); }
add_failure() { failures+=("$1"); }

usage() {
  cat <<EOF
Usage:
  REGION=us-west-2 INSTANCE_ID=i-0cff400cc4f896081 SECRET_ID=taaops/lab/mysql ./gate_secrets_and_role.sh

Required:
  REGION        AWS region (default: us-west-2)
  INSTANCE_ID   EC2 instance id to check (required)
  SECRET_ID     Secrets Manager secret name or ARN (required)

Optional toggles (env vars):
  REQUIRE_ROTATION=true|false                (default: true)
  CHECK_SECRET_POLICY_WILDCARD=true|false    (default: true)
  CHECK_SECRET_VALUE_READ=true|false         (default: true)  # should be run ON the EC2 instance
  EXPECTED_ROLE_NAME=<RoleName>              (default: resolved from instance profile)
  OUT_JSON=gate_result.json                  (default: gate_result.json)

Examples:
  REGION=us-west-2 INSTANCE_ID=i-0cff400cc4f896081 SECRET_ID=taaops/lab/mysql ./gate_secrets_and_role.sh

  # Strict rotation requirement:
  REQUIRE_ROTATION=true REGION=us-west-2 INSTANCE_ID=i-0cff400cc4f896081 SECRET_ID=taaops/lab/mysql ./gate_secrets_and_role.sh

  # Run on the EC2 and verify it can read the secret value (does NOT print it):
  CHECK_SECRET_VALUE_READ=true REGION=us-west-2 INSTANCE_ID=i-0cff400cc4f896081 SECRET_ID=taaops/lab/mysql ./gate_secrets_and_role.sh
EOF
}

# ---------- Args (optional) ----------
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

# ---------- Preconditions ----------
if ! have_cmd aws; then
  echo "ERROR: aws CLI not found on PATH." >&2
  exit 1
fi

if [[ "$WRITE_GATE_LOG" == "true" ]]; then
  mkdir -p "$GATE_LOG_DIR"
  cat >> "$GATE_LOG_FILE" <<EOF

===== Gate: secrets_and_role =====
Timestamp (UTC): $(now_utc)
Region: $REGION
Instance ID: $INSTANCE_ID
Secret ID: $SECRET_ID
EOF
  exec > >(tee -a "$GATE_LOG_FILE") 2>&1
fi

mkdir -p "$OUTPUT_DIR"

if [[ -z "$INSTANCE_ID" || -z "$SECRET_ID" ]]; then
  echo "ERROR: INSTANCE_ID and SECRET_ID are required." >&2
  usage >&2
  exit 1
fi

# ---------- Check 0: identity sanity ----------
if aws sts get-caller-identity --region "$REGION" >/dev/null 2>&1; then
  add_detail "PASS: aws sts get-caller-identity succeeded (credentials OK)."
else
  add_failure "FAIL: aws sts get-caller-identity failed (credentials/permissions)."
fi

# ---------- Check 1: secret exists ----------
if aws secretsmanager describe-secret --secret-id "$SECRET_ID" --region "$REGION" >/dev/null 2>&1; then
  add_detail "PASS: secret exists and is describable ($SECRET_ID)."
else
  add_failure "FAIL: cannot describe secret ($SECRET_ID). It may not exist or you lack permission."
fi

# ---------- Check 2: rotation (optional strict) ----------
if [[ "$REQUIRE_ROTATION" == "true" ]]; then
  rot="$(aws secretsmanager describe-secret --secret-id "$SECRET_ID" --region "$REGION" \
    --query "RotationEnabled" --output text 2>/dev/null || echo "Unknown")"
  if [[ "$rot" == "True" ]]; then
    add_detail "PASS: secret rotation enabled ($SECRET_ID)."
  else
    add_failure "FAIL: secret rotation is not enabled (RotationEnabled=$rot) for $SECRET_ID."
  fi
else
  add_detail "INFO: rotation requirement disabled (REQUIRE_ROTATION=false)."
fi

# ---------- Check 3: secret policy wildcard principal (optional) ----------
if [[ "$CHECK_SECRET_POLICY_WILDCARD" == "true" ]]; then
  # Some secrets may not have a resource policy; that's OK.
  policy="$(aws secretsmanager get-resource-policy --secret-id "$SECRET_ID" --region "$REGION" \
    --query "ResourcePolicy" --output text 2>/dev/null || echo "")"
  if [[ -z "$policy" || "$policy" == "None" ]]; then
    add_detail "PASS: no resource policy found (OK) or not applicable ($SECRET_ID)."
  else
    if echo "$policy" | grep -q '"Principal":"\*"' ; then
      add_failure "FAIL: secret resource policy allows wildcard Principal=\"*\" ($SECRET_ID)."
    else
      add_detail "PASS: secret resource policy does not show wildcard Principal (basic check) ($SECRET_ID)."
    fi
  fi
else
  add_detail "INFO: secret policy wildcard check disabled (CHECK_SECRET_POLICY_WILDCARD=false)."
fi

# ---------- Check 4: instance has IAM instance profile ----------
profile_arn="$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" \
  --query "Reservations[0].Instances[0].IamInstanceProfile.Arn" --output text 2>/dev/null || echo "None")"

if [[ "$profile_arn" =~ ^arn:aws:iam:: ]]; then
  add_detail "PASS: instance has IAM instance profile attached ($INSTANCE_ID)."
else
  add_failure "FAIL: instance has NO IAM instance profile attached ($INSTANCE_ID)."
fi

# ---------- Check 5: resolve profile -> role ----------
resolved_role=""

if [[ "$profile_arn" =~ ^arn:aws:iam:: ]]; then
  profile_name="$(echo "$profile_arn" | awk -F/ '{print $NF}')"

  resolved_role="$(aws iam get-instance-profile --instance-profile-name "$profile_name" \
    --query "InstanceProfile.Roles[0].RoleName" --output text 2>/dev/null || echo "")"

  if [[ -n "$resolved_role" && "$resolved_role" != "None" ]]; then
    add_detail "PASS: resolved instance profile -> role ($profile_name -> $resolved_role)."
  else
    add_failure "FAIL: could not resolve role name from instance profile ($profile_name)."
  fi
fi

# ---------- Check 6: expected role match (if EXPECTED_ROLE_NAME provided) ----------
if [[ -n "$EXPECTED_ROLE_NAME" ]]; then
  if [[ -n "$resolved_role" && "$resolved_role" == "$EXPECTED_ROLE_NAME" ]]; then
    add_detail "PASS: resolved role matches EXPECTED_ROLE_NAME ($EXPECTED_ROLE_NAME)."
  else
    add_failure "FAIL: resolved role ($resolved_role) does not match EXPECTED_ROLE_NAME ($EXPECTED_ROLE_NAME)."
  fi
else
  # If not specified, we treat the resolved role as the expected one for subsequent on-EC2 checks.
  EXPECTED_ROLE_NAME="$resolved_role"
  if [[ -n "$EXPECTED_ROLE_NAME" ]]; then
    add_detail "INFO: EXPECTED_ROLE_NAME not set; using resolved role ($EXPECTED_ROLE_NAME)."
  fi
fi

# ---------- Check 7: if run on EC2, verify caller ARN is assumed-role/EXPECTED_ROLE_NAME ----------
caller_arn="$(aws sts get-caller-identity --region "$REGION" --query Arn --output text 2>/dev/null || echo "")"
if [[ -n "$EXPECTED_ROLE_NAME" ]]; then
  if echo "$caller_arn" | grep -q ":assumed-role/$EXPECTED_ROLE_NAME/"; then
    add_detail "PASS: current caller is running as expected role ($EXPECTED_ROLE_NAME)."
    on_instance=true
  else
    # Not necessarily a failure if run from workstation; treat as warning.
    add_warning "WARN: current caller ARN is not assumed-role/$EXPECTED_ROLE_NAME (you may be running off-instance)."
    on_instance=false
  fi
else
  add_warning "WARN: expected role unknown; cannot validate caller role context."
  on_instance=false
fi

# ---------- Check 8: on EC2, verify secret describe + (optional) get value ----------
if [[ "${on_instance}" == "true" ]]; then
  if aws secretsmanager describe-secret --secret-id "$SECRET_ID" --region "$REGION" >/dev/null 2>&1; then
    add_detail "PASS: on-instance role can describe secret ($SECRET_ID)."
  else
    add_failure "FAIL: on-instance role cannot describe secret ($SECRET_ID)."
  fi

  if [[ "$CHECK_SECRET_VALUE_READ" == "true" ]]; then
    if aws secretsmanager get-secret-value --secret-id "$SECRET_ID" --region "$REGION" \
        --query "SecretString" --output text >/dev/null 2>&1; then
      add_detail "PASS: on-instance role can read secret value ($SECRET_ID) (value not printed)."
    else
      add_failure "FAIL: on-instance role cannot read secret value ($SECRET_ID)."
    fi
  else
    add_detail "INFO: secret-value read check disabled (CHECK_SECRET_VALUE_READ=false)."
  fi
else
  add_detail "INFO: on-instance checks skipped (not running as expected role on EC2)."
fi

# ---------- Compute result ----------
status="PASS"
exit_code=0

if (( ${#failures[@]} > 0 )); then
  status="FAIL"
  exit_code=2
fi

# ---------- Emit human summary ----------
echo ""
echo "=== SEIR Gate: Secrets + EC2 Role Verification ==="
echo "Timestamp (UTC): $(now_utc)"
echo "Region:          $REGION"
echo "Instance ID:     $INSTANCE_ID"
echo "Secret ID:       $SECRET_ID"
echo "Resolved Role:   ${resolved_role:-"(none)"}"
echo "Caller ARN:      ${caller_arn:-"(unknown)"}"
echo "-----------------------------------------------"

for d in "${details[@]}"; do
  echo "$d"
done

if (( ${#warnings[@]} > 0 )); then
  echo ""
  echo "Warnings:"
  for w in "${warnings[@]}"; do
    echo "  - $w"
  done
fi

if (( ${#failures[@]} > 0 )); then
  echo ""
  echo "Failures:"
  for f in "${failures[@]}"; do
    echo "  - $f"
  done
fi

echo ""
echo "RESULT: $status"
echo "==============================================="
echo ""

# ---------- Emit machine-readable JSON ----------
# Build JSON arrays safely
fail_json="[]"
warn_json="[]"
detail_json="[]"

if (( ${#failures[@]} > 0 )); then
  fail_json="$(printf '%s\n' "${failures[@]}" | json_escape | awk 'BEGIN{print "["} {printf "%s\"%s\"", (NR>1?",":""), $0} END{print "]"}')"
fi
if (( ${#warnings[@]} > 0 )); then
  warn_json="$(printf '%s\n' "${warnings[@]}" | json_escape | awk 'BEGIN{print "["} {printf "%s\"%s\"", (NR>1?",":""), $0} END{print "]"}')"
fi
if (( ${#details[@]} > 0 )); then
  detail_json="$(printf '%s\n' "${details[@]}" | json_escape | awk 'BEGIN{print "["} {printf "%s\"%s\"", (NR>1?",":""), $0} END{print "]"}')"
fi

cat > "$OUT_JSON" <<EOF
{
  "gate": "secrets_and_role",
  "timestamp_utc": "$(now_utc)",
  "region": "$(echo "$REGION" | json_escape)",
  "instance_id": "$(echo "$INSTANCE_ID" | json_escape)",
  "secret_id": "$(echo "$SECRET_ID" | json_escape)",
  "resolved_instance_profile_arn": "$(echo "${profile_arn:-}" | json_escape)",
  "resolved_role_name": "$(echo "${resolved_role:-}" | json_escape)",
  "caller_arn": "$(echo "${caller_arn:-}" | json_escape)",
  "toggles": {
    "require_rotation": $REQUIRE_ROTATION,
    "check_secret_policy_wildcard": $CHECK_SECRET_POLICY_WILDCARD,
    "check_secret_value_read": $CHECK_SECRET_VALUE_READ
  },
  "status": "$(echo "$status" | json_escape)",
  "exit_code": $exit_code,
  "details": $detail_json,
  "warnings": $warn_json,
  "failures": $fail_json
}
EOF

echo "Wrote: $OUT_JSON"
exit "$exit_code"
