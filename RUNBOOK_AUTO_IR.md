## Auto-IR Runbook (Human + Amazon Bedrock + Translation Incident Response)
Purpose: This runbook defines how a human on-call engineer uses the Bedrock-generated incident report safely, verifies it against raw evidence, and produces a final, auditable incident artifact with automatic Japanese translation for APPI compliance.

Core rule: Bedrock accelerates analysis. Humans own correctness. Translation ensures regulatory compliance.

## Quick Reference

CloudWatch Alarm → Lambda (Bedrock AI Report) → S3 Incident Reports → Translation Module (EN→JA)
                                ↓                           ↓
                    SSM Automation → Copy to Translation Input → Japanese Reports in Output Bucket
                                ↓  
                    Auto Scaling Group Refresh (if needed)

### Multi-Region Architecture
- **Tokyo (ap-northeast-1)**: Primary incident reporting, AI generation, translation hub
- **São Paulo (sa-east-1)**: Shares incident data via cross-region TGW for compliance
- **Translation Flow**: EN incident reports → Amazon Translate → JA reports for APPI compliance

### S3 Buckets and Outputs
- **Tokyo Incident Reports**: `REPORT_BUCKET="$(terraform output -raw incident_reports_bucket_name)"`
- **Translation Input**: `TRANSLATION_INPUT="$(terraform output -raw translation_input_bucket_name)"`  
- **Translation Output**: `TRANSLATION_OUTPUT="$(terraform output -raw translation_output_bucket_name)"`

### Retrieve Reports (English + Japanese)
- English reports: `aws s3 ls "s3://$REPORT_BUCKET/reports/" --region ap-northeast-1`
- Japanese translations: `aws s3 ls "s3://$TRANSLATION_OUTPUT/translated/" --region ap-northeast-1`

### Download Incident Reports
```bash
# English original
aws s3 cp "s3://$REPORT_BUCKET/reports/ir-<incident_id>.md" ./reports/IR/ir-report-en.md

# Japanese translation  
aws s3 cp "s3://$TRANSLATION_OUTPUT/translated/ir-<incident_id>-ja.md" ./reports/IR/ir-report-ja.md

# Evidence bundle
aws s3 cp "s3://$REPORT_BUCKET/reports/ir-<incident_id>.json" ./reports/IR/ir-evidence.json
```
### Verification and Finalization
- Verify: CloudWatch alarm + logs (app/WAF), SSM `/lab/db/*` + Secrets Manager `taaops/rds/mysql`  
- Finalize: `aws s3 cp ./reports/IR/ir-report-en.md "s3://$REPORT_BUCKET/reports/ir-<incident_id>-final-en.md" --region ap-northeast-1`
- Finalize (JP): `aws s3 cp ./reports/IR/ir-report-ja.md "s3://$REPORT_BUCKET/reports/ir-<incident_id>-final-ja.md" --region ap-northeast-1`

### Emergency Shortcuts
Pull latest reports (both languages):
```bash
REPORT_BUCKET="$(terraform output -raw incident_reports_bucket_name)"
TRANSLATION_OUTPUT="$(terraform output -raw translation_output_bucket_name)"

# Latest English report
LATEST_EN="$(aws s3 ls "s3://$REPORT_BUCKET/reports/" --region ap-northeast-1 | awk '/\\.md$/ {print $4}' | tail -n 1)"
aws s3 cp "s3://$REPORT_BUCKET/reports/$LATEST_EN" ./reports/IR/ir-report-en.md

# Latest Japanese translation
LATEST_JA="$(aws s3 ls "s3://$TRANSLATION_OUTPUT/translated/" --region ap-northeast-1 | awk '/\\.md$/ {print $4}' | tail -n 1)"
aws s3 cp "s3://$TRANSLATION_OUTPUT/translated/$LATEST_JA" ./reports/IR/ir-report-ja.md
```

### Translation Status Check
```bash
# Check if translation completed
aws s3 ls "s3://$TRANSLATION_OUTPUT/translated/" --region ap-northeast-1 | grep <incident_id>

# Manual translation trigger (if needed)
aws s3 cp ./reports/IR/ir-report-en.md "s3://$TRANSLATION_INPUT/incident-reports/en/ir-<incident_id>-manual.md" --region ap-northeast-1
```

