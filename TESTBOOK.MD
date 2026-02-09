# LAB2 Testbook

Checklist with commands and expected results. Replace placeholders:
- `<ALB_DNS_NAME>`
- `<DISTRIBUTION_ID>`
- `<WEB_ACL_ID>`
- `<project>`
- `<domain>` (e.g., `jastek.click`)
- `<app-domain>` (e.g., `app.jastek.click`)

## Pre-step: Load outputs from Terraform (optional)
```bash
ALB_DNS_NAME="$(terraform output -raw alb_dns_name)"
DISTRIBUTION_ID="$(terraform output -raw cloudfront_distribution_id)"
WEB_ACL_ID="$(terraform output -raw cloudfront_waf_id)"
DOMAIN_NAME="$(terraform output -raw domain_name 2>/dev/null || echo "jastek.click")"
APP_SUBDOMAIN="$(terraform output -raw app_subdomain 2>/dev/null || echo "app")"
APP_DOMAIN="${APP_SUBDOMAIN}.${DOMAIN_NAME}"
```
If you set these, replace placeholders with the variables:
- `<ALB_DNS_NAME>` -> `$ALB_DNS_NAME`
- `<DISTRIBUTION_ID>` -> `$DISTRIBUTION_ID`
- `<WEB_ACL_ID>` -> `$WEB_ACL_ID`
- `<domain>` -> `$DOMAIN_NAME`
- `<app-domain>` -> `$APP_DOMAIN`

## 1) VPC only reachable via CloudFront
- [ ] Direct ALB access fails
```bash
curl -I https://$ALB_DNS_NAME
```
Expected:
- **Strict cloaking** (ALB SG only allows CloudFront prefix list): connection **fails** (timeout/reset/TLS error). This is OK and expected.
- **Header-only cloaking** (ALB reachable from your IP): returns `403` (blocked by missing header).

- [ ] CloudFront access succeeds
```bash
curl -I https://$DOMAIN_NAME
curl -I https://$APP_DOMAIN
```
Expected: `200` or `301 -> 200`.
If CloudFront returns `502`, check:
- ALB target health and listener rules
- Origin hostname + TLS cert match (`origin.<domain>`)
- Security group allows CloudFront prefix list on 443
Note: Direct ALB testing with HTTPS should use the origin hostname (e.g., `https://origin.<domain>`) so SNI matches the ALB cert. Using the raw ALB DNS can fail TLS.

## 2) WAF moved to CloudFront
- [ ] Get CloudFront WAF
```bash
aws wafv2 get-web-acl \
  --name <project>-cf-waf01 \
  --scope CLOUDFRONT \
  --id $WEB_ACL_ID
```
- [ ] Confirm distribution references WAF
```bash
aws cloudfront get-distribution \
  --id $DISTRIBUTION_ID \
  --query "Distribution.DistributionConfig.WebACLId"
```
Expected: WebACL ARN present.

## 3) DNS points to CloudFront
- [ ] Apex resolves to CloudFront
```bash
dig $DOMAIN_NAME A +short
```
- [ ] App subdomain resolves to CloudFront
```bash
dig $APP_DOMAIN A +short
```
Expected: CloudFront anycast behavior (not ALB IPs).

## 4) Safe Caching (headers + evidence)
- [ ] Demonstrate Cache-Control from origin
```bash
curl -i https://$DOMAIN_NAME/static/index.html | sed -n '1,30p'
```
Expected: `Cache-Control` present and appropriate.

- [ ] Static file sanity (example.txt)
```bash
curl -I https://$DOMAIN_NAME/static/example.txt | head -n 20
curl -I https://$DOMAIN_NAME/static/example.txt | head -n 20
```
Expected:
- First request: `200 OK`, `X-Cache: Miss from cloudfront`
- Second request: `X-Cache: Hit from cloudfront` or `RefreshHit from cloudfront`
- `Age` increases once cached

## 5) Break-glass invalidation (CLI)
- [ ] Create invalidation (single path)
```bash
aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/static/index.html"
```

- [ ] Create invalidation (wildcard path)
```bash
aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/static/*"
```
Notes:
- Wildcards must be the last character.
- Paths must start with `/`.
- Docs: `https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/invalidation-specifying-objects.html`

Windows/Git Bash note (spaces in path): use a JSON batch file.
```bash
cat > /c/temp/invalidation.json <<'JSON'
{
  "Paths": {
    "Quantity": 1,
    "Items": ["/static/example.txt"]
  },
  "CallerReference": "manual-$(date +%s)"
}
JSON

aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --invalidation-batch "file://c:/temp/invalidation.json"
```

- [ ] Track invalidation completion
```bash
aws cloudfront get-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --id <INVALIDATION_ID>
```

## 6) Correctness proof (cache before/after)
- [ ] Before invalidation, prove cached object
```bash
curl -i https://$DOMAIN_NAME/static/index.html | sed -n '1,30p'
curl -i https://$DOMAIN_NAME/static/index.html | sed -n '1,30p'
```
Expected:
- `Age` increases on second request
- `x-cache` shows `Hit from cloudfront` (or similar)
- Docs: `https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cache-statistics.html`

