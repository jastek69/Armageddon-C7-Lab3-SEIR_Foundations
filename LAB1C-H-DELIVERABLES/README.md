Recommended Terraform layout for Aurora

## providers.tf/versions.tf:
AWS provider, region, default tags.

## variables.tf/locals.tf:
DB engine/class/version, instance count/AZs, usernames/passwords (prefer Secrets Manager/SSM), backup/retention toggles, storage encryption flags.
Note: `admin_ssh_cidr` is currently open (0.0.0.0/0) for setup. Tighten to your public IP (/32) before production.

## networking-rds.tf:
DB subnet group from private subnets; dedicated RDS SG allowing DB port only from app/ECS/EC2 SGs.

## vpc-endpoints.tf:
- Interface VPC endpoints for SSM, EC2 messages, SSM messages, and CloudWatch Logs.
- Endpoints are placed in private subnets and use the SSM/CW endpoint security groups.
- Resources: `aws_vpc_endpoint.ssm`, `aws_vpc_endpoint.ec2messages`, `aws_vpc_endpoint.ssmmessages`, `aws_vpc_endpoint.taaops_vpce_logs01`.

## kms.tf:
- CMK for RDS storage/logs, S3 data bucket, and Secrets Manager (via `kms:ViaService`).
- CMK `aws_kms_key.rds_s3_data` is used for RDS storage and the `jasopsoregon-s3-rds` bucket (SSE-KMS).
- ALB logs bucket uses SSE-S3 (AES256) for compatibility with log delivery.
- Optional: `kms_key_id` variable can be used later to switch to an existing CMK.

## rds-params.tf:
Cluster + instance parameter groups; option group if needed.

## rds-cluster.tf:
aws_rds_cluster with engine/version, creds via secret or managed password, backup/deletion protection/final snapshot settings, log exports, subnet group, SGs, KMS key, perf insights.

## rds-instances.tf:
aws_rds_cluster_instance (count/for_each) with instance class, AZ placement, monitoring role, parameter/option group refs.

## secrets.tf:
Secrets Manager/SSM params and (optionally) rotation.

## secrets-rotation.tf:
- Secret rotation Lambda: `SecretsManagertaaops-lab1-asm-rotation`
- Rotation schedule: every 24 hours for testing (set back to 30 days for production)
- Lambda VPC config: private subnets + `taaops_lambda_asm_sg`
- Note: do not use `manage_master_user_password = true` when using a custom rotation Lambda (service-managed secrets do not allow a custom Lambda).
- Variable: `secrets_rotation_days` controls rotation interval (set to `1` for testing, `30+` for production).

### How Secrets Manager + Lambda rotation is handled (Terraform)
This configuration uses a **custom Secrets Manager secret** plus a **rotation Lambda** (not the RDS service-managed secret). The flow is:

1) `16-secrets.tf` creates `aws_secretsmanager_secret.db_secret` and a `db_secret_version` with the initial username/password, engine, host, port, and dbname.
2) `15-database.tf` creates the Aurora cluster using `master_username` / `master_password` from variables (because we are **not** using `manage_master_user_password = true`).
3) `20-secrets-rotation.tf` deploys the rotation Lambda from `lambda/SecretsManagertaaops-lab1-asm-rotation.zip`, attaches it to the VPC, and grants Secrets Manager permission to invoke it.
4) `aws_secretsmanager_secret_rotation` links the Lambda to `db_secret` and sets the rotation interval (`secrets_rotation_days`).
5) On each rotation run, the Lambda updates the **secret** and the **DB password** in Aurora, keeping them in sync.

Key points:
- Service-managed RDS secrets (`manage_master_user_password = true`) cannot use a custom rotation Lambda.
- Rotation depends on the Lambda’s IAM permissions and network access (private subnets + security group + Secrets Manager endpoint or NAT).
- Use `secrets_rotation_days = 1` for testing; set to `30+` for production.

### CloudWatch alarms + SNS automation
- CloudWatch alarms publish to `aws_sns_topic.cloudwatch_alarms`.
- Optional email notifications use `sns_email_endpoint` (leave blank to skip the subscription).
- You can attach automation to the SNS topic (Lambda, SSM Automation, PagerDuty, etc.).
- This repo includes a basic Lambda hook: `aws_lambda_function.alarm_hook` (logs alarm payloads).

