#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# gate_network_db.sh
#
# SEIR-style gate: verify EC2 <-> RDS network correctness.
#
# Checks:
#   1) RDS instance exists
#   2) RDS is NOT publicly accessible
#   3) Resolve DB port (or use DB_PORT override)
#   4) Resolve EC2 security groups
#   5) Resolve RDS security groups
#   6) Verify RDS SG allows ingress from EC2 SG on DB port (SG-to-SG)
#   7) Fail if DB port is open to 0.0.0.0/0 or ::/0 on RDS SG
#   8) Optional: verify DB subnets are private (no IGW route)
#
# Outputs:
#   - human summary to stdout
#   - machine-readable gate_result.json
#
# Exit codes:
#   0 = PASS
#   2 = FAIL (one or more checks failed)
#   1 = ERROR
# ============================================================

# ---------- Defaults (override via env) ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/output}"
REGION="${REGION:-us-west-2}"
INSTANCE_ID="${INSTANCE_ID:-i-0cff400cc4f896081}"
DB_ID="${DB_ID:-taaops-rds}"                   # RDS DBInstanceIdentifier
DB_PORT="${DB_PORT:-3306}"               # optional override
OUT_JSON="${OUT_JSON:-$OUTPUT_DIR/gate_network_db.json}"
WRITE_GATE_LOG="${WRITE_GATE_LOG:-true}"
GATE_LOG_DIR="${GATE_LOG_DIR:-LAB1-DELIVERABLES}"
GATE_LOG_FILE="${GATE_LOG_FILE:-$GATE_LOG_DIR/gate_checks.log}"

CHECK_PRIVATE_SUBNETS="${CHECK_PRIVATE_SUBNETS:-true}"  # true/false

# ---------- Helpers ----------
now_utc() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

json_escape() {
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
  REGION=us-west-2 INSTANCE_ID=i-0cff400cc4f896081 DB_ID=taaops-rds ./gate_network_db.sh

Required env vars:
  REGION       AWS region (default: us-west-2)
  INSTANCE_ID  EC2 instance id (required)
  DB_ID        RDS DB instance identifier (required)

Optional:
  DB_PORT=3306                     override discovered port
  CHECK_PRIVATE_SUBNETS=true|false verify DB subnets have no IGW route (default: true)
  OUT_JSON=gate_result.json        output file (default: gate_result.json)

Examples:
  REGION=us-west-2 INSTANCE_ID=i-0cff400cc4f896081 DB_ID=taaops-rds ./gate_network_db.sh

  CHECK_PRIVATE_SUBNETS=true REGION=us-west-2 INSTANCE_ID=i-0cff400cc4f896081 DB_ID=taaops-rds ./gate_network_db.sh
EOF
}

# ---------- Args ----------
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

===== Gate: network_db =====
Timestamp (UTC): $(now_utc)
Region: $REGION
Instance ID: $INSTANCE_ID
DB ID: $DB_ID
EOF
  exec > >(tee -a "$GATE_LOG_FILE") 2>&1
fi

mkdir -p "$OUTPUT_DIR"

if [[ -z "$INSTANCE_ID" || -z "$DB_ID" ]]; then
  echo "ERROR: INSTANCE_ID and DB_ID are required." >&2
  usage >&2
  exit 1
fi

# ---------- Check 0: credential sanity ----------
if aws sts get-caller-identity --region "$REGION" >/dev/null 2>&1; then
  add_detail "PASS: aws sts get-caller-identity succeeded (credentials OK)."
else
  add_failure "FAIL: aws sts get-caller-identity failed (credentials/permissions)."
fi

# ---------- Check 1: RDS exists ----------
if aws rds describe-db-instances --db-instance-identifier "$DB_ID" --region "$REGION" >/dev/null 2>&1; then
  add_detail "PASS: RDS instance exists ($DB_ID)."
else
  add_failure "FAIL: RDS instance not found or no permission ($DB_ID)."
fi

# ---------- Resolve RDS properties ----------
public_flag="$(aws rds describe-db-instances --db-instance-identifier "$DB_ID" --region "$REGION" \
  --query "DBInstances[0].PubliclyAccessible" --output text 2>/dev/null || echo "Unknown")"

engine="$(aws rds describe-db-instances --db-instance-identifier "$DB_ID" --region "$REGION" \
  --query "DBInstances[0].Engine" --output text 2>/dev/null || echo "Unknown")"

discovered_port="$(aws rds describe-db-instances --db-instance-identifier "$DB_ID" --region "$REGION" \
  --query "DBInstances[0].Endpoint.Port" --output text 2>/dev/null || echo "")"