- [ ] Deploy change (simulate)
Update `index.html` at origin.

- [ ] After invalidation, prove cache refresh
```bash
curl -i https://$DOMAIN_NAME/static/index.html | sed -n '1,30p'
```
Expected:
- `x-cache` shows `Miss` or `RefreshHit`
- Docs: `https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/standard-logs-reference.html`

## 7) RefreshHit / Validators
- [ ] Identify validators (ETag or Last-Modified)
```bash
curl -i https://$DOMAIN_NAME/static/index.html | sed -n '1,30p'
```
Expected: `ETag` or `Last-Modified`.

- [ ] Explain RefreshHit (written)
"CloudFront had a cached copy, TTL expired, it sent a conditional request (If-None-Match/If-Modified-Since). Origin returned 304, CloudFront reused cached body."

## 8) Prove it's NOT a full miss
- [ ] Wait for TTL then re-check
```bash
sleep 6
curl -i https://$DOMAIN_NAME/static/index.html | sed -n '1,30p'
```
Expected:
- `x-cache: RefreshHit from cloudfront`
- Response body unchanged
- Latency slightly higher than Hit

## 9) Injection B  "Why won't my change show up?"
- [ ] Change content but keep same ETag or validators
Expected:
- `RefreshHit` continues
- Users see stale content

- [ ] Choose fix (justify one)
| Fix | When appropriate |
| --- | --- |
| Update ETag | Correct fix |
| Update Last-Modified | Acceptable |
| Invalidate object | Emergency only |
| Increase TTL | Only if content truly stable |

## 10) Controlled invalidation (tie-in to Honors+)
- [ ] Invalidate only the minimum path
```bash
aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/static/index.html"
```
Explain:
- Why invalidation works
- Why it's not preferred
- Why updating validators is better

## 11) Log interpretation (advanced)
- [ ] If ALB access logs are enabled, verify conditional requests (If-None-Match / 304).
- [ ] If CloudFront logs enabled, explain:
  - `x-edge-result-type = RefreshHit`
  - `sc-status = 304`

## 12) Auto-IR tie-in (bonus)
- [ ] If Auto-IR reports "CloudFront cache anomaly," override with:
"Observed RefreshHit due to short TTL + validators; system operating as designed."

## 13) Additional Python Checks (from ./python)
- [ ] Alarm triage (CloudWatch)
```bash
python galactus_alarm_triage.py
```
Expected: list of ALARM state alarms (or zero).

- [ ] Origin cloaking verifier
```bash
python galactus_origin_cloak_tester.py https://$DOMAIN_NAME https://origin.$DOMAIN_NAME
```
Expected (header-only cloaking): CloudFront URL is OK; ALB direct returns `401/403`.
Expected (strict SG cloaking): direct ALB is unreachable (timeout/TLS handshake fail).
Follow-up checks (proof of strict cloaking):
```bash
nslookup origin.$DOMAIN_NAME
curl -I https://origin.$DOMAIN_NAME
curl -vk https://origin.$DOMAIN_NAME
```

- [ ] CloudFront cache probe
```bash
python galactus_cloudfront_cache_probe.py https://$DOMAIN_NAME/static/example.txt
```
Expected: `x-cache` evolves (Miss -> Hit/RefreshHit) and `Age` increases.

- [ ] Logs Insights runner
```bash
python galactus_logsinsights_runner.py \
  --log-group /aws/ec2/taaops-rds-app \
  --minutes 15 \
  --query 'fields @timestamp, @message | sort @timestamp desc | limit 5'
```
Expected: recent log lines printed as key/value maps.

- [ ] Secret drift checker
```bash
SSM_PATH=/lab/db/ SECRET_ID=taaops/rds/mysql \
python galactus_secret_drift_checker.py
```
Expected: `OK` lines or `DRIFT:` warnings, then PASS/FAIL.

- [ ] WAF block spike detector
```bash
WAF_WEB_ACL_ARN="$(terraform output -raw waf_web_acl_arn)" \
python galactus_waf_block_spike_detector.py
```
Expected: "No significant spike" or spike warning.

- [ ] Cost guardrail estimator (CloudFront invalidations)
```bash
python galactus_cost_guardrail_estimator.py --dist-id "$DISTRIBUTION_ID"
```
or
```bash
CLOUDFRONT_DISTRIBUTION_ID="$DISTRIBUTION_ID" \
python galactus_cost_guardrail_estimator.py
```
Expected: list of recent invalidations.

## 14) Tokyo + Sao Paulo Architecture Proofs
Verification commands (CLI proof students can paste):

### 14.1) Data residency proof (RDS only in Tokyo)
- [ ] Tokyo: RDS exists
```bash
aws rds describe-db-instances --region ap-northeast-1 \
  --query "DBInstances[].{DB:DBInstanceIdentifier,AZ:AvailabilityZone,Region:'ap-northeast-1',Endpoint:Endpoint.Address}"
```

- [ ] Sao Paulo: No RDS
```bash
aws rds describe-db-instances --region sa-east-1 \
  --query "DBInstances[].DBInstanceIdentifier"
```