### Alarm hook pipeline (SNS → Lambda → Evidence bundle)
The alarm hook Lambda performs these steps when a CloudWatch alarm fires:
1) Parses alarm metadata from the SNS payload.
2) Runs a CloudWatch Logs Insights query (via `StartQuery`/`GetQueryResults`).
3) Fetches config from SSM Parameter Store and credentials metadata from Secrets Manager.
4) Calls Bedrock Runtime to generate a brief report (if `bedrock_model_id` is set).
5) Writes a Markdown + JSON evidence bundle to S3 (`alarm_reports_bucket_name`).
6) Triggers an SSM Automation runbook (defaults to the Terraform-created document if `automation_document_name` is empty).

Related variables:
- `alarm_reports_bucket_name`
- `alarm_logs_group_name`
- `alarm_logs_insights_query`
- `alarm_ssm_param_name`
- `alarm_secret_id` (optional override; defaults to the Terraform DB secret ARN)
- `automation_document_name`
- `automation_parameters_json`
- `bedrock_model_id`

### Bedrock Auto Incident Report Lambda (23-bedrock_autoreport.tf)
Environment variables used by `aws_lambda_function.galactus_ir_lambda01`:
- `REPORT_BUCKET`: S3 bucket for JSON + Markdown reports.
- `APP_LOG_GROUP`: CloudWatch Logs group for app logs (ensure it matches your app log group name).
- `WAF_LOG_GROUP`: CloudWatch Logs group for WAF logs (only if WAF logging → CloudWatch).
- `SECRET_ID`: Secrets Manager secret name/ARN for DB creds (e.g., `taaops/rds/mysql`).
- `SSM_PARAM_PATH`: Parameter Store path for DB config (e.g., `/lab/db/`).
- `BEDROCK_MODEL_ID`: Bedrock model ID (leave blank until ready).
- `SNS_TOPIC_ARN`: SNS topic for “Report Ready” notifications.

Report outputs (S3 + SNS):
- S3 keys are written under `reports/`:
  - JSON evidence bundle: `reports/ir-<incident_id>.json`
  - Markdown report: `reports/ir-<incident_id>.md`
- SNS message payload:
  - `bucket`, `json_key`, `markdown_key`, `incident_id`

AWS documentation (links):
```
https://docs.aws.amazon.com/bedrock/latest/userguide/what-is-bedrock.html
https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html
https://docs.aws.amazon.com/lambda/latest/dg/welcome.html
https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/AnalyzingLogData.html
https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html
https://docs.aws.amazon.com/systems-manager/latest/userguide/automation-documents.html
```

