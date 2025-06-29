#!/bin/bash

# Description:
# This script scans a PHP web project directory for hardcoded secrets,
# extracts them for manual review, replaces them with environment-based calls,
# and sets up git hooks + workflows to prevent future leaks.

# Requirements: semgrep, git, jq (optional), envsubst (for templating), docker or vault CLI if using Vault

# Check for project directory input
if [ -z "$1" ]; then
  echo "Usage: $0 /path/to/your/php-project"
  exit 1
fi

PROJECT_DIR="$1"
SEMGREP_RULES_URL="https://github.com/returntocorp/semgrep-rules.git"
SEMGREP_LOCAL_RULES="./semgrep-php-secrets"
EXTRACTED_SECRETS="secrets_found.txt"
GIT_HOOK_FILE="$PROJECT_DIR/.git/hooks/pre-commit"

# Step 1: Clone semgrep rules or define your own
if [ ! -d "$SEMGREP_LOCAL_RULES" ]; then
  git clone --depth=1 "$SEMGREP_RULES_URL" "$SEMGREP_LOCAL_RULES"
fi

# Step 2: Run semgrep to find secrets in the project
# Copy semgrep rules from current directory into project directory for git hook use.
if [ ! -d "$PROJECT_DIR/$SEMGREP_LOCAL_RULES/generic" ]; then
  mkdir -p "$PROJECT_DIR/$SEMGREP_LOCAL_RULES/generic"
  cp -r "$SEMGREP_LOCAL_RULES/generic" "$PROJECT_DIR/$SEMGREP_LOCAL_RULES/"
fi
# Create .semgrepignore to exclude the ruleset from analysi
cat <<EOF > "$PROJECT_DIR/.semgrepignore"
# Ignore ruleset.
semgrep-php-secrets/**
EOF
# Run semgrep to find secrets
PYTHONWARNINGS="ignore::UserWarning" semgrep --config "$SEMGREP_LOCAL_RULES/generic/secrets" -o "$EXTRACTED_SECRETS" --include "*.php" --include="*.js" --include="*.css" "$PROJECT_DIR"

echo "[INFO] Secrets found and written to: $EXTRACTED_SECRETS"

# Step 3: Replace secrets with getenv/env() or placeholder variables
# (this needs human review to identify variable names)
echo "[INFO] Review $EXTRACTED_SECRETS and replace values in source files with getenv('SECRET_NAME') or vault API access."

# Optional: example sed replace (run manually after reviewing)
# sed -i "s/'APIKEY123456'\/\'getenv(\'MY_API_KEY\')\'/g" file.php

# Step 4: Create a .env loader in PHP if not present
cat <<'PHP' > "$PROJECT_DIR/load_env.php"
<?php
if (file_exists(__DIR__ . '/.env')) {
    $lines = file(__DIR__ . '/.env');
    foreach ($lines as $line) {
        if (trim($line) && strpos($line, '=') !== false) {
            list($key, $value) = explode('=', trim($line), 2);
            putenv("$key=$value");
        }
    }
}
?>
PHP

# Step 4.1: Ensure .htaccess includes auto_prepend_file for load_env.php
HTACCESS_FILE="$PROJECT_DIR/.htaccess"
LOAD_ENV_PATH="$(realpath "$PROJECT_DIR/load_env.php")"

if ! grep -q "auto_prepend_file" "$HTACCESS_FILE" 2>/dev/null; then
  echo "\n# Auto-prepend environment loader" >> "$HTACCESS_FILE"
  echo "php_value auto_prepend_file \"$LOAD_ENV_PATH\"" >> "$HTACCESS_FILE"
  echo "[INFO] .htaccess updated to auto-load environment variables."
else
  echo "[INFO] .htaccess already contains auto_prepend_file directive. Skipping."
fi

# Step 4.2: Verify .env entries and print usage tips, also create .env.example
ENV_FILE="$PROJECT_DIR/.env"
ENV_EXAMPLE_FILE="$PROJECT_DIR/.env.example"
if [ -f "$ENV_FILE" ]; then
  echo "[INFO] Verifying .env entries and showing usage suggestions:"
  > "$ENV_EXAMPLE_FILE"
  while IFS= read -r line; do
    if [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      key="${line%%=*}"
      echo "- $key (use in PHP as: getenv('$key'))"
      echo "$key=" >> "$ENV_EXAMPLE_FILE"
    fi
  done < "$ENV_FILE"
  echo "[INFO] .env.example created at $ENV_EXAMPLE_FILE"
else
  echo "[INFO] No .env file found at $ENV_FILE. Skipping verification."
fi

# Step 5: Git pre-commit hook to detect secrets
cat <<EOF > "$GIT_HOOK_FILE"
#!/bin/bash
PYTHONWARNINGS="ignore::UserWarning" semgrep --config "$SEMGREP_LOCAL_RULES/generic/secrets" --include "*.php" --include="*.js" --include="*.css" . > /dev/null
if [ \$? -ne 0 ]; then
    echo "[ERROR] Possible secret found. Please remove before commit."
    exit 1
fi
EOF
chmod +x "$GIT_HOOK_FILE"
echo "[INFO] Git pre-commit hook installed."

# Step 6: Optional - GitHub/Gitea workflow sample for secret scanning
mkdir -p "$PROJECT_DIR/.github/workflows"
cat <<'YAML' > "$PROJECT_DIR/.github/workflows/semgrep-secrets.yml"
name: Check for Secrets

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  semgrep:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Semgrep
        run: |
          curl -sL https://semgrep.dev/install.sh | sh
      - name: Run Semgrep
        run: |
          PYTHONWARNINGS="ignore::UserWarning" ./semgrep --config auto
YAML

# Note for Gitea: replicate the workflow in your CI/CD runner setup
USER=$(whoami)
echo "[DONE] Secret detection and guardrails in place, $USER. Time to clean up that spaghetti and let Vault do the hiding."


