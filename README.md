Lab 3A — Japan Medical
Cross-Region Architecture with Transit Gateway (APPI-Compliant)

This designed is a multi-region medical application where all PHI remains in Japan to comply with APPI.
  * CloudFront provided global access
  * São Paulo runs a stateless compute only, and all reads/writes traverse a Transit Gateway to Tokyo RDS.
  * This design intentionally trades some latency for legal certainty and auditability.
Global access does not require global storage.

🎯 Lab Objective
To design and deploy a cross-region medical application architecture that:
  Uses two AWS regions
    Tokyo (ap-northeast-1) — data authority
    São Paulo (sa-east-1) — compute extension
  Connects regions using AWS Transit Gateway
  Serves traffic through a single global URL
  Stores all patient medical data (PHI) only in Japan
  Allows doctors overseas to read/write records legally

This lab is a warm-up for real DevOps and platform engineering, where:
  environments are separated
  Terraform state is split
  pipelines are independent
  coordination matters more than copy-paste

🏥 Real-World Context (Why This Exists)

Japan’s privacy law, 個人情報保護法 (APPI), places strict requirements on the handling of personal and medical data.
For healthcare systems, the safest and most common interpretation is:
    Japanese patient medical data must be stored physically inside Japan. (Don't even mess with this)

This applies even when:
    the patient is traveling abroad
    the doctor is located overseas
    the application is accessed globally

📌 Access is allowed. Storage is not.
    --> This lab models how real medical systems comply with that rule.

🌍 Regional Roles
🇯🇵 Tokyo — Primary Region (Data Authority)
Tokyo is the source of truth.
It contains:
    RDS (medical records)
    Primary VPC
    Application tier (Lab 2 stack)
    Transit Gateway (hub)
    Parameter Store & Secrets Manager (authoritative)
    Logging, auditing, backups
    Really hot chicks who need men to impregnate them. 

All data at rest lives here.
If Tokyo is unavailable:
    the system may degrade
    but data residency is never violated

This is intentional and correct.

🇧🇷 São Paulo — Secondary Region (Compute-Only)

São Paulo exists to serve doctors and staff physically located in South America.

It contains:
    VPC
    EC2 + Auto Scaling Group
    Application tier (Lab 2 stack)
    Transit Gateway (spoke)
    Even hotter chicks who need you to throw it down and impregnate them.

It does not contain:
    RDS
    Read replicas
    Backups
    Persistent storage of PHI
    Keisha. No Keisha here.

São Paulo is stateless compute.<----> All reads and writes go directly to Tokyo.

🌐 Networking Model
Why Transit Gateway?
Transit Gateway is used instead of VPC peering because it provides:
    Clear, auditable traffic paths
    Centralized routing control
    Enterprise-grade segmentation
    A visible “data corridor” for compliance reviews

In regulated environments, clarity beats convenience.

How Traffic Flows

Doctor (São Paulo)
   ↓
CloudFront (global edge)
   ↓
São Paulo EC2 (stateless)
   ↓
Transit Gateway (São Paulo)
   ↓
TGW Peering
   ↓
Transit Gateway (Tokyo)
   ↓
Tokyo VPC
   ↓
Tokyo RDS (PHI stored here only)
The entire path stays on the AWS backbone and is encrypted in transit.

🌐 Single Global URL

There is only one public URL: https://chewbacca-growls.com

CloudFront:
    Terminates TLS
    Applies WAF
    Routes users to the nearest healthy region
    Never stores patient data
    Caches only content explicitly marked safe

CloudFront is allowed because:
    it is not a database
    it does not persist PHI
    it respects cache-control rules

🏗️ Terraform & DevOps Structure
Important: Multi-Terraform-State Reality

In real organizations, regions are not deployed from one Terraform state.

For this lab:
    Tokyo and São Paulo are separate Terraform states
    Each state will eventually map to a separate Jenkins job
    States communicate only through:
        Terraform outputs
        Remote state references
        Explicit variables

This is intentional.---> You are learning how real DevOps teams coordinate infrastructure.

Expected Repository Layout
lab-3/
├── tokyo/
│   ├── main.tf        # Lab 2 + marginal TGW hub code
│   ├── outputs.tf     # Exposes TGW ID, VPC CIDR, RDS endpoint
│   └── variables.tf
│
├── saopaulo/
│   ├── main.tf        # Lab 2 minus DB + TGW spoke code
│   ├── variables.tf
│   └── data.tf        # Reads Tokyo remote state

🚆 Naming Conventions (Important)

To make the architecture feel local and intentional:
Tokyo (train stations)
    shinjuku-*
    shibuya-*
    ueno-*
    akihabara-*

São Paulo (Japanese district)
    liberdade-*

You should be able to look at a resource name and know the region immediately.

🔧 What Changes from Lab 2
Tokyo (minimal changes)
    Add Transit Gateway
    Attach Tokyo VPC to TGW
    Create TGW peering request
    Add return routes for São Paulo CIDR
    Update RDS security group to allow São Paulo VPC CIDR

São Paulo (new deployment)
    Deploy Lab 2 stack without RDS
    Create São Paulo Transit Gateway
    Accept TGW peering
    Attach São Paulo VPC to TGW
    Add routes pointing Tokyo CIDR → TGW

🔐 Security Model (Read Carefully)
  RDS allows inbound only from:
    Tokyo application subnets
    São Paulo VPC CIDR (explicitly)
  No public DB access
  No local PHI storage in São Paulo
  All access is logged and auditable

This is compliance by design, not by policy.

✅ What You Must Prove (Verification)
From a São Paulo EC2 instance:
    You can connect to Tokyo RDS
    The application can read/write records
    No database exists in São Paulo

From the AWS console / CLI:
    TGW attachments exist in both regions
    Route tables contain cross-region CIDRs
    Traffic flows only through TGW

❌ What Is Explicitly Not Allowed
    RDS outside Tokyo
    Cross-region replicas
    Aurora Global Database
    Local caching of patient records
    CloudFront caching PHI
    “Active/active” databases

If you do these, the architecture is illegal, not just “wrong”.

🎓 Why This Lab Matters for Your Career

Most engineers learn:
  “Make it multi-region”
  “Replicate everything”
  "Study CompTia and give my money to Keisha"{

This lab teaches you:
  How law shapes architecture
  How to design asymmetric global systems
  How to explain tradeoffs to security, legal, and auditors
  How DevOps actually works across teams and states
  Become a Passport Bro and marry the girl of your dreams

If you can explain this lab clearly, you are operating at a Senior level.

🗣️ Interview Talk Track (Memorize This)

    “I designed a cross-region medical system where all PHI remained in Japan to comply with APPI.
    Tokyo hosted the database, São Paulo ran stateless compute, and Transit Gateway provided a controlled data corridor.
    CloudFront delivered a single global URL without violating data residency.”

That answer will stop the room.

🧠 One Sentence to Remember---> Global access does not require global storage.
    Anothe Sentence to Remember ---> I completed this lab in 2026 and now in 2029, I have a family.




Recommended Terraform layout for Aurora

## providers.tf/versions.tf:
AWS provider, region, default tags.

## variables.tf/locals.tf:
DB engine/class/version, instance count/AZs, usernames/passwords (prefer Secrets Manager/SSM), backup/retention toggles, storage encryption flags.
Note: `admin_ssh_cidr` is currently open (0.0.0.0/0) for setup. Tighten to your public IP (/32) before production.

## networking-rds.tf:
DB subnet group from private subnets; dedicated RDS SG allowing DB port only from app/ECS/EC2 SGs.

## vpc-endpoints.tf:
- Interface VPC endpoints for SSM, EC2 messages, SSM messages, and CloudWatch Logs.
- Endpoints are placed in private subnets and use the SSM/CW endpoint security groups.
- Resources: `aws_vpc_endpoint.ssm`, `aws_vpc_endpoint.ec2messages`, `aws_vpc_endpoint.ssmmessages`, `aws_vpc_endpoint.taaops_vpce_logs01`.

## kms.tf:
- CMK for RDS storage/logs, S3 data bucket, and Secrets Manager (via `kms:ViaService`).
- CMK `aws_kms_key.rds_s3_data` is used for RDS storage and the `jasopsoregon-s3-rds` bucket (SSE-KMS).
- ALB logs bucket uses SSE-S3 (AES256) for compatibility with log delivery.
- Optional: `kms_key_id` variable can be used later to switch to an existing CMK.

## rds-params.tf:
Cluster + instance parameter groups; option group if needed.

## rds-cluster.tf:
aws_rds_cluster with engine/version, creds via secret or managed password, backup/deletion protection/final snapshot settings, log exports, subnet group, SGs, KMS key, perf insights.

## rds-instances.tf:
aws_rds_cluster_instance (count/for_each) with instance class, AZ placement, monitoring role, parameter/option group refs.

## secrets.tf:
Secrets Manager/SSM params and (optionally) rotation.

## secrets-rotation.tf:
- Secret rotation Lambda: `SecretsManagertaaops-lab1-asm-rotation`
- Rotation schedule: every 24 hours for testing (set back to 30 days for production)
- Lambda VPC config: private subnets + `taaops_lambda_asm_sg`
- Note: do not use `manage_master_user_password = true` when using a custom rotation Lambda (service-managed secrets do not allow a custom Lambda).
- Variable: `secrets_rotation_days` controls rotation interval (set to `1` for testing, `30+` for production).

### How Secrets Manager + Lambda rotation is handled (Terraform)
This configuration uses a **custom Secrets Manager secret** plus a **rotation Lambda** (not the RDS service-managed secret). The flow is:

1) `16-secrets.tf` creates `aws_secretsmanager_secret.db_secret` and a `db_secret_version` with the initial username/password, engine, host, port, and dbname.
2) `15-database.tf` creates the Aurora cluster using `master_username` / `master_password` from variables (because we are **not** using `manage_master_user_password = true`).
3) `20-secrets-rotation.tf` deploys the rotation Lambda from `lambda/SecretsManagertaaops-lab1-asm-rotation.zip`, attaches it to the VPC, and grants Secrets Manager permission to invoke it.
4) `aws_secretsmanager_secret_rotation` links the Lambda to `db_secret` and sets the rotation interval (`secrets_rotation_days`).
5) On each rotation run, the Lambda updates the **secret** and the **DB password** in Aurora, keeping them in sync.

