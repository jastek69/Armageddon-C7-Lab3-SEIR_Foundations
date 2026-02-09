# Multi-Region Terraform Architecture - Tokyo & São Paulo

## 📁 Repository Structure

```
lab-3/
├── tokyo/                    # 🏯 Tokyo Region (Primary - Data Authority)
│   ├── main.tf              # Complete Lab 2 + TGW hub
│   ├── outputs.tf            # Exposes TGW ID, VPC CIDR, RDS endpoint
│   ├── variables.tf          # Tokyo-specific variables
│   └── backend.tf            # Remote state configuration
│
├── saopaulo/                 # 🌴 São Paulo Region (Compute Spoke)
│   ├── main.tf              # Lab 2 minus DB + TGW spoke  
│   ├── variables.tf          # São Paulo-specific variables
│   ├── data.tf               # Reads Tokyo remote state
│   └── backend.tf            # Remote state configuration
│
└── DEPLOYMENT_GUIDE.md      # This file
```

## 🚀 **Deployment Sequence (IMPORTANT!)**

### **Step 1: Setup Remote State Backend**
Before deploying, create an S3 bucket for state management:

```bash
# Create state bucket (run once)
aws s3 mb s3://your-terraform-state-bucket --region ap-northeast-1

# Optional: Create DynamoDB table for state locking (RECOMMENDED for teams)
aws dynamodb create-table \
    --table-name terraform-state-locks \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region ap-northeast-1

# For São Paulo region
aws dynamodb create-table \
    --table-name terraform-state-locks \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region sa-east-1
```

### **Step 2: Configure Backend Settings**

Update backend configurations in both regions:

**tokyo/backend.tf:**
```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "tokyo/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locks"  # Enables state locking
  }
}
```

**saopaulo/backend.tf:**
```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"  
    key            = "saopaulo/terraform.tfstate"
    region         = "sa-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locks"  # Enables state locking
  }
}
``` 
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

**saopaulo/backend.tf:**
```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "saopaulo/terraform.tfstate"
    region         = "sa-east-1"
    dynamodb_table = "terraform-state-lock" 
    encrypt        = true
  }
}
```

### **Step 3: Deploy Tokyo (Primary Region)**

```bash
# Navigate to Tokyo
cd tokyo/

# Initialize and plan
terraform init
terraform plan

# Deploy Tokyo infrastructure
terraform apply

# Note the outputs - São Paulo will need these
terraform output tokyo_transit_gateway_id
terraform output tokyo_vpc_cidr
terraform output rds_endpoint
```

### **Step 4: Configure São Paulo Variables**

Update `saopaulo/variables.tf` with your state bucket:

```hcl
variable "tokyo_state_bucket" {
  description = "S3 bucket containing Tokyo Terraform state"
  default     = "your-terraform-state-bucket"  # UPDATE THIS
}
```

### **Step 5: Deploy São Paulo (Dependent Region)**

```bash
# Navigate to São Paulo  
cd ../saopaulo/

# Initialize and plan
terraform init
terraform plan

# Deploy São Paulo infrastructure
terraform apply
```

## 🔗 **Inter-Region Dependencies**

### **Tokyo Exposes:**
- `tokyo_transit_gateway_id` → Used by São Paulo for TGW peering
- `tokyo_vpc_cidr` → Used for São Paulo routing tables  
- `rds_endpoint` → Database connection for São Paulo apps
- `db_secret_arn` → Database credentials access

### **São Paulo Consumes:**
- Reads Tokyo remote state via `data.tf`
- Creates TGW peering connection to Tokyo
- Routes database traffic through TGW
- Configures security groups for cross-region access

## 🛡️ **Security Architecture**

### **Database Security:**
- ✅ **Database only in Tokyo** (data sovereignty)
- ✅ **São Paulo access via TGW** (encrypted transit)
- ✅ **No public database access**
- ✅ **Secrets Manager integration**

### **Network Security:**
- ✅ **Inter-region encryption** (TGW default)
- ✅ **Security group rules** for cross-region traffic
- ✅ **VPC isolation** with controlled routing

## 📊 **Resource Distribution**

