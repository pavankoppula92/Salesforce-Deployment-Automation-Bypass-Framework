#!/usr/bin/env bash
# Load a CSV with automation bypassed, and always turn the bypass back off,
# even when the load fails.
#
# Usage: scripts/load-with-bypass.sh <org-alias> <sobject> <csv-file> <external-id-field>
# Example: scripts/load-with-bypass.sh migration Account data/accounts.csv Legacy_Id__c
#
# Set the migration username in scripts/apex/enable-bypass.apex and disable-bypass.apex first.
set -euo pipefail

ORG="$1"
SOBJECT="$2"
CSV="$3"
EXTERNAL_ID="$4"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

disable_bypass() {
  echo "Turning automation back on..."
  sf apex run --file "$SCRIPT_DIR/apex/disable-bypass.apex" --target-org "$ORG" >/dev/null
}

echo "Enabling automation bypass on $ORG..."
sf apex run --file "$SCRIPT_DIR/apex/enable-bypass.apex" --target-org "$ORG" >/dev/null
trap disable_bypass EXIT

echo "Loading $CSV into $SOBJECT..."
sf data upsert bulk --sobject "$SOBJECT" --file "$CSV" --external-id "$EXTERNAL_ID" --target-org "$ORG" --wait 30
