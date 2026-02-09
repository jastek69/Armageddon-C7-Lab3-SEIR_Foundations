# TESTBOOK RESULTS

## Pre-step Outputs (Terraform)
- ALB_DNS_NAME: taaops-tokyo-alb-101234176.ap-northeast-1.elb.amazonaws.com
- DISTRIBUTION_ID: E2T6L4WML8KX93
- CloudFront Domain: d1q01cj8sa3hta.cloudfront.net
- WEB_ACL_ID: a3addd66-56a7-4327-924d-7663d81b3444
- DOMAIN_NAME: jastek.click
- APP_DOMAIN: app.jastek.click

## 1) VPC only reachable via CloudFront
- Direct ALB access fails
Command: curl -I https://taaops-load-balancer-1940885000.us-west-2.elb.amazonaws.com
Result: curl: (35) schannel: failed to receive handshake, SSL/TLS connection failed
Status: PASS (expected failure)



- CloudFront access succeeds (app domain)
Command: curl -I https://app.jastek.click
Result:
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8
Content-Length: 114
Connection: keep-alive
Date: Fri, 06 Feb 2026 22:27:31 GMT
Server: Werkzeug/3.1.5 Python/3.9.25
X-Cache: Miss from cloudfront
Via: 1.1 f96503dd698abb96689f6023391729a4.cloudfront.net (CloudFront)
X-Amz-Cf-Pop: LAX54-P11
X-Amz-Cf-Id: HFzR0w6-PXkb2_bzvG3cf0_sPda1H4h4hyl9NBOjvGvJ9yc_CPj7cw==
Status: PASS

- CloudFront access succeeds (apex domain)
Command: curl -I https://jastek.click
Result:
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8
Content-Length: 114
Connection: keep-alive
Date: Fri, 06 Feb 2026 22:31:56 GMT
Server: Werkzeug/3.1.5 Python/3.9.25
X-Cache: Miss from cloudfront
Via: 1.1 decdbca6d1c29900b3f7901d2e2bc954.cloudfront.net (CloudFront)
X-Amz-Cf-Pop: LAX54-P11
X-Amz-Cf-Id: -wVYKOlzTzr2fPtlsUcFR_BAVvJSjbv9Qw29eyQfgchypazfDGWV0Q==
Status: PASS

## 2) WAF moved to CloudFront
- Get CloudFront WAF (us-east-1)
Command: aws wafv2 get-web-acl --name taaops-cf-waf01 --scope CLOUDFRONT --id 99d6a81b-5e9f-4e12-a5d5-d728ae4eafc8 --region us-east-1
Result: WebACL ARN arn:aws:wafv2:us-east-1:015195098145:global/webacl/taaops-cf-waf01/99d6a81b-5e9f-4e12-a5d5-d728ae4eafc8
Status: PASS

- Confirm distribution references WAF
Command: aws cloudfront get-distribution --id E1B1H41XMRI4R5 --query 'Distribution.DistributionConfig.WebACLId'
Result: arn:aws:wafv2:us-east-1:015195098145:global/webacl/taaops-cf-waf01/99d6a81b-5e9f-4e12-a5d5-d728ae4eafc8
Status: PASS

## 3) DNS points to CloudFront
Command: nslookup -type=A jastek.click
Result: DNS request timed out (server 192.168.1.1)
Status: INCONCLUSIVE (local DNS timeout)

Command: nslookup -type=A app.jastek.click
Result: DNS request timed out (server 192.168.1.1)
Status: INCONCLUSIVE (local DNS timeout)

Command: nslookup -type=A jastek.click 8.8.8.8
Result: DNS request timed out (server 8.8.8.8)
Status: INCONCLUSIVE (external DNS timeout)

Command: nslookup -type=A app.jastek.click 8.8.8.8
Result: DNS request timed out (server 8.8.8.8)
Status: INCONCLUSIVE (external DNS timeout)

## 4) Safe Caching (headers + evidence)
Command: curl -i https://jastek.click/static/index.html | sed -n '1,30p'
Result: curl: (6) Could not resolve host: jastek.click
Status: INCONCLUSIVE (DNS resolution failure)

## 4) Safe Caching (headers + evidence)
Command: curl -i https://d1w5uclskrcusd.cloudfront.net/static/index.html | sed -n '1,30p'
Result: HTTP/1.1 404 Not Found; X-Cache: Error from cloudfront; Cache-Control: public, max-age=86400, immutable
Status: FAIL (static path missing at origin)

Command: curl -i https://app.jastek.click/static/index.html | sed -n '1,30p'
Result: HTTP/1.1 404 Not Found; X-Cache: Error from cloudfront; Age: 8; Cache-Control: public, max-age=86400, immutable
Status: FAIL (static path missing at origin)

- Static file sanity (example.txt)
Command: curl -I https://app.jastek.click/static/example.txt | head -n 20 (first)
Result: HTTP/1.1 200 OK; X-Cache: Miss from cloudfront; Cache-Control: public, max-age=86400, immutable
Command: curl -I https://app.jastek.click/static/example.txt | head -n 20 (second)
Result: HTTP/1.1 200 OK; X-Cache: Miss from cloudfront; Cache-Control: public, max-age=86400, immutable
Status: FAIL (expected Hit/RefreshHit on second request)
Note: ETag/Last-Modified changed between requests, suggesting file is being rewritten; cache never stabilizes.

## 4) Safe Caching (headers + evidence) - RETEST
Command: curl -i https://app.jastek.click/static/index.html | sed -n '1,30p'
Result: HTTP/1.1 200 OK; Cache-Control: public, max-age=86400, immutable; X-Cache: Miss from cloudfront
Status: PASS (Cache-Control present)

Command: curl -I https://app.jastek.click/static/example.txt | head -n 20 (first)
Result: HTTP/1.1 200 OK; X-Cache: Miss from cloudfront; Cache-Control: public, max-age=86400, immutable
Command: curl -I https://app.jastek.click/static/example.txt | head -n 20 (second)
Result: HTTP/1.1 200 OK; X-Cache: Miss from cloudfront; Cache-Control: public, max-age=86400, immutable
Status: FAIL (expected Hit/RefreshHit on second request)
Note: ETag/Last-Modified changed between requests; likely different origin instances or file rewritten.