Key points:
- Service-managed RDS secrets (`manage_master_user_password = true`) cannot use a custom rotation Lambda.
- Rotation depends on the Lambda’s IAM permissions and network access (private subnets + security group + Secrets Manager endpoint or NAT).
- Use `secrets_rotation_days = 1` for testing; set to `30+` for production.

### CloudWatch alarms + SNS automation
- CloudWatch alarms publish to `aws_sns_topic.cloudwatch_alarms`.
- Optional email notifications use `sns_email_endpoint` (leave blank to skip the subscription).
- You can attach automation to the SNS topic (Lambda, SSM Automation, PagerDuty, etc.).
- This repo includes a basic Lambda hook: `aws_lambda_function.alarm_hook` (logs alarm payloads).
- Alarm docs (state values + alarm message format):
```
https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html
https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html#alarm-notification-format
https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/cloudwatch_concepts.html#CloudWatchAlarms
```

### Alarm hook pipeline (SNS → Lambda → Evidence bundle)
The alarm hook Lambda performs these steps when a CloudWatch alarm fires:
1) Parses alarm metadata from the SNS payload.
2) Runs a CloudWatch Logs Insights query (via `StartQuery`/`GetQueryResults`).
3) Fetches config from SSM Parameter Store and credentials metadata from Secrets Manager.
4) Calls Bedrock Runtime to generate a brief report (if `bedrock_model_id` is set).
5) Writes a Markdown + JSON evidence bundle to S3 (`alarm_reports_bucket_name`).
6) Triggers an SSM Automation runbook (defaults to the Terraform-created document if `automation_document_name` is empty).

