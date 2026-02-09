# Translation Module Usage Guide

## Overview
The translation module provides automated English ↔ Japanese translation for incident reports using Amazon Translate. This module is integrated into the Tokyo region infrastructure to support operational reporting requirements.

## Architecture
```
Incident Report → S3 Input Bucket → Lambda Trigger → Amazon Translate → S3 Output Bucket → Final Reports Directory
```

### Workflow Process
1. **Upload**: Place incident report in the translation input bucket
2. **Trigger**: S3 event automatically triggers Lambda function
3. **Detection**: Lambda detects source language (English or Japanese)
4. **Translation**: Amazon Translate processes the document
5. **Storage**: Translated content stored in output bucket temporarily
6. **Organization**: Both English and Japanese versions placed in `/reports` directory

## How to Use

### 1. Upload Incident Report
Upload your incident report to the translation input bucket:
- **Bucket**: Available in Tokyo outputs as `translation_input_bucket_name`
- **Supported Formats**: `.txt`, `.md`, `.json` files
- **File Size**: Up to 5KB per chunk (Lambda handles larger files automatically)

### 2. Automatic Processing
The system automatically:
- Detects if document is English or Japanese
- Translates to the other language
- Stores both versions in organized directory structure

### 3. Access Translated Reports
Find your translated reports in the main reports bucket:
```
/reports/
├── incident_report_english_20240201_123456.txt
├── incident_report_japanese_20240201_123456.txt
├── security_alert_english_20240201_124530.md
└── security_alert_japanese_20240201_124530.md
```

## Input/Output Examples

### Input (English Incident Report)
```
INCIDENT REPORT: Database Connection Failure
Date: 2024-02-01 12:34:56 UTC
Severity: HIGH

Description:
The primary Aurora MySQL database in the Tokyo region 
experienced connection timeouts starting at 12:30 UTC.
Applications were unable to establish new connections.

Impact:
- Web applications returned 500 errors
- API endpoints became unresponsive
- Estimated 15 minutes downtime

Resolution:
Restarted the Aurora cluster and verified connections.
All services restored by 12:45 UTC.
```

### Output (Japanese Translation)
```
インシデント報告：データベース接続障害
日付：2024-02-01 12:34:56 UTC
重要度：高

説明：
東京リージョンのプライマリAurora MySQLデータベースが
12:30 UTCから接続タイムアウトを経験しました。
アプリケーションは新しい接続を確立できませんでした。

影響：
- Webアプリケーションが500エラーを返しました
- APIエンドポイントが応答しなくなりました
- 推定15分間のダウンタイム

解決策：
Auroraクラスターを再起動し、接続を確認しました。
すべてのサービスは12:45 UTCまでに復旧しました。
```

## Module Configuration

### Variables Used
```hcl
# In tokyo/main.tf
module "tokyo_translation" {
  source = "../modules/translation"
  
  region                = "ap-northeast-1"
  input_bucket_name     = "taaops-translate-tokyo-input"
  output_bucket_name    = "taaops-translate-tokyo-output"
  reports_bucket_name   = module.tokyo_s3_logging.primary_bucket_name
  reports_bucket_arn    = module.tokyo_s3_logging.primary_bucket_arn
  
  # Language settings
  source_language       = "en"  # Default source
  target_language       = "ja"  # Target language
  lambda_timeout        = 300   # 5 minutes
  log_retention_days    = 14
}
```

### Outputs Available
- `translation_input_bucket_name`: Where to upload reports
- `translation_input_bucket_arn`: Input bucket ARN
- `translation_output_bucket_name`: Temporary translated storage
- `translation_lambda_function_name`: Function name for monitoring
- `translation_lambda_function_arn`: Function ARN for permissions

## Monitoring & Logging

### CloudWatch Logs
Lambda execution logs are available at:
```
/aws/lambda/taaops-translate-ap-northeast-1-processor
```

### Error Handling
The Lambda function includes robust error handling:
- Translation failures include original content
- Large documents automatically chunked
- Binary files copied without translation
- Detailed logging for troubleshooting

## Best Practices

### 1. File Naming
Use descriptive filenames:
```
incident_report_db_failure_20240201.txt
security_alert_suspicious_activity_20240201.md
capacity_planning_report_q1_2024.txt
```

### 2. Content Structure
Format reports with clear sections:
- **Title/Summary**
- **Date/Time** 
- **Severity Level**
- **Description**
- **Impact Assessment**
- **Resolution Steps**

### 3. File Size Management
- Keep individual files under 4KB for optimal performance
- For larger reports, split into logical sections
- Use bullet points and clear formatting

## Integration with Other Systems

### Incident Response Workflow
1. Create incident report in standard format
2. Upload to translation input bucket
3. Automated translation occurs within minutes
4. Both English and Japanese versions available in `/reports`
5. Share appropriate language version with stakeholders

### Integration Points
- **S3 Events**: Automatic triggering
- **CloudWatch**: Monitoring and alerting
- **IAM**: Secure access control
- **KMS**: Encryption at rest
- **Route53**: Regional DNS resolution

## Troubleshooting

### Common Issues
1. **Translation not triggered**: Check S3 event configuration
2. **Translation quality**: Amazon Translate optimized for technical content
3. **File format errors**: Ensure text-based formats (.txt, .md, .json)
4. **Permission errors**: Verify IAM roles and bucket policies

### Monitoring Commands
```bash
# Check recent Lambda executions
aws logs describe-log-streams --log-group-name "/aws/lambda/taaops-translate-ap-northeast-1-processor"

# List files in input bucket
aws s3 ls s3://your-input-bucket-name/

# List translated reports
aws s3 ls s3://your-reports-bucket-name/reports/
```

## Scripted Testing (Local CLI Helpers)

Use these helper scripts from repository root to test the full S3 -> Lambda -> Translate -> S3 workflow and save local artifacts.

### Single File Roundtrip
Uploads one local file to the translation input bucket, waits for translated output object, and downloads it locally.

```bash
python ./python/translate_via_s3.py \
  --input-bucket taaops-translate-input \
  --output-bucket taaops-translate-output \
  --source-file Tokyo/audit/3b_audit.txt \
  --region ap-northeast-1
```

Default local output path:
- `LAB3-DELIVERABLES/results/<source_basename>_translated<ext>`

### Batch Translation (Audit Directory)
Processes all matching files in `Tokyo/audit` and downloads translated outputs locally.

```bash
python ./python/translate_batch_audit.py \
  --input-bucket taaops-translate-input \
  --output-bucket taaops-translate-output \
  --source-dir Tokyo/audit \
  --glob "*.txt" \
  --region ap-northeast-1
```

Default local batch output path:
- `LAB3-DELIVERABLES/results/translations/`

### Useful Optional Flags
- `--s3-key`: set custom input key for single-file upload (default `audit/<basename>`).
- `--download-to`: set custom local download path for single-file output.
- `--key-prefix`: set input S3 key prefix for batch mode (default `audit`).
- `--timeout-seconds`: maximum wait for translated object (default `180`).
- `--poll-seconds`: polling interval while waiting (default `5`).

## Security Considerations
- All buckets have public access blocked
- IAM roles follow principle of least privilege
- Server-side encryption enabled on all S3 buckets
- CloudWatch logs retained for 14 days
- Translation API calls logged for audit purposes
