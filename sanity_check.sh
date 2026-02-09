#!/usr/bin/env bash
set -euo pipefail

# Override with env vars if needed.
REGION="${REGION:-us-west-2}"
INSTANCE_ID="${INSTANCE_ID:-}"
SECRET_ID="${SECRET_ID:-}"
RUN_REMOTE_CHECKS="${RUN_REMOTE_CHECKS:-false}"
RUN_OPTIONAL_GUARDS="${RUN_OPTIONAL_GUARDS:-false}"
RUN_INFO_CHECKS="${RUN_INFO_CHECKS:-false}"
RUN_POST_APPLY_CHECKS="${RUN_POST_APPLY_CHECKS:-false}"
INSTANCE_NAME_TAG="${INSTANCE_NAME_TAG:-taaops-armageddon-lab1-public-ec2}"
DB_ID="${DB_ID:-}"
VPC_ID="${VPC_ID:-}"
RDS_SG_NAME="${RDS_SG_NAME:-}"
RDS_SG_DB_ID="${RDS_SG_DB_ID:-}"
SECRETS_WARNING_ID="${SECRETS_WARNING_ID:-}"
WRITE_REPORT="${WRITE_REPORT:-true}"
REPORT_DIR="${REPORT_DIR:-LAB1-DELIVERABLES}"
REPORT_BASENAME="${REPORT_BASENAME:-sanity_check}"
REPORT_TS="${REPORT_TS:-$(date -u +%Y%m%d_%H%M%SZ)}"
REPORT_LOG="${REPORT_LOG:-$REPORT_DIR/${REPORT_BASENAME}_${REPORT_TS}.log}"
REPORT_FILE="${REPORT_FILE:-$REPORT_DIR/${REPORT_BASENAME}_${REPORT_TS}.md}"
REPORT_JSON="${REPORT_JSON:-$REPORT_DIR/${REPORT_BASENAME}_${REPORT_TS}.jsonl}"
TARGET_GROUP_ARN="${TARGET_GROUP_ARN:-}"
ALB_DNS="${ALB_DNS:-}"
ASG_NAME="${ASG_NAME:-ec2-taaops-asg}"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; exit 1; }
warn() { echo "WARN: $*"; }
info() { echo "INFO: $*"; }

python_hint() {
  if command -v python3 >/dev/null 2>&1; then
    info "python3 = $(python3 --version 2>/dev/null)"
  elif command -v py >/dev/null 2>&1; then
    info "py -3 = $(py -3 --version 2>/dev/null)"
  else
    warn "python3 not found (py launcher also missing); JSON parsing may be limited"
  fi
}

python_hint

is_ec2_instance() {
  local token iid
  token="$(curl -s --connect-timeout 1 -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 60" || true)"
  [[ -z "$token" ]] && return 1
  iid="$(curl -s --connect-timeout 1 -H "X-aws-ec2-metadata-token: $token" \
    http://169.254.169.254/latest/meta-data/instance-id || true)"
  [[ "$iid" == i-* ]]
}

auto_discover_secret() {
  if command -v terraform >/dev/null 2>&1; then
    local arn
    arn="$(terraform output -raw secrets_manager_db_secret_arn 2>/dev/null || true)"
    if [[ -z "$arn" || "$arn" == "None" ]]; then
      arn="$(terraform output -raw db_secret_arn 2>/dev/null || true)"
    fi
    if [[ -n "$arn" && "$arn" != "None" ]]; then
      echo "$arn"
      return 0
    fi
    return 1
  fi
  return 1
}

auto_discover_db_id_from_tf() {
  if command -v terraform >/dev/null 2>&1; then
    local py_cmd="python3"
    if ! command -v python3 >/dev/null 2>&1; then
      py_cmd="py -3"
    fi
    terraform output -json db_cluster_id 2>/dev/null | $py_cmd - <<'PY' || true
import json,sys
try:
    data=json.load(sys.stdin)
    if isinstance(data, list) and data:
        print(data[0])
except Exception:
    pass
PY
    return 0
  fi
  return 1
}

