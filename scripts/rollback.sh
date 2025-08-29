#!/usr/bin/env bash
set -euo pipefail

# Región (puedes exportarla antes o pasarla inline)
export AWS_REGION="${AWS_REGION:-us-east-1}"

echo "==> Checking AWS caller identity..."
aws sts get-caller-identity >/dev/null

echo "==> Terraform init"
cd "$(dirname "${BASH_SOURCE[0]}")/../infrastructure"
terraform init -input=false

echo "==> Terraform destroy (this may take a while, CloudFront takes longer)"
terraform destroy -auto-approve -input=false

#AWS_REGION=us-east-1 ./scripts/rollback.sh