### SSM Automation Integration
```bash
# Check automation execution status
aws ssm describe-automation-executions \
  --filter "Key=DocumentName,Values=taaops-tokyo-incident-report" \
  --region ap-northeast-1

# Manual SSM execution with translation
aws ssm start-automation-execution \
  --document-name "taaops-tokyo-incident-report" \
  --parameters "IncidentId=<incident_id>,AlarmName=<alarm_name>,ReportBucket=$REPORT_BUCKET,ReportJsonKey=reports/ir-<incident_id>.json,ReportMarkdownKey=reports/ir-<incident_id>.md,TranslationBucket=$TRANSLATION_INPUT" \
  --region ap-northeast-1
```
### Report Filtering and Management
```bash
REPORT_BUCKET="$(terraform output -raw incident_reports_bucket_name)"

# List ALARM report JSON files
REPORT_BUCKET="$REPORT_BUCKET" ./scripts/filter_alarm_reports.sh

# Download ALARM report JSON + MD pairs
REPORT_BUCKET="$REPORT_BUCKET" ./scripts/download_alarm_reports.sh

# Change alarm state filter (e.g., OK or INSUFFICIENT_DATA)
ALARM_STATE=OK REPORT_BUCKET="$REPORT_BUCKET" ./scripts/filter_alarm_reports.sh
ALARM_STATE=INSUFFICIENT_DATA REPORT_BUCKET="$REPORT_BUCKET" ./scripts/download_alarm_reports.sh

# Additional filters (requires jq):
# Match alarm name with a regex
ALARM_NAME_REGEX="manual-test" REPORT_BUCKET="$REPORT_BUCKET" ./scripts/filter_alarm_reports.sh
# Only reports since a Unix epoch timestamp  
ALARM_SINCE_EPOCH=1700000000 REPORT_BUCKET="$REPORT_BUCKET" ./scripts/download_alarm_reports.sh
ALARM_UNTIL_EPOCH=1700003600 REPORT_BUCKET="$REPORT_BUCKET" ./scripts/download_alarm_reports.sh
# Severity filter 
ALARM_SEVERITY=critical REPORT_BUCKET="$REPORT_BUCKET" ./scripts/filter_alarm_reports.sh
```

## Tokyo Infrastructure Components

**Where Auto-IR Runs:**
- **Primary Lambda**: `taaops-tokyo-ir-reporter` (Bedrock AI generation)
- **Translation Module**: `modules/translation/` (English ⇆ Japanese via Amazon Translate)
- **SSM Automation**: `taaops-tokyo-incident-report` (Multi-step workflow with translation trigger)

**S3 Bucket Structure:**
```
taaops-tokyo-incident-reports-<account>/
├── reports/
│   ├── ir-<incident_id>.json          # Evidence bundle
│   ├── ir-<incident_id>.md             # English report  
│   ├── ir-<incident_id>-final-en.md    # Human-reviewed English
│   └── ir-<incident_id>-final-ja.md    # Human-reviewed Japanese

taaops-translate-input-<random>/
└── incident-reports/
    └── en/
        └── ir-<incident_id>-<timestamp>.md  # Translation input 

taaops-translate-output-<random>/
└── translated/
    └── ir-<incident_id>-ja.md              # Japanese translation
```
**Trigger Path:**
```
CloudWatch Alarm → SNS → IR Lambda → Bedrock → S3 (English Report) → Translation Input
                    ↓                                                        ↓
            SSM Automation                                          Amazon Translate
                    ↓                                                        ↓  
         ASG Refresh (Optional)                              S3 (Japanese Translation)
```

**Environment Variables (Tokyo IR Lambda):**
- `REPORT_BUCKET`: S3 bucket for incident reports
- `TRANSLATION_BUCKET`: S3 bucket for translation input
- `APP_LOG_GROUP`: `/aws/ec2/rdsapp` (CloudWatch Agent default)
- `WAF_LOG_GROUP`: `aws-waf-logs-taaops-tokyo-regional-waf`
- `SECRET_ID`: `taaops/rds/mysql` (Secrets Manager)
- `SSM_PARAM_PATH`: `/lab/db/` (Parameter Store)
- `BEDROCK_MODEL_ID`: `mistral.mistral-large-3-675b-instruct`
- `SNS_TOPIC_ARN`: Tokyo IR reports topic
- `AUTOMATION_DOC_NAME`: `taaops-tokyo-incident-report`
- `AWS_REGION`: `ap-northeast-1`