Related variables:
- `alarm_reports_bucket_name`
- `alarm_logs_group_name`
- `alarm_logs_insights_query`
- `alarm_ssm_param_name`
- `alarm_secret_id` (optional override; defaults to the Terraform DB secret ARN)
- `automation_document_name`
- `automation_parameters_json`
- `bedrock_model_id`

### Bedrock Auto Incident Report Lambda (23-bedrock_autoreport.tf)
Environment variables used by `aws_lambda_function.galactus_ir_lambda01`:
- `REPORT_BUCKET`: S3 bucket for JSON + Markdown reports.
- `APP_LOG_GROUP`: CloudWatch Logs group for app logs (ensure it matches your app log group name).
- `WAF_LOG_GROUP`: CloudWatch Logs group for WAF logs (only if WAF logging → CloudWatch).
- `SECRET_ID`: Secrets Manager secret name/ARN for DB creds (e.g., `taaops/rds/mysql`).
- `SSM_PARAM_PATH`: Parameter Store path for DB config (e.g., `/lab/db/`).
- `BEDROCK_MODEL_ID`: Bedrock model ID (leave blank until ready).
- `SNS_TOPIC_ARN`: SNS topic for “Report Ready” notifications.

Report outputs (S3 + SNS):
- S3 keys are written under `reports/`:
  - JSON evidence bundle: `reports/ir-<incident_id>.json`
  - Markdown report: `reports/ir-<incident_id>.md`
