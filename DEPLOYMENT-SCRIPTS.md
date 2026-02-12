# LAB3 Deployment Scripts

## 🚀 Quick Start

Run these from the `LAB3` repository root (`SEIR_Foundations/LAB3`).

Note on naming:
- This repo's apply wrapper is `terraform_startup.sh`.
- If you renamed/copied it to `terraform_apply.sh`, run it the same way.

### Deploy Everything
```bash
bash ./terraform_startup.sh
# or (if you created it)
bash ./terraform_apply.sh
```

### Destroy Everything  
```bash
bash ./terraform_destroy.sh
```

### Optional: Activate DynamoDB State Locking
Default backend mode in this repo uses S3 lock files (`use_lockfile = true`).
DynamoDB locking is optional and can be activated when needed (team/CI use).

```bash
# Create lock table in Tokyo region
aws dynamodb create-table \
  --table-name taaops-terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-northeast-1

# Create lock table in Sao Paulo region
aws dynamodb create-table \
  --table-name taaops-terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region sa-east-1
```

Then add this line to each backend block (`Tokyo/backend.tf`, `global/backend.tf`, `saopaulo/backend.tf`):
```hcl
dynamodb_table = "taaops-terraform-state-lock"
```

Then reinitialize each stack backend:
```bash
(cd Tokyo && terraform init -reconfigure)
(cd global && terraform init -reconfigure)
(cd saopaulo && terraform init -reconfigure)
```

## 📋 Script Overview

### `terraform_startup.sh`
**Deploys the complete LAB3 multi-region architecture in optimal sequence:**

1. **🏯 Tokyo Region** - Primary hub with database, VPC, TGW hub, ALB
2. **🌐 Global Stack** - CloudFront, Route53, and global edge controls
3. **🌴 São Paulo Region** - Compute spoke with VPC, TGW spoke, ALB  
4. **🔍 Summary Outputs** - Collects key TGW/ALB/CloudFront outputs

**Features:**
- ✅ Proper deployment sequencing (Tokyo → Global → São Paulo)
- ✅ Transit Gateway peering wait times (120s)
- ✅ Comprehensive output collection
- ✅ Error handling with line number reporting
- ✅ Fails if required summary outputs are missing

### `terraform_destroy.sh`
**Safely destroys infrastructure in a remote-state-safe order:**

1. **🔧 Global** - Removes CloudFront/Route53 dependencies
2. **🏯 Tokyo** - Destroys hub region while São Paulo state outputs still exist
3. **🌴 São Paulo** - Destroys spoke region last
4. **🧹 Cleanup** - Removes plan files and verifies destruction

**Safety Features:**
- ✅ Confirmation prompts before destruction
- ✅ Proper dependency order (global → hub → spoke)
- ✅ Resource verification after destruction
- ✅ S3 state bucket preservation (with manual cleanup instructions)

## 🎯 Usage Examples

### Standard Deployment
```bash
# Deploy complete LAB3 infrastructure
bash ./terraform_startup.sh

# Expected output:
# === Deploying Tokyo ===
# === Deploying global ===
# === Deploying saopaulo ===
# LAB3 deployment complete.
# (With DynamoDB locking enabled, Terraform will also show lock acquire/release messages.)
```

### Cleanup Deployment
```bash
# Destroy all infrastructure
bash ./terraform_destroy.sh

# Prompts:
# - Confirm destruction: yes
```

### Manual Steps (if needed)
```bash
# Individual stack deployment
(cd Tokyo && terraform init && terraform apply)
(cd global && terraform init && terraform apply)
(cd saopaulo && terraform init && terraform apply)

# Individual stack destruction (match script order)
(cd global && terraform destroy)
(cd Tokyo && terraform destroy)
(cd saopaulo && terraform destroy)
```

## 🔧 Prerequisites

Before running the scripts:

1. **AWS CLI configured** with appropriate permissions
2. **Update backend.tf files** with your actual S3 bucket names:
   ```hcl
   bucket = "your-actual-bucket-name-tokyo"
   ```
3. **Create S3 buckets** for state storage (scripts do not create state buckets)
4. **Optional:** enable DynamoDB locking using the section above
5. **Terraform >= 1.3** installed

## 📊 Script Output Guide

### Successful Deployment Shows:
```
=== Deploying Tokyo ===
=== Deploying global ===
=== Deploying saopaulo ===
=== Deployment summary ===
Tokyo TGW:             tgw-...
Global CloudFront ID:  E...
Sao Paulo TGW:         tgw-...
LAB3 deployment complete.
```

### Common Issues and Solutions:

| Issue | Cause | Solution |
|-------|-------|----------|
| `backend not configured` | S3 bucket doesn't exist | Create bucket or update backend.tf |
| `DynamoDB table not found` | State locking not set up | Run DynamoDB setup step |
| `Error acquiring the state lock` | Stale/active lock present | Wait, coordinate, or `terraform force-unlock <LOCK_ID>` |
| `TGW peering failed` | Tokyo not deployed first | Deploy Tokyo before São Paulo |
| `ALB not responding` | Resources still initializing | Wait 5-10 minutes and retry |
| `terraform_destroy.sh: command not found` | Script executed without `./` or from wrong folder | `cd` to `LAB3` and run `bash ./terraform_destroy.sh` |

## ⚡ Advanced Usage

### Customization Options

**Modify wait times in terraform_startup.sh:**
```bash
WAIT_TIME=30          # General resource wait
TGW_WAIT_TIME=120     # Transit Gateway peering wait
```

**Add custom verification:**
```bash
# Add to verification stage
echo "🧪 Custom health check..."
# Your custom tests here
```

**Selective deployment:**
```bash
# Deploy only Tokyo
cd Tokyo/ && terraform init && terraform apply

# Deploy only São Paulo (requires Tokyo first)
cd saopaulo/ && terraform init && terraform apply
```

## 🎯 Integration with CI/CD

### GitHub Actions Example
```yaml
- name: Deploy LAB3
  run: |
    chmod +x terraform_startup.sh
    ./terraform_startup.sh
    
- name: Cleanup on failure
  if: failure()
  run: bash ./terraform_destroy.sh
```

### Pipeline Stages
1. **Validate** - `terraform validate` in both regions
2. **Plan** - `terraform plan` with output files
3. **Deploy** - Sequential regional deployment
4. **Test** - ALB health checks and connectivity tests
5. **Monitor** - Infrastructure status dashboard

---

## 🏁 Success Criteria

After successful deployment, you should have:
- ✅ Multi-region VPCs with non-overlapping CIDRs
- ✅ Transit Gateway inter-region peering
- ✅ Aurora MySQL database in Tokyo only
- ✅ Auto-scaling web applications in both regions
- ✅ Load balancers with health checks
- ✅ Regional modules for IAM, S3, and monitoring
- ✅ State locking for team collaboration

**Total deployment time**: Usually 8-12 minutes for complete infrastructure.