**Inputs:**
- Alarm payload from CloudWatch
- CloudWatch Logs Insights queries (app + regional WAF)
- SSM Parameter Store path: `/lab/db/`  
- Secrets Manager secret: `taaops/rds/mysql`

**Outputs:**
- S3 `reports/ir-<incident_id>.json` (evidence bundle)
- S3 `reports/ir-<incident_id>.md` (English report)
- Translation input → `incident-reports/en/ir-<incident_id>-<timestamp>.md`
- Translation output → `translated/ir-<incident_id>-ja.md`
- SNS message with `{bucket, json_key, markdown_key, incident_id, translation_status}`

**Fallback Behavior:**
- If Bedrock fails: Report generated with placeholder summary
- If translation fails: English report still available, manual translation trigger available
- If SSM automation fails: Reports still generated, ASG refresh skipped

## Runbook Steps (Human-Validated + Translation)

### 1) Retrieve the report and evidence bundle (both languages)
```bash
REPORT_BUCKET="$(terraform output -raw incident_reports_bucket_name)"
TRANSLATION_OUTPUT="$(terraform output -raw translation_output_bucket_name)"

aws s3 ls "s3://$REPORT_BUCKET/reports/" --region ap-northeast-1
aws s3 ls "s3://$TRANSLATION_OUTPUT/translated/" --region ap-northeast-1

# Download English original
aws s3 cp "s3://$REPORT_BUCKET/reports/ir-<incident_id>.md" ./reports/IR/ir-report-en.md

# Download Japanese translation
aws s3 cp "s3://$TRANSLATION_OUTPUT/translated/ir-<incident_id>-ja.md" ./reports/IR/ir-report-ja.md  

# Download evidence bundle
aws s3 cp "s3://$REPORT_BUCKET/reports/ir-<incident_id>.json" ./reports/IR/ir-evidence.json
```

### 2) Verify alarm metadata (source of truth)
```bash
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
CloudFront standard logs (S3, optional; not used by Auto-IR):
```
aws s3 ls s3://taaops-cloudfront-logs-<account-id>/cloudfront/ --recursive | tail -n 5
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

### 5) Human review and corrections (bilingual)
- Compare English and Japanese reports for content accuracy
- Correct any mismatches between report and evidence in both languages
- Fill in: root cause, timeline accuracy, actions taken, and preventive actions
- Validate Japanese technical terms and translations for APPI compliance

### 6) Finalize and archive (both languages)
```bash
# English final report
aws s3 cp ./reports/IR/ir-report-en.md "s3://$REPORT_BUCKET/reports/ir-<incident_id>-final-en.md" --region ap-northeast-1

# Japanese final report  
aws s3 cp ./reports/IR/ir-report-ja.md "s3://$REPORT_BUCKET/reports/ir-<incident_id>-final-ja.md" --region ap-northeast-1
```

## Tokyo Multi-Region SSM Automation with Translation
SSM automation provides orchestration, translation triggers, and optional infrastructure recovery:
- **Translation Integration**: Automatically copies English reports to translation input bucket
- **Bilingual Template**: Incident report template includes both English and Japanese sections
- **Bedrock Integration**: Lambda calls Bedrock for AI analysis, SSM orchestrates the workflow
- **ASG Refresh**: Optional auto scaling group instance refresh for recovery
- **Cross-Region Support**: Designed for Tokyo-São Paulo multi-region architecture

## Translation Management

### Translation Status and Control
```bash
# Check translation service status
aws translate describe-text-translation-job \
  --job-id <translation-job-id> \
  --region ap-northeast-1

# Manual translation trigger (if auto-translation failed)
TRANSLATION_INPUT="$(terraform output -raw translation_input_bucket_name)"
aws s3 cp ./reports/IR/ir-report-en.md "s3://$TRANSLATION_INPUT/incident-reports/en/ir-$(date +%s)-manual.md" --region ap-northeast-1

# Check translation Lambda logs for debugging
aws logs tail /aws/lambda/taaops-translate-processor --region ap-northeast-1 --follow
```

