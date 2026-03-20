#!/bin/bash
# Usage: ./scripts/validator.sh [local|prd|staging]

ENV=${1:-local}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALIDATIONS_DIR="$REPO_ROOT/validators"

if [ -z "${CONFIG_FILE:-}" ]; then
  if [ -f "$PWD/wrangler.jsonc" ]; then
    CONFIG_FILE="$PWD/wrangler.jsonc"
  else
    CONFIG_FILE="$REPO_ROOT/wrangler.jsonc"
  fi
fi

if [ "$ENV" != "local" ] && [ "$ENV" != "prd" ] && [ "$ENV" != "staging" ]; then
  echo "Invalid environment: $ENV"
  echo "Usage: ./scripts/validator.sh [local|prd|staging]"
  exit 1
fi

echo "Running validations for environment: $ENV"

for file in "$VALIDATIONS_DIR"/*.sql; do
  if [ ! -e "$file" ]; then
    echo "No validator files found in $VALIDATIONS_DIR"
    exit 1
  fi

  filename=$(basename "$file")
  echo "Applying: $filename"

  if [ "$ENV" = "local" ]; then
    wrangler d1 execute prd-zenos-blog-db --local \
      --config "$CONFIG_FILE" \
      --file="$file"
  elif [ "$ENV" = "prd" ]; then
    wrangler d1 execute prd-zenos-blog-db --remote \
      --config "$CONFIG_FILE" \
      --file="$file"
  elif [ "$ENV" = "staging" ]; then
    wrangler d1 execute staging-zenos-blog-db --remote \
      --config "$CONFIG_FILE" \
      --env staging \
      --file="$file"
  fi
done

echo "All validations applied for: $ENV"
