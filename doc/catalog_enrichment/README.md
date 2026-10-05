# External episode evidence: first comparison

This first stage compares existing reconciliation observations against independently
collected episode metadata. It reads JSON files only: no Rails boot, database
connection, network request, rename, catalog update or VideoAsset creation.

The pilot evidence is manually extracted from the ARTE publisher page linked in
`europe-un-continent-bouleverse.json`, consulted on 2026-10-05. It contains six
episode titles and their publisher order. The record ID and series title select
the local catalog context; they are not publisher identifiers. The source does
not specify a season number, so none is asserted.

From the project root:

```sh
ruby test/services/catalog_enrichment/episode_comparison_test.rb
bundle exec rubocop app/services/catalog_enrichment/episode_comparison.rb
ruby script/external_episode_comparison.rb \
  tmp/video-asset-reconciliation-production-2026-10-04-v4b.json \
  doc/catalog_enrichment/europe-un-continent-bouleverse.json \
  tmp/europe-external-episode-comparison.json
```

The report retains the original inventory provenance, the source evidence,
disk numbering and titles, and separate publisher candidates by number and title.
Every observation has `accepted: false`, including agreeing titles and numbers.
No title means `number_only_unverified`; in a permuted local sequence, a number
alone cannot identify the content. A title matching a different publisher number
means `title_number_conflict`. Repeated publisher titles remain ambiguous.

The historical pilot should yield one title/number agreement, two conflicts and
three observations lacking titles. The latter need additional content evidence
before any files are assigned or renamed. Do not infer their identities by
elimination. A future acceptance step must also check current disk state, duplicate
files, existing children and local hierarchy before applying any changes.

This is a source-neutral comparison service, not yet an automatic API client or
catalog importer. Other publisher or API adapters can produce the same evidence
format later. A shared schema for persisted external claims and accepted proposals
is still to be implemented.