## 4) Safe Caching (headers + evidence) - FINAL
Command: curl -i https://app.jastek.click/static/index.html | sed -n '1,30p'
Result: HTTP/1.1 200 OK; Cache-Control: public, max-age=86400, immutable; X-Cache: Miss from cloudfront
Status: PASS (Cache-Control present)

Command: curl -I https://app.jastek.click/static/example.txt | head -n 20 (first)
Result: HTTP/1.1 200 OK; X-Cache: Miss from cloudfront; ETag stable; Last-Modified: Sat, 07 Feb 2026 00:00:00 GMT
Command: curl -I https://app.jastek.click/static/example.txt | head -n 20 (second)
Result: HTTP/1.1 200 OK; X-Cache: RefreshHit from cloudfront
Status: PASS (RefreshHit on second request)

## 5) Break-glass invalidation (CLI)
- Create invalidation (single path)
Command: aws cloudfront create-invalidation --distribution-id E1B1H41XMRI4R5 --paths "/static/index.html"
Result: InvalidArgument: invalid invalidation paths
Status: FAIL

- Create invalidation (wildcard path)
Command: aws cloudfront create-invalidation --distribution-id E1B1H41XMRI4R5 --paths "/static/*"
Result: Invalidation Id IAN0BCLUX27450FOWZBVVMZFOA; Status InProgress; CreateTime 2026-02-07T01:14:02.153000+00:00
Status: PASS

- Create invalidation (single path) - retries
Command: aws cloudfront create-invalidation --distribution-id E1B1H41XMRI4R5 --paths /static/index.html
Result: InvalidArgument (invalid invalidation paths)
Status: FAIL

- Create invalidation (single path) - single quotes
Command: aws cloudfront create-invalidation --distribution-id E1B1H41XMRI4R5 --paths '/static/index.html'
Result: InvalidArgument (invalid invalidation paths)
Status: FAIL

- Create invalidation (batch file)
Command: aws cloudfront create-invalidation --invalidation-batch file://c:/temp/invalidation.json
Result: InvalidArgument (caller reference reused: manual-1770427404)
Status: FAIL

- Create invalidation (single path) - batch file success
Command: aws cloudfront create-invalidation --invalidation-batch file://c:/temp/invalidation.json
Result: Invalidation Id I68HO5C5E9C8NY1OF74YI48G2I; Status InProgress; CreateTime 2026-02-07T01:24:23.463000+00:00
Status: PASS

- Track invalidation completion (single path)
Command: aws cloudfront get-invalidation --distribution-id E1B1H41XMRI4R5 --id I68HO5C5E9C8NY1OF74YI48G2I
Result: Status Completed
Status: PASS

- Track invalidation completion (wildcard)
Command: aws cloudfront get-invalidation --distribution-id E1B1H41XMRI4R5 --id IAN0BCLUX27450FOWZBVVMZFOA
Result: Status Completed
Status: PASS

## 6) Correctness proof (cache before/after)
- Before invalidation (attempt 1)
Command: curl -i https://app.jastek.click/static/index.html | sed -n '1,30p'
Result: curl: (6) Could not resolve host: app.jastek.click
Status: INCONCLUSIVE (DNS failure)

- Before invalidation (attempt 2)
Command: curl -i https://app.jastek.click/static/index.html | sed -n '1,30p'
Result: HTTP/1.1 200 OK; X-Cache: Miss from cloudfront
Status: PARTIAL (expected Hit/RefreshHit on second request)

- Before invalidation (retry - success)
Command: curl -i https://app.jastek.click/static/index.html | sed -n '1,30p' (1)
Result: HTTP/1.1 200 OK; X-Cache: RefreshHit from cloudfront
Command: curl -i https://app.jastek.click/static/index.html | sed -n '1,30p' (2)
Result: HTTP/1.1 200 OK; X-Cache: RefreshHit from cloudfront
Status: PASS (RefreshHit observed)

- Before invalidation (retry - unstable origin)
Command: curl -i https://app.jastek.click/static/index.html | sed -n '1,30p' (1)
Result: HTTP/1.1 200 OK; X-Cache: Miss from cloudfront; ETag 1770423540...; Last-Modified 00:19:00
Command: curl -i https://app.jastek.click/static/index.html | sed -n '1,30p' (2)
Result: HTTP/1.1 200 OK; X-Cache: Miss from cloudfront; ETag 1770423213...; Last-Modified 00:13:33
Status: FAIL (origin content differs between instances; cache never stabilizes)

## Note on Static Cache Tests
- Static cache tests require consistent content across instances. We now pin `Last-Modified` by setting a fixed mtime for `/opt/rdsapp/static/index.html` and `/opt/rdsapp/static/example.txt` in `scripts/user_data.sh`.
- If you intentionally update static content, update the file contents and bump the fixed timestamp (or invalidate the path) so CloudFront recognizes the change.
- Before invalidation (post-mtime fix)
Command: curl -i https://app.jastek.click/static/index.html | sed -n '1,30p' (1)
Result: HTTP/1.1 200 OK; X-Cache: Miss from cloudfront; ETag 1770422400.0-2316...; Last-Modified 00:00:00
Command: curl -i https://app.jastek.click/static/index.html | sed -n '1,30p' (2)
Result: HTTP/1.1 200 OK; X-Cache: Miss from cloudfront; ETag 1770422400.0-2318...; Last-Modified 00:00:00
Status: FAIL (content length/ETag differ between instances; cache still not stabilizing)

- Static image cache sanity (placeholder.png)
Command: curl -I https://app.jastek.click/static/placeholder.png | head -n 20 (first)
Result: HTTP/1.1 200 OK; X-Cache: Miss from cloudfront; Cache-Control: public, max-age=86400, immutable
Command: curl -I https://app.jastek.click/static/placeholder.png | head -n 20 (second)
Result: HTTP/1.1 200 OK; X-Cache: Miss from cloudfront; Cache-Control: public, max-age=86400, immutable
Status: FAIL (expected Hit/RefreshHit on second request)

