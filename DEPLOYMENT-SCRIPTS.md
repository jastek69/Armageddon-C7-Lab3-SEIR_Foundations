# LAB3 Deployment Scripts

## 🚀 Quick Start

### Deploy Everything
```bash
./terraform_startup.sh
```

### Destroy Everything  
```bash
./terraform_destroy.sh
```

## 📋 Script Overview

### `terraform_startup.sh`
**Deploys the complete LAB3 multi-region architecture in optimal sequence:**

1. **🔧 DynamoDB State Locking** - Creates state lock tables in both regions
2. **🏯 Tokyo Region** - Primary hub with database, VPC, TGW hub, ALB
3. **🌴 São Paulo Region** - Compute spoke with VPC, TGW spoke, ALB  
4. **🔍 Verification** - Comprehensive health checks and status reporting

**Features:**
- ✅ Proper deployment sequencing (Tokyo → São Paulo)
- ✅ Transit Gateway peering wait times (120s)
- ✅ Comprehensive output collection
- ✅ ALB endpoint health testing
- ✅ Error handling with line number reporting
- ✅ Infrastructure status dashboard

### `terraform_destroy.sh`
**Safely destroys infrastructure in reverse dependency order:**

1. **🌴 São Paulo** - Destroys spoke region first (dependent resources)
2. **🏯 Tokyo** - Destroys hub region second (core resources)  
3. **🔧 DynamoDB** - Optional cleanup of state locking tables
4. **🧹 Cleanup** - Removes plan files and verifies destruction

**Safety Features:**
- ✅ Confirmation prompts before destruction
- ✅ Proper dependency order (spoke → hub)
- ✅ Resource verification after destruction
- ✅ S3 state bucket preservation (with manual cleanup instructions)

## 🎯 Usage Examples

### Standard Deployment
```bash
# Deploy complete LAB3 infrastructure
./terraform_startup.sh

# Expected output:
# ✅ DynamoDB state locking ready
# ✅ Tokyo region deployed (VPC, TGW, Aurora, ALB)  
# ✅ São Paulo region deployed (VPC, TGW, ALB)
# ✅ Multi-region connectivity verified
```

### Cleanup Deployment
```bash
# Destroy all infrastructure
./terraform_destroy.sh

# Prompts:
# - Confirm destruction: yes
# - Keep DynamoDB tables: no (if you want full cleanup)
```

### Manual Steps (if needed)
```bash
# Individual region deployment
cd tokyo/
terraform init && terraform apply

cd ../saopaulo/  
terraform init && terraform apply

# Individual region destruction
cd saopaulo/
terraform destroy

cd ../tokyo/
terraform destroy
```

## 🔧 Prerequisites

Before running the scripts:

1. **AWS CLI configured** with appropriate permissions
2. **Update backend.tf files** with your actual S3 bucket names:
   ```hcl
   bucket = "your-actual-bucket-name-tokyo"
   ```
3. **Create S3 buckets** for state storage (or let scripts create them)
4. **Terraform >= 1.3** installed

## 📊 Script Output Guide

### Successful Deployment Shows:
```
✅ Tokyo region deployment complete
✅ São Paulo region deployment complete  
TGW Peering Status: available
✅ Tokyo ALB responding
✅ São Paulo ALB responding
✅ Multi-region infrastructure deployed successfully!
```

### Common Issues and Solutions:

| Issue | Cause | Solution |
|-------|-------|----------|
| `backend not configured` | S3 bucket doesn't exist | Create bucket or update backend.tf |
| `DynamoDB table not found` | State locking not set up | Run DynamoDB setup step |
| `TGW peering failed` | Tokyo not deployed first | Deploy Tokyo before São Paulo |
| `ALB not responding` | Resources still initializing | Wait 5-10 minutes and retry |

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
cd tokyo/ && terraform init && terraform apply

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
  run: ./terraform_destroy.sh
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