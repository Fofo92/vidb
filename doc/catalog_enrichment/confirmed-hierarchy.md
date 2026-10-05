# Confirmed documentary hierarchy pilot

Pascal confirmed by viewing all six files on 2026-10-05 that their numbers follow
the ARTE episode order. Earlier filenames E02 and E03 had incorrect titles; the
user renamed them and moved all six files into `Saison 01`. The refreshed inventory
also confirms the six new paths. The accepted evidence is retained in
`europe-confirmed-hierarchy.json`, separately from the historical comparison.

This pilot accepts an explicit local season 1, rather than claiming ARTE supplied
a season number. It qualifies record 3060 as a series and creates a season plus
six episode records. Only the mandatory language version is inherited. Year,
duration, abstract, country, media and genre are not inferred. New episode viewing,
recording and availability states remain unknown; `is_checked` stays false. It
does not create VideoAssets or touch video files.

The service requires the expected root ID, title, compatible kind and a language
version. It accepts an empty hierarchy or an already identical full hierarchy.
Partial or conflicting trees stop the operation. Application runs in one database
transaction under a root row lock; a late failure rolls back the root qualification
and all new children. A rerun preserves existing metadata and viewing states.
This serializes this importer for the root; catalog UI writers must still avoid
editing the same hierarchy during the operation.

Tests:

```sh
bundle exec ruby bin/rails test test/services/catalog_enrichment/confirmed_hierarchy_test.rb
bundle exec rubocop app/services/catalog_enrichment/confirmed_hierarchy.rb
```

Preview (database reads only), using the application's configured environment:

```sh
bin/rails runner script/apply_confirmed_episode_hierarchy.rb \
  doc/catalog_enrichment/europe-confirmed-hierarchy.json
```

Append `--apply` to apply the confirmed proposal. The runner checks the six files
still exist and their basenames agree with the confirmed titles. It prints the
result and full confirmed evidence. This runner is limited to the verified pilot
convention; a general proposal UI and persistent external-claim tables remain
future work.
