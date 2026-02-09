#!/usr/bin/env bash
set -euo pipefail

# Override with env vars if needed.
REGION="${REGION:-us-west-2}"
INSTANCE_ID="${INSTANCE_ID:-i-0cff400cc4f896081}"
SECRET_ID="${SECRET_ID:-taaops/lab/mysql}"
RUN_REMOTE_CHECKS="${RUN_REMOTE_CHECKS:-false}"
RUN_OPTIONAL_GUARDS="${RUN_OPTIONAL_GUARDS:-false}"
RUN_INFO_CHECKS="${RUN_INFO_CHECKS:-false}"
INSTANCE_NAME_TAG="${INSTANCE_NAME_TAG:-taaops-armageddon-lab1-public-ec2}"
DB_ID="${DB_ID:-taaops-rds}"
VPC_ID="${VPC_ID:-vpc-0650bb80688d52180}"
RDS_SG_NAME="${RDS_SG_NAME:-taaops-rds-sg}"
RDS_SG_DB_ID="${RDS_SG_DB_ID:-taaops-rds}"
SECRETS_WARNING_ID="${SECRETS_WARNING_ID:-taaops/lab/mysql}"
WRITE_REPORT="${WRITE_REPORT:-true}"
REPORT_DIR="${REPORT_DIR:-LAB1-DELIVERABLES}"
REPORT_BASENAME="${REPORT_BASENAME:-sanity_check}"
REPORT_TS="${REPORT_TS:-$(date -u +%Y%m%d_%H%M%SZ)}"
REPORT_LOG="${REPORT_LOG:-$REPORT_DIR/${REPORT_BASENAME}_${REPORT_TS}.log}"
REPORT_FILE="${REPORT_FILE:-$REPORT_DIR/${REPORT_BASENAME}_${REPORT_TS}.md}"
REPORT_JSON="${REPORT_JSON:-$REPORT_DIR/${REPORT_BASENAME}_${REPORT_TS}.jsonl}"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; exit 1; }

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

# 1) PASS/FAIL: Secret exists
echo "CHECK: secret exists"
aws secretsmanager describe-secret \
  --secret-id "$SECRET_ID" \
  --region "$REGION" >/dev/null 2>&1 \
  && pass "secret exists ($SECRET_ID)" \
  || fail "secret not found or no permission ($SECRET_ID)"

# 2) PASS/FAIL: EC2 instance has an IAM instance profile attached
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
  MSYS_NO_PATHCONV=1 aws logs describe-log-groups \
    --region "$REGION" \
    --log-group-name-prefix "/aws/lambda/SecretsManagertaaops-lab1-asm-rotation" \
    --query 'logGroups[].logGroupName' \
    --output text

  echo "INFO: CloudWatch log group exists (ASM rotation lambda)"
  aws logs describe-log-groups \
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
