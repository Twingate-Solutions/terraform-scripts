#!/bin/bash
# filepath: .devcontainer/post-create.sh
set -e

# Install Task
sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin

# Create state directory
mkdir -p terraform-state

# Install additional tools
apt-get update
apt-get install -y jq curl wget

# Load GitHub Secrets as environment variables (in Codespaces)
if [ -n "$GITHUB_TOKEN" ]; then
  echo "GitHub Codespaces environment detected"
  # Secrets are auto-injected in Codespaces
fi

echo "✅ Terraform monorepo environment ready!"
echo "Run 'task --list' to see available tasks"