auto_discover_db_endpoint_from_tf() {
  if command -v terraform >/dev/null 2>&1; then
    terraform output -raw db_endpoint 2>/dev/null || true
    return 0
  fi
  return 1
}

auto_discover_secret_arn_from_tf() {
  if command -v terraform >/dev/null 2>&1; then
    terraform output -raw secrets_manager_db_secret_arn 2>/dev/null || true
    return 0
  fi
  return 1
}

auto_discover_vpc_id_from_tf() {
  if command -v terraform >/dev/null 2>&1; then
    terraform output -raw vpc_id 2>/dev/null || true
    return 0
  fi
  return 1
}

auto_discover_rds_sg_name_from_tf() {
  if command -v terraform >/dev/null 2>&1; then
    terraform output -raw rds_security_group_name 2>/dev/null || true
    return 0
  fi
  return 1
}

auto_discover_db_id() {
  aws rds describe-db-instances \
    --region "$REGION" \
    --query "DBInstances[0].DBInstanceIdentifier" \
    --output text 2>/dev/null
}

auto_discover_vpc_id_from_db() {
  local db_id="$1"
  aws rds describe-db-instances \
    --db-instance-identifier "$db_id" \
    --region "$REGION" \
    --query "DBInstances[0].DBSubnetGroup.VpcId" \
    --output text 2>/dev/null
}

auto_discover_rds_sg_name_from_db() {
  local db_id="$1"
  local sg_id
  sg_id="$(aws rds describe-db-instances \
    --db-instance-identifier "$db_id" \
    --region "$REGION" \
    --query "DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId" \
    --output text 2>/dev/null)"
  if [[ -n "$sg_id" && "$sg_id" != "None" ]]; then
    aws ec2 describe-security-groups \
      --group-ids "$sg_id" \
      --region "$REGION" \
      --query "SecurityGroups[0].GroupName" \
      --output text 2>/dev/null
  fi
}

auto_discover_target_group_arn() {
  if command -v terraform >/dev/null 2>&1; then
    terraform output -raw alb_target_group_arn 2>/dev/null || true
    return 0
  fi
  return 1
}

auto_discover_alb_dns() {
  if command -v terraform >/dev/null 2>&1; then
    terraform output -raw taaops-lb_dns_name 2>/dev/null || true
    return 0
  fi
  return 1
}

report_written=false
json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

write_report_summary() {
  local status="$1"
  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  cat >> "$REPORT_FILE" <<EOF
### Sanity Check Run - $ts
- Status: $status
- Region: $REGION
- Instance ID: $INSTANCE_ID
- Secret ID: $SECRET_ID
- DB ID: $DB_ID
- VPC ID: $VPC_ID
- RDS SG Name: $RDS_SG_NAME
- Info Checks: $RUN_INFO_CHECKS
- Optional Guards: $RUN_OPTIONAL_GUARDS
- Remote Checks: $RUN_REMOTE_CHECKS
- Post-Apply Checks: $RUN_POST_APPLY_CHECKS
EOF
  cat >> "$REPORT_JSON" <<EOF
{"timestamp_utc":"$(json_escape "$ts")","status":"$(json_escape "$status")","region":"$(json_escape "$REGION")","instance_id":"$(json_escape "$INSTANCE_ID")","secret_id":"$(json_escape "$SECRET_ID")","db_id":"$(json_escape "$DB_ID")","vpc_id":"$(json_escape "$VPC_ID")","rds_sg_name":"$(json_escape "$RDS_SG_NAME")","info_checks":"$(json_escape "$RUN_INFO_CHECKS")","optional_guards":"$(json_escape "$RUN_OPTIONAL_GUARDS")","remote_checks":"$(json_escape "$RUN_REMOTE_CHECKS")"}
EOF
  report_written=true
}

on_exit() {
  local exit_code=$?
  if [[ "$WRITE_REPORT" == "true" && "$report_written" == "false" ]]; then
    local status="PASS"
    [[ $exit_code -ne 0 ]] && status="FAIL"
    write_report_summary "$status"
  fi
}
trap on_exit EXIT

if [[ "$WRITE_REPORT" == "true" ]]; then
  mkdir -p "$REPORT_DIR"
  exec > >(tee -a "$REPORT_LOG") 2>&1
