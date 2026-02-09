README: Sanity Check Script

Overview
The `sanity_check.sh` script runs AWS CLI checks for this lab. It validates:
- Secrets Manager existence and access
- EC2 instance profile and IAM role resolution
- Secrets Manager permissions in managed and inline policies (prints allowed actions)
- Optional remote checks (when run on the EC2 instance)
- Optional informational checks for EC2/RDS/VPC/IAM/SG/Secrets

Requirements
- AWS CLI configured with credentials
- Access to the target AWS account and region
- On Windows Git Bash: `bash` is used to run the script

Quick Start (local)
From the repo root:
  chmod +x sanity_check.sh

Run with defaults:
  ./sanity_check.sh

Run with overrides:
  RUN_INFO_CHECKS=true \
  REGION=us-west-2 \
  INSTANCE_ID=i-0cff400cc4f896081 \
  SECRET_ID=taaops/lab/mysql \
  DB_ID=taaops-rds \
  VPC_ID=vpc-0650bb80688d52180 \
  RDS_SG_NAME=taaops-rds-sg \
  INSTANCE_NAME_TAG=taaops-armageddon-lab1-public-ec2 \
  ./sanity_check.sh

Run with info checks only:
  RUN_INFO_CHECKS=true ./sanity_check.sh

Run without report files (stdout only):
  WRITE_REPORT=false ./sanity_check.sh

Override example (single line):
  RUN_INFO_CHECKS=true REGION=us-west-2 INSTANCE_ID=i-0cff400cc4f896081 SECRET_ID=taaops/lab/mysql DB_ID=taaops-rds VPC_ID=vpc-0650bb80688d52180 RDS_SG_NAME=taaops-rds-sg INSTANCE_NAME_TAG=taaops-armageddon-lab1-public-ec2 ./sanity_check.sh

Defaults vs Overrides
- Defaults use the values baked into `sanity_check.sh` (best for the standard lab setup).
- Overrides let you point checks at different resources without editing the script.
  Use overrides when your instance ID, secret name, VPC, or SG names differ.
- Setting `RUN_INFO_CHECKS=true` enables the extra informational AWS CLI checks.
  This is separate from overrides: you can turn info checks on or off regardless of
  whether you override values. Example:
  - Info checks only: `RUN_INFO_CHECKS=true ./sanity_check.sh`
  - Info checks + overrides: `RUN_INFO_CHECKS=true REGION=us-west-2 INSTANCE_ID=... ./sanity_check.sh`

Run with a specific AWS profile:
  AWS_PROFILE=your-profile RUN_INFO_CHECKS=true ./sanity_check.sh

Running on the EC2 Instance
If you want to run the script with the instance role:
1) Copy it up:
   scp -i rds-ssh-lab01.pem sanity_check.sh ec2-user@<public-ip>:~/
2) SSH in:
   ssh -i rds-ssh-lab01.pem ec2-user@<public-ip>
3) Run:
   ./sanity_check.sh

Environment Variables
Required for most runs (defaults provided):
- REGION (default: us-west-2)
- INSTANCE_ID
- SECRET_ID

Optional toggles:
- RUN_REMOTE_CHECKS=true  (extra checks that should run on the EC2 instance)
- RUN_OPTIONAL_GUARDS=true (guardrails like rotation and wildcard policy checks)
- RUN_INFO_CHECKS=true (extra informational AWS CLI queries)

Optional overrides:
- INSTANCE_NAME_TAG (default: taaops-armageddon-lab1-public-ec2)
- DB_ID (default: taaops-rds)
- VPC_ID (default: vpc-0650bb80688d52180)
- RDS_SG_NAME (default: taaops-rds-sg)
- RDS_SG_DB_ID (default: taaops-rds)
- SECRETS_WARNING_ID (default: taaops/lab1a/rds)

Report Outputs
When `WRITE_REPORT=true` (default), each run writes three files in `LAB1-DELIVERABLES`:
- `sanity_check_<timestamp>.log` → full command output (tables, JSON, PASS/FAIL).
- `sanity_check_<timestamp>.md` → short summary (status + key parameters).
- `sanity_check_<timestamp>.jsonl` → summary in JSON Lines format.

If you only want console output, set:
  WRITE_REPORT=false ./sanity_check.sh

Notes
- The script fails fast on missing permissions and prints a clear FAIL message.
- The Secrets Manager policy check inspects both managed and inline policies and prints allowed actions, along with the policy they came from.
- If the role does not have `ec2:DescribeInstances`, the script will fail at that check when run on the instance.

