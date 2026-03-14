#!/bin/bash
# Usage: ./scripts/migrate.sh [local|prd|staging]

ENV=${1:-local}
VALIDATIONS_DIR="./validators"
BACKEND_DIR="../zenos-backend"

echo "Running validations for environment: $ENV"

for file in $VALIDATIONS_DIR/*.sql; do
  filename=$(basename "$file")
  echo "Applying: $filename"

  if [ "$ENV" = "local" ]; then
    wrangler d1 execute prd-zenos-blog-db --local \
      --config "$BACKEND_DIR/wrangler.jsonc" \
      --file="$file"
  elif [ "$ENV" = "prd" ]; then
    wrangler d1 execute prd-zenos-blog-db --remote \
      --config "$BACKEND_DIR/wrangler.jsonc" \
      --file="$file"
  elif [ "$ENV" = "staging" ]; then
    wrangler d1 execute staging-zenos-blog-db --remote \
      --config "$BACKEND_DIR/wrangler.jsonc" \
      --env staging \
      --file="$file"
  fi
done

echo "✅ All migrations applied for: $ENV"
