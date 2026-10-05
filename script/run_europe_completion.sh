#!/usr/bin/env bash
set -euo pipefail

if (( $# > 1 )) || { (( $# == 1 )) && [[ "${1:-}" != --apply ]]; }; then
  echo 'Usage: bash script/run_europe_completion.sh [--apply]' >&2
  exit 1
fi

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$project_dir"
audit_dir=/srv/vidb/reconciliation-audit.QNQDe9
if ! sudo test -d "$audit_dir"; then
  echo "Dossier d'audit absent : $audit_dir" >&2
  exit 1
fi

for file in \
  app/models/record.rb \
  app/models/video_asset.rb \
  app/models/concerns/record_states.rb \
  app/models/concerns/video_asset_states.rb \
  app/services/catalog_enrichment/confirmed_hierarchy.rb \
  app/services/catalog_enrichment/confirmed_metadata.rb \
  app/services/catalog_enrichment/confirmed_completion.rb \
  app/services/catalog_enrichment/file_observation.rb \
  script/complete_confirmed_episode_assets.rb \
  doc/catalog_enrichment/europe-confirmed-completion.json
do
  sudo install -D -o vidb -g vidb -m 0644 "$file" "$audit_dir/$file"
done

sudo systemd-run --wait --pipe --collect \
  --property=User=vidb \
  --property=WorkingDirectory="$audit_dir" \
  --property=EnvironmentFile=/etc/vidb/vidb.env \
  --setenv=RAILS_ENV=production \
  --setenv=BUNDLE_PATH=/srv/vidb/shared/bundle \
  --setenv=BUNDLE_DEPLOYMENT=1 \
  --setenv=BUNDLE_WITHOUT=development:test \
  --setenv=PATH=/opt/rubies/4.0.6/bin:/usr/bin:/bin \
  /opt/rubies/4.0.6/bin/bundle _2.7.1_ exec ruby bin/rails runner \
  script/complete_confirmed_episode_assets.rb \
  doc/catalog_enrichment/europe-confirmed-completion.json "$@"
