# Clean-room Terraform validation image.
# Runs fmt, init, validate, tflint, and `terraform test` (mocked providers) with no cloud credentials.

FROM hashicorp/terraform:1.17.2

ARG TARGETARCH=amd64
ARG TFLINT_VERSION=0.66.0

RUN apk add --no-cache bash curl unzip tar coreutils findutils

# tflint, checksum-verified against the release's checksums.txt
RUN set -eu; \
    zip="tflint_linux_${TARGETARCH}.zip"; \
    base="https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}"; \
    curl -fsSL -o "/tmp/${zip}" "${base}/${zip}"; \
    curl -fsSL -o /tmp/checksums.txt "${base}/checksums.txt"; \
    cd /tmp && grep " ${zip}\$" checksums.txt | sha256sum -c -; \
    unzip -o "/tmp/${zip}" -d /usr/local/bin; \
    rm -f "/tmp/${zip}" /tmp/checksums.txt; \
    tflint --version

# Bake tflint rulesets into the image so runs need no GitHub API calls
ENV TFLINT_PLUGIN_DIR=/opt/tflint/plugins
COPY .tflint.hcl /opt/tflint/.tflint.hcl
RUN --mount=type=secret,id=github_token,required=false \
    if [ -f /run/secrets/github_token ]; then export GITHUB_TOKEN="$(cat /run/secrets/github_token)"; fi; \
    tflint --init --config /opt/tflint/.tflint.hcl

# Lock files are excluded from the scratch tree on purpose, so let init use the
# plugin cache without a lock-file checksum (otherwise every run re-downloads).
ENV TF_IN_AUTOMATION=1 \
    TF_INPUT=0 \
    TF_PLUGIN_CACHE_DIR=/plugin-cache \
    TF_PLUGIN_CACHE_MAY_BREAK_DEPENDENCY_LOCK_FILE=1 \
    CHECKPOINT_DISABLE=1

WORKDIR /src
ENTRYPOINT ["bash", "/src/ci/validate.sh"]