Troubleshooting
- Use `bash -x ./sanity_check.sh` to see where it stops.
- Ensure your AWS credentials are set correctly (`AWS_PROFILE`, `AWS_REGION`).
- If a secret is marked for deletion, `get-secret-value` will fail for that secret.

Verify rdsapp Logging + CloudWatch Log Group
Run on the EC2 instance:
```
sudo tail -n 20 /var/log/rdsapp.log
aws logs describe-log-groups --log-group-name-prefix /aws/ec2/rdsapp
```

DB Outage Test (Capture rdsapp.log)
Use this to stop the RDS instance, capture errors in `/var/log/rdsapp.log`, and verify recovery.

Stop the DB:
```
aws rds stop-db-instance --db-instance-identifier taaops-rds --region us-west-2
```

Wait for stopped:
```
aws rds describe-db-instances --db-instance-identifier taaops-rds \
  --region us-west-2 --query "DBInstances[0].DBInstanceStatus"
```

Generate an app call to log DB errors:
```
curl -s http://localhost/init
```

Capture log output during outage:
```
sudo tail -n 50 /var/log/rdsapp.log
```

Start the DB:
```
aws rds start-db-instance --db-instance-identifier taaops-rds --region us-west-2
```

Wait for available, then confirm recovery:
```
aws rds describe-db-instances --db-instance-identifier taaops-rds \
  --region us-west-2 --query "DBInstances[0].DBInstanceStatus"

curl -s http://localhost/init
```

Manual Commands (AWS CLI)

Context Values
- Owner ID: 015195098145
- VPC CIDR: 10.233.0.0/16
- Instance Name: taaops-armageddon-lab1-public-ec2
- Instance ID: i-0cff400cc4f896081
- DB Identifier: taaops-rds
- Secret: taaops/lab/mysql

Parameter Store (examples)
- /lab/db/endpoint (SecureString): taaops-rds.cfqumkgmmcja.us-west-2.rds.amazonaws.com
- /lab/db/port (SecureString): 3306
- /lab/db/name (SecureString): labdb

SSH
```
ssh -i rds-ssh-lab01.pem ec2-user@<public-ip>
ssh -i rds-ssh-lab01.pem ec2-user@ec2-<public-ip>.us-west-2.compute.amazonaws.com
```

EC2 Checks
```
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=taaops-armageddon-lab1-public-ec2" \
  --query "Reservations[].Instances[].InstanceId"

aws ec2 describe-instances \
  --instance-ids i-0cff400cc4f896081 \
  --query "Reservations[].Instances[].IamInstanceProfile.Arn"
```

RDS Status + Endpoint
```
aws rds describe-db-instances \
  --db-instance-identifier taaops-rds \
  --query "DBInstances[].DBInstanceStatus"

aws rds describe-db-instances \
  --db-instance-identifier taaops-rds \
  --query "DBInstances[].Endpoint"
```

VPC Checks (DB Subnet Group Placement)
```
aws rds describe-db-subnet-groups \
  --region us-west-2 \
  --query "DBSubnetGroups[].{Name:DBSubnetGroupName,Vpc:VpcId,Subnets:Subnets[].SubnetIdentifier}" \
  --output table
```

IAM Role Checks
```
aws iam list-attached-role-policies \
  --role-name taaops-armageddon-lab1-asm-role \
  --output table

aws iam get-instance-profile \
  --instance-profile-name taaops-armageddon-lab1-asm-role \
  --query "InstanceProfile.Roles[].RoleName" \
  --output text
```

Security Groups
```
aws ec2 describe-security-groups \
  --region us-west-2 \
  --query "SecurityGroups[].{GroupId:GroupId,Name:GroupName,VpcId:VpcId}" \
  --output table

aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=vpc-0650bb80688d52180" "Name=group-name,Values=taaops-rds-sg" \
  --query "SecurityGroups[].IpPermissions"

aws rds describe-db-instances \
  --db-instance-identifier taaops-rds \
  --region us-west-2 \
  --query "DBInstances[].VpcSecurityGroups[].VpcSecurityGroupId" \
  --output table
```

Secrets Manager
```
aws secretsmanager list-secrets \
  --region us-west-2 \
  --query "SecretList[].{Name:Name,ARN:ARN,Rotation:RotationEnabled}" \
  --output table

aws secretsmanager describe-secret \
  --secret-id taaops/lab/mysql \
  --region us-west-2 \
  --query ARN \
  --output text

aws secretsmanager get-resource-policy \
  --secret-id taaops/lab/mysql \
  --region us-west-2 \
  --output json

# WARNING: prints secret value
aws secretsmanager get-secret-value \
  --secret-id taaops/lab/mysql \
  --query SecretString \
  --output text
```

