# LAB3 Multi-Region AWS Architecture with Transit Gateway

This project implements a multi-region AWS infrastructure across Tokyo (ap-northeast-1) and São Paulo (sa-east-1) connected via AWS Transit Gateway with inter-region peering.

## Architecture Overview

### Regional Separation
- **Global**: Route53 + CloudFront + edge WAF + global logging
- **Tokyo (Primary)**: Contains secure services (database, VPC hub)
- **São Paulo (Spoke)**: Compute-focused infrastructure connecting to Tokyo database
- **Modular Design**: Reusable modules for IAM, monitoring, and S3 logging

### Key Components

#### Global (us-east-1 + Route53)
- **Route53**: Apex + app + origin records
- **CloudFront**: Global CDN and TLS
- **Edge WAF**: WAFv2 Web ACL for CloudFront

#### Tokyo (ap-northeast-1)
- **VPC**: `10.0.0.0/16` (Primary hub)
- **Transit Gateway**: Hub for inter-region connectivity
- **Database**: Aurora MySQL cluster (secure, Tokyo-only)
- **Application**: Auto-scaling EC2 with ALB
- **Modules**: Regional IAM, S3 logging, monitoring

#### São Paulo (sa-east-1)  
- **VPC**: `10.234.0.0/16` (Non-overlapping spoke)
- **Transit Gateway**: Spoke connecting to Tokyo
- **Compute**: Auto-scaling EC2 fleet accessing Tokyo database
- **Application**: Load-balanced web tier
- **Modules**: Same regional modules as Tokyo

## Directory Structure

```
LAB3/
├── global/                   # Global stack (Route53 + CloudFront + edge WAF)
│   ├── providers.tf
│   ├── cloudfront.tf
│   ├── route53.tf
│   ├── waf.tf
│   ├── outputs.tf
│   └── backend.tf
├── tokyo/                     # Tokyo region (primary + secure services)
│   ├── main.tf               # VPC, TGW hub, ALB, EC2, modules
│   ├── database.tf           # Aurora MySQL cluster
│   ├── global-iam.tf         # Cross-region IAM roles
│   ├── userdata.sh           # EC2 initialization script
│   ├── outputs.tf            # Outputs for remote state
│   ├── variables.tf          # Region-specific variables
│   └── backend.tf            # S3 remote state config
├── saopaulo/                 # São Paulo region (compute spoke)
│   ├── main.tf               # VPC, TGW spoke, ALB, EC2, modules
│   ├── outputs.tf            # Outputs for remote state
│   ├── variables.tf          # Region-specific variables
│   └── backend.tf            # S3 remote state config
└── modules/                  # Shared reusable modules
    ├── regional-iam/         # IAM roles and policies
    ├── regional-monitoring/  # CloudWatch and SNS
    └── regional-s3-logging/  # S3 buckets for logs
```

## Module Architecture

### Regional IAM Module
- **Purpose**: Standardized EC2 roles with conditional database access
- **Features**: SSM, CloudWatch, optional database permissions
- **Cross-Region**: Tokyo role can assume São Paulo resources

### Regional Monitoring Module
- **Purpose**: CloudWatch logs, alarms, and SNS topics
- **Features**: Application/system log groups, CPU/disk monitoring
- **Regional**: Independent monitoring per region

### Regional S3 Logging Module
- **Purpose**: S3 buckets for ALB and application logs
- **Features**: Lifecycle policies, encryption, proper bucket policies
- **Compliance**: Regional data residency

## Transit Gateway Design

### Peering Configuration
1. **Tokyo initiates** peering to São Paulo
2. **São Paulo accepts** the peering connection
3. **Route tables** configured for cross-region database access
4. **Security groups** allow MySQL (3306) between regions

### Network Flow
```
São Paulo App Servers → São Paulo TGW → TGW Peering → Tokyo TGW → Tokyo Database
```

## Deployment Process

### Prerequisites
1. AWS CLIs configured for both regions
2. S3 buckets for Terraform state in each region
3. Key pairs created in both regions
4. Update backend configurations with actual bucket names

### State Locking Options
Terraform supports two backend locking modes for S3 state:
- **DynamoDB locking** (`dynamodb_table`): Uses a DynamoDB table to coordinate locks. Best for team or CI/CD usage.
- **S3 lock file** (`use_lockfile = true`): Uses a lock file in the state bucket. Simpler, but less robust for concurrent runs.

Switching between them:
1. Update the backend block in each stack's `backend.tf`.
  - DynamoDB: `dynamodb_table = "taaops-terraform-state-lock"`
  - Lock file: `use_lockfile = true`
2. Reinitialize the backend:
  - `terraform init -reconfigure`

