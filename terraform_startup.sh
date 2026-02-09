#!/usr/bin/env bash
# LAB3 multi-stack Terraform deployment
# Order: Tokyo -> Global -> Sao Paulo
# Maintainer note: active stacks are in `Tokyo/`, `global/`, `saopaulo/`; legacy root Terraform files are in `archive/root-terraform-from-root/`.

set -euo pipefail
trap 'echo "ERROR on line $LINENO"; exit 1' ERR

WAIT_TIME=30
TGW_WAIT_TIME=120

run_apply() {
  local stack_dir="$1"
  local plan_file="$2"
  echo ""
  echo "=== Deploying ${stack_dir} ==="
  cd "$stack_dir"
  terraform validate
  terraform init -upgrade
  terraform plan -out="$plan_file"
  terraform apply -auto-approve "$plan_file"
  cd - >/dev/null
}

echo "Starting LAB3 deployment: Tokyo -> Global -> Sao Paulo"

# Stage 1: Tokyo
run_apply "Tokyo" "tokyo.tfplan"
echo "Waiting ${WAIT_TIME}s for Tokyo resources to stabilize..."
sleep "$WAIT_TIME"

# Stage 2: Global
run_apply "global" "global.tfplan"
echo "Waiting ${WAIT_TIME}s for Global resources to stabilize..."
sleep "$WAIT_TIME"

# Stage 3: Sao Paulo
run_apply "saopaulo" "saopaulo.tfplan"
echo "Waiting ${TGW_WAIT_TIME}s for TGW peering/resources to stabilize..."
sleep "$TGW_WAIT_TIME"

# Stage 4: Summary outputs
echo ""
echo "=== Deployment summary ==="

cd Tokyo
TOKYO_TGW_ID=$(terraform output -raw tokyo_transit_gateway_id 2>/dev/null || echo "Not found")
TOKYO_ALB_DNS=$(terraform output -raw tokyo_alb_dns_name 2>/dev/null || echo "Not found")
cd - >/dev/null

cd global
CF_DIST_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "Not found")
CF_DIST_DOMAIN=$(terraform output -raw cloudfront_distribution_domain_name 2>/dev/null || echo "Not found")
ORIGIN_FQDN=$(terraform output -raw origin_fqdn 2>/dev/null || echo "Not found")
cd - >/dev/null

cd saopaulo
SAO_TGW_ID=$(terraform output -raw saopaulo_transit_gateway_id 2>/dev/null || echo "Not found")
SAO_ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "Not found")
cd - >/dev/null

echo "Tokyo TGW:             $TOKYO_TGW_ID"
echo "Tokyo ALB:             $TOKYO_ALB_DNS"
echo "Global CloudFront ID:  $CF_DIST_ID"
echo "Global CloudFront DNS: $CF_DIST_DOMAIN"
echo "Global Origin FQDN:    $ORIGIN_FQDN"
echo "Sao Paulo TGW:         $SAO_TGW_ID"
echo "Sao Paulo ALB:         $SAO_ALB_DNS"

if [[ "$TOKYO_TGW_ID" != "Not found" && "$CF_DIST_ID" != "Not found" && "$SAO_TGW_ID" != "Not found" ]]; then
  echo ""
  echo "LAB3 deployment complete."
else
  echo ""
  echo "Deployment finished with missing outputs. Review stack logs above."
  exit 1
fi
