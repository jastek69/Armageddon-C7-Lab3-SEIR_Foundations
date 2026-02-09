#!/usr/bin/env python3
import boto3
import os
import subprocess
import argparse
from pathlib import Path
from datetime import datetime, timezone, timedelta

# Galactus enjoys crushing enemies but he hates wasting credits on sloppy operations.

# Cost-aware engineering is modern DevOps/SRE reality: guardrails prevent surprise bills.

# This is a lightweight guardrail that flags risky operational actions (like over-broad invalidations)
#  and correlates them with traffic/log surges.""

cf = boto3.client("cloudfront")

def parse_args():
    parser = argparse.ArgumentParser(description="CloudFront invalidation guardrail")
    parser.add_argument("--dist-id", help="CloudFront distribution ID")
    return parser.parse_args()


def get_dist_id(cli_id=None):
    if cli_id:
        return cli_id.strip()
    env_id = os.environ.get("CLOUDFRONT_DISTRIBUTION_ID")
    if env_id:
        return env_id.strip()
    


    # 2) Terraform output (assumes repo root is parent of ./python)
    repo_root = Path(__file__).resolve().parents[1]
    try:
        result = subprocess.run(
            ["terraform", "output", "-raw", "cloudfront_distribution_id"],
            cwd=repo_root,
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.strip()
    except Exception as exc:
        raise RuntimeError(
            "Could not resolve CloudFront distribution ID. Set CLOUDFRONT_DISTRIBUTION_ID "
            "or run from a Terraform-initialized repo with output cloudfront_distribution_id."
        ) from exc

def main():
    args = parse_args()
    # provide distribution id
    dist_id = get_dist_id(args.dist_id)
    resp = cf.list_invalidations(DistributionId=dist_id, MaxItems="10")
    items = resp.get("InvalidationList", {}).get("Items", [])
    print(f"Recent invalidations for {dist_id}: {len(items)}")
    for inv in items:
        print(inv["Id"], inv["Status"], inv["CreateTime"])

if __name__ == "__main__":
    main()