fi

# Extract allowed Secrets Manager actions from a policy document on stdin.
find_sm_actions() {
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import json
import sys
import fnmatch

try:
    doc = json.load(sys.stdin)
except Exception:
    sys.exit(1)

stmts = doc.get("Statement", [])
if isinstance(stmts, dict):
    stmts = [stmts]

actions_out = []
for st in stmts:
    if st.get("Effect") != "Allow":
        continue
    actions = st.get("Action")
    if actions is None:
        continue
    if isinstance(actions, str):
        actions = [actions]
    for a in actions:
        a_l = a.lower()
        if a == "*" or fnmatch.fnmatch(a_l, "secretsmanager:*") or a_l.startswith("secretsmanager:"):
            actions_out.append(a)

for a in actions_out:
    print(a)
sys.exit(0 if actions_out else 1)
PY
    return $?
  fi

  if command -v jq >/dev/null 2>&1; then
    jq -r '
      .Statement
      | if type=="object" then [.] else . end
      | .[]
      | select(.Effect=="Allow")
      | .Action?
      | if type=="array" then .[] else . end
      | select(type=="string")
    ' 2>/dev/null \
      | awk 'BEGIN{IGNORECASE=1} ($0=="*" || $0 ~ /^secretsmanager:/){print $0}' \
      | awk '!seen[$0]++'
    return ${PIPESTATUS[0]}
  fi

  # Fallback: best-effort grep from raw JSON if no python/jq is available.
  local raw
  raw="$(cat)"
  echo "$raw" | grep -ioE 'secretsmanager:[a-z0-9*]+' | awk '!seen[$0]++'
  [[ -n "$raw" ]] && return 0 || return 1
}

# Resolve secret before checks
if [[ -z "$SECRET_ID" || "$SECRET_ID" == "None" ]]; then
  SECRET_ID="$(auto_discover_secret)"
  [[ -n "$SECRET_ID" && "$SECRET_ID" != "None" ]] && echo "INFO: auto-discovered secret = $SECRET_ID"
fi

if [[ -z "$SECRET_ID" || "$SECRET_ID" == "None" ]]; then
  fail "could not resolve SECRET_ID (run from terraform root or set SECRET_ID env var)"
fi

if [[ -z "$SECRETS_WARNING_ID" || "$SECRETS_WARNING_ID" == "None" ]]; then
  SECRETS_WARNING_ID="$SECRET_ID"
fi

# 1) PASS/FAIL: Secret exists
echo "CHECK: secret exists"
aws secretsmanager describe-secret \
  --secret-id "$SECRET_ID" \
  --region "$REGION" >/dev/null 2>&1 \
  && pass "secret exists ($SECRET_ID)" \
  || fail "secret not found or no permission ($SECRET_ID)"

# 2) PASS/FAIL: EC2 instance has an IAM instance profile attached
if [[ -z "$INSTANCE_ID" ]]; then
  INSTANCE_ID="$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --region "$REGION" \
    --query "AutoScalingGroups[0].Instances[0].InstanceId" \
    --output text 2>/dev/null)"
  if [[ -z "$INSTANCE_ID" || "$INSTANCE_ID" == "None" ]]; then
    fail "could not auto-discover instance ID from ASG ($ASG_NAME)"
  fi
  echo "INFO: auto-discovered instance ID = $INSTANCE_ID"
fi

if [[ -z "$DB_ID" || "$DB_ID" == "None" ]]; then
  DB_ID="$(auto_discover_db_id_from_tf)"
  [[ -z "$DB_ID" || "$DB_ID" == "None" ]] && DB_ID="$(auto_discover_db_id)"
  [[ -n "$DB_ID" && "$DB_ID" != "None" ]] && echo "INFO: auto-discovered DB ID = $DB_ID"
fi

if [[ -z "$RDS_SG_DB_ID" || "$RDS_SG_DB_ID" == "None" ]]; then
  RDS_SG_DB_ID="$DB_ID"
fi