- SNS message payload:
  - `bucket`, `json_key`, `markdown_key`, `incident_id`

AWS documentation (links):
```
https://docs.aws.amazon.com/bedrock/latest/userguide/what-is-bedrock.html
https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html
https://docs.aws.amazon.com/lambda/latest/dg/welcome.html
https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/AnalyzingLogData.html
https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html
https://docs.aws.amazon.com/systems-manager/latest/userguide/automation-documents.html
```

### AWS Translate
code courtesy of: maazinmm
https://github.com/maazinmm/AWS-Powered-Text-Translator-App-with-Amazon-Translate.git



### SSM Automation document
[SSM Agent](https://docs.aws.amazon.com/systems-manager/latest/userguide/install-plugin-windows.html)
[SSM Plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-setting-up-console-access.html)
- Terraform creates `aws_ssm_document.alarm_report_runbook` with a default incident report template.
- Lambda passes `IncidentId`, `AlarmName`, and S3 report keys to the runbook.

## outputs.tf:
Cluster and reader endpoints, SG ID, subnet group name, secret ARN.


# IAM
AmazonSSMManagedInstance
CloudWatchAgentServerPolicy
taaops-armageddon-lab-policy
    - TODO: verify these managed/inline policies are attached to the instance role and in effect.
    - KMS: Write // All resources // kms:ViaService = secretsmanager.us-west-2.amazonaws.com
    - Secrets Manager // Read us-west-2
    - Systems Manager // Read us-west-2



# Logs and S3 Buckets
- RDS data bucket: `jasopsoregon-s3-rds`
- ALB logs bucket: `jasopsoregon-alb-logs`
- ALB access logs prefix: `alb/taaops`
- Log path format: `s3://jasopsoregon-alb-logs/alb/taaops/AWSLogs/<account-id>/...`
- ALB log delivery policy is scoped to `data.aws_caller_identity.taaops_self01` and `aws_lb.taaops_lb01`.
- CloudFront logs bucket: `taaops-cloudfront-logs-<account-id>`
- CloudFront logs prefix: `cloudfront/`
- Recommended: add S3 lifecycle rules to expire or transition ALB logs (e.g., expire after 30–90 days or transition to Glacier).
- Recommended: set retention expectations in documentation and keep logs bucket private with public access blocked.

# WAF Logging (14b-waf-logging.tf)
- `waf_log_destination` supports:
  - `cloudwatch` (WAF -> CloudWatch Logs). Log group name must start with `aws-waf-logs-`.
  - `firehose` (WAF -> Kinesis Firehose -> S3). Use this for S3 storage (WAF does not support direct S3 logging).
- `waf_log_retention_days` controls log retention when using CloudWatch Logs.

# Terraform Script Execution (LAB3)
Run from `SEIR_Foundations/LAB3`:

```bash
bash ./terraform_startup.sh
bash ./terraform_destroy.sh
```

Notes:
- The apply wrapper in this repo is `terraform_startup.sh` (same role as `terraform_apply.sh`).
- In Bash, `terraform_destroy.sh` without `./` fails with `command not found`.
- If execute permissions are missing:

```bash
chmod +x terraform_startup.sh terraform_destroy.sh
```

PowerShell calling Bash:

```powershell
bash .\terraform_startup.sh
bash .\terraform_destroy.sh
```

# Python Scripts (Shell Notes)
If you run Python scripts from Git Bash on Windows, path conversion can break relative paths like `.\python\script.py` (it becomes `.pythonscript.py`). Use one of these instead:

PowerShell (recommended):
```
python .\python\script_name.py <args>
```

Git Bash (safe):
```
MSYS2_ARG_CONV_EXCL="*" python ./python/script_name.py <args>
```

If you see `can't open file ... .pythonscript.py`, switch to PowerShell or use the Git Bash command above.

# Run Gate Scripts (Lab 2)
From Git Bash in the repo root:
```
chmod +x python/run_all_gates.sh

ORIGIN_REGION="$(terraform output -raw origin_region)" \
CF_DISTRIBUTION_ID="$(terraform output -raw cloudfront_distribution_id)" \
DOMAIN_NAME="$(terraform output -raw domain_name)" \
ROUTE53_ZONE_ID="$(terraform output -raw route53_zone_id)" \
ACM_CERT_ARN="$(terraform output -raw cloudfront_acm_cert_arn)" \
WAF_WEB_ACL_ARN="$(terraform output -raw waf_web_acl_arn)" \
LOG_BUCKET="$(terraform output -raw cloudfront_logs_bucket)" \
ORIGIN_SG_ID="$(terraform output -raw origin_sg_id)" \
bash ./python/run_all_gates_l2.sh
```

# Gate Warning Notes
- **Origin SG "no visible sources"**: the gate checks `IpRanges`, `Ipv6Ranges`, and `UserIdGroupPairs`. If you use the **CloudFront managed prefix list**, the SG sources live under `PrefixListIds`, which is not visible to those older checks. The updated gate now reads prefix lists and will PASS when they are present.

# Post-Apply Verification Checklist
- Confirm ALB targets are healthy (ELB target group health is `healthy`).
- Confirm app responds on the ALB DNS:
  - `GET /` returns 200
  - `GET /init` initializes DB and returns 200
  - `GET /list` returns HTML list
- Confirm Secrets Manager secret exists and rotation is enabled.
- Confirm SSM document `taaops-incident-report` is Active.
- Confirm SNS topic `taaops-cloudwatch-alarms` has Lambda + email subscriptions.

## CloudFront Validation (cache + forwarding)
Origin TLS note:
- CloudFront connects to the ALB using a dedicated origin hostname (e.g., `${var.alb_origin_subdomain}.${var.domain_name}`) so the ALB cert matches.


### CloudFront Origin Cloaking:
NOTE: Origin cloaking enforced at Layer 7 via ALB header rule (not SG-only cloaking).
Uses HTTPS origin + header - Layer 7 over REST API's (/api/*)
ALB SG allows inbound 443 from internet
ALB HTTPS listener has:
  * Rule 1: if header X-Galactus-Code matches → forward (enforces cloaking with listener header rule)
  * Rule 2: default/fallback → fixed 403
CloudFront origin sends the secret header, so it passes.
Direct ALB request has no header, so it gets 403.
If you enforce strict SG cloaking (CloudFront prefix-list only), direct ALB can be unreachable (timeout/TLS handshake fail) instead of 403.

Follow-up checks (strict cloaking proof):
```
nslookup origin.<domain>
curl -I https://origin.<domain>
curl -vk https://origin.<domain>
```

# Restrict Access to ALB (CloudFront Managed Prefix List)
Commentary:
- This is “true origin cloaking” via SG rules: only CloudFront origin-facing IPs can reach the ALB.
- It’s stronger than header-only cloaking because it blocks direct-to-ALB traffic at the network layer.
- Expect direct ALB requests to time out or fail TLS handshake (no HTTP response).

Docs:
```
https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/restrict-access-to-load-balancer.html
https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/LocationsOfEdgeServers.html
https://aws.amazon.com/blogs/networking-and-content-delivery/limit-access-to-your-origins-using-the-aws-managed-prefix-list-for-amazon-cloudfront/
https://docs.aws.amazon.com/whitepapers/latest/aws-best-practices-ddos-resiliency/protecting-your-origin-bp1-bp5.html
```

TESTS:
1) Confirm distribution status is Deployed:
```
aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='${var.project_name}-cf01'].[Id,Status,DomainName]" --output table
```

