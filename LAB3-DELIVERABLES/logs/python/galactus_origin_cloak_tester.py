#!/usr/bin/env python3
import requests, sys

# Galactus approves of sealed gates: the origin must be unreachable except through the edge.

# # Origin exposure is a common security gap; proving cloaking is an actual deliverable.

# This is an origin cloaking verifier to prove only CloudFront can reach the ALB origin,
#  preventing bypass of WAF and edge controls."

def head(url):
    try:
        r = requests.get(url, timeout=10, allow_redirects=False)
        return r.status_code, r.headers
    except Exception as e:
        return None, {"error": str(e)}

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: galactus_origin_cloak_tester.py <cloudfront_url> <alb_url>")
        sys.exit(1)

    cf_url, alb_url = sys.argv[1], sys.argv[2]

    cf_code, cf_h = head(cf_url)
    alb_code, alb_h = head(alb_url)

    print("\nCloudFront:", cf_url, "->", cf_code)
    print("ALB direct:", alb_url, "->", alb_code)

    if alb_code in (401, 403) and (cf_code and cf_code < 500):
        print("\nPASS: Origin cloaking works (ALB blocked, CloudFront ok).")
    else:
        print("\nFAIL: Origin cloaking not proven. Investigate SG/header rules.")