Note: Only configure one locking method at a time.

### Step 1: Deploy Tokyo Infrastructure
```bash
cd tokyo/
# Update backend.tf with your S3 bucket details
# Update variables.tf with your key pair name
terraform init
terraform plan
terraform apply
```

### Step 2: Deploy Global Infrastructure
```bash
cd ../global/
# Update backend.tf with your S3 bucket details
terraform init
terraform plan
terraform apply
```

### Step 3: Deploy São Paulo Infrastructure  
```bash
cd ../saopaulo/
# Update backend.tf with your S3 bucket details
# Update variables.tf with your key pair name
# Ensure Tokyo deployment completed first
terraform init
terraform plan
terraform apply
```

### Step 3: Verify Connectivity
```bash
# Test database connectivity from São Paulo instances
# Check TGW route tables
# Verify ALB health checks
```

## Security Architecture

### IAM Strategy
- **Global IAM in Tokyo**: Cross-region roles and policies
- **Regional Modules**: Local EC2 roles with database access
- **Principle of Least Privilege**: Minimal permissions per service

### Network Security
- **VPC Isolation**: Non-overlapping CIDR blocks
- **Security Groups**: Granular port/protocol restrictions
- **Database Access**: TGW-only, no public endpoints
- **Encryption**: In transit and at rest

### Data Protection
- **Database**: Aurora MySQL with encryption
- **Secrets**: AWS Secrets Manager for credentials
- **S3**: Server-side encryption for logs
- **KMS**: Customer-managed keys for sensitive data

## Monitoring and Logging

### CloudWatch Integration
- **Application Logs**: Centralized per region
- **System Logs**: OS and infrastructure metrics
- **Custom Dashboards**: Regional performance views

### Alerting
- **SNS Topics**: Regional alert distribution
- **CloudWatch Alarms**: CPU, disk, memory thresholds
- **Auto Scaling**: Reactive scaling based on demand

## Module Usage Examples

### Using Regional IAM Module
```hcl
module "regional_iam" {
  source = "../modules/regional-iam"
  
  region = "sa-east-1"
  database_access_enabled = true  # For São Paulo apps
  common_tags = local.common_tags
}
```

### Using S3 Logging Module
```hcl
module "s3_logging" {
  source = "../modules/regional-s3-logging"
  
  region = var.aws_region
  common_tags = local.common_tags
}

# Reference in ALB
access_logs {
  bucket  = module.s3_logging.alb_logs_bucket_id
  prefix  = "regional-alb"
  enabled = true
}
```

## Remote State Dependencies

### Tokyo Exports (for São Paulo consumption)
- `database_endpoint`: Aurora cluster endpoint
- `database_secret_arn`: Secrets Manager ARN
- `tokyo_sao_peering_id`: TGW peering attachment ID
- `tokyo_transit_gateway_id`: TGW hub ID

### São Paulo Exports (for Tokyo consumption)  
- `saopaulo_transit_gateway_id`: TGW spoke ID
- `vpc_cidr`: For routing configuration
- `alb_dns_name`: Application endpoints

## Customization Points

### Variables to Update
1. **backend.tf**: S3 bucket names and regions
2. **variables.tf**: Key pair names, AMI IDs
3. **terraform.tfvars**: Environment-specific values

### Regional Differences
- **AMI IDs**: Different per region
- **Availability Zones**: Region-specific AZ names
- **Instance Types**: Regional availability varies

## Troubleshooting

### Common Issues
1. **State conflicts**: Ensure separate S3 buckets/keys
2. **TGW peering failures**: Deploy Tokyo first
3. **Database connectivity**: Check security groups and routes
4. **Module errors**: Verify module source paths

### Debug Commands
```bash
# Check TGW peering status
aws ec2 describe-transit-gateway-peering-attachments

# Verify route tables
aws ec2 describe-route-tables

# Check security groups
aws ec2 describe-security-groups
```

## Cost Optimization

### Multi-Region Considerations
- **TGW charges**: Per attachment and data transfer
- **Cross-region data**: Significant for high volume
- **Double ALB costs**: Load balancers in both regions
- **Aurora regional**: Consider read replicas vs full cluster

### Recommendations
- **Spot instances**: For development environments
- **Scheduled scaling**: Scale down during off-hours
- **Reserved capacity**: For predictable workloads
- **Log retention**: Set appropriate retention periods

## Next Steps

### Recommended Enhancements
1. **HTTPS termination**: Add SSL certificates to ALBs
2. **CloudFront integration**: Global CDN with both regions
3. **Database replication**: Cross-region Aurora replicas
4. **Auto-failover**: Health check-based region switching
5. **CI/CD integration**: Automated deployment pipelines