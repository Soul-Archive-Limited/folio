#!/bin/sh
# One-time setup after cloning: turns on the gitleaks pre-commit hook.
set -e
cd "$(git rev-parse --show-toplevel)"
command -v gitleaks >/dev/null 2>&1 || { echo "Install gitleaks first: brew install gitleaks"; exit 1; }
git config core.hooksPath .githooks
echo "Pre-commit secret scanning is on (gitleaks $(gitleaks version))."