- Static image cache sanity (placeholder.png) - retry
Command: curl -I https://app.jastek.click/static/placeholder.png | head -n 20 (first)
Result: HTTP/1.1 200 OK; X-Cache: Miss from cloudfront
Command: curl -I https://app.jastek.click/static/placeholder.png | head -n 20 (second)
Result: HTTP/1.1 200 OK; X-Cache: RefreshHit from cloudfront
Status: PASS (RefreshHit observed)

## 6) Correctness proof (cache before/after) - static placeholder.png
- Before invalidation (two requests)
Command: curl -I https://app.jastek.click/static/placeholder.png | head -n 20 (1)
Result: HTTP/1.1 200 OK; X-Cache: RefreshHit from cloudfront
Command: curl -I https://app.jastek.click/static/placeholder.png | head -n 20 (2)
Result: HTTP/1.1 200 OK; X-Cache: RefreshHit from cloudfront
Status: PASS (cached object confirmed)

- Create invalidation (static placeholder.png)
Command: aws cloudfront create-invalidation --distribution-id E1B1H41XMRI4R5 --paths '/static/placeholder.png'
Result: InvalidArgument (invalid invalidation paths)
Status: FAIL

- Placeholder.png cache check (no invalidation yet)
Command: curl -I https://app.jastek.click/static/placeholder.png | head -n 20
Result: HTTP/1.1 200 OK; X-Cache: RefreshHit from cloudfront
Status: PASS (cached)

- Invalidation (static placeholder.png)
Command: aws cloudfront create-invalidation --distribution-id E1B1H41XMRI4R5 --invalidation-batch file://c:/temp/invalidation.json
Result: Invalidation Id I532FGVH3V9QTDTTUYWPXLOVTJ; Status InProgress; CreateTime 2026-02-07T04:12:08.478000+00:00
Status: PASS

- After invalidation check
Command: curl -I https://app.jastek.click/static/placeholder.png | head -n 20
Result: HTTP/1.1 200 OK; X-Cache: Miss from cloudfront
Status: PASS (cache refreshed after invalidation)

## 7) RefreshHit / Validators
[AWS: Manage how long content stays in the cache (expiration)](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Expiration.html)
RefreshHit means CloudFront had the object cached but its TTL expired, so it sent a conditional request (If-None-Match/If-Modified-Since) to the origin. The origin returned 304 Not Modified, and CloudFront reused the cached body and refreshed the TTL.

Flow for RefreshHit:
1. Revalidation request: CloudFront sends a conditional GET using ETag or Last-Modified.
2. Origin response:
3. Not Modified (304): CloudFront serves the cached body and resets the object age.
4. Modified (200): CloudFront caches the new content and serves it.

Command: curl -i https://app.jastek.click/static/placeholder.png | sed -n '1,30p'
Result: ETag present (1770422400.0-251-3800829208); Last-Modified present (Sat, 07 Feb 2026 00:00:00 GMT)
Status: PASS (validators present)

Note: Step 8 covered by Step 7 RefreshHit evidence (non-miss confirmed).

## 9) Injection B — Why won't my change show up?
Explanation:
CloudFront serves cached objects based on validators (ETag/Last-Modified). If the origin returns the same validators after you edit content, CloudFront will treat it as unchanged and reuse the cached body, so users keep seeing the old version. This often happens when files are rewritten with identical mtime/ETag or when validators are forced to a fixed value.

Fix choice:
| Fix | When appropriate |
| --- | --- |
| Update ETag | Correct fix when content changes; ensure validators reflect new content |
| Update Last-Modified | Acceptable if ETag not used; bump mtime to reflect new content |
| Invalidate object | Emergency only; use sparingly to force refresh |
| Increase TTL | Only if content truly stable; not a fix for stale content |