if [[ -z "$VPC_ID" || "$VPC_ID" == "None" ]]; then
  VPC_ID="$(auto_discover_vpc_id_from_tf)"
  if [[ -z "$VPC_ID" || "$VPC_ID" == "None" ]]; then
    if [[ -n "$DB_ID" && "$DB_ID" != "None" ]]; then
      VPC_ID="$(auto_discover_vpc_id_from_db "$DB_ID")"
    fi
  fi
  [[ -n "$VPC_ID" && "$VPC_ID" != "None" ]] && echo "INFO: auto-discovered VPC ID = $VPC_ID"
fi

if [[ -z "$RDS_SG_NAME" || "$RDS_SG_NAME" == "None" ]]; then
  RDS_SG_NAME="$(auto_discover_rds_sg_name_from_tf)"
  if [[ -z "$RDS_SG_NAME" || "$RDS_SG_NAME" == "None" ]]; then
    if [[ -n "$RDS_SG_DB_ID" && "$RDS_SG_DB_ID" != "None" ]]; then
      RDS_SG_NAME="$(auto_discover_rds_sg_name_from_db "$RDS_SG_DB_ID")"
    fi
  fi
  [[ -n "$RDS_SG_NAME" && "$RDS_SG_NAME" != "None" ]] && echo "INFO: auto-discovered RDS SG name = $RDS_SG_NAME"
fi


if [[ -z "$TARGET_GROUP_ARN" || "$TARGET_GROUP_ARN" == "None" ]]; then
  TARGET_GROUP_ARN="$(auto_discover_target_group_arn)"
  [[ -n "$TARGET_GROUP_ARN" && "$TARGET_GROUP_ARN" != "None" ]] && echo "INFO: auto-discovered target group ARN = $TARGET_GROUP_ARN"
fi

if [[ -z "$ALB_DNS" || "$ALB_DNS" == "None" ]]; then
  ALB_DNS="$(auto_discover_alb_dns)"
  [[ -n "$ALB_DNS" && "$ALB_DNS" != "None" ]] && echo "INFO: auto-discovered ALB DNS = $ALB_DNS"
fi
echo "CHECK: instance has IAM instance profile"
if ! profile_arn="$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION" \
  --query "Reservations[0].Instances[0].IamInstanceProfile.Arn" \
  --output text 2>/dev/null)"; then
  fail "no permission to describe instances (need ec2:DescribeInstances)"
fi

[[ "$profile_arn" == arn:aws:iam::* ]] \
  && pass "instance has IAM role attached ($INSTANCE_ID)" \
  || fail "no IAM instance profile attached ($INSTANCE_ID)"

# 3) PASS/FAIL: Extract the instance profile name
echo "CHECK: resolve instance profile name"
PROFILE_NAME="${profile_arn##*/}"
[[ -n "$PROFILE_NAME" && "$PROFILE_NAME" != "None" ]] \
  && pass "instance profile = $PROFILE_NAME" \
  || fail "could not resolve instance profile"

# 4) PASS/FAIL: Resolve instance profile role name
echo "CHECK: resolve role name from instance profile"
ROLE_NAME="$(aws iam get-instance-profile \
  --instance-profile-name "$PROFILE_NAME" \
  --query "InstanceProfile.Roles[0].RoleName" \
  --output text 2>/dev/null)"

[[ -n "$ROLE_NAME" && "$ROLE_NAME" != "None" ]] \
  && pass "role name = $ROLE_NAME" \
  || fail "could not resolve role from instance profile"

# 5) PASS/FAIL: Role has some Secrets Manager read capability (managed + inline)
echo "CHECK: role has Secrets Manager actions (managed/inline)"
managed_actions=()
inline_actions=()
managed_action_map=()
inline_action_map=()

managed_policy_arns="$(aws iam list-attached-role-policies \
  --role-name "$ROLE_NAME" \
  --query "AttachedPolicies[].PolicyArn" \
  --output text 2>/dev/null)"