2) Static caching proof (run twice):
```
curl -I https://jastek.click/
curl -I https://jastek.click/
```
Expected:
- `Cache-Control: public, max-age=...` from response headers policy
- `Age` appears and increases on the second request
Note:
- Static cache tests assume consistent content across instances. In `scripts/user_data.sh`, we set a fixed mtime for `/opt/rdsapp/static/index.html` and `/opt/rdsapp/static/example.txt` so CloudFront sees stable `ETag`/`Last-Modified`. If you intentionally change static content, update the file contents and bump the fixed timestamp (or invalidate the path).

3) API must NOT cache (run twice):
```
curl -I https://jastek.click/api/list
curl -I https://jastek.click/api/list
```
Expected:
- `Age` absent or `0`

4) Cache key sanity (query strings ignored on static):
```
curl -I "https://jastek.click/?v=1"
curl -I "https://jastek.click/?v=2"
```
Expected:
- Same cached object (Age stays high or increases)

Example sanity check run:
```
RUN_POST_APPLY_CHECKS=true \
TARGET_GROUP_ARN="arn:aws:elasticloadbalancing:us-west-2:015195098145:targetgroup/taaops-lb-tg80/39344a5264d40de8" \
ALB_DNS="taaops-load-balancer-989477164.us-west-2.elb.amazonaws.com" \
./sanity_check.sh
```