### SSM Automation document
[SSM Agent](https://docs.aws.amazon.com/systems-manager/latest/userguide/install-plugin-windows.html)
[SSM Plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-setting-up-console-access.html)
- Terraform creates `aws_ssm_document.alarm_report_runbook` with a default incident report template.
- Lambda passes `IncidentId`, `AlarmName`, and S3 report keys to the runbook.

## outputs.tf:
Cluster and reader endpoints, SG ID, subnet group name, secret ARN.


# IAM
AmazonSSMManagedInstance
CloudWatchAgentServerPolicy
taaops-armageddon-lab-policy
    - TODO: verify these managed/inline policies are attached to the instance role and in effect.
    - KMS: Write // All resources // kms:ViaService = secretsmanager.us-west-2.amazonaws.com
    - Secrets Manager // Read us-west-2
    - Systems Manager // Read us-west-2



# Logs and S3 Buckets
- RDS data bucket: `jasopsoregon-s3-rds`
- ALB logs bucket: `jasopsoregon-alb-logs`
- ALB access logs prefix: `alb/taaops`
- Log path format: `s3://jasopsoregon-alb-logs/alb/taaops/AWSLogs/<account-id>/...`
- ALB log delivery policy is scoped to `data.aws_caller_identity.taaops_self01` and `aws_lb.taaops_lb01`.
- Recommended: add S3 lifecycle rules to expire or transition ALB logs (e.g., expire after 30–90 days or transition to Glacier).
- Recommended: set retention expectations in documentation and keep logs bucket private with public access blocked.

# WAF Logging (14b-waf-logging.tf)
- `waf_log_destination` supports:
  - `cloudwatch` (WAF -> CloudWatch Logs). Log group name must start with `aws-waf-logs-`.
  - `firehose` (WAF -> Kinesis Firehose -> S3). Use this for S3 storage (WAF does not support direct S3 logging).
- `waf_log_retention_days` controls log retention when using CloudWatch Logs.

# Post-Apply Verification Checklist
- Confirm ALB targets are healthy (ELB target group health is `healthy`).
- Confirm app responds on the ALB DNS:
  - `GET /` returns 200
  - `GET /init` initializes DB and returns 200
  - `GET /list` returns HTML list
- Confirm Secrets Manager secret exists and rotation is enabled.
- Confirm SSM document `taaops-incident-report` is Active.
- Confirm SNS topic `taaops-cloudwatch-alarms` has Lambda + email subscriptions.

Example sanity check run:
```
RUN_POST_APPLY_CHECKS=true \
TARGET_GROUP_ARN="arn:aws:elasticloadbalancing:us-west-2:015195098145:targetgroup/taaops-lb-tg80/39344a5264d40de8" \
ALB_DNS="taaops-load-balancer-989477164.us-west-2.elb.amazonaws.com" \
./sanity_check.sh
```

### Bedrock Invoke Test (Claude)
The test script reads values from environment variables so you can switch regions/models quickly.
Defaults:
- `AWS_REGION`: `us-east-1`
- `BEDROCK_MODEL_ID`: `anthropic.claude-3-haiku-20240307-v1:0`
- `BEDROCK_PROMPT`: `Describe the purpose of a 'hello world' program in one line.`

Example:
```
AWS_REGION=us-west-2 \
BEDROCK_MODEL_ID="anthropic.claude-3-haiku-20240307-v1:0" \
BEDROCK_PROMPT="Say hello in one line." \
python python/bedrock_invoke_test_claude.py
```

### Run Remote Checks on the EC2 (SSM)
Remote checks must run on the instance (they validate the instance role directly). Steps:
1) Start an SSM session:
```
aws ssm start-session --target <instance-id> --region us-west-2
```
2) On the instance, install the script:
```
cd /home/ec2-user
# paste the contents of sanity_check.sh from this repo into the file:
cat > sanity_check.sh <<'EOF'
<paste the file contents here>
EOF
chmod +x sanity_check.sh
```
3) Run remote checks:
```
RUN_REMOTE_CHECKS=true ./sanity_check.sh
```

Notes:
- `RUN_REMOTE_CHECKS=true` will auto-skip if not running on EC2.
- If you prefer copying instead of pasting, use `scp` or `aws ssm send-command` from your local terminal (not inside the EC2 session).

Optional: Fetch the script from S3 instead of pasting
1) Upload from your local terminal:
```
aws s3 cp sanity_check.sh s3://<your-bucket>/tools/sanity_check.sh
```
2) On the EC2 instance (SSM session):
```
cd /home/ec2-user
aws s3 cp s3://<your-bucket>/tools/sanity_check.sh ./sanity_check.sh
chmod +x ./sanity_check.sh
RUN_REMOTE_CHECKS=true ./sanity_check.sh
```

Optional: Use a pre-signed URL (no S3 permissions on the instance)
1) From your local terminal:
```
aws s3 presign s3://<your-bucket>/tools/sanity_check.sh --expires-in 3600
```
2) On the EC2 instance (SSM session), download via curl:
```
cd /home/ec2-user
curl -o sanity_check.sh "<presigned-url>"
chmod +x ./sanity_check.sh
RUN_REMOTE_CHECKS=true ./sanity_check.sh
```

### Test the Incident Report Pipeline (Manual)
1) Create a test alarm payload:
```
cat > ./scripts/alarm.json <<'EOF'
{
  "AlarmName": "manual-test-alarm",
  "AlarmDescription": "Manual test to trigger incident report pipeline",
  "NewStateValue": "ALARM",
  "OldStateValue": "OK",
  "StateChangeTime": "2026-02-01T12:00:00Z",
  "MetricName": "RdsAppDbErrors",
  "Namespace": "Lab/RDSApp",
  "Statistic": "Sum",
  "Period": 60,
  "EvaluationPeriods": 1,
  "Threshold": 1,
  "ComparisonOperator": "GreaterThanOrEqualToThreshold"
}
EOF
```

