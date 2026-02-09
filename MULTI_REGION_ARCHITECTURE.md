# Multi-Region Architecture - Tokyo & São Paulo

## Overview
This Terraform configuration implements a secure multi-region AWS architecture with:
- **Tokyo (ap-northeast-1)**: Primary region with secure database
- **São Paulo (sa-east-1)**: Secondary region for distributed compute
- **Transit Gateway**: Secure inter-region connectivity

## Architecture Components

### 🏙️ Tokyo Region (Data Authority)
- **VPC**: `shinjuku_vpc01` (10.233.0.0/16)
- **Subnets**:
  - Public: 10.233.1-3.0/24 (3 AZs)
  - Private: 10.233.10-12.0/24 (3 AZs)
  - TGW: 10.233.100.0/28
- **Database**: Aurora MySQL cluster (private subnets only)
- **Transit Gateway**: `shinjuku_tgw01` (main hub)

### 🌆 São Paulo Region (Compute Spoke)
- **VPC**: `liberdade_vpc01` (10.234.0.0/16)
- **Subnets**: 
  - Public: 10.234.1-3.0/24 (3 AZs)
  - Private: 10.234.10-12.0/24 (3 AZs)
  - TGW: 10.234.100.0/28
- **Compute**: EC2 instances for distributed processing
- **Transit Gateway**: `liberdade_tgw01` (spoke)

## Security Architecture

### 🔒 Database Security
- **Location**: Tokyo region only
- **Access**: 
  - Tokyo EC2 instances (direct VPC access)
  - São Paulo compute (via Transit Gateway only)
  - No public internet access
- **Encryption**: Storage encrypted with KMS

### 🛡️ Network Security
- **Inter-region**: Transit Gateway peering (encrypted)
- **Routing**: Controlled routes between regions
- **Security Groups**: Region-specific with cross-region rules
- **VPC Endpoints**: For AWS services in both regions

## Key Files Updated

### Core Infrastructure
- `[variables.tf](variables.tf)`: Added region-specific CIDR blocks and AZ definitions
- `[02-vpc.tf](02-vpc.tf)`: Tokyo and São Paulo VPCs
- `[03-subnets.tf](03-subnets.tf)`: Multi-region subnet configuration
- `[04-igw-nat.tf](04-igw-nat.tf)`: Internet and NAT gateways for both regions
- `[05-rtb.tf](05-rtb.tf)`: Route tables with cross-region routing

### Connectivity & Security
- `[tokyo_tgw.tf](tokyo_tgw.tf)`: Transit Gateway inter-region peering
- `[09-security-groups.tf](09-security-groups.tf)`: Multi-region security groups
- `[15-database.tf](15-database.tf)`: Tokyo-only database configuration

## Network Flow

```
São Paulo Compute → São Paulo TGW → Tokyo TGW → Tokyo Database
```

## Deployment Notes

1. **Provider Configuration**: 
   - Default provider: Tokyo (`ap-northeast-1`)
   - Named provider: São Paulo (`aws.saopaulo`)

2. **Dependencies**:
   - Transit Gateway peering must be established before routing
   - VPC attachments must complete before cross-region communication

3. **Security Compliance**:
   - Database remains in Tokyo (data sovereignty)
   - All cross-region traffic uses encrypted Transit Gateway
   - No direct internet access to database

## Variables Required

```hcl
# Tokyo Configuration
tokyo_vpc_cidr = "10.233.0.0/16"
tokyo_azs = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]

# São Paulo Configuration  
saopaulo_vpc_cidr = "10.234.0.0/16"
sao_azs = ["sa-east-1a", "sa-east-1b", "sa-east-1c"]
```

## Next Steps

1. **Test Connectivity**: Verify TGW peering and routing
2. **Deploy Applications**: EC2 instances in both regions
3. **Monitor Performance**: Cross-region latency and throughput
4. **Security Validation**: Database access patterns and logging

---

**Architecture Benefits**:
- ✅ Data sovereignty (database in Tokyo)
- ✅ Distributed compute capability
- ✅ Secure cross-region connectivity
- ✅ High availability across regions
- ✅ Scalable Inter-region bandwidth