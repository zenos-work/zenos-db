#!/bin/bash
# Usage: ./scripts/migrate.sh [local|prd|staging] [config_file_path]

ENV=${1:-local}
CONFIG_FILE_ARG=${2:-}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIGRATIONS_DIR="$REPO_ROOT/migrations"

if [ -n "$CONFIG_FILE_ARG" ]; then
  CONFIG_FILE="$CONFIG_FILE_ARG"
elif [ -z "${CONFIG_FILE:-}" ]; then
  if [ -f "$PWD/wrangler.jsonc" ]; then
    CONFIG_FILE="$PWD/wrangler.jsonc"
  else
    CONFIG_FILE="$REPO_ROOT/wrangler.jsonc"
  fi
fi

if [ "$ENV" != "local" ] && [ "$ENV" != "prd" ] && [ "$ENV" != "staging" ]; then
  echo "Invalid environment: $ENV"
  echo "Usage: ./scripts/migrate.sh [local|prd|staging] [config_file_path]"
  exit 1
fi

echo "Running migrations for environment: $ENV"

for file in "$MIGRATIONS_DIR"/*.sql; do
  if [ ! -e "$file" ]; then
    echo "No migration files found in $MIGRATIONS_DIR"
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

echo "All migrations applied for: $ENV"