| Component | Tokyo | São Paulo |
|-----------|-------|-----------|
| **VPC** | ✅ `shinjuku_vpc01` | ✅ `liberdade_vpc01` |
| **Database** | ✅ Aurora MySQL | ❌ None (uses Tokyo) |
| **Compute** | ✅ EC2/ASG | ✅ EC2/ASG |
| **Load Balancer** | ✅ ALB + CloudFront | ✅ Local ALB |
| **Transit Gateway** | ✅ Hub | ✅ Spoke |
| **IAM Roles** | ✅ Full Lab 2 roles | ✅ Compute-only roles |
| **KMS/Secrets** | ✅ Shared services | ❌ References Tokyo |

## 🔧 **Management Commands**

### **Show TGW Peering Status:**
```bash
# From Tokyo
terraform output tokyo_transit_gateway_id

# From São Paulo - verify peering
aws ec2 describe-transit-gateway-peering-attachments \
    --region sa-east-1 \
    --filters "Name=state,Values=available"
```

### **Test Database Connectivity:**
```bash
# From São Paulo EC2 instance
mysql -h <tokyo-rds-endpoint> -u admin -p taaopsdb
```

### **Destroy Infrastructure:**
```bash
# ALWAYS destroy São Paulo first (dependent)
cd saopaulo/
terraform destroy

# Then destroy Tokyo (primary)  
cd ../tokyo/
terraform destroy
```

## 🔒 **DynamoDB State Locking Deep Dive**

### **Why State Locking Matters**

**The Problem:**
Without state locking, concurrent Terraform operations can corrupt your state file:
```bash
# Terminal 1: Developer A runs
terraform apply  # Takes 3 minutes

# Terminal 2: Developer B runs simultaneously  
terraform apply  # Corruption risk! 💥
```

**The Solution:**
DynamoDB provides atomic locking to ensure only one Terraform operation runs per state file.

### **AWS Documentation References**

- **Official Guide**: [S3 Backend with DynamoDB Locking](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- **DynamoDB**: [AWS DynamoDB Developer Guide](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/)
- **Best Practices**: [Terraform State Management](https://developer.hashicorp.com/terraform/tutorials/state)

### **How State Locking Works**

1. **Lock Acquisition**: Terraform writes a lock record to DynamoDB with operation metadata
2. **Operation Execution**: If lock successful, Terraform proceeds with plan/apply/destroy
3. **Lock Release**: After completion, Terraform removes the lock record  
4. **Conflict Prevention**: Concurrent operations wait or fail gracefully

```bash
# What you see during lock conflicts:
Error: Error locking state: ConditionalCheckFailedException: 
The conditional request failed

Lock Info:
  ID:        1a2b3c4d-e5f6-7890-abcd-ef1234567890
  Path:      your-bucket/tokyo/terraform.tfstate
  Operation: OperationTypeApply
  Who:       john@laptop
  Version:   1.5.7
  Created:   2026-02-07 15:30:00 UTC
```

### **Setting Up DynamoDB Tables Properly**

**Option 1: Use Terraform (Recommended)**
```bash
# Create the setup file for both regions
terraform apply setup-dynamodb-locking.tf
```

**Option 2: Manual AWS CLI Setup**
```bash
# Tokyo region table
aws dynamodb create-table \
  --table-name terraform-state-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-northeast-1 \
  --tags Key=Purpose,Value=TerraformStateLocking

# São Paulo region table
aws dynamodb create-table \
  --table-name terraform-state-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region sa-east-1 \
  --tags Key=Purpose,Value=TerraformStateLocking
```

### **Testing State Locking**

Verify your locking works:
```bash
# Terminal 1: Start long-running command
cd tokyo/
terraform plan -detailed-exitcode

# Terminal 2: Try concurrent operation (should wait)
cd tokyo/  
terraform plan
# Expected: "Error locking state: ConditionalCheckFailedException"
```

### **Managing Locks in Production**

**Check Active Locks:**
```bash
# View current locks
aws dynamodb scan \
  --table-name terraform-state-locks \
  --region ap-northeast-1

# Check specific state file lock
aws dynamodb get-item \
  --table-name terraform-state-locks \
  --key '{"LockID":{"S":"your-bucket/tokyo/terraform.tfstate-md5"}}' \
  --region ap-northeast-1
```

**Emergency Lock Removal:**
```bash
# When someone's laptop crashes during apply
terraform force-unlock <LOCK_ID>

# Example:
terraform force-unlock 1a2b3c4d-e5f6-7890-abcd-ef1234567890
```

### **Cost Analysis: DynamoDB State Locking**

**Pricing (Pay-per-Request Model):**
- Write requests: $0.25 per million writes
- Read requests: $0.05 per million reads
- Storage: $0.25 per GB-month

**Real-world Cost Example (5-person team):**
```
Operations per month: ~200 lock/unlock cycles
DynamoDB writes: 400 
DynamoDB reads: 400
Monthly cost: ~$0.10 (less than 10 cents!)

Annual cost for state locking: ~$1.20 per project
```

**Free Tier Coverage:**
- 25 WCU/RCU per month (sufficient for small teams)
- First year covers most small to medium teams

### **Required IAM Permissions**

Add these permissions to your Terraform execution role:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": [
        "arn:aws:dynamodb:ap-northeast-1:*:table/terraform-state-locks",
        "arn:aws:dynamodb:sa-east-1:*:table/terraform-state-locks"
      ]
    }
  ]
}
```

### **Troubleshooting State Locking Issues**

| Issue | Cause | Solution |
|-------|-------|----------|
| `ResourceNotFoundException` | DynamoDB table doesn't exist | Create table in correct region |
| `AccessDenied` | Missing DynamoDB permissions | Add IAM permissions above |
| Stale locks after crash | Process terminated unexpectedly | Use `terraform force-unlock` |
| Lock timeout | Another operation running | Wait or coordinate with team |

**Debug Commands:**
```bash
# Check if table exists
aws dynamodb describe-table \
  --table-name terraform-state-locks \
  --region ap-northeast-1