## 10) Invalidation vs Versioned Filenames
[AWS: Invalidate files (remove from edge caches)](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Invalidation.html)
[AWS: CloudFront Pricing](https://aws.amazon.com/cloudfront/pricing/)
If you need to remove a file from CloudFront edge caches before it expires, you can either:
- Invalidate the file from edge caches. The next time a viewer requests it, CloudFront fetches the latest version from the origin.
- Use file versioning (a different filename) to serve a new version.

If you update files frequently, AWS recommends using versioned filenames because:
- Versioning ensures users get the new file even if they or a proxy still cache the old one (invalidations don’t clear those caches).
- CloudFront access logs include filenames, so versioning makes change analysis easier.
- Versioning enables serving different versions to different users.
- Versioning simplifies roll-forward/rollback.
- Versioning is less expensive; you pay for transfer/storage of new versions but avoid invalidation charges.

Choice table (invalidate vs versioned filenames):
| Option | When to use | Pros | Cons |
| --- | --- | --- | --- |
| Invalidate | One-off urgent removal of cached content | Immediate edge cache refresh | Does not clear browser/proxy caches; can incur invalidation fees |
| Versioned filenames | Frequent updates | Works even with client/proxy caches; easier log analysis; supports rollback | Requires changing references to new filenames |

## 11) Log interpretation (advanced)
- CloudFront logging config enabled
Command: aws cloudfront get-distribution --id E1B1H41XMRI4R5 --query "Distribution.DistributionConfig.Logging"
Result: Enabled true; Bucket taaops-cloudfront-logs-015195098145.s3.amazonaws.com; Prefix cloudfront/
Status: PASS

- CloudFront log delivery check (S3)
Command: aws s3 ls s3://taaops-cloudfront-logs-015195098145/cloudfront/ --recursive | tail -n 5
Result: no output (no log objects yet)
Status: INCONCLUSIVE (logs can take time to appear)

## 13) Additional Python Checks (from ./python)
Note: On Windows Git Bash, use `MSYS2_ARG_CONV_EXCL="*"` with `./python/...` or run in PowerShell to avoid path conversion errors (e.g., `.pythonscript.py`).
- Alarm triage
Command: python .\\python\\galactus_alarm_triage.py
Result: Active alarms: 1; AWS/RDS DatabaseConnections DBInstanceIdentifier=taaops-rds; Reason: no datapoints for 2 periods treated as breaching; Updated: 2026-02-05 00:17:27.950000-08:00
Status: PASS (script ran)

- Origin cloaking verifier
Command: python .\\python\\galactus_origin_cloak_tester.py https://jastek.click https://origin.jastek.click
Result: CloudFront 200; ALB direct None; curl -vk https://origin.jastek.click -> TLS handshake failed (no HTTP response).
Status: PASS (strict SG cloaking blocks direct ALB; expected from public internet)

Origin cloaking via CloudFront managed prefix list (strict SG cloaking):

Note: With strict SG cloaking, the ALB security group only allows CloudFront origin-facing IPs (managed prefix list). DNS resolves to ALB IPs, but direct-to-ALB requests from the public internet fail before HTTP (timeout/TLS handshake). This is expected.

Docs:
- Restrict access to Application Load Balancers (CloudFront)
  https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/restrict-access-to-load-balancer.html
- CloudFront managed prefix list / origin-facing servers
  https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/LocationsOfEdgeServers.html

Follow-up checks (strict cloaking proof):
Command: nslookup origin.jastek.click
Result: resolves to 35.85.210.184, 54.68.98.105

Command: curl -I https://origin.jastek.click
Result: curl: (35) schannel: failed to receive handshake, SSL/TLS connection failed

Command: curl -vk https://origin.jastek.click
Result: TCP connect then TLS handshake failure; no HTTP status returned

Docs (origin cloaking via CloudFront managed prefix list):
- https://aws.amazon.com/blogs/networking-and-content-delivery/limit-access-to-your-origins-using-the-aws-managed-prefix-list-for-amazon-cloudfront/
- https://docs.aws.amazon.com/whitepapers/latest/aws-best-practices-ddos-resiliency/protecting-your-origin-bp1-bp5.html

- CloudFront cache probe
Command: python .\python\galactus_cloudfront_cache_probe.py https://jastek.click/static/example.txt
Result: 3 requests; Status 200; cache-control public, max-age=86400, immutable; x-cache RefreshHit from cloudfront each time
Status: PASS (RefreshHit observed)
Latest run (outputs):
[1] Status 200; x-cache RefreshHit; via 1.1 35cf2d368ade712cbe1c88e37bade95e.cloudfront.net (CloudFront)
[2] Status 200; x-cache RefreshHit; via 1.1 301344113dc05dc15d7b460113c8b8a4.cloudfront.net (CloudFront)
[3] Status 200; x-cache RefreshHit; via 1.1 bb0594f2e9ea1308fed733a4ebfcc102.cloudfront.net (CloudFront)

Note: If you see an initial Miss, it can be due to different CloudFront edges (cold cache). Pin a single edge to prove caching.

Follow-up cache proof (same POP):
Command: curl -I https://jastek.click/static/example.txt | grep -i -E "x-cache|x-amz-cf-pop|age"
Result: X-Cache RefreshHit; X-Amz-Cf-Pop SFO53-P9

- Logs Insights runner
Command: python .\\python\\galactus_logsinsights_runner.py --log-group /aws/ec2/taaops-rds-app --minutes 15 --query "fields @timestamp, @message | sort @timestamp desc | limit 5"
Result: AccessDeniedException: not authorized to perform StartQuery on resources /Program Files/Git/aws/ec2/taaops-rds-app
Status: FAIL (permissions or log group path issue)

- Logs Insights runner (retry)
Command: MSYS2_ARG_CONV_EXCL="*" python ./python/galactus_logsinsights_runner.py --log-group /aws/ec2/rdsapp --minutes 15 --query "fields @timestamp, @message | sort @timestamp desc | limit 5"
Result: no output (query returned 0 rows)
Status: PASS (script ran; no recent log rows)

- Secret drift checker
Command: MSYS2_ARG_CONV_EXCL="*" SSM_PATH=/lab/db/ SECRET_ID=taaops/rds/mysql python ./python/galactus_secret_drift_checker.py
Result: ValidationException: parameter name must begin with "/" (SSM_PATH parsing failed in Git Bash)
Status: FAIL (env/path parsing issue; rerun in PowerShell)

- Secret drift checker (PowerShell)
Command: python .\\python\\galactus_secret_drift_checker.py
Result: DRIFT endpoint SSM=taaops-rds.cfqumkgmmcja.us-west-2.rds.amazonaws.com SECRET=taaops-aurora-cluster.cluster-cfqumkgmmcja.us-west-2.rds.amazonaws.com; OK port; DRIFT dbname SSM=labdb SECRET=taa2db; OK username
Status: FAIL (drift detected)

- Secret drift checker (after SSM updates)
Command: python .\\python\\galactus_secret_drift_checker.py
Result: OK endpoint; OK port; OK dbname; OK username
Status: PASS (no drift)

- WAF block spike detector
Command: python .\\python\\galactus_waf_block_spike_detector.py
Result: Last 10 min BLOCKS: 0, Previous 10 min: 0; No significant spike.
Status: PASS

- Cost guardrail estimator (CloudFront invalidations)
Command: python .\\python\\galactus_cost_guardrail_estimator.py --dist-id "E1B1H41XMRI4R5"
Result: Recent invalidations: 5 (I532FGVH3V9QTDTTUYWPXLOVTJ, I68HO5C5E9C8NY1OF74YI48G2I, I63T210F1GV9XKQLEC03G2XCSQ, IAN0BCLUX27450FOWZBVVMZFOA, IUV8MJTSZG0ANDFXLTLOL0NL4); all Completed
Status: PASS

## Gate Check (run_all_gates_l2.sh)
Command (Git Bash):
ORIGIN_REGION="$(terraform output -raw origin_region)" \
CF_DISTRIBUTION_ID="$(terraform output -raw cloudfront_distribution_id)" \
DOMAIN_NAME="$(terraform output -raw domain_name)" \
ROUTE53_ZONE_ID="$(terraform output -raw route53_zone_id)" \
ACM_CERT_ARN="$(terraform output -raw cloudfront_acm_cert_arn)" \
WAF_WEB_ACL_ARN="$(terraform output -raw waf_web_acl_arn)" \
LOG_BUCKET="$(terraform output -raw cloudfront_logs_bucket)" \
ORIGIN_SG_ID="$(terraform output -raw origin_sg_id)" \
bash ./python/run_all_gates_l2.sh

Result: badge.txt = YELLOW; status = PASS (warnings only)
Explanation:
- CloudFront logs bucket warning was due to string formatting; gate now normalizes bucket strings to avoid false diffs.
- Origin SG warning happens when using CloudFront managed prefix list; sources are in PrefixListIds, not IpRanges/UserIdGroupPairs. Gate now detects PrefixListIds and marks PASS.

Final gate run:
Result: badge.txt = GREEN; status = PASS (no warnings, no failures)


## 12) Auto-IR tie-in (bonus)
Command: aws s3 ls "s3://$REPORT_BUCKET/reports/" --region us-west-2
Result: no reports found yet
Status: N/A (no Auto-IR report to review)

## 14) Tokyo + Sao Paulo Architecture Proofs
### 14.1) Data residency proof (RDS only in Tokyo)
Tokyo: RDS exists
Command:
aws rds describe-db-instances --region ap-northeast-1 \
  --query "DBInstances[].{DB:DBInstanceIdentifier,AZ:AvailabilityZone,Region:'ap-northeast-1',Endpoint:Endpoint.Address}"
[
    {
        "DB": "taaops-aurora-0",
        "AZ": "ap-northeast-1a",
        "Region": "ap-northeast-1",
        "Endpoint": "taaops-aurora-0.cziy8u28egkv.ap-northeast-1.rds.amazonaws.com"
    },
    {
        "DB": "taaops-aurora-1",
        "AZ": "ap-northeast-1d",
        "Region": "ap-northeast-1",
        "Endpoint": "taaops-aurora-1.cziy8u28egkv.ap-northeast-1.rds.amazonaws.com"
    }
]

Result: PASS


Sao Paulo: No RDS
Command:
aws rds describe-db-instances --region sa-east-1 \
  --query "DBInstances[].DBInstanceIdentifier"
[]
Result: PASS

### 14.2) Edge proof (CloudFront logs show cache + access)
Commands:
curl.exe -I https://jastek.click/api/public-feed
curl.exe https://jastek.click/api/public-feed
curl.exe -I https://jastek.click/static/example.txt

Result:
- `/api/public-feed` returns `HTTP/1.1 200 OK`, `Content-Type: application/json`, `X-Cache: Miss from cloudfront`
- API body: `{"region":"ap-northeast-1","service":"tokyo-rdsapp","status":"ok"}`
- `/static/example.txt` serves via CloudFront with expected caching headers

Status: PASS


### 14.3) WAF proof
Command:
aws wafv2 list-web-acls --scope CLOUDFRONT --region us-east-1
Result:
{
    "NextMarker": "taaops-cloudfront-waf",
    "WebACLs": [
        {
            "Name": "CreatedByCloudFront-7156b05c-706f-473b-b878-8a46136ce30b",
            "Id": "1493c482-e152-4915-ac87-6342019c2e5f",
            "Description": "",
            "LockToken": "d3eb9cb8-745e-42d7-8ce0-ca117b54dc8f",
            "ARN": "arn:aws:wafv2:us-east-1:015195098145:global/webacl/CreatedByCloudFront-7156b05c-706f-473b-b878-8a46136ce30b/1493c482-e152-4915-ac87-6342019c2e5f"
        },
        {
            "Name": "CreatedByCloudFront-72e85052-88ed-42f2-9dcc-dee12893cc09",
            "Id": "ef2f742c-dc68-4378-80d0-0ed3b47205d2",
            "Description": "",
            "LockToken": "28438db7-c42b-43a9-b899-724b6f269504",
            "ARN": "arn:aws:wafv2:us-east-1:015195098145:global/webacl/CreatedByCloudFront-72e85052-88ed-42f2-9dcc-dee12893cc09/ef2f742c-dc68-4378-80d0-0ed3b47205d2"
        },
        {
            "Name": "CreatedByCloudFront-8cb15f8e-efd0-4ae8-a02e-b8db9bcfacc8",
            "Id": "74a7fc19-503d-4d6f-9a51-c5bc85c439f6",
            "Description": "",
            "LockToken": "2ebc843f-0cec-4436-b608-85e023ed0816",
            "ARN": "arn:aws:wafv2:us-east-1:015195098145:global/webacl/CreatedByCloudFront-8cb15f8e-efd0-4ae8-a02e-b8db9bcfacc8/74a7fc19-503d-4d6f-9a51-c5bc85c439f6"
        },
        {
            "Name": "taaops-atp-cf-waf01",
            "Id": "8b0eab82-292c-43d3-83a0-4353cf464e76",
            "Description": "Managed ATP rule.",
            "LockToken": "769a5a89-15d4-4248-ae93-850d02ccb219",
            "ARN": "arn:aws:wafv2:us-east-1:015195098145:global/webacl/taaops-atp-cf-waf01/8b0eab82-292c-43d3-83a0-4353cf464e76"
        },
        {
            "Name": "taaops-atp-cloudfront-waf",
            "Id": "4c93c367-125a-434d-b2f5-88cb392d267d",
            "Description": "Account Takeover Protection for login endpoints",
            "LockToken": "ece5fe59-6e4c-49d3-ae49-5fb2fd25bc24",
            "ARN": "arn:aws:wafv2:us-east-1:015195098145:global/webacl/taaops-atp-cloudfront-waf/4c93c367-125a-434d-b2f5-88cb392d267d"
        },
        {
            "Name": "taaops-cf-waf01",
            "Id": "a3addd66-56a7-4327-924d-7663d81b3444",
            "Description": "",
            "LockToken": "bd20bf19-2dee-45af-b6c7-305e80aa51a4",
            "ARN": "arn:aws:wafv2:us-east-1:015195098145:global/webacl/taaops-cf-waf01/a3addd66-56a7-4327-924d-7663d81b3444"
        },
        {
            "Name": "taaops-cloudfront-waf",
            "Id": "890d8d42-8716-4dbf-95bb-a80080fc749a",
            "Description": "CloudFront WAF for global edge protection",
            "LockToken": "1eaaf34a-a2a2-47ad-8200-d61263dc4018",
            "ARN": "arn:aws:wafv2:us-east-1:015195098145:global/webacl/taaops-cloudfront-waf/890d8d42-8716-4dbf-95bb-a80080fc749a"
        }
    ]
}

### 14.4) Change proof (CloudTrail)

Result:
CloudTrail shows CloudFront write events (`readOnly=false`) for `CreateInvalidation` on distribution `E1B1H41XMRI4R5` at:
- 2026-02-06T12:43:07Z (eventID: c5a0d065-e44a-4131-94d3-9b0c6d1c8eaf)
- 2026-02-06T12:25:53Z (eventID: 0cf95b63-9f97-4820-a7f7-4de048ebe7fa)

Both attempts failed with:
`InvalidArgument: Your request contains one or more invalid invalidation paths`
(path sent as `C:/Program Files/Git/static/example.txt`, which is invalid for CloudFront).

Status: PASS (change attempts are auditable in CloudTrail; error cause identified).

Result:
CloudTrail shows CloudFront write events (`readOnly=false`) for `CreateInvalidation` on distribution `E1B1H41XMRI4R5` at:
- 2026-02-06T12:43:07Z (eventID: c5a0d065-e44a-4131-94d3-9b0c6d1c8eaf)
- 2026-02-06T12:25:53Z (eventID: 0cf95b63-9f97-4820-a7f7-4de048ebe7fa)

Both attempts failed with:
`InvalidArgument: Your request contains one or more invalid invalidation paths`
(path sent as `C:/Program Files/Git/static/example.txt`, which is invalid for CloudFront).

Status: PASS (change attempts are auditable in CloudTrail; error cause identified).

Fix:
Use CloudFront object paths, not local filesystem paths:
aws cloudfront create-invalidation --distribution-id E1B1H41XMRI4R5 --paths "/static/example.txt"


### 14.5) Network corridor proof (TGW)
Result: TBD
# 14.5) TGW corridor proof
aws ec2 describe-transit-gateways \
  --query "TransitGateways[].{Id:TransitGatewayId,State:State}"

aws ec2 describe-transit-gateway-attachments \
  --query "TransitGatewayAttachments[].{Id:TransitGatewayAttachmentId,Type:ResourceType,State:State,Vpc:ResourceId}"

aws ec2 describe-route-tables \
  --query "RouteTables[].{Id:RouteTableId,Routes:Routes[?TransitGatewayId!=null].[DestinationCidrBlock,TransitGatewayId]}"




### 14.6) AWS CLI verification (bucket/logs exist)
Command:
aws s3 ls s3://Class_Lab3/
aws s3 ls s3://Class_Lab3/cloudfront-logs/ --recursive | tail -n 20
aws s3 cp s3://Class_Lab3/cloudfront-logs/<somefile>.gz .

# from LAB3/global
cd ~/aws/class7/armageddon/jastekAI/SEIR_Foundations/LAB3/global

CF_LOG_BUCKET="$(terraform output -raw cloudfront_logs_bucket)"
echo "$CF_LOG_BUCKET"
aws s3 ls "s3://$CF_LOG_BUCKET/"
aws s3 ls "s3://$CF_LOG_BUCKET/cloudfront/" --recursive | tail -n 20

RESULT:
CF_LOG_BUCKET="$(terraform output -raw cloudfront_logs_bucket)"
echo "$CF_LOG_BUCKET"

taaops-cloudfront-logs-015195098145

aws s3 ls "s3://$CF_LOG_BUCKET/"
                           PRE cloudfront/

aws s3 ls "s3://$CF_LOG_BUCKET/cloudfront/" --recursive | tail -n 20
2026-02-08 20:37:39        806 cloudfront/E2T6L4WML8KX93.2026-02-09-04.1d18323c.gz
2026-02-08 20:22:38        502 cloudfront/E2T6L4WML8KX93.2026-02-09-04.3bda07b5.gz
2026-02-08 20:07:39        781 cloudfront/E2T6L4WML8KX93.2026-02-09-04.4ac60df8.gz
2026-02-08 20:42:38        801 cloudfront/E2T6L4WML8KX93.2026-02-09-04.872f70a0.gz
2026-02-08 20:52:39        827 cloudfront/E2T6L4WML8KX93.2026-02-09-04.c307cdd9.gz
2026-02-08 20:17:39       1380 cloudfront/E2T6L4WML8KX93.2026-02-09-04.d1646d03.gz
2026-02-08 20:12:38        828 cloudfront/E2T6L4WML8KX93.2026-02-09-04.e60b6e3f.gz
2026-02-08 21:47:38        902 cloudfront/E2T6L4WML8KX93.2026-02-09-05.0a7c0092.gz
2026-02-08 21:22:39        514 cloudfront/E2T6L4WML8KX93.2026-02-09-05.25d80414.gz
2026-02-08 21:27:39        711 cloudfront/E2T6L4WML8KX93.2026-02-09-05.2def4ede.gz
2026-02-08 21:12:39        608 cloudfront/E2T6L4WML8KX93.2026-02-09-05.7e10803b.gz
2026-02-08 22:57:39        712 cloudfront/E2T6L4WML8KX93.2026-02-09-06.130fb2db.gz
2026-02-08 22:27:39        801 cloudfront/E2T6L4WML8KX93.2026-02-09-06.2d0b81a4.gz
2026-02-08 22:12:38        764 cloudfront/E2T6L4WML8KX93.2026-02-09-06.8789c2b4.gz
2026-02-08 23:07:39        502 cloudfront/E2T6L4WML8KX93.2026-02-09-07.1242a956.gz
2026-02-08 23:47:39        501 cloudfront/E2T6L4WML8KX93.2026-02-09-07.325fe515.gz
2026-02-08 23:42:39        605 cloudfront/E2T6L4WML8KX93.2026-02-09-07.6cc6fc7a.gz
2026-02-08 23:57:39        593 cloudfront/E2T6L4WML8KX93.2026-02-09-07.d24dc430.gz
2026-02-08 23:37:39        613 cloudfront/E2T6L4WML8KX93.2026-02-09-07.ddbdc717.gz
2026-02-08 23:32:39        641 cloudfront/E2T6L4WML8KX93.2026-02-09-07.faa4e6a8.gz

John Sweeney@SEBEK MINGW64 ~/aws/class7/armageddon/jastekAI/SEIR_Foundations/LAB3/global
$ # from LAB3/Tokyo (incident reports bucket, not CF logs)


# replace with one real key from previous command
aws s3 cp "s3://Class_Lab3/cloudfront-logs/<somefile>.gz" .

 aws s3 cp "s3://$CF_LOG_BUCKET/cloudfront/E2T6L4WML8KX93.2026-02-09-07.faa4e6a8.gz" .
download: s3://taaops-cloudfront-logs-015195098145/cloudfront/E2T6L4WML8KX93.2026-02-09-07.faa4e6a8.gz to .\E2T6L4WML8KX93.2026-02-09-07.faa4e6a8.gz

gzip -dc ./E2T6L4WML8KX93.2026-02-09-07.faa4e6a8.gz | head -n 5
#Version: 1.0
#Fields: date time x-edge-location sc-bytes c-ip cs-method cs(Host) cs-uri-stem sc-status cs(Referer) cs(User-Agent) cs-uri-query cs(Cookie) x-edge-result-type x-edge-request-id x-host-header cs-protocol cs-bytes time-taken x-forwarded-for ssl-protocol ssl-cipher x-edge-response-result-type cs-protocol-version fle-status fle-encrypted-fields c-port time-to-first-byte x-edge-detailed-result-type sc-content-type sc-content-len sc-range-start sc-range-end
2026-02-09      07:30:15        SFO53-P1        385     91.196.220.21   HEAD    d1q01cj8sa3hta.cloudfront.net   /api/public-feed        404     -       curl/8.10.1        -       -       Error   Nln8vJQv0swq1ln5CtvfhayUA1KNaUGZVJeOe3_bNC8w3iOjaLqnDw==        jastek.click    https   92      0.436   -       TLSv1.2    ECDHE-RSA-AES128-GCM-SHA256     Error   HTTP/1.1        -       -       41830   0.436   Error   text/html;%20charset=utf-8      232     -       -  
2026-02-09      07:30:13        SFO53-P1        523     91.196.220.21   HEAD    d1q01cj8sa3hta.cloudfront.net   /static/example.txt     200     -       curl/8.10.1        -       -       Miss    z2hVYpU53wH_xu9lCwP4IAON9W4p_CGkNtxgdvvSNap2wGKuvlt9Ig==        jastek.click    https   95      0.519   -       TLSv1.2    ECDHE-RSA-AES128-GCM-SHA256     Miss    HTTP/1.1        -       -       39266   0.519   Miss    text/plain;%20charset=utf-8     18      -       -  

RESULT: PASS
bucket exists
logs listed
sample .gz downloaded
sample lines extracted
file placed in `LAB3-DELIVERABLES` folder


### 14.7) Proof scripts
- galactus_residency_proof.py
- galactus_tgw_corridor_proof.py
- galactus_cloudtrail_last_changes.py
- galactus_waf_summary.py
- galactus_cloudfront_log_explainer.py


# 14.7) Proof scripts (Git Bash path style)
python ./python/galactus_residency_proof.py
python ./python/galactus_tgw_corridor_proof.py
python ./python/galactus_cloudtrail_last_changes.py
python ./python/galactus_waf_summary.py
python ./python/galactus_cloudfront_log_explainer.py


Result: PASS

# 15) Transaltion Test
Translation pipeline test:
Command: upload `Tokyo/audit/3b_audit.txt` to `s3://taaops-translate-input/audit/...`
Result: Lambda logs show `Detected language: ja` and `Successfully processed translation`; output files created in `taaops-translate-output` and reports bucket; translated file downloaded to `LAB3-DELIVERABLES/results/translation_fresh.txt`.
Status: PASS

OUTPUT:

$ aws iam list-role-policies --role-name taaops-translate-ap-northeast-1-lambda-role
{
    "PolicyNames": [
        "allow-comprehend-detect-language",
        "allow-kms-for-reports-bucket"
    ]
}

 cat "LAB3-DELIVERABLES/results/translation_fresh.txt"
Lab 3B — Japan Medical
Audit Evidence & Regulator-Ready Logging (APPI reporting)

🎯 Objective
What students make in this lab is not a “system,” but a proof (proof).
 PHI is stored only in Tokyo (ap-northeast-1) (APPI's way of thinking)
 São Paulo (sa-east-1) is just calculation (compute)
 Make it possible to show “who, when, what, and where” as evidence in a form that can be shown to an auditor
 Combine CloudFront/WAF/CloudTrail/logs into “one evidence pack”
 Pick up a beautiful woman

🧠 The Compliance Audit Principle
In the regulated industry, “being able to prove” wins over “moving.”
And global access ≠ global storage.

What “Good Evidence” Looks Like (What Auditors Actually Want)
The things I want about auditing, legality, and security are roughly these 6 things:
 1. Data residency proof
 That RDS is in Tokyo
 There is no DB in the cross-region

 2. Access trail
 Who hit the API (not including personal information)

 3. Change trail
 Who changed security settings (CloudTrail)

 4. Network Corridor Proof
 The route from São Paulo to Tokyo is TGW

 5. Edge security proof
 CloudFront + WAF is in the front row, and ALB is directly closed

 6. Retention/immutability posture
 Audit logs must be stored in an untampered location (S3+ versioning, etc.)

Required Services (Lab 3B control plane)
1) CloudTrail (change evidence)
 CloudTrail Event History allows you to view management events for 90 days (available by default)
 Furthermore, if a “Trail” is created, long-term storage is possible in S3
 CloudTrail has types such as management events/data events/insights (management events are the default)

Lab requirements: Being able to take “trails” in both Tokyo and São Paulo (at least management events).

2) CloudFront logs (Edge access evidence)
 CloudFront standard logs record viewer requests
 Can you prove hit/miss/refreshHit with x-edge-result-type