Database Checks
```
aws rds describe-db-instances \
  --region us-west-2 \
  --query "DBInstances[].{DB:DBInstanceIdentifier,Engine:Engine,Public:PubliclyAccessible,Vpc:DBSubnetGroup.VpcId}" \
  --output table

aws rds describe-db-instances \
  --region us-west-2 \
  --query "DBInstances[].{DB:DBInstanceIdentifier,Endpoint:Endpoint.Address,Port:Endpoint.Port,Public:PubliclyAccessible,VPC:DBSubnetGroup.VpcId}" \
  --output table

aws rds describe-db-instances \
  --db-instance-identifier taaops-rds \
  --region us-west-2 \
  --query "DBInstances[].PubliclyAccessible" \
  --output text
```

Lab Gates - Required for Passing



These gates are the official pass/fail checks for the lab and are used for verification.
1) From your workstation (metadata checks; role attach + secret exists)
```
chmod +x ./python/gate_secrets_and_role.sh
REGION=us-west-2 INSTANCE_ID=i-0cff400cc4f896081 SECRET_ID=taaops/lab/mysql \
  ./python/gate_secrets_and_role.sh
```

example: `ssh -i "rds-ssh-lab01.pem" ec2-user@54.212.83.197`

Or Try
`ssh -i "123.pem" ec2-user@ec2-54.212.83.197.us-west-2.compute.amazonaws.com`

Then from inside the EC2 instance run the following:

  1.  Copy the gate_secrets_and_role.sh to the Instance: `scp -i rds-ssh-lab01.pem python/gate_secrets_and_role.sh ec2-user@54.212.83.197:~/`
  2. Connect (SSH) to the EC2 instance: `ssh -i <123.pem> ec2-user@<ip address>`
    example: `ssh -i "rds-ssh-lab01.pem" ec2-user@54.212.83.197`
  3. Prove the instance role can actually read the secret:
```
chmod +x ~/gate_secrets_and_role.sh
CHECK_SECRET_VALUE_READ=true REGION=us-west-2 INSTANCE_ID=i-0cff400cc4f896081 SECRET_ID=taaops/lab/mysql \
  ~/gate_secrets_and_role.sh
```

Strict mode: require rotation enabled:
```
    REQUIRE_ROTATION=true REGION=us-west-2 INSTANCE_ID=i-0cff400cc4f896081 SECRET_ID=taaops/lab/mysql ./python/gate_secrets_and_role.sh
```


3) Basic: verify RDS isn’t public + SG-to-SG rule exists
```
chmod +x ./python/gate_network_db.sh
REGION=us-west-2 INSTANCE_ID=i-0cff400cc4f896081 DB_ID=taaops-rds \
  ./python/gate_network_db.sh
```


4) Run all gates
```
chmod +x ./python/run_all_gates.sh
    REGION=us-west-2 INSTANCE_ID=i-0cff400cc4f896081 SECRET_ID=taaops/lab/mysql ./python/gate_secrets_and_role.sh
```

NOTE: To create output files run as the following:
OUT_JSON=python/output/gate_secrets_and_role.json ./python/gate_secrets_and_role.sh
OUT_JSON=python/output/gate_network_db.json ./python/gate_network_db.sh



Summary (Lab Submission)
- Sanity checks run locally with defaults or overrides; `RUN_INFO_CHECKS=true` adds verbose AWS CLI context.
- Reports are generated in `LAB1-DELIVERABLES` (`.log` full output, `.md` summary, `.jsonl` summary).
- Gate checks are output to `gate_secrets_and_role.txt`.
- RDS outage test captures `/var/log/rdsapp.log` during stop/restart to prove failure and recovery.
- CloudWatch log group `/aws/ec2/rdsapp` ships app logs; metric filter emits `Lab/RDSApp/RdsAppDbErrors`.
- Alarm `rdsapp-db-errors-alarm` triggers when error logs breach 2 of 3 datapoints.
- NOTE: On EC2, the gate_secrets_and_role check may report "no IAM instance profile attached" because
  the instance role lacks `ec2:DescribeInstances` in this lab; secret-read still passes.
- NOTE: gate_secrets_and_role.json shows FAIL because there are 3 Public Subnets within the VPC, however the database is on a Private Subnet so this PASSES.