### APPI Compliance Notes
- **Data Residency**: All incident data (original and translated) stored in ap-northeast-1 (Tokyo)
- **Language Requirements**: Critical incident reports must be available in Japanese for local compliance teams
- **Audit Trail**: Both language versions archived with final approval timestamps
- **Cross-Region**: São Paulo incidents reported to Tokyo for centralized compliance management

## Enhanced Checklist (Multi-Language + APPI Compliance)
- [ ] Alarm details verified against CloudWatch (Tokyo region)
- [ ] Logs evidence verified against CloudWatch Logs (app + regional/global WAF)  
- [ ] Parameter Store and Secrets verified (Tokyo infrastructure)
- [ ] English report corrected for accuracy
- [ ] Japanese translation reviewed for technical accuracy and APPI compliance
- [ ] Both language versions archived with "-final-en" and "-final-ja" suffixes
- [ ] Translation module status verified (input/output buckets accessible)
- [ ] SSM automation execution confirmed (if triggered)
- [ ] Cross-region data residency compliance verified (all PHI remains in Tokyo)

## Notes and Glossary (Updated for Translation)
- **Multi-Region Architecture**: Tokyo (data authority) + São Paulo (compute extension) connected via TGW
- **Translation Automation**: English incident reports → Amazon Translate → Japanese reports for regulatory compliance  
- **Incident ID**: Slug derived from alarm name + timestamp (used across both language report versions)
- **Evidence bundle**: `reports/ir-<incident_id>.json` (raw alarm, logs, SSM, secret metadata)
- **English report**: `reports/ir-<incident_id>.md` (original Bedrock-generated report)
- **Japanese report**: `translated/ir-<incident_id>-ja.md` (Amazon Translate output)
- **APPI Compliance**: All medical/personal data and incident reports stored only in Japan (ap-northeast-1)
- **Translation Module**: `modules/translation/` providing EN⇆JA via Amazon Translate service
- **SSM Enhancement**: Bilingual automation document with translation triggers + ASG refresh capability
- **Report Ready SNS**: Message with `{bucket, json_key, markdown_key, incident_id, translation_status}` for downstream workflows
- **Trigger SNS**: Dedicated topic used to invoke the Lambda (prevents recursive loops)
- **Log groups (Tokyo)**:
  - App logs: `/aws/ec2/rdsapp`
  - Regional WAF logs: `aws-waf-logs-taaops-tokyo-regional-waf` 
  - CloudFront WAF logs: `aws-waf-logs-taaops-cloudfront-waf` (us-east-1)
- **SSM path**: `/lab/db/` (DB endpoint/port/name in Tokyo)
- **Secrets Manager**: `taaops/rds/mysql` (Tokyo-based Aurora credentials)

## Troubleshooting (Enhanced for Translation + Multi-Region)
- **Lambda error: Log group does not exist**
  - Ensure the app log group is `/aws/ec2/rdsapp` (CloudWatch Agent default)
  - Verify region is ap-northeast-1 for Tokyo infrastructure
  - If the app is not emitting logs yet, the report will still generate with empty log results
- **Lambda error: AccessDenied on SNS publish**
  - Confirm the Lambda role includes `sns:Publish` on the report topic
  - Verify cross-region permissions if São Paulo incidents triggered
- **No report objects in S3**
  - Verify the Lambda ran and has `s3:PutObject` on the Tokyo incident reports bucket
  - Check CloudWatch Logs for the Lambda: `/aws/lambda/taaops-tokyo-ir-reporter`
- **Translation not working**
  - Verify Amazon Translate service permissions in Lambda role
  - Check translation input bucket has correct S3 event triggers
  - Verify translation module outputs are correct: `terraform output translation_input_bucket_name`
  - Check translate Lambda logs: `/aws/lambda/taaops-translate-processor`
- **Japanese translations inaccurate**  
  - Review Japanese technical terminology for medical/compliance context
  - Validate translation against APPI requirements for incident documentation
  - Consider manual review for critical compliance reports
- **Cross-region data residency concerns**
  - Confirm all incident data remains in ap-northeast-1 (Tokyo)
  - Verify São Paulo compute layer does not store PHI locally
  - Review TGW routing to ensure compliance data corridor
- **Bedrock summary is missing**
  - Ensure `BEDROCK_MODEL_ID` is set and the role has `bedrock:InvokeModel`
  - Verify Bedrock service availability in ap-northeast-1
  - If Bedrock fails, the report should still generate with placeholder summary in both languages