Lab Requirements:
Include evidence showing “Direct ALB is closed and only via CloudFront” into the audit pack

3) WAF logs (security evidence)
 WAF logs can be sent to Firehose and can also be sent to CloudWatch Logs/S3
 If you send to SIEM, Firehose is on-site

Lab Request: Logs or aggregates that can prove WAF's Allow/Block

4) VPC Flow Logs/TGW path evidence (Network Corridor Proof)
 (This is the part that proves “the correctness of the design”)
 When using Flow Logs: Can be treated as metadata that does not include PHI
The existence of TGW routes and attachments can be proven with CLI

## 15) Glossary: Terraform Outputs by Stack

### Global stack (`LAB3/global`)
Command: `terraform output`
Result:
```
cloudfront_distribution_domain_name = "d1q01cj8sa3hta.cloudfront.net"
cloudfront_distribution_id = "E2T6L4WML8KX93"
cloudfront_logs_bucket = "taaops-cloudfront-logs-015195098145"
cloudfront_waf_arn = "arn:aws:wafv2:us-east-1:015195098145:global/webacl/taaops-cf-waf01/a3addd66-56a7-4327-924d-7663d81b3444"
origin_fqdn = "origin.jastek.click"
route53_zone_id = "Z0226086O3FCYG2A1C50"
```