db_subnet_group="$(aws rds describe-db-instances --db-instance-identifier "$DB_ID" --region "$REGION" \
  --query "DBInstances[0].DBSubnetGroup.DBSubnetGroupName" --output text 2>/dev/null || echo "")"

# ---------- Check 2: RDS not public ----------
if [[ "$public_flag" == "False" ]]; then
  add_detail "PASS: RDS is not publicly accessible (PubliclyAccessible=False)."
elif [[ "$public_flag" == "True" ]]; then
  add_failure "FAIL: RDS is publicly accessible (PubliclyAccessible=True)."
else
  add_warning "WARN: could not determine PubliclyAccessible for $DB_ID (value=$public_flag)."
fi

# ---------- Resolve DB port ----------
if [[ -n "$DB_PORT" ]]; then
  add_detail "INFO: using DB_PORT override = $DB_PORT."
else
  DB_PORT="$discovered_port"
  if [[ -n "$DB_PORT" && "$DB_PORT" != "None" ]]; then
    add_detail "PASS: discovered DB port = $DB_PORT (engine=$engine)."
  else
    add_failure "FAIL: could not discover DB port for $DB_ID (set DB_PORT=... to override)."
  fi
fi

# ---------- Resolve EC2 security groups ----------
ec2_sgs="$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" \
  --query "Reservations[0].Instances[0].SecurityGroups[].GroupId" --output text 2>/dev/null || echo "")"

if [[ -n "$ec2_sgs" && "$ec2_sgs" != "None" ]]; then
  add_detail "PASS: EC2 security groups resolved ($INSTANCE_ID): $ec2_sgs"
else
  add_failure "FAIL: could not resolve EC2 security groups for $INSTANCE_ID."
fi

# ---------- Resolve RDS security groups ----------
rds_sgs="$(aws rds describe-db-instances --db-instance-identifier "$DB_ID" --region "$REGION" \
  --query "DBInstances[0].VpcSecurityGroups[].VpcSecurityGroupId" --output text 2>/dev/null || echo "")"

if [[ -n "$rds_sgs" && "$rds_sgs" != "None" ]]; then
  add_detail "PASS: RDS security groups resolved ($DB_ID): $rds_sgs"
else
  add_failure "FAIL: could not resolve RDS VPC security groups for $DB_ID."
fi

# ---------- Check 3: RDS SG allows ingress from EC2 SG on DB port ----------
# We PASS if ANY RDS SG has an ingress rule on DB_PORT with UserIdGroupPairs including ANY EC2 SG.
sg_to_sg_ok=false
found_open_world=false

