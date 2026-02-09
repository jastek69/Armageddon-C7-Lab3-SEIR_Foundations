#!/usr/bin/env bash
# LAB3 multi-stack Terraform destroy
# Order: Global -> Sao Paulo -> Tokyo
# Maintainer note: active stacks are in `Tokyo/`, `global/`, `saopaulo/`; legacy root Terraform files are in `archive/root-terraform-from-root/`.

set -euo pipefail
trap 'echo "ERROR on line $LINENO"; exit 1' ERR

run_destroy() {
  local stack_dir="$1"
  local plan_file="$2"
  echo ""
  echo "=== Destroying ${stack_dir} ==="
  cd "$stack_dir"
  terraform init -upgrade
  terraform plan -destroy -out="$plan_file"
  terraform apply -auto-approve "$plan_file"
  cd - >/dev/null
}

echo "WARNING: This will destroy LAB3 infrastructure in Global, Sao Paulo, and Tokyo stacks."
read -r -p "Type 'yes' to continue: " confirm
if [[ "$confirm" != "yes" ]]; then
  echo "Destroy cancelled."
  exit 0
fi

echo "Starting destroy in 5 seconds (Ctrl+C to cancel)..."
sleep 5

# Stage 1: Global (must go first due origin/CloudFront dependencies)
run_destroy "global" "global-destroy.tfplan"

# Stage 2: Sao Paulo
run_destroy "saopaulo" "saopaulo-destroy.tfplan"

# Stage 3: Tokyo
run_destroy "Tokyo" "tokyo-destroy.tfplan"

# Stage 4: Local cleanup
echo ""
echo "=== Local cleanup ==="
find . -name "*.tfplan" -type f -delete 2>/dev/null || true
find . -name "terraform.tfstate.backup" -type f -delete 2>/dev/null || true

echo "Destroy complete."