if [[ -n "$managed_policy_arns" ]]; then
  for policy_arn in $managed_policy_arns; do
    version_id="$(aws iam get-policy \
      --policy-arn "$policy_arn" \
      --query "Policy.DefaultVersionId" \
      --output text 2>/dev/null)"
    if [[ -n "$version_id" && "$version_id" != "None" ]]; then
      readarray -t found_actions < <(aws iam get-policy-version \
        --policy-arn "$policy_arn" \
        --version-id "$version_id" \
        --query "PolicyVersion.Document" \
        --output json 2>/dev/null | find_sm_actions || true)
      if ((${#found_actions[@]})); then
        managed_actions+=("${found_actions[@]}")
        managed_action_map+=("$(printf "%s: %s" "$policy_arn" "${found_actions[*]}")")
      fi
    fi
  done
fi

inline_policies="$(aws iam list-role-policies \
  --role-name "$ROLE_NAME" \
  --query "PolicyNames[]" \
  --output text 2>/dev/null)"

if [[ -n "$inline_policies" ]]; then
  for policy_name in $inline_policies; do
    readarray -t found_actions < <(aws iam get-role-policy \
      --role-name "$ROLE_NAME" \
      --policy-name "$policy_name" \
      --query "PolicyDocument" \
      --output json 2>/dev/null | find_sm_actions || true)
    if ((${#found_actions[@]})); then
      inline_actions+=("${found_actions[@]}")
      inline_action_map+=("$(printf "%s: %s" "$policy_name" "${found_actions[*]}")")
    fi
  done
fi

if ((${#managed_actions[@]})) || ((${#inline_actions[@]})); then
  pass "role allows Secrets Manager actions ($ROLE_NAME)"
  if ((${#managed_action_map[@]})); then
    for line in "${managed_action_map[@]}"; do
      echo "INFO: managed policy -> $line"
    done
  else
    echo "INFO: managed policy actions: none"
  fi
  if ((${#inline_action_map[@]})); then
    for line in "${inline_action_map[@]}"; do
      echo "INFO: inline policy -> $line"
    done
  else
    echo "INFO: inline policy actions: none"
  fi
else
  fail "role appears to lack Secrets Manager actions in managed/inline policies ($ROLE_NAME)"
fi

if [[ "$RUN_REMOTE_CHECKS" == "true" ]]; then
  if ! is_ec2_instance; then
    echo "SKIP: remote checks (must run on EC2; set RUN_REMOTE_CHECKS=true on the instance)"
    RUN_REMOTE_CHECKS="false"
  fi
fi

if [[ "$RUN_REMOTE_CHECKS" == "true" ]]; then
  # 6) PASS/FAIL: From inside EC2, prove the instance identity is the expected role
  echo "CHECK: running as expected role (remote)"
  aws sts get-caller-identity \
    --query "Arn" --output text 2>/dev/null \
    | grep -q ":assumed-role/$ROLE_NAME/" \
    && pass "running as expected role ($ROLE_NAME)" \
    || fail "not running as expected role ($ROLE_NAME)"

  # 7) PASS/FAIL: From inside EC2, role can read the secret metadata (safe)
  echo "CHECK: role can describe secret (remote)"
  aws secretsmanager describe-secret \
    --secret-id "$SECRET_ID" \
    --region "$REGION" >/dev/null 2>&1 \
    && pass "role can describe secret ($SECRET_ID)" \
    || fail "role cannot describe secret ($SECRET_ID)"

  # 8) PASS/FAIL: From inside EC2, role can read the secret value (lab-approved only)
  echo "CHECK: role can read secret value (remote)"
  aws secretsmanager get-secret-value \
    --secret-id "$SECRET_ID" \
    --region "$REGION" \
    --query "SecretString" --output text >/dev/null 2>&1 \
    && pass "role can read secret value ($SECRET_ID)" \
    || fail "role cannot read secret value ($SECRET_ID)"
else
  echo "SKIP: remote checks (set RUN_REMOTE_CHECKS=true on EC2 to run 6-8)"
fi

if [[ "$RUN_OPTIONAL_GUARDS" == "true" ]]; then
  # 9) OPTIONAL Guardrail: Fail if secret rotation is disabled
  echo "CHECK: secret rotation enabled (optional guard)"
  aws secretsmanager describe-secret \
    --secret-id "$SECRET_ID" \
    --region "$REGION" \
    --query "RotationEnabled" \
    --output text 2>/dev/null \
    | grep -qi '^True$' \
    && pass "rotation enabled ($SECRET_ID)" \
    || fail "rotation disabled or unknown ($SECRET_ID)"

  # 10) OPTIONAL Guardrail: Fail if secret policy allows wildcard principal
  echo "CHECK: no wildcard principal in secret policy (optional guard)"
  aws secretsmanager get-resource-policy \
    --secret-id "$SECRET_ID" \
    --region "$REGION" \
    --query "ResourcePolicy" \
    --output text 2>/dev/null \
    | grep -q '"Principal":"\*"' \
    && fail "secret resource policy allows wildcard principal" \
    || pass "no wildcard principal detected (basic check)"
else
  echo "SKIP: optional guardrails (set RUN_OPTIONAL_GUARDS=true to run 9-10)"
fi

if [[ "$RUN_INFO_CHECKS" == "true" ]]; then
  echo "INFO: additional EC2/RDS/VPC/IAM/SG/Secrets checks"
  set +e

  # EC2 - Instance Profile Checks
  echo "INFO: Describe EC2 instances by Name tag (Instance ID lookup)"
  aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$INSTANCE_NAME_TAG" \
    --query "Reservations[].Instances[].InstanceId"

  echo "INFO: Describe EC2 instance profile ARN"
  aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query "Reservations[].Instances[].IamInstanceProfile.Arn"

  echo "INFO: RDS instance status"
  aws rds describe-db-instances \
    --db-instance-identifier "$DB_ID" \
    --query "DBInstances[].DBInstanceStatus"

  echo "INFO: RDS endpoint"
  aws rds describe-db-instances \
    --db-instance-identifier "$DB_ID" \
    --query "DBInstances[].Endpoint"

  echo "INFO: EC2 instance profile ARN (text output)"
  aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --query "Reservations[].Instances[].IamInstanceProfile.Arn" \
    --output text

  echo "INFO: EC2 instance profile (json)"
  aws ec2 describe-instances \
    --region "$REGION" \
    --instance-ids "$INSTANCE_ID" \
    --query "Reservations[0].Instances[0].IamInstanceProfile" \
    --output json

  # VPC Checks
  echo "INFO: RDS DB subnet groups (subnet placement)"
  aws rds describe-db-subnet-groups \
    --region "$REGION" \
    --query "DBSubnetGroups[].{Name:DBSubnetGroupName,Vpc:VpcId,Subnets:Subnets[].SubnetIdentifier}" \
    --output table

  # IAM
  echo "INFO: IAM attached role policies"
  aws iam list-attached-role-policies \
    --role-name "$ROLE_NAME" \
    --output table

  echo "INFO: IAM managed policy document (SecretsManagerReadWrite)"
  aws iam get-policy-version \
    --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite \
    --version-id v1 \
    --output json

  echo "INFO: IAM instance profile -> role name"
  aws iam get-instance-profile \
    --instance-profile-name "$PROFILE_NAME" \
    --query "InstanceProfile.Roles[].RoleName" \
    --output text

  # Security Groups
  echo "INFO: List all security groups"
  aws ec2 describe-security-groups \
    --region "$REGION" \
    --query "SecurityGroups[].{GroupId:GroupId,Name:GroupName,VpcId:VpcId}" \
    --output table

  echo "INFO: RDS security group rules (filtered)"
  aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=$RDS_SG_NAME" \
    --query "SecurityGroups[].IpPermissions"

  echo "INFO: RDS security groups attached to DB instance"
  aws rds describe-db-instances \
    --db-instance-identifier "$RDS_SG_DB_ID" \
    --region "$REGION" \
    --query "DBInstances[].VpcSecurityGroups[].VpcSecurityGroupId" \
    --output table

  # Secrets Manager
  echo "INFO: List Secrets Manager secrets"
  aws secretsmanager list-secrets \
    --region "$REGION" \
    --query "SecretList[].{Name:Name,ARN:ARN,Rotation:RotationEnabled}" \
    --output table

  echo "INFO: Get secret value (lab)"
  aws secretsmanager get-secret-value \
    --secret-id "$SECRET_ID"

  echo "INFO: Describe secret ARN"
  aws secretsmanager describe-secret \
    --secret-id "$SECRET_ID" \
    --region "$REGION" \
    --query ARN \
    --output text

  echo "INFO: Get secret resource policy"
  aws secretsmanager get-resource-policy \
    --secret-id "$SECRET_ID" \
    --region "$REGION" \
    --output json

  # WARNING - Get secret value (lab-only)
  echo "INFO: WARNING - get secret value (lab-only)"
  aws secretsmanager get-secret-value \
    --secret-id "$SECRETS_WARNING_ID" \
    --query SecretString \
    --output text

  # Parameter Store
  echo "INFO: Parameter Store values"
  MSYS2_ARG_CONV_EXCL='*' aws ssm get-parameters \
    --names /lab/db/endpoint /lab/db/port /lab/db/name \
    --with-decryption \
    --region "$REGION"

  # CloudWatch Logs
  echo "INFO: CloudWatch log group (ASM rotation lambda)"
  MSYS2_ARG_CONV_EXCL='*' aws logs describe-log-groups \
    --region "$REGION" \
    --log-group-name-prefix "/aws/lambda/SecretsManagertaaops-lab1-asm-rotation" \
    --query 'logGroups[].logGroupName' \
    --output text

  echo "INFO: CloudWatch log group exists (ASM rotation lambda)"
  MSYS2_ARG_CONV_EXCL='*' aws logs describe-log-groups \
    --region "$REGION" \
    --log-group-name-prefix /aws/lambda/SecretsManagertaaops-lab1-asm-rotation

  # CloudWatch Alarms + Metrics
  echo "INFO: CloudWatch alarm status (rdsapp-db-errors-alarm)"
  aws cloudwatch describe-alarms \
    --alarm-names rdsapp-db-errors-alarm \
    --query "MetricAlarms[].{Name:AlarmName,State:StateValue,Actions:AlarmActions}" \
    --output table

  echo "INFO: CloudWatch metrics (Lab/RDSApp)"
  aws cloudwatch list-metrics \
    --namespace Lab/RDSApp

  # Database Checks
  echo "INFO: RDS summary table"
  aws rds describe-db-instances \
     --region "$REGION" \
     --query "DBInstances[].{DB:DBInstanceIdentifier,Engine:Engine,Public:PubliclyAccessible,Vpc:DBSubnetGroup.VpcId}" \
     --output table

  echo "INFO: RDS endpoint/port table"
  aws rds describe-db-instances \
    --region "$REGION" \
    --query "DBInstances[].{DB:DBInstanceIdentifier,Endpoint:Endpoint.Address,Port:Endpoint.Port,Public:PubliclyAccessible,VPC:DBSubnetGroup.VpcId}" \
    --output table

  set -e
else
  echo "SKIP: info checks (set RUN_INFO_CHECKS=true to run additional AWS CLI queries)"
fi

if [[ "$RUN_POST_APPLY_CHECKS" == "true" ]]; then
  echo "POST-APPLY: ALB target health"
  if [[ -n "$TARGET_GROUP_ARN" ]]; then
    aws elbv2 describe-target-health \
      --target-group-arn "$TARGET_GROUP_ARN" \
      --region "$REGION" \
      --query "TargetHealthDescriptions[].TargetHealth.State" \
      --output text
  else
    echo "SKIP: TARGET_GROUP_ARN not set"
  fi

  echo "POST-APPLY: ALB DNS checks"
  if [[ -n "$ALB_DNS" ]]; then
    curl -s -o /dev/null -w "GET / => %{http_code}\n" "http://$ALB_DNS/"
    curl -s -o /dev/null -w "GET /init => %{http_code}\n" "http://$ALB_DNS/init"
    curl -s -o /dev/null -w "GET /list => %{http_code}\n" "http://$ALB_DNS/list"
  else
    echo "SKIP: ALB_DNS not set"
  fi
else
  echo "SKIP: post-apply checks (set RUN_POST_APPLY_CHECKS=true to run)"
fi
