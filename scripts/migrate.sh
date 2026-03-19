#!/bin/bash
# Usage: ./scripts/migrate.sh [local|prd|staging]

ENV=${1:-local}
MIGRATIONS_DIR="./migrations"
CONFIG_FILE=${CONFIG_FILE:-"./wrangler.jsonc"}

echo "Running migrations for environment: $ENV"

for file in $MIGRATIONS_DIR/*.sql; do
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
