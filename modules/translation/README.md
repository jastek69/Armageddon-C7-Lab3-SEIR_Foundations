### Translation Module

Creates an Amazon Translate service with S3-triggered Lambda function for automated document translation between English and Japanese, specifically designed for incident reports.

#### Features:
- S3 input/output buckets for document processing
- Lambda function triggered on file upload
- Automatic English ↔ Japanese translation
- Integration with /reports directory structure  
- Support for multiple document formats
- Incident report specific processing

#### Usage:
```hcl
module "translation" {
  source = "../modules/translation"
  
  region = var.aws_region
  common_tags = local.common_tags
  
  # Optional customization
  input_bucket_name = "incident-reports-input-${var.aws_region}"
  output_bucket_name = "incident-reports-output-${var.aws_region}"
  reports_bucket_id = module.s3_logging.app_logs_bucket_id  # Where final reports go
}
```

#### Architecture:
```
Incident Report → S3 Input Bucket → Lambda Trigger → Amazon Translate → S3 Output Bucket → /reports/
                                                                                      ├── english/
                                                                                      └── japanese/
```

#### Scripted Testing
- End-to-end local test commands (single-file and batch) are documented in `modules/translation/USAGE.md`.
- Helper scripts:
  - `python/translate_via_s3.py`
  - `python/translate_batch_audit.py`
- Default local downloaded outputs:
  - `LAB3-DELIVERABLES/results/`
  - `LAB3-DELIVERABLES/results/translations/`