### Tokyo stack (`LAB3/Tokyo`)
Command: `terraform output`
Result:
```
account_id = "015195098145"
cloudwatch_log_group_name = "/taaops/application"
database_endpoint = "taaops-aurora-cluster-02.cluster-cziy8u28egkv.ap-northeast-1.rds.amazonaws.com"
database_reader_endpoint = "taaops-aurora-cluster-02.cluster-ro-cziy8u28egkv.ap-northeast-1.rds.amazonaws.com"
database_secret_arn = "arn:aws:secretsmanager:ap-northeast-1:015195098145:secret:taaops/rds/mysql-79lmCr"
database_security_group_id = "sg-0af7c06dae8737e6a"
domain_name = "jastek.click"
incident_reports_bucket_arn = "arn:aws:s3:::taaops-tokyo-incident-reports-015195098145"
incident_reports_bucket_name = "taaops-tokyo-incident-reports-015195098145"
ir_lambda_function_arn = "arn:aws:lambda:ap-northeast-1:015195098145:function:taaops-tokyo-ir-reporter"
ir_lambda_function_name = "taaops-tokyo-ir-reporter"
ir_reports_topic_arn = "arn:aws:sns:ap-northeast-1:015195098145:taaops-tokyo-ir-reports-topic"
ir_trigger_topic_arn = "arn:aws:sns:ap-northeast-1:015195098145:taaops-tokyo-ir-trigger-topic"
kms_key_id = "arn:aws:kms:ap-northeast-1:015195098145:key/fd93b975-d339-407e-8745-9149a1b2e973"
regional_waf_arn = "arn:aws:wafv2:ap-northeast-1:015195098145:regional/webacl/taaops-tokyo-regional-waf/ac73b03f-fd9a-4b56-9446-f4a6e15d456d"
route53_zone_id = "Z0226086O3FCYG2A1C50"
ssm_automation_document_name = "taaops-tokyo-incident-report"
tokyo_alb_dns_name = "taaops-tokyo-alb-101234176.ap-northeast-1.elb.amazonaws.com"
tokyo_alb_https_listener_arn = "arn:aws:elasticloadbalancing:ap-northeast-1:015195098145:listener/app/taaops-tokyo-alb/98eca7adb5b38f29/ae2eb8d7ff8a53b3"
tokyo_alb_sg_id = "sg-0553e3b73e8f8afb1"
tokyo_alb_tg_arn = "arn:aws:elasticloadbalancing:ap-northeast-1:015195098145:targetgroup/taaops-tokyo-tg80/604fe92da7ce81b8"
tokyo_alb_zone_id = "Z14GRHDCWA56QT"
tokyo_region = "ap-northeast-1"
tokyo_sao_peering_id = "tgw-attach-0000f6cd2c22dfa7c"
tokyo_transit_gateway_arn = "arn:aws:ec2:ap-northeast-1:015195098145:transit-gateway/tgw-095ffb508be5b0ece"
tokyo_transit_gateway_id = "tgw-095ffb508be5b0ece"
tokyo_vpc_cidr = "10.233.0.0/16"
tokyo_vpc_id = "vpc-09e5b773bcb74237c"
translation_input_bucket_arn = "arn:aws:s3:::taaops-translate-input"
translation_input_bucket_name = "taaops-translate-input"
translation_lambda_function_arn = "arn:aws:lambda:ap-northeast-1:015195098145:function:taaops-translate-ap-northeast-1-processor"
translation_lambda_function_name = "taaops-translate-ap-northeast-1-processor"
translation_output_bucket_name = "taaops-translate-output"
```

