#!/usr/bin/env bash
set -euo pipefail

# retrieve.sh — Pull metadata changes made via GUI from the target org.
#
# Usage:
#   ./scripts/retrieve.sh [org-alias]
#
# Defaults to "sandbox" if no alias is provided.

ORG="${1:-sandbox}"

echo "Retrieving metadata from org: $ORG"
sf project retrieve start --target-org "$ORG" --wait 30

echo ""
echo "Done. Review changes with: git diff"