2) Publish to the report SNS topic:
```
REPORT_TOPIC_ARN="$(aws sns list-topics --region us-west-2 \
  --query "Topics[?contains(TopicArn,'taaops-ir-reports-topic')].TopicArn" \
  --output text)"

aws sns publish \
  --topic-arn "$REPORT_TOPIC_ARN" \
  --message file://scripts/alarm.json \
  --region us-west-2
```

3) List the generated reports in S3:
```
REPORT_BUCKET="$(terraform output -raw galactus_ir_reports_bucket)"
aws s3 ls "s3://$REPORT_BUCKET/reports/" --region us-west-2
```

4) View the latest Markdown report:
```
aws s3 cp "s3://$REPORT_BUCKET/reports/ir-manual-test-alarm-<timestamp>.md" -
```

## Auto-IR Runbook (Human + Amazon Bedrock Incident Response)
Purpose: This runbook defines how a human on-call engineer uses the Bedrock-generated incident report safely, verifies it against raw evidence, and produces a final, auditable incident artifact.

Core rule: Bedrock accelerates analysis. Humans own correctness.

### Preconditions
- Alarm triggered and SNS -> Lambda -> S3 pipeline completed.
- Report artifacts exist in S3 (`ir-*.md` + `ir-*.json`).
- Access to CloudWatch Logs, CloudWatch Alarms, SSM Parameter Store, and Secrets Manager.

### Step 1: Retrieve the report and evidence bundle
```
REPORT_BUCKET="$(terraform output -raw galactus_ir_reports_bucket)"
aws s3 ls "s3://$REPORT_BUCKET/reports/" --region us-west-2
aws s3 cp "s3://$REPORT_BUCKET/reports/ir-<incident_id>.md" ./ir-report.md
aws s3 cp "s3://$REPORT_BUCKET/reports/ir-<incident_id>.json" ./ir-evidence.json
```

### Step 2: Verify alarm metadata (source of truth)
- Open the alarm in CloudWatch and confirm:
  - Alarm name, metric, threshold, evaluation periods.
  - State transitions and timestamps.
```
aws cloudwatch describe-alarms \
  --alarm-names "<alarm-name>" \
  --region us-west-2 \
  --output table
```

### Step 3: Verify logs evidence (raw)
- App logs (CloudWatch Logs Insights):
```
aws logs start-query \
  --log-group-name "/aws/ec2/rdsapp" \
  --start-time <epoch-start> \
  --end-time <epoch-end> \
  --query-string "fields @timestamp, @message | sort @timestamp desc | limit 50" \
  --region us-west-2
```
- WAF logs (if enabled; CloudWatch destination):
```
aws logs start-query \
  --log-group-name "aws-waf-logs-<project>-webacl01" \
  --start-time <epoch-start> \
  --end-time <epoch-end> \
  --query-string "fields @timestamp, action, httpRequest.clientIp as clientIp, httpRequest.uri as uri | stats count() as hits by action, clientIp, uri | sort hits desc | limit 25" \
  --region us-west-2
```
- Confirm the report’s summary matches raw logs (timestamps, counts, key errors).

### Step 4: Verify config sources used for recovery
- Parameter Store values:
```
aws ssm get-parameters \
  --names /lab/db/endpoint /lab/db/port /lab/db/name \
  --with-decryption \
  --region us-west-2
```
- Secrets Manager metadata:
```
aws secretsmanager describe-secret \
  --secret-id "taaops/rds/mysql" \
  --region us-west-2
```
- Confirm that the report references the correct secret name/ARN and SSM path.

### Step 5: Human review + corrections
- Identify any mismatch between the report and evidence.
- Add corrections directly in the Markdown report:
  - Root cause summary (what actually failed).
  - Timeline accuracy (when it started and recovered).
  - Actions taken and validation.
  - Preventive actions.

### Step 6: Finalize and archive
- Save the corrected report locally and re-upload to S3:
```
aws s3 cp ./ir-report.md "s3://$REPORT_BUCKET/reports/ir-<incident_id>-final.md" --region us-west-2
```
- Optional: store a short summary to a ticketing system or change log.

### Checklist (human-owned)
- [ ] Alarm details verified against CloudWatch
- [ ] Logs evidence verified against CloudWatch Logs
- [ ] Parameter Store and Secrets verified
- [ ] Report corrected for accuracy
- [ ] Final report archived with “-final” suffix