if [[ -n "$rds_sgs" && -n "$ec2_sgs" && -n "$DB_PORT" ]]; then
  for rds_sg in $rds_sgs; do
    # Get allowed source SGs for the DB port
    allowed_src_sgs="$(aws ec2 describe-security-groups --group-ids "$rds_sg" --region "$REGION" \
      --query "SecurityGroups[0].IpPermissions[?FromPort==\`${DB_PORT}\` && ToPort==\`${DB_PORT}\`].UserIdGroupPairs[].GroupId" \
      --output text 2>/dev/null || echo "")"

    # Detect world-open (IPv4)
    world_v4="$(aws ec2 describe-security-groups --group-ids "$rds_sg" --region "$REGION" \
      --query "SecurityGroups[0].IpPermissions[?FromPort==\`${DB_PORT}\` && ToPort==\`${DB_PORT}\`].IpRanges[].CidrIp" \
      --output text 2>/dev/null || echo "")"

    # Detect world-open (IPv6)
    world_v6="$(aws ec2 describe-security-groups --group-ids "$rds_sg" --region "$REGION" \
      --query "SecurityGroups[0].IpPermissions[?FromPort==\`${DB_PORT}\` && ToPort==\`${DB_PORT}\`].Ipv6Ranges[].CidrIpv6" \
      --output text 2>/dev/null || echo "")"

    if echo "$world_v4 $world_v6" | grep -Eq '(^| )0\.0\.0\.0/0( |$)|(^| )::/0( |$)'; then
      found_open_world=true
      add_failure "FAIL: RDS SG $rds_sg allows DB port $DB_PORT from the world (0.0.0.0/0 or ::/0)."
    fi

    for ec2_sg in $ec2_sgs; do
      if echo "$allowed_src_sgs" | grep -q "$ec2_sg"; then
        sg_to_sg_ok=true
      fi
    done
  done

  if [[ "$sg_to_sg_ok" == "true" ]]; then
    add_detail "PASS: RDS SG allows DB port $DB_PORT from EC2 SG (SG-to-SG ingress present)."
  else
    add_failure "FAIL: no SG-to-SG ingress rule found allowing EC2 SG -> RDS on port $DB_PORT."
  fi
fi

# ---------- Optional Check 4: DB subnets are private (no IGW route) ----------
if [[ "$CHECK_PRIVATE_SUBNETS" == "true" ]]; then
  if [[ -z "$db_subnet_group" || "$db_subnet_group" == "None" ]]; then
    add_warning "WARN: could not resolve DBSubnetGroupName; skipping private subnet checks."
  else
    subnets="$(aws rds describe-db-subnet-groups --db-subnet-group-name "$db_subnet_group" --region "$REGION" \
      --query "DBSubnetGroups[0].Subnets[].SubnetIdentifier" --output text 2>/dev/null || echo "")"
    if [[ -z "$subnets" ]]; then
      add_warning "WARN: could not list subnets for DB subnet group ($db_subnet_group)."
    else
      add_detail "INFO: DB subnet group ($db_subnet_group) subnets: $subnets"
      for subnet in $subnets; do
        # Find route tables associated with subnet; if none, the main route table applies.
        rt_ids="$(aws ec2 describe-route-tables --region "$REGION" \
          --filters "Name=association.subnet-id,Values=$subnet" \
          --query "RouteTables[].RouteTableId" --output text 2>/dev/null || echo "")"

        if [[ -z "$rt_ids" ]]; then
          # Grab the VPC ID for subnet, then main route table
          vpc_id="$(aws ec2 describe-subnets --subnet-ids "$subnet" --region "$REGION" \
            --query "Subnets[0].VpcId" --output text 2>/dev/null || echo "")"
          if [[ -n "$vpc_id" && "$vpc_id" != "None" ]]; then
            rt_ids="$(aws ec2 describe-route-tables --region "$REGION" \
              --filters "Name=vpc-id,Values=$vpc_id" "Name=association.main,Values=true" \
              --query "RouteTables[].RouteTableId" --output text 2>/dev/null || echo "")"
          fi
        fi

        if [[ -z "$rt_ids" ]]; then
          add_warning "WARN: could not resolve route table for subnet $subnet (private subnet check inconclusive)."
          continue
        fi

        # Check for IGW route on any route table for that subnet
        igw_routes="$(aws ec2 describe-route-tables --route-table-ids $rt_ids --region "$REGION" \
          --query "RouteTables[].Routes[?starts_with(GatewayId, 'igw-')].GatewayId" --output text 2>/dev/null || echo "")"

        if [[ -n "$igw_routes" ]]; then
          add_failure "FAIL: subnet $subnet has IGW route via $igw_routes (not private)."
        else
          add_detail "PASS: subnet $subnet shows no IGW route (private check OK)."
        fi
      done
    fi
  fi
else
  add_detail "INFO: private subnet check disabled (CHECK_PRIVATE_SUBNETS=false)."
fi

# ---------- Compute result ----------
status="PASS"
exit_code=0
if (( ${#failures[@]} > 0 )); then
  status="FAIL"
  exit_code=2
fi

# ---------- Emit human summary ----------
caller_arn="$(aws sts get-caller-identity --region "$REGION" --query Arn --output text 2>/dev/null || echo "")"

echo ""
echo "=== SEIR Gate: Network + RDS Verification ==="
echo "Timestamp (UTC): $(now_utc)"
echo "Region:          $REGION"
echo "EC2 Instance:    $INSTANCE_ID"
echo "RDS Instance:    $DB_ID"
echo "Engine:          ${engine:-"(unknown)"}"
echo "DB Port:         ${DB_PORT:-"(unknown)"}"
echo "Caller ARN:      ${caller_arn:-"(unknown)"}"
echo "-------------------------------------------"

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
echo "==========================================="
echo ""

# ---------- Emit machine-readable JSON ----------
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
  "gate": "network_db",
  "timestamp_utc": "$(now_utc)",
  "region": "$(echo "$REGION" | json_escape)",
  "instance_id": "$(echo "$INSTANCE_ID" | json_escape)",
  "db_id": "$(echo "$DB_ID" | json_escape)",
  "engine": "$(echo "${engine:-}" | json_escape)",
  "db_port": "$(echo "${DB_PORT:-}" | json_escape)",
  "publicly_accessible": "$(echo "${public_flag:-}" | json_escape)",
  "ec2_security_groups": "$(echo "${ec2_sgs:-}" | json_escape)",
  "rds_security_groups": "$(echo "${rds_sgs:-}" | json_escape)",
  "db_subnet_group": "$(echo "${db_subnet_group:-}" | json_escape)",
  "toggles": {
    "check_private_subnets": $CHECK_PRIVATE_SUBNETS
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
