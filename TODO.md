# CloudFront + Origin Cloaking TODO

## Core Requirements
- [X] Lock ALB SG ingress to CloudFront only (remove public 0.0.0.0/0 on 80/443).
- [ ] [post-apply] Ensure ALB origin hostname exists in Route53 (e.g., `origin.<domain>`).
- [ ] [post-apply] Ensure ALB origin cert (us-west-2) is ISSUED and attached to HTTPS listener.
- [ ] [post-apply] Ensure CloudFront viewer cert (us-east-1) is ISSUED and set in `cloudfront_acm_cert_arn`.
- [ ] [post-apply] Confirm CloudFront origin uses `origin.<domain>` (not ALB DNS name).
- [ ] [post-apply] Confirm WAF is attached to the CloudFront distribution.

## Caching + Validation
- [ ] [post-apply] Update CloudFront validation tests to use real paths (`/`, `/list`).
- [ ] Optional: add a real `/static/*` asset or adjust tests to non-static endpoints.
- [ ] [post-apply] Verify `/api/public-feed` is origin-driven (Cache-Control required from origin).
- [ ] [post-apply] Verify `/api/*` is no-cache (managed CachingDisabled).

## Honors+ (Optional)
- [ ] Add invalidation runbook steps + CLI example.
- [ ] Add RefreshHit/validators tests (ETag or Last-Modified).
- [ ] Add “stale index.html” incident scenario notes and response checklist.