### Bedrock Invoke Test (Claude)
The test script reads values from environment variables so you can switch regions/models quickly.
Defaults:
- `AWS_REGION`: `us-east-1`
- `BEDROCK_MODEL_ID`: `anthropic.claude-3-haiku-20240307-v1:0`
- `BEDROCK_PROMPT`: `Describe the purpose of a 'hello world' program in one line.`

Example:
```
AWS_REGION=us-west-2 \
BEDROCK_MODEL_ID="anthropic.claude-3-haiku-20240307-v1:0" \
BEDROCK_PROMPT="Say hello in one line." \
python python/bedrock_invoke_test_claude.py
```

### AWS Translate Pipeline Test (S3 -> Lambda -> Translate)
Translation resources (Tokyo stack outputs):
- `translation_input_bucket_name`: `taaops-translate-input`
- `translation_output_bucket_name`: `taaops-translate-output`
- `translation_lambda_function_name`: `taaops-translate-ap-northeast-1-processor`

Single-file end-to-end test:
```
python ./python/translate_via_s3.py \
  --input-bucket taaops-translate-input \
  --output-bucket taaops-translate-output \
  --source-file Tokyo/audit/3b_audit.txt \
  --region ap-northeast-1 \
  --download-to LAB3-DELIVERABLES/results/3b_audit_translated_latest.txt
```

Batch test for all audit text files:
```
python ./python/translate_batch_audit.py \
  --input-bucket taaops-translate-input \
  --output-bucket taaops-translate-output \
  --source-dir Tokyo/audit \
  --glob "*.txt" \
  --region ap-northeast-1
```

Verify Lambda execution logs:
```
MSYS2_ARG_CONV_EXCL="*" aws logs tail "/aws/lambda/taaops-translate-ap-northeast-1-processor" \
  --region ap-northeast-1 --since 10m
```

### Run Remote Checks on the EC2 (SSM)
Remote checks must run on the instance (they validate the instance role directly). Steps:
1) Start an SSM session:
```
aws ssm start-session --target <instance-id> --region us-west-2
```
2) On the instance, install the script:
```
cd /home/ec2-user
# paste the contents of sanity_check.sh from this repo into the file:
cat > sanity_check.sh <<'EOF'
<paste the file contents here>
EOF
chmod +x sanity_check.sh
```
3) Run remote checks:
```
RUN_REMOTE_CHECKS=true ./sanity_check.sh
```