### 14.2) Edge proof (CloudFront logs show cache + access)
- [ ] Capture request headers
```bash
curl -I https://jastek.click/api/public-feed
```

- [ ] Provide CloudFront standard log evidence (Hit/Miss/RefreshHit)

### 14.3) WAF proof
- [ ] Provide WAF log snippet or Insights summary
- [ ] WAF logging destination options are documented

### 14.4) Change proof (CloudTrail)
CloudTrail event history provides a 90-day immutable record of management events.
- [ ] Capture: who changed SG / TGW route / WAF / CloudFront config

### 14.5) Network corridor proof (TGW)
- [ ] TGW attachments exist in both regions
- [ ] Routes point cross-region CIDRs to TGW

### 14.6) AWS CLI verification (bucket/logs exist)
```bash
aws s3 ls s3://taaops-cloudfront-logs-015195098145/
# If logs are under a folder/prefix:
aws s3 ls s3://taaops-cloudfront-logs-015195098145/cloudfront/ --recursive | tail -n 20
```

Download one file manually (sanity check):
```bash
aws s3 cp s3://taaops-cloudfront-logs-015195098145/cloudfront/<somefile>.gz .
```

### 14.7) Outputs snapshot (Tokyo + Sao Paulo)
Capture outputs for proof:

Tokyo:
```bash
terraform output
```
Expected outputs include:
- tokyo_transit_gateway_id
- tokyo_transit_gateway_arn
- tokyo_vpc_id
- tokyo_vpc_cidr
- database_endpoint
- database_reader_endpoint
- database_secret_arn
- database_security_group_id
- tokyo_sao_peering_id
- kms_key_id
- cloudwatch_log_group_name
- domain_name
- cloudfront_distribution_id
- cloudfront_distribution_domain_name
- cloudfront_waf_arn
- regional_waf_arn
- incident_reports_bucket_name
- incident_reports_bucket_arn
- ir_lambda_function_name
- ir_lambda_function_arn
- ir_trigger_topic_arn
- ir_reports_topic_arn
- ssm_automation_document_name
- route53_zone_id
- tokyo_region
- account_id
- translation_input_bucket_name
- translation_input_bucket_arn
- translation_output_bucket_name
- translation_lambda_function_name
- translation_lambda_function_arn

Sao Paulo:
```bash
terraform output
```
Expected outputs include:
- vpc_id
- vpc_cidr
- private_subnet_ids
- public_subnet_ids
- saopaulo_transit_gateway_id
- transit_gateway_arn
- alb_dns_name
- alb_zone_id
- alb_arn
- asg_name
- asg_arn
- instance_profile_name
- instance_role_arn
- s3_alb_logs_bucket
- s3_app_logs_bucket
- cloudwatch_log_group_app
- cloudwatch_log_group_system
- sns_topic_alerts_arn
- region

## 15) Proof Scripts
Script 1 - galactus_residency_proof.py
Creates a "DB only in Tokyo" proof file.

Script 2 - galactus_tgw_corridor_proof.py
Shows TGW attachments + routes that form the "legal corridor".

Script 3 - galactus_cloudtrail_last_changes.py
Pulls recent CloudTrail events for "who changed what".
Event history is available by default; it provides a 90-day record of management events.

Script 4 - galactus_waf_summary.py
Summarizes WAF logs (Allow vs Block) from CloudWatch Logs destination.
WAF logging destinations: CloudWatch Logs, S3, Firehose.

Script 5 - galactus_cloudfront_log_explainer.py (optional)
If you ingest CloudFront standard logs into S3, this script reads a log file and counts Hit/Miss/RefreshHit.

CloudFront standard logs reference Hit / RefreshHit semantics.

### 15.1) Standard logs in S3 (downloaded locally)
```bash
python3 galactus_cloudfront_log_explainer.py --mode standard cloudfront.log.gz
python3 galactus_cloudfront_log_explainer.py --mode standard cloudfront_part1.log cloudfront_part2.log
```

### 15.2) Real-time logs as JSON lines
```bash
python3 galactus_cloudfront_log_explainer.py --mode realtime realtime_logs.jsonl
```

## 16) Final Lab Assumptions (Locked)
- S3 Bucket: taaops-cloudfront-logs-015195098145
- CloudFront Logs Prefix: cloudfront/
- AWS Account ID: 015195098145

## 17) Running Scripts
```bash
python3 galactus_cloudfront_log_explainer.py --latest 5
python3 galactus_cloudfront_log_explainer.py --prefix cloudfront-logs/ --latest 10
python3 galactus_cloudfront_log_explainer.py --prefix cloudfront-logs/ --latest 5 --keep
```

From stdin (nice for pipelines):
```bash
zcat cloudfront.log.gz | python3 galactus_cloudfront_log_explainer.py --mode standard -
```

Where "Hit / Miss / RefreshHit" come from (student-facing truth)
In standard CloudFront logs, read:
- x-edge-result-type (primary)
- x-edge-response-result-type (secondary)

Common values: Hit, Miss, RefreshHit, plus other states like Error, LimitExceeded, etc.
## Deliverables (required)
- [ ] One-paragraph takeaway:
"What does RefreshHit mean, and why is it often better than a Miss?"



