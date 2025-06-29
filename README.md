# Semgrep Secrets Enabler Tool

This repository contains a helper script for quickly enabling secret scanning in PHP projects using [Semgrep](https://semgrep.dev/). It automates setup of Semgrep rules, extracts secrets for manual review, installs a Git pre-commit hook, and provides a GitHub workflow example.

## Purpose

The script `semgrep_secrets_enabler_tool.sh` helps bootstrap a workflow that detects hardcoded credentials in a PHP web application. It clones a ruleset of Semgrep patterns, runs a scan over your source code, and installs guardrails so that future leaks are caught before code reaches your repository.

## Requirements

- **Semgrep** must be installed and available in your `PATH`.
- **Git** for installing hooks and cloning the Semgrep ruleset.
- Optional utilities such as `jq`, `envsubst`, Docker, or Vault CLI if you extend the workflow for secrets management.

## How It Works

1. **Clone rules** – Downloads the public Semgrep rules repository or uses an existing local copy.
2. **Scan the project** – Runs Semgrep over PHP, JavaScript, and CSS files and writes potential secrets to `secrets_found.txt`.
3. **Assist with replacement** – Prompts you to replace the detected values with `getenv()` calls or a secrets management solution.
4. **Add `.env` loader** – Generates a PHP helper that loads environment variables from a `.env` file if one does not exist.
5. **Install pre-commit hook** – Adds a Git hook that prevents commits if Semgrep finds secrets in staged files.
6. **Provide CI sample** – Creates a GitHub Actions workflow under `.github/workflows/semgrep-secrets.yml` so server‑side checks mirror local ones.

## Planned Enhancements

Future updates aim to support completely airgapped environments. This would allow hosting a local copy of the Semgrep rules repository and skipping network access when running the script. Additional configuration options may be added to customize rules or integrate with other CI platforms such as Gitea.

## Usage

```bash
./semgrep_secrets_enabler_tool.sh /path/to/your/php-project
```

After running, review the generated `secrets_found.txt` file and update your code to load secrets from the environment or a secure vault. The script will also set up a pre‑commit hook to prevent new hardcoded secrets from slipping in.

## Possible Changes

- Adjust the rules location by editing `SEMGREP_RULES_URL` and `SEMGREP_LOCAL_RULES` in the script.
- Modify the included file patterns (`*.php`, `*.js`, `*.css`) to match your project structure.
- Extend the GitHub Actions workflow or adapt it for your preferred CI system.