Notes:
- `RUN_REMOTE_CHECKS=true` will auto-skip if not running on EC2.
- If you prefer copying instead of pasting, use `scp` or `aws ssm send-command` from your local terminal (not inside the EC2 session).

Optional: Fetch the script from S3 instead of pasting
1) Upload from your local terminal:
```
aws s3 cp sanity_check.sh s3://<your-bucket>/tools/sanity_check.sh
```
2) On the EC2 instance (SSM session):
```
cd /home/ec2-user
aws s3 cp s3://<your-bucket>/tools/sanity_check.sh ./sanity_check.sh
chmod +x ./sanity_check.sh
RUN_REMOTE_CHECKS=true ./sanity_check.sh
```

Optional: Use a pre-signed URL (no S3 permissions on the instance)
1) From your local terminal:
```
aws s3 presign s3://<your-bucket>/tools/sanity_check.sh --expires-in 3600
```
2) On the EC2 instance (SSM session), download via curl:
```
cd /home/ec2-user
curl -o sanity_check.sh "<presigned-url>"
chmod +x ./sanity_check.sh
RUN_REMOTE_CHECKS=true ./sanity_check.sh
```

### Test the Incident Report Pipeline (Manual)
1) Create a test alarm payload:
```
cat > ./scripts/alarm.json <<'EOF'
{
  "AlarmName": "manual-test-alarm",
  "AlarmDescription": "Manual test to trigger incident report pipeline",
  "NewStateValue": "ALARM",
  "OldStateValue": "OK",
  "StateChangeTime": "2026-02-01T12:00:00Z",
  "MetricName": "RdsAppDbErrors",
  "Namespace": "Lab/RDSApp",
  "Statistic": "Sum",
  "Period": 60,
  "EvaluationPeriods": 1,
  "Threshold": 1,
  "ComparisonOperator": "GreaterThanOrEqualToThreshold"
}
EOF
```

2) Publish to the trigger SNS topic (Lambda trigger; avoids recursion):
```
REPORT_TOPIC_ARN="$(aws sns list-topics --region us-west-2 \
  --query "Topics[?contains(TopicArn,'taaops-ir-trigger-topic')].TopicArn" \
  --output text)"

aws sns publish \
  --topic-arn "$REPORT_TOPIC_ARN" \
  --message file://scripts/alarm.json \
  --region us-west-2
```

3) List the generated reports in S3:
```
REPORT_BUCKET="$(terraform output -raw galactus_ir_reports_bucket)"
aws s3 ls "s3://$REPORT_BUCKET/reports/" --region us-west-2
```

4) View the latest Markdown report:
```
aws s3 cp "s3://$REPORT_BUCKET/reports/ir-manual-test-alarm-<timestamp>.md" -
```

Optional: filter important reports by name (example includes ALARM in filename):
```
aws s3 sync "s3://$REPORT_BUCKET/reports/" ./reports/IR/ \
  --exclude "*" \
  --include "*ALARM*.md" \
  --include "*ALARM*.json" \
  --region us-west-2
```

Optional helper scripts (ALARM report filters/downloads):
```
REPORT_BUCKET="$(terraform output -raw galactus_ir_reports_bucket)"

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
# Severity filter (reads alarm.Severity or parses AlarmDescription for "Severity: <value>")
ALARM_SEVERITY=critical REPORT_BUCKET="$REPORT_BUCKET" ./scripts/filter_alarm_reports.sh
```

Shell note:
- Git Bash: run the `./scripts/*.sh` commands shown above.
- PowerShell: use PowerShell-native commands/examples (e.g., `Get-ChildItem`, `Select-String`).

## Auto-IR Runbook (Human + Amazon Bedrock Incident Response)
Purpose: This runbook defines how a human on-call engineer uses the Bedrock-generated incident report safely, verifies it against raw evidence, and produces a final, auditable incident artifact.

Core rule: Bedrock accelerates analysis. Humans own correctness.

### Preconditions
- Alarm triggered and SNS -> Lambda -> S3 pipeline completed.
- Report artifacts exist in S3 (`ir-*.md` + `ir-*.json`).
- Access to CloudWatch Logs, CloudWatch Alarms, SSM Parameter Store, and Secrets Manager.

