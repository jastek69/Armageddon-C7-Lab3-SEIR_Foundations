#!/usr/bin/env python3
import requests, sys, time

# This is a cache probe for CloudFront distributions. It repeatedly requests the same URL and prints cache-related headers to verify caching behavior (Hit/Miss/RefreshHit).
# Galactus enjoys watching cache lies collapse under repeated probing.

# CDN caching mistakes cause real incidents; this is how to test them

# This is a cache probe that validates CDN behavior over time (Hit/Miss/RefreshHit),
#  used to prevent auth leaks and stale reads."

def probe(url, rounds=3, delay=2):
    for i in range(rounds):
        r = requests.get(url, timeout=10)
        print(f"\n[{i+1}] {url}")
        print("Status:", r.status_code)
        for h in ["cache-control", "age", "x-cache", "via"]:
            if h in r.headers:
                print(f"{h}: {r.headers[h]}")
        time.sleep(delay)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: galactus_cloudfront_cache_probe.py <url>")
        sys.exit(1)
    probe(sys.argv[1])