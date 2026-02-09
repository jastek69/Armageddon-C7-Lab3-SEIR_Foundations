# Translation Module Integration Examples

## Tokyo Region Integration (Primary)
The translation module is integrated into the Tokyo region as the primary location for incident report processing.

### Add to tokyo/main.tf
```hcl
# Translation Module (Tokyo) - English ⇆ Japanese Incident Reports
module "tokyo_translation" {
  source = "../modules/translation"
  
  region                = var.aws_region
  common_tags = {
    ManagedBy = "Terraform" 
    Region    = "Tokyo"
    Purpose   = "IncidentReportTranslation"
    Project   = var.project_name
  }
  
  # S3 bucket configuration
  input_bucket_name     = "${local.name_prefix}-translate-input"
  output_bucket_name    = "${local.name_prefix}-translate-output"
  reports_bucket_name   = module.tokyo_s3_logging.primary_bucket_name
  reports_bucket_arn    = module.tokyo_s3_logging.primary_bucket_arn
  
  # Translation settings
  source_language       = "en"  # Default to English
  target_language       = "ja"  # Target Japanese
  lambda_timeout        = 300   # 5 minutes for document processing
  log_retention_days    = 14
}
```

## São Paulo Region Integration (Optional)
If you need translation services in São Paulo as well, add similar configuration.

### Add to saopaulo/main.tf
```hcl
# Translation Module (São Paulo) - Portuguese ⇆ English Reports
module "saopaulo_translation" {
  source = "../modules/translation"
  
  region                = var.aws_region
  common_tags = {
    ManagedBy = "Terraform"
    Region    = "SaoPaulo"  
    Purpose   = "IncidentReportTranslation"
    Project   = var.project_name
  }
  
  # S3 bucket configuration
  input_bucket_name     = "${local.name_prefix}-translate-input"
  output_bucket_name    = "${local.name_prefix}-translate-output"
  reports_bucket_name   = module.saopaulo_s3_logging.primary_bucket_name
  reports_bucket_arn    = module.saopaulo_s3_logging.primary_bucket_arn
  
  # Translation settings - Portuguese ⇆ English
  source_language       = "pt"  # Portuguese
  target_language       = "en"  # English
  lambda_timeout        = 300
  log_retention_days    = 14
}
```

## Cross-Region Translation Workflow
For true multi-regional incident response:

### Scenario 1: Tokyo → São Paulo
1. Tokyo team uploads Japanese incident report
2. Auto-translated to English in Tokyo
3. English version shared with São Paulo team
4. São Paulo can translate to Portuguese if needed

### Scenario 2: Central Processing
1. All regions send reports to Tokyo translation service
2. Tokyo provides both English and Japanese versions
3. English versions distributed to other regions
4. Regional teams translate from English to local languages

## Custom Language Configurations

### Tokyo (Japanese Business)
```hcl
source_language = "en"    # English input
target_language = "ja"    # Japanese output
```

### São Paulo (Portuguese Business) 
```hcl
source_language = "pt"    # Portuguese input
target_language = "en"    # English output for international coordination
```

### European Region (Future)
```hcl
source_language = "en"    # English input
target_language = "de"    # German output (for EU operations)
```

## Integration with Existing Infrastructure

### Module Dependencies
```hcl
# Translation module requires:
1. Regional S3 logging module (for reports bucket)
2. VPC and networking (for Lambda execution)
3. IAM roles and policies (for permissions)
4. CloudWatch logging (for monitoring)
```

### Resource Naming Patterns
```hcl
# Tokyo resources
taaops-translate-tokyo-ap-northeast-1-input
taaops-translate-tokyo-ap-northeast-1-output
taaops-translate-tokyo-ap-northeast-1-processor

# São Paulo resources  
taaops-translate-saopaulo-sa-east-1-input
taaops-translate-saopaulo-sa-east-1-output
taaops-translate-saopaulo-sa-east-1-processor
```

## Deployment Order

### Initial Setup (Tokyo only)
1. Deploy Tokyo base infrastructure
2. Deploy translation module in Tokyo
3. Test English ↔ Japanese workflow

### Multi-Region Expansion
1. Deploy São Paulo base infrastructure  
2. Add translation module to São Paulo
3. Configure cross-region report sharing
4. Test Portuguese ↔ English workflow

### Maintenance Commands
```bash
# Initialize translation module
terraform init

# Plan translation changes
terraform plan -target=module.tokyo_translation

# Apply translation module only
terraform apply -target=module.tokyo_translation

# Test translation functionality
aws s3 cp test_report.txt s3://$(terraform output -raw translation_input_bucket_name)/
```

## Cost Considerations

### Per-Region Costs
- **S3 Storage**: Input/output buckets (~$0.023/GB)
- **Lambda Execution**: ~$0.20 per 1M requests
- **Amazon Translate**: ~$15.00 per 1M characters
- **CloudWatch Logs**: ~$0.50/GB ingested

### Estimated Monthly Costs (100 reports/month, 2KB avg)
- Tokyo Translation: ~$5-10/month
- São Paulo Translation: ~$5-10/month  
- Cross-region data transfer: ~$1-2/month

## Security & Compliance

### Data Residency
- Tokyo: Reports stay in ap-northeast-1
- São Paulo: Reports stay in sa-east-1
- Cross-region: Only metadata shared via outputs

### Encryption
- S3: Server-side encryption (AES-256)
- Lambda: Environment variables encrypted
- Translate API: In-transit encryption (TLS 1.2)

### Access Control
- IAM roles: Least privilege access
- S3 buckets: Private with explicit permissions
- Lambda: VPC execution for network isolation

This modular approach allows you to start with Tokyo translation and expand to other regions as needed while maintaining consistent architecture patterns.