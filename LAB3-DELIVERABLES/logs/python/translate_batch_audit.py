#!/usr/bin/env python3
import argparse
import subprocess
import sys
from pathlib import Path


def parse_args():
    p = argparse.ArgumentParser(
        description="Batch-translate files from a local directory via S3 input/output buckets."
    )
    p.add_argument("--input-bucket", required=True)
    p.add_argument("--output-bucket", required=True)
    p.add_argument("--source-dir", default="Tokyo/audit", help="Local folder of source files.")
    p.add_argument("--glob", default="*.txt", help="File pattern in source dir.")
    p.add_argument("--region", default=None)
    p.add_argument("--timeout-seconds", type=int, default=180)
    p.add_argument("--poll-seconds", type=int, default=5)
    p.add_argument("--key-prefix", default="audit", help="S3 input key prefix.")
    p.add_argument(
        "--dest-dir",
        default="LAB3-DELIVERABLES/results/translations",
        help="Local folder for downloaded translated files.",
    )
    return p.parse_args()


def main():
    args = parse_args()
    src_dir = Path(args.source_dir)
    files = sorted(src_dir.glob(args.glob))
    if not files:
        print(f"[ERROR] No files found: {src_dir}/{args.glob}", file=sys.stderr)
        return 2

    dest_dir = Path(args.dest_dir)
    dest_dir.mkdir(parents=True, exist_ok=True)

    failures = 0
    for f in files:
        s3_key = f"{args.key_prefix}/{f.name}"
        out_file = dest_dir / f"{f.stem}_translated{f.suffix or '.txt'}"
        cmd = [
            sys.executable,
            str(Path(__file__).with_name("translate_via_s3.py")),
            "--input-bucket",
            args.input_bucket,
            "--output-bucket",
            args.output_bucket,
            "--source-file",
            str(f),
            "--s3-key",
            s3_key,
            "--timeout-seconds",
            str(args.timeout_seconds),
            "--poll-seconds",
            str(args.poll_seconds),
            "--download-to",
            str(out_file),
        ]
        if args.region:
            cmd.extend(["--region", args.region])

        print(f"[INFO] Processing {f}")
        rc = subprocess.call(cmd)
        if rc != 0:
            failures += 1
            print(f"[ERROR] Failed: {f}")

    if failures:
        print(f"[DONE] Completed with {failures} failure(s).", file=sys.stderr)
        return 1
    print("[DONE] All files translated successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
