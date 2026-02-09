#!/usr/bin/env python3
import argparse
import os
import sys
import time
from pathlib import Path

import boto3
from botocore.exceptions import ClientError


def parse_args():
    p = argparse.ArgumentParser(
        description="Upload a local file to translation input bucket and fetch translated output."
    )
    p.add_argument("--input-bucket", required=True, help="S3 input bucket that triggers Lambda translation.")
    p.add_argument("--output-bucket", required=True, help="S3 output bucket where translated object is written.")
    p.add_argument("--source-file", required=True, help="Local source file path.")
    p.add_argument("--s3-key", default=None, help="Destination key in input bucket (default: audit/<basename>).")
    p.add_argument("--region", default=None, help="AWS region (defaults to profile/environment).")
    p.add_argument("--timeout-seconds", type=int, default=180, help="Max wait time for translated output.")
    p.add_argument("--poll-seconds", type=int, default=5, help="Polling interval while waiting.")
    p.add_argument(
        "--download-to",
        default=None,
        help="Local output path. Default: LAB3-DELIVERABLES/results/<basename>_translated<ext>.",
    )
    return p.parse_args()


def ensure_parent(path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)


def default_download_path(src: Path) -> Path:
    out_dir = Path("LAB3-DELIVERABLES") / "results"
    stem = src.stem
    suffix = src.suffix or ".txt"
    return out_dir / f"{stem}_translated{suffix}"


def list_matches(s3, bucket: str, prefix: str):
    paginator = s3.get_paginator("list_objects_v2")
    matches = []
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents", []):
            matches.append({"Key": obj["Key"], "LastModified": obj["LastModified"]})
    return matches


def main():
    args = parse_args()
    src = Path(args.source_file)
    if not src.exists():
        print(f"[ERROR] Source file not found: {src}", file=sys.stderr)
        return 2

    session = boto3.session.Session(region_name=args.region) if args.region else boto3.session.Session()
    s3 = session.client("s3")

    s3_key = args.s3_key or f"audit/{src.name}"
    base, ext = os.path.splitext(s3_key)
    translated_prefix = f"{base}_translated_"

    print(f"[INFO] Uploading {src} -> s3://{args.input_bucket}/{s3_key}")
    s3.upload_file(str(src), args.input_bucket, s3_key)

    deadline = time.time() + args.timeout_seconds
    latest = None
    print(f"[INFO] Waiting for translated object in s3://{args.output_bucket}/{translated_prefix}*{ext}")
    while time.time() < deadline:
        matches = list_matches(s3, args.output_bucket, translated_prefix)
        matches = [m for m in matches if m["Key"].endswith(ext)]
        if matches:
            latest = sorted(matches, key=lambda m: m["LastModified"], reverse=True)[0]
            break
        time.sleep(args.poll_seconds)

    if not latest:
        print("[ERROR] Timed out waiting for translated output object.", file=sys.stderr)
        return 1

    dest = Path(args.download_to) if args.download_to else default_download_path(src)
    ensure_parent(dest)
    print(f"[INFO] Downloading s3://{args.output_bucket}/{latest['Key']} -> {dest}")
    s3.download_file(args.output_bucket, latest["Key"], str(dest))
    print("[OK] Translation roundtrip complete.")
    print(f"[OK] Output object: s3://{args.output_bucket}/{latest['Key']}")
    print(f"[OK] Local file: {dest}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ClientError as e:
        print(f"[ERROR] AWS error: {e}", file=sys.stderr)
        raise SystemExit(1)
