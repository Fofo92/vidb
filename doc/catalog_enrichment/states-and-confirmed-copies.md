# States and confirmed copies

Rules agreed with Pascal on 2026-10-05:

- Recording is historical: once true, ordinary model saves cannot erase it.
- Present availability implies historical recording. Confirmed tracked copies
  determine availability; deleting the last copy's status preserves recording.
- Use `status: deleted` to retain copy history, rather than deleting its database
  record. Several present copies remain possible for the same work.
- Counters on series and seasons use episode and other video leaves, excluding
  intermediate containers and empty seasons. Parent scalar flags remain historical
  data; they are not used as aggregate states and are hidden in container forms.
- Nil is unknown. Legacy false on an unchecked record is also unknown for viewing,
  recording and availability. False `is_checked` means not editorially verified.
  Confirmed asset evidence can establish negative availability even for an unchecked
  record. The current schema cannot separately date each manual negative claim.
- Episode production years drive parent ranges. Season and series scalar years are
  not used when descendant episode years are available. Only leaf catalogue lengths
  are summed; unknown lengths are not displayed as zero.

Model callbacks keep leaf scalar states coherent when a confirmed VideoAsset is
saved, marked deleted or removed. Direct SQL and `update_columns` bypass callbacks;
use the normal model APIs. An asset owner cannot be silently reassigned.

The pilot manifest retains the publisher evidence and Pascal's viewing confirmation.
It proposes Germany/France/Belgium on all eight records, one dictionary genre
Documentaire (Documentaires is accepted as an alternative spelling), and production
year 2022 on the six episodes. Existing country subsets are completed; additional
countries, different genres or different episode years stop the operation. Dictionary
entries are resolved, never created automatically. Generic automatic country
propagation after arbitrary UI edits remains a separate change.

Six files are observed directly with ffprobe before database changes. Their byte sizes,
container and observed time go into VideoAssets; measured durations populate the
existing integer minutes field, rounded to the nearest minute. Exact measured seconds
are also printed in the report. These measurements never overwrite the catalogue
length field. Fiche verification, viewing state, abstracts, media and language are
preserved. A path already present on another record blocks application. Metadata and
all copies are applied in one transaction; reruns refresh existing copies.

Run the tests and lint before using the production wrapper. Preview:

```sh
bash script/run_europe_completion.sh
```

This installs files only into the existing audit checkout and prints a preview.
It does not update database metadata or assets. Applying the confirmed pilot:

```sh
bash script/run_europe_completion.sh --apply
```

The audit checkout uses the production database and environment. It is not the
running web release: new counters, forms and copy displays require the project's
normal deployment of these code changes. No migration or dependency change is
introduced by this patch. Source status changes elsewhere on disk are not detected
automatically; this pilot confirms only the six explicitly verified files.