### Sao Paulo stack (`LAB3/saopaulo`)
Command: `terraform output`
Result:
```
alb_arn = "arn:aws:elasticloadbalancing:sa-east-1:015195098145:loadbalancer/app/sao-app-lb/56becd698647b793"
alb_dns_name = "sao-app-lb-350817173.sa-east-1.elb.amazonaws.com"
alb_zone_id = "Z2P70J7HTTTPLU"
asg_arn = "arn:aws:autoscaling:sa-east-1:015195098145:autoScalingGroup:21713d6d-86e9-461b-963e-b84cdc8e3ef1:autoScalingGroupName/sao-app-asg"
asg_name = "sao-app-asg"
cloudwatch_log_group_app = "/aws/taaops-saopaulo/application"
cloudwatch_log_group_system = "/aws/taaops-saopaulo/system"
instance_profile_name = "taaops-saopaulo-ec2-instance-profile"
instance_role_arn = "arn:aws:iam::015195098145:role/taaops-saopaulo-ec2-role"
private_subnet_ids = [
  "subnet-0ae4f3b37e933ffd1",
  "subnet-0ecd5dce330c350f4",
  "subnet-0cfa713a82bb7a683",
]
public_subnet_ids = [
  "subnet-056bdebeda56ef2e5",
  "subnet-0d079f419244ac727",
  "subnet-0c00307e82a9b1b8d",
]
region = "sa-east-1"
s3_alb_logs_bucket = "taaops-saopaulo-alb-logs"
s3_app_logs_bucket = "taaops-saopaulo-app-logs"
saopaulo_transit_gateway_id = "tgw-0361d8c3404a37f6f"
sns_topic_alerts_arn = "arn:aws:sns:sa-east-1:015195098145:taaops-saopaulo-alerts"
transit_gateway_arn = "arn:aws:ec2:sa-east-1:015195098145:transit-gateway/tgw-0361d8c3404a37f6f"
vpc_cidr = "10.234.0.0/16"
vpc_id = "vpc-0950a1ab90789c7b2"
```
