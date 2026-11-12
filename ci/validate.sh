#!/usr/bin/env bash
# Credential-free validation of every Terraform root module in the repo.
#
# Usage (inside the ci image):
#   validate.sh                 # all modules
#   validate.sh aws/ec2 gcp/gke # selected modules
#
# Steps per module: terraform init (no backend) -> validate -> tflint -> terraform test.
# terraform test uses mock_provider blocks, so no cloud or Twingate credentials are read.
# The source tree is copied to a scratch dir so no .terraform/ or lock files land on the host.

set -euo pipefail

SRC="${SRC:-/src}"
WORK="${WORK:-/tmp/work}"
TFLINT_CONFIG="${TFLINT_CONFIG:-/opt/tflint/.tflint.hcl}"

mkdir -p "${TF_PLUGIN_CACHE_DIR:-/plugin-cache}"
rm -rf "$WORK" && mkdir -p "$WORK"
tar -C "$SRC" \
  --exclude='./.git' --exclude='.terraform' --exclude='./claudedocs' \
  --exclude='*.tfstate' --exclude='*.tfstate.*' --exclude='.terraform.lock.hcl' \
  -cf - . | tar -C "$WORK" -xf -
cd "$WORK"

if [ "$#" -gt 0 ]; then
  modules=("$@")
else
  mapfile -t modules < <(
    find . -name '*.tf' -not -path '*/.terraform/*' -printf '%h\n' | sed 's|^\./||' | sort -u
  )
fi

failed=()
step() { printf '\n\033[1m== %s\033[0m\n' "$*"; }

step "terraform fmt -check (repo)"
terraform fmt -check -recursive -diff -no-color || failed+=("fmt")

for m in "${modules[@]}"; do
  step "$m"
  if ! terraform -chdir="$m" init -backend=false -input=false -no-color >"/tmp/init.log" 2>&1; then
    cat /tmp/init.log
    failed+=("$m:init")
    continue
  fi
  echo "-- validate"
  terraform -chdir="$m" validate -no-color || { failed+=("$m:validate"); continue; }
  echo "-- tflint"
  tflint --chdir="$m" --config="$TFLINT_CONFIG" --format=compact || failed+=("$m:tflint")
  if compgen -G "$m/tests/*.tftest.hcl" >/dev/null; then
    echo "-- terraform test (mocked providers)"
    terraform -chdir="$m" test -no-color || failed+=("$m:test")
  else
    echo "-- no tests/ directory"
    failed+=("$m:no-tests")
  fi
done

step "summary"
if [ "${#failed[@]}" -gt 0 ]; then
  printf 'FAILED: %s\n' "${failed[@]}"
  exit 1
fi
echo "All ${#modules[@]} modules passed."
