#!/usr/bin/env python3
import boto3
import os
from datetime import datetime, timezone, timedelta

# A Hearald doesn't wait for the alarm — he detects the uprising before it forms.

# WAF tuning and attack detection are core security ops tasks (false positives vs real abuse).

# This is a WAF spike detector that compares short-term vs baseline BLOCK rates to
# flag likely abuse or misconfiguration and trigger investigation."

cw = boto3.client("cloudwatch")

def main():
    # fill these in (CloudFront WAF metric names can vary)
    namespace = "AWS/WAFV2"
    metric = "BlockedRequests"
    waf_web_acl_arn = os.getenv("WAF_WEB_ACL_ARN", "").strip()
    waf_web_acl_name = os.getenv("WAF_WEB_ACL_NAME", "").strip()
    waf_rule_name = os.getenv("WAF_RULE_NAME", "").strip()
    waf_region = os.getenv("WAF_REGION", "").strip()
    scope = os.getenv("WAF_SCOPE", "").strip().lower()

    if waf_web_acl_arn:
        parts = waf_web_acl_arn.split(":")
        arn_region = parts[3] if len(parts) > 3 else ""
        resource = parts[5] if len(parts) > 5 else ""
        res_parts = resource.split("/")
        if len(res_parts) >= 3:
            scope = res_parts[0].lower()
            if not waf_web_acl_name:
                waf_web_acl_name = res_parts[2]
        if not waf_region:
            if scope == "global":
                waf_region = "Global"
            elif arn_region:
                waf_region = arn_region

    if not waf_region and scope == "global":
        waf_region = "Global"

    dims = []
    if waf_web_acl_name:
        dims.append({"Name": "WebACL", "Value": waf_web_acl_name})
    if waf_rule_name:
        dims.append({"Name": "Rule", "Value": waf_rule_name})
    if waf_region:
        dims.append({"Name": "Region", "Value": waf_region})

    end = datetime.now(timezone.utc)
    start = end - timedelta(minutes=30)

    resp = cw.get_metric_statistics(
        Namespace=namespace,
        MetricName=metric,
        Dimensions=dims,
        StartTime=start,
        EndTime=end,
        Period=60,
        Statistics=["Sum"]
    )

    points = sorted(resp.get("Datapoints", []), key=lambda x: x["Timestamp"])
    last10 = sum(p["Sum"] for p in points[-10:])
    prev10 = sum(p["Sum"] for p in points[-20:-10]) if len(points) >= 20 else 0

    print(f"Last 10 min BLOCKS: {last10}, Previous 10 min: {prev10}")
    if prev10 == 0 and last10 > 0:
        print("⚠️ Spike detected (baseline 0). Investigate.")
    elif prev10 > 0 and last10 / prev10 >= 3:
        print("⚠️ Spike detected (>=3x). Investigate.")
    else:
        print("No significant spike.")

if __name__ == "__main__":
    main()