### Step 1: Retrieve the report and evidence bundle
```
REPORT_BUCKET="$(terraform output -raw galactus_ir_reports_bucket)"
aws s3 ls "s3://$REPORT_BUCKET/reports/" --region us-west-2
aws s3 cp "s3://$REPORT_BUCKET/reports/ir-<incident_id>.md" ./reports/IR/ir-report.md
aws s3 cp "s3://$REPORT_BUCKET/reports/ir-<incident_id>.json" ./reports/IR/ir-evidence.json
```

### Step 2: Verify alarm metadata (source of truth)
- Open the alarm in CloudWatch and confirm:
  - Alarm name, metric, threshold, evaluation periods.
  - State transitions and timestamps.
```
aws cloudwatch describe-alarms \
  --alarm-names "<alarm-name>" \
  --region us-west-2 \
  --output table
```

### Step 3: Verify logs evidence (raw)
- App logs (CloudWatch Logs Insights):
```
aws logs start-query \
  --log-group-name "/aws/ec2/rdsapp" \
  --start-time <epoch-start> \
  --end-time <epoch-end> \
  --query-string "fields @timestamp, @message | sort @timestamp desc | limit 50" \
  --region us-west-2
```
- WAF logs (if enabled; CloudWatch destination):
```
aws logs start-query \
  --log-group-name "aws-waf-logs-<project>-webacl01" \
  --start-time <epoch-start> \
  --end-time <epoch-end> \
  --query-string "fields @timestamp, action, httpRequest.clientIp as clientIp, httpRequest.uri as uri | stats count() as hits by action, clientIp, uri | sort hits desc | limit 25" \
  --region us-west-2
```
- Confirm the report’s summary matches raw logs (timestamps, counts, key errors).

### Step 4: Verify config sources used for recovery
- Parameter Store values:
```
aws ssm get-parameters \
  --names /lab/db/endpoint /lab/db/port /lab/db/name \
  --with-decryption \
  --region us-west-2
```
- Secrets Manager metadata:
```
aws secretsmanager describe-secret \
  --secret-id "taaops/rds/mysql" \
  --region us-west-2
```
- Confirm that the report references the correct secret name/ARN and SSM path.

### Step 5: Human review + corrections
- Identify any mismatch between the report and evidence.
- Add corrections directly in the Markdown report:
  - Root cause summary (what actually failed).
  - Timeline accuracy (when it started and recovered).
  - Actions taken and validation.
  - Preventive actions.

### Step 6: Finalize and archive
- Save the corrected report locally and re-upload to S3:
```
aws s3 cp ./reports/IR/ir-report.md "s3://$REPORT_BUCKET/reports/ir-<incident_id>-final.md" --region us-west-2
```
- Optional: store a short summary to a ticketing system or change log.

## Script glossary (quick reference)
- `sanity_check.sh`: Local/remote verification of infra + app health; supports flags for optional checks.
- `scripts/publish_sanity_check.sh`: Uploads `sanity_check.sh` to S3 and prints a presigned URL.
- `scripts/filter_alarm_reports.sh`: Lists report JSONs and filters by alarm state/name/severity/time.
- `scripts/download_alarm_reports.sh`: Downloads matching report JSON + Markdown pairs from S3.
- `scripts/alarm.json`: Sample manual alarm payload for SNS/Lambda tests.
- `scripts/user_data.sh`: EC2 user-data script for the app + dependencies.
- `python/bedrock_invoke_test_claude.py`: Simple Bedrock invoke test using env vars.

### Checklist (human-owned)
- [ ] Alarm details verified against CloudWatch
- [ ] Logs evidence verified against CloudWatch Logs
- [ ] Parameter Store and Secrets verified
- [ ] Report corrected for accuracy
- [ ] Final report archived with “-final” suffix

## Stack Directory Note
- Active Terraform stacks are run from:
  - `global/`
  - `Tokyo/`
  - `saopaulo/`
- Do not run Terraform from the repository root.
- Legacy root-level Terraform files were moved to `archive/root-terraform-from-root/` for reference.
