## Auto-IR Runbook (Human + Amazon Bedrock Incident Response)
Purpose: This runbook defines how a human on-call engineer uses the Bedrock-generated incident report safely, verifies it against raw evidence, and produces a final, auditable incident artifact.

Core rule: Bedrock accelerates analysis. Humans own correctness.

## Quick Reference
- Trigger: Alarm → SNS → Lambda → Bedrock → S3 → SNS “Report Ready”
- S3 outputs:
  - `reports/ir-<incident_id>.json`
  - `reports/ir-<incident_id>.md`
- Retrieve:
  - `REPORT_BUCKET="$(terraform output -raw galactus_ir_reports_bucket)"`
  - `aws s3 ls "s3://$REPORT_BUCKET/reports/" --region us-west-2`
  - `aws s3 cp "s3://$REPORT_BUCKET/reports/ir-<incident_id>.md" ./ir-report.md`
- Verify:
  - CloudWatch alarm + logs (app/WAF)
  - SSM `/lab/db/*` + Secrets Manager `taaops/rds/mysql`
- Finalize:
  - `aws s3 cp ./ir-report.md "s3://$REPORT_BUCKET/reports/ir-<incident_id>-final.md" --region us-west-2`
- Emergency shortcut (pull latest report):
  - `REPORT_BUCKET="$(terraform output -raw galactus_ir_reports_bucket)"`
  - `LATEST_MD="$(aws s3 ls "s3://$REPORT_BUCKET/reports/" --region us-west-2 | awk '/\\.md$/ {print $4}' | tail -n 1)"`
  - `aws s3 cp "s3://$REPORT_BUCKET/reports/$LATEST_MD" ./ir-report.md`
  - Open in editor:
    - `code ./ir-report.md` (VS Code)
    - `notepad ./ir-report.md` (Windows)
    - `nano ./ir-report.md` (Linux/macOS)

Where Bedrock runs:
- `taaops-ir-reporter01` Lambda (not in SSM)

Trigger path:
- Alarm → SNS → Lambda → Bedrock → S3 → SNS “Report Ready”

Inputs:
- Alarm payload
- CloudWatch Logs Insights queries (app + WAF)
- SSM Parameter Store path: `/lab/db/`
- Secrets Manager secret: `taaops/rds/mysql`

Outputs:
- S3 `reports/ir-<incident_id>.json` (evidence bundle)
- S3 `reports/ir-<incident_id>.md` (report)
- SNS message with `{bucket, json_key, markdown_key, incident_id}`

Fallback behavior:
- If Bedrock fails or is not configured, report is still generated with a placeholder summary.

## Runbook Steps (Human-Validated)
### 1) Retrieve the report and evidence bundle
```
REPORT_BUCKET="$(terraform output -raw galactus_ir_reports_bucket)"
aws s3 ls "s3://$REPORT_BUCKET/reports/" --region us-west-2
aws s3 cp "s3://$REPORT_BUCKET/reports/ir-<incident_id>.md" ./ir-report.md
aws s3 cp "s3://$REPORT_BUCKET/reports/ir-<incident_id>.json" ./ir-evidence.json
```

### 2) Verify alarm metadata (source of truth)
```
aws cloudwatch describe-alarms \
  --alarm-names "<alarm-name>" \
  --region us-west-2 \
  --output table
```
Confirm alarm name, metric, threshold, and state transitions match the report.

### 3) Verify logs evidence (raw)
App logs (CloudWatch Logs Insights):
```
aws logs start-query \
  --log-group-name "/aws/ec2/rdsapp" \
  --start-time <epoch-start> \
  --end-time <epoch-end> \
  --query-string "fields @timestamp, @message | sort @timestamp desc | limit 50" \
  --region us-west-2
```
WAF logs (if CloudWatch destination enabled):
```
aws logs start-query \
  --log-group-name "aws-waf-logs-<project>-webacl01" \
  --start-time <epoch-start> \
  --end-time <epoch-end> \
  --query-string "fields @timestamp, action, httpRequest.clientIp as clientIp, httpRequest.uri as uri | stats count() as hits by action, clientIp, uri | sort hits desc | limit 25" \
  --region us-west-2
```
Confirm the report’s counts, timestamps, and key errors align with raw logs.

### 4) Verify configuration sources used for recovery
Parameter Store:
```
aws ssm get-parameters \
  --names /lab/db/endpoint /lab/db/port /lab/db/name \
  --with-decryption \
  --region us-west-2
```
Secrets Manager:
```
aws secretsmanager describe-secret \
  --secret-id "taaops/rds/mysql" \
  --region us-west-2
```
Confirm the report references the correct secret name and SSM path.

### 5) Human review and corrections
- Correct any mismatches between report and evidence.
- Fill in: root cause, timeline accuracy, actions taken, and preventive actions.

### 6) Finalize and archive
```
aws s3 cp ./ir-report.md "s3://$REPORT_BUCKET/reports/ir-<incident_id>-final.md" --region us-west-2
```

## SSM Automation (Scope)
SSM is used for orchestration and optional diagnostics only.
- It does not call Bedrock.
- It can record report keys and optionally start an ASG refresh.

## Checklist
- [ ] Alarm details verified against CloudWatch
- [ ] Logs evidence verified against CloudWatch Logs
- [ ] Parameter Store and Secrets verified
- [ ] Report corrected for accuracy
- [ ] Final report archived with “-final” suffix

## Notes and Glossary
- **Automation boundary**: Bedrock runs in Lambda (`taaops-ir-reporter01`). SSM Automation only orchestrates diagnostics (no Bedrock calls).
- **Incident ID**: A slug derived from the alarm name + timestamp (used in report filenames).
- **Evidence bundle**: `reports/ir-<incident_id>.json` (raw alarm, logs, SSM, secret metadata).
- **Markdown report**: `reports/ir-<incident_id>.md` (human-readable summary).
- **Report Ready SNS**: Message with `{bucket, json_key, markdown_key, incident_id}` for downstream workflows.
- **Log groups**:
  - App logs: `/aws/ec2/rdsapp`
  - WAF logs: `aws-waf-logs-<project>-webacl01` (if CloudWatch destination enabled)
- **SSM path**: `/lab/db/` (DB endpoint/port/name)
- **Secrets Manager**: `taaops/rds/mysql`

## Troubleshooting
- **Lambda error: Log group does not exist**
  - Ensure the app log group is `/aws/ec2/rdsapp` (CloudWatch Agent default).
  - If the app is not emitting logs yet, the report will still generate with empty log results.
- **Lambda error: AccessDenied on SNS publish**
  - Confirm the Lambda role includes `sns:Publish` on the report topic.
- **No report objects in S3**
  - Verify the Lambda ran and has `s3:PutObject` on the report bucket.
  - Check CloudWatch Logs for the Lambda: `/aws/lambda/taaops-ir-reporter01`.
- **Bedrock summary is missing**
  - Ensure `BEDROCK_MODEL_ID` is set and the role has `bedrock:InvokeModel`.
  - If Bedrock fails, the report should still be generated with a placeholder summary.
