#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/publish_sanity_check.sh s3://my-bucket/tools/sanity_check.sh
#   ./scripts/publish_sanity_check.sh s3://my-bucket/tools/sanity_check.sh 3600

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 s3://bucket/path/to/sanity_check.sh [expires_in_seconds]"
  exit 1
fi

S3_URI="$1"
EXPIRES_IN="${2:-3600}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/sanity_check.sh"

if [[ ! -f "$SCRIPT_PATH" ]]; then
  echo "ERROR: sanity_check.sh not found at $SCRIPT_PATH"
  exit 1
fi

echo "Uploading $SCRIPT_PATH to $S3_URI ..."
aws s3 cp "$SCRIPT_PATH" "$S3_URI"

echo "Generating pre-signed URL (expires in ${EXPIRES_IN}s) ..."
aws s3 presign "$S3_URI" --expires-in "$EXPIRES_IN"