# View table contents
aws dynamodb scan \
  --table-name terraform-state-locks \
  --region ap-northeast-1 \
  --max-items 5

# Check Terraform state metadata
terraform show -json | jq '.version, .serial'
```

### **State Locking Best Practices**

**For Teams:**
1. **Always enable locking** in shared environments
2. **Use lock timeouts** in CI/CD: `terraform plan -lock-timeout=5m`
3. **Communicate long operations** in team chat
4. **Monitor stale locks** - investigate locks older than 30 minutes

**For CI/CD Pipelines:**
```bash
# In your deployment scripts
terraform init -input=false
terraform plan -lock-timeout=10m -input=false -out=plan.tfplan
terraform apply -lock-timeout=10m -input=false plan.tfplan
```

**Backup and Recovery:**
```bash
# Enable point-in-time recovery on DynamoDB table
aws dynamodb update-continuous-backups \
  --table-name terraform-state-locks \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true \
  --region ap-northeast-1
```

## ⚠️ **Important Notes**

1. **Deploy Order:** Tokyo MUST be deployed before São Paulo
2. **State Dependencies:** São Paulo reads Tokyo's remote state
3. **State Locking:** Enable DynamoDB locking for team environments (see detailed section above)
4. **TGW Timing:** Allow 2-3 minutes for TGW peering to establish
5. **Cost Management:** Consider TGW data transfer costs between regions
6. **Security:** Database access is only via TGW - no public endpoints
7. **Lock Management:** Monitor and cleanup stale locks in production environments

## 🎯 **Benefits of This Architecture**

- ✅ **Separated concerns** - Database vs Compute regions
- ✅ **Independent state management** - No monolithic state files  
- ✅ **Production-ready state locking** - DynamoDB prevents concurrent conflicts
- ✅ **Secure cross-region connectivity** - TGW encrypted transit
- ✅ **Data sovereignty** - Database remains in Tokyo
- ✅ **Scalable compute** - EC2 auto-scaling in São Paulo
- ✅ **Clean dependencies** - Clear resource ownership
- ✅ **Team-friendly** - State locking enables safe collaboration

---

🚀 **Your multi-region infrastructure is ready for deployment!**