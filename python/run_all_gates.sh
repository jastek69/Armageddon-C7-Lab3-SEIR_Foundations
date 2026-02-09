#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# run_all_gates.sh
#
# Runs:
#  1) gate_secrets_and_role.sh  -> gate_secrets_and_role.json
#  2) gate_network_db.sh        -> gate_network_db.json
#
# Produces:
#  - combined gate_result.json (default)
#  - prints badge-style summary: GREEN / YELLOW / RED
#
# Exit codes:
#   0 = PASS (all gates PASS)
#   2 = FAIL (one or more gates FAIL)
#   1 = ERROR (script missing, bad env, execution error)
# ============================================================

# ---------- Inputs (override via env) ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/output}"
REGION="${REGION:-us-west-2}"
ORIGIN_REGION="${ORIGIN_REGION:-$REGION}"
CF_DISTRIBUTION_ID="${CF_DISTRIBUTION_ID:-}"
DOMAIN_NAME="${DOMAIN_NAME:-}"
ROUTE53_ZONE_ID="${ROUTE53_ZONE_ID:-}"
ACM_CERT_ARN="${ACM_CERT_ARN:-}"
WAF_WEB_ACL_ARN="${WAF_WEB_ACL_ARN:-}"
LOG_BUCKET="${LOG_BUCKET:-}"
ORIGIN_SG_ID="${ORIGIN_SG_ID:-}"
INSTANCE_ID="${INSTANCE_ID:-i-0cff400cc4f896081}"
SECRET_ID="${SECRET_ID:-taaops/lab/mysql}"
DB_ID="${DB_ID:-taaops-rds}"

# toggles pass-through
REQUIRE_ROTATION="${REQUIRE_ROTATION:-true}"
CHECK_SECRET_POLICY_WILDCARD="${CHECK_SECRET_POLICY_WILDCARD:-true}"
CHECK_SECRET_VALUE_READ="${CHECK_SECRET_VALUE_READ:-true}"
EXPECTED_ROLE_NAME="${EXPECTED_ROLE_NAME:-taaops-armageddon-lab1-asm-role}"

CHECK_PRIVATE_SUBNETS="${CHECK_PRIVATE_SUBNETS:-true}"

# output
OUT_JSON="${OUT_JSON:-$OUTPUT_DIR/gate_result.json}"
WRITE_GATE_LOG="${WRITE_GATE_LOG:-true}"
GATE_LOG_DIR="${GATE_LOG_DIR:-LAB1-DELIVERABLES}"
GATE_LOG_FILE="${GATE_LOG_FILE:-$GATE_LOG_DIR/gate_checks.log}"

# ---------- Helpers ----------
now_utc() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

have_file() { [[ -f "$1" ]]; }

json_escape() {
  sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a;N;$!ba;s/\n/\\n/g'
}

badge_color() {
  # Simple badge logic:
  # GREEN = all PASS
  # RED   = any FAIL
  # YELLOW= no FAIL but warnings exist or on-instance checks skipped
  local status="$1"
  local warnings_count="$2"
  if [[ "$status" == "FAIL" ]]; then echo "RED"; return; fi
  if [[ "$warnings_count" -gt 0 ]]; then echo "YELLOW"; return; fi
  echo "GREEN"
}

# ---------- Preconditions ----------
if [[ -z "$INSTANCE_ID" || -z "$SECRET_ID" || -z "$DB_ID" ]]; then
  echo "ERROR: You must set INSTANCE_ID, SECRET_ID, and DB_ID." >&2
  echo "Example:" >&2
  echo "  REGION=us-west-2 INSTANCE_ID=i-... SECRET_ID=my-secret DB_ID=mydb01 ./run_all_gates.sh" >&2
  exit 1
fi

if ! have_file "$SCRIPT_DIR/gate_secrets_and_role.sh" || ! have_file "$SCRIPT_DIR/gate_network_db.sh"; then
  echo "ERROR: Missing required gate scripts in current directory." >&2
  echo "Expected:" >&2
  echo "  $SCRIPT_DIR/gate_secrets_and_role.sh" >&2
  echo "  $SCRIPT_DIR/gate_network_db.sh" >&2
  exit 1
fi

if [[ "$WRITE_GATE_LOG" == "true" ]]; then
  mkdir -p "$GATE_LOG_DIR"
  cat >> "$GATE_LOG_FILE" <<EOF

===== Gate: all_gates =====
Timestamp (UTC): $(now_utc)
Region: $REGION
Origin Region: $ORIGIN_REGION
CloudFront Distribution ID: $CF_DISTRIBUTION_ID
Domain Name: $DOMAIN_NAME
Route53 Zone ID: $ROUTE53_ZONE_ID
ACM Cert ARN: $ACM_CERT_ARN
WAF Web ACL ARN: $WAF_WEB_ACL_ARN
Log Bucket: $LOG_BUCKET
Origin SG ID: $ORIGIN_SG_ID
Instance ID: $INSTANCE_ID
Secret ID: $SECRET_ID
DB ID: $DB_ID
EOF
  exec > >(tee -a "$GATE_LOG_FILE") 2>&1
fi

mkdir -p "$OUTPUT_DIR"

chmod +x "$SCRIPT_DIR/gate_secrets_and_role.sh" "$SCRIPT_DIR/gate_network_db.sh" || true

# ---------- Run Gate 1: Secrets + Role ----------
echo "=== Running Gate 1/2: secrets_and_role ==="
set +e
OUT_JSON_1="$OUTPUT_DIR/gate_secrets_and_role.json" \
REGION="$REGION" INSTANCE_ID="$INSTANCE_ID" SECRET_ID="$SECRET_ID" \
REQUIRE_ROTATION="$REQUIRE_ROTATION" \
CHECK_SECRET_POLICY_WILDCARD="$CHECK_SECRET_POLICY_WILDCARD" \
CHECK_SECRET_VALUE_READ="$CHECK_SECRET_VALUE_READ" \
EXPECTED_ROLE_NAME="$EXPECTED_ROLE_NAME" \
"$SCRIPT_DIR/gate_secrets_and_role.sh"
rc1=$?
set -e

# ---------- Run Gate 2: Network + DB ----------
echo "=== Running Gate 2/2: network_db ==="
set +e
OUT_JSON_2="$OUTPUT_DIR/gate_network_db.json" \
REGION="$REGION" INSTANCE_ID="$INSTANCE_ID" DB_ID="$DB_ID" \
CHECK_PRIVATE_SUBNETS="$CHECK_PRIVATE_SUBNETS" \
"$SCRIPT_DIR/gate_network_db.sh"
rc2=$?
set -e

# ---------- Determine overall ----------
overall_exit=0
overall_status="PASS"

if [[ "$rc1" -ne 0 || "$rc2" -ne 0 ]]; then
  overall_status="FAIL"
  overall_exit=2
fi

# ---------- Parse warnings count (best-effort without jq) ----------
warnings_1="$(grep -o '"warnings":[[][^]]*[]]' "$OUTPUT_DIR/gate_secrets_and_role.json" 2>/dev/null | wc -c | tr -d ' ')"
warnings_2="$(grep -o '"warnings":[[][^]]*[]]' "$OUTPUT_DIR/gate_network_db.json" 2>/dev/null | wc -c | tr -d ' ')"

# Crude heuristic: if warnings array isn't empty, its text length > ~15
warn_count=0
[[ "${warnings_1:-0}" -gt 15 ]] && warn_count=$((warn_count+1))
[[ "${warnings_2:-0}" -gt 15 ]] && warn_count=$((warn_count+1))

badge="$(badge_color "$overall_status" "$warn_count")"

# ---------- Emit combined JSON ----------
ts="$(now_utc)"
cat >> "$OUT_JSON" <<EOF
{
  "gate": "all_gates",
  "timestamp_utc": "$ts",
  "region": "$(echo "$REGION" | json_escape)",
  "inputs": {
    "origin_region": "$(echo "$ORIGIN_REGION" | json_escape)",
    "cloudfront_distribution_id": "$(echo "$CF_DISTRIBUTION_ID" | json_escape)",
    "domain_name": "$(echo "$DOMAIN_NAME" | json_escape)",
    "route53_zone_id": "$(echo "$ROUTE53_ZONE_ID" | json_escape)",
    "acm_cert_arn": "$(echo "$ACM_CERT_ARN" | json_escape)",
    "waf_web_acl_arn": "$(echo "$WAF_WEB_ACL_ARN" | json_escape)",
    "log_bucket": "$(echo "$LOG_BUCKET" | json_escape)",
    "origin_sg_id": "$(echo "$ORIGIN_SG_ID" | json_escape)",
    "instance_id": "$(echo "$INSTANCE_ID" | json_escape)",
    "secret_id": "$(echo "$SECRET_ID" | json_escape)",
    "db_id": "$(echo "$DB_ID" | json_escape)"
  },
  "child_gates": [
    {
      "name": "secrets_and_role",
      "script": "gate_secrets_and_role.sh",
      "result_file": "$OUTPUT_DIR/gate_secrets_and_role.json",
      "exit_code": $rc1
    },
    {
      "name": "network_db",
      "script": "gate_network_db.sh",
      "result_file": "$OUTPUT_DIR/gate_network_db.json",
      "exit_code": $rc2
    }
  ],
  "badge": {
    "status": "$(echo "$badge" | json_escape)",
    "meaning": "GREEN=all pass, YELLOW=pass with warnings, RED=one or more failures"
  },
  "status": "$(echo "$overall_status" | json_escape)",
  "exit_code": $overall_exit
}
EOF

# ---------- Console summary (badge-friendly) ----------
echo ""
echo "===== SEIR Combined Gate Summary ====="
echo "Gate 1 (secrets_and_role) exit: $rc1  -> $OUTPUT_DIR/gate_secrets_and_role.json"
echo "Gate 2 (network_db)       exit: $rc2  -> $OUTPUT_DIR/gate_network_db.json"
echo "--------------------------------------"
echo "BADGE:  $badge"
echo "RESULT: $overall_status"
echo "Wrote:  $OUT_JSON"
echo "======================================"
echo ""

exit "$overall_exit"
