<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Design

## Scope

`@deckyard/strider` reads the allele-frequency export of
[STRidER™](https://strider.online/), the ENFSI STR reference database, and
converts one population of it into the `forensics.FrequencyDb` of
`@deckyard/forensicgenetics`. It is pure computation on a string the caller has
already read: `src/` does no file or network I/O and declares no capabilities.

Not in scope:

- **Downloading.** STRidER's terms govern access and use; the caller fetches
  the export and passes its text in.
- **Statistics.** Match probabilities, pooling (`forensics.combineFrequencies`)
  and uncertain-population estimates operate on `FrequencyDb` values and live
  in forensicgenetics, so every frequency source shares one implementation.
- **Other formats.** The deck reads STRidER XML only. Another source gets its
  own reader that converges on `forensics.FrequencyDb`.
- **Casework.** Neither this deck nor forensicgenetics has been through the
  validation a jurisdiction requires; the docs state research, teaching and
  cross-checking as the use.

## Decisions

- **A deck on top of forensicgenetics, not part of it.** The core defines the
  generic `FrequencyDb`; a reader per source converts into it. The dependency
  runs one way: forensicgenetics does not import this deck (its docs point
  here). Until forensicgenetics is in the registry, `deck.toml` resolves it
  through a `[sources]` git URL.
- **Package name and repository differ.** The package is `@deckyard/strider`;
  the repository is `deck-strider-frequency-converter`.
- **Parse once, choose the population afterwards.** One export carries the
  whole database, each continent and each contributing country, locus-major
  (populations nested in each `<marker>`). `parse` folds it into a
  population-major `Table` (`byPopulation`), so one parse serves every
  population, and `toFrequencyDb` picks one by label. `load` is `parse` plus
  `toFrequencyDb` for the single-population case.
- **Loci are asked per population.** Populations are typed for different loci,
  so `loci` takes a population; a table-wide locus list would invent cells.
- **Numbers as published.** Frequencies are kept exactly as the export states
  them: no floor, no renormalisation. forensicgenetics applies the 5/(2N) floor
  when it reads a frequency and validates the database in `forensics.withLocus`.
  `frequencySum`, `frequencySums` and `allFrequencySums` let a caller check a
  table before trusting it, since a misread table looks plausible rather than
  broken.
- **Strict number spelling.** A frequency must match `FREQUENCY_PATTERN`
  (unsigned decimal with an optional exponent, as the export writes
  `1.35127e-01`) and `n` must match `COUNT_PATTERN`. The `convert` functions
  alone accepted spellings such as `0x1p-1`, `0.5_0`, `+0.5` and `+500`.
- **Duplicates are errors, not last-wins.** A repeated allele within one
  population of a locus, or a repeated locus within one population, fails the
  parse. Repeat-count labels compare by exact decimal value (`15` equals
  `15.0`, `9.3` equals `9.30`) through the `decimal` library; locus names
  compare case-insensitively and keep the first spelling.
- **Case-insensitive tags and attributes.** Element and attribute names match
  regardless of case, with the exact lower-case name tried first.
- **Markers at any depth.** `<marker>` elements are found wherever they sit
  under the root, in document order. A marker without any `<origin>`
  contributes nothing rather than failing.
- **A missing `n` becomes 0.** No stated sample size means no 5/(2N) floor in
  forensicgenetics; the limitations page spells out the consequences.
- **Root metadata is kept.** `created_timestamp` and `validity` land in
  `Table.created` and `Table.validity` ("" when absent).

## Errors

- Kind `"strider"` (a plain `Error`) for structural problems: no markers, no
  population data, a missing `<name>`, `name`, `allele` or value, a duplicate
  allele or locus, and an unknown population or locus in an accessor.
- Kind `"runtime"` for a frequency or `n` that fails the strict spelling, or a
  frequency element with a child element; this is the kind `convert` throws
  for unparseable text. Malformed XML from `xml.decode` passes through with its
  own kind.
- `toFrequencyDb` and `load` pass on kind `"forensicgenetics"` from
  `forensics.withLocus` (a bad frequency, or a locus summing above
  `forensics.MAX_FREQUENCY_SUM`). A rename of that kind upstream would surface
  here.

The deck reports no server status or code, so it has no error struct.

## Security and limits

- No I/O and no capabilities: the input is a string the caller supplies.
- Hostile or malformed input fails rather than yielding a partial table.
  Nesting depth is bounded by `xml.decode`'s own cap (1000 levels).
- The cost of a parse is linear in the input, including deeply nested
  documents: markers are found by an iterative walk with an explicit stack,
  and results are written in place, not copied up through each level.
- `toFrequencyDb` is linear in the number of loci: it validates each locus
  through `forensics.withLocus` on an empty database and moves the entry into
  the result, instead of extending one growing database per locus.

## Testing and validation

- One overlay, `src/strider_test.j` (31 tests). Malformed inputs are built
  inline. The sample export is inlined in the overlay as a constant so the
  tests pass from an installed copy of `src/`; a test keeps it byte-equal to
  `testdata/frequencies.xml` when run from the deck root.
- `testdata/frequencies.xml` is synthetic (4 loci, 3 populations, Europe
  deliberately lacks TH01). No real STRidER table is bundled, because
  STRidER's terms reserve redistribution.
- Two overlay tests guard the linear cost (deep nesting against a flat
  document, `toFrequencyDb` against a smaller table) by ratio, not absolute
  time.
- The overlay also runs on `jennifer-tiny-dev`, whose `xml.decode` stops at
  64 levels: the deep-nesting test wraps 50 levels there instead of 990.
- A conversion mismatch with forensicgenetics' validation is covered by a test
  that expects kind `"forensicgenetics"`.
- The reader has been run over one full STRidER download: 45 loci across 33
  populations, 704 locus-by-population cells, every locus summing to 1.0 within
  the published precision, all 33 populations converting.
- The tests need `vendor/` populated (`tools/vendor-deps.sh`, network).
- Not covered: other export revisions, and STRidER's online calculator as a
  cross-check of downstream results.

## Known limitations and open questions

- Validated against one export; a changed layout may misread quietly. Check
  with `allFrequencySums`.
- `Table` is a value, so each accessor call copies the export.
  `frequencySums` and `allFrequencySums` exist for bulk checks; looping
  `frequencySum` over every locus is several times slower.
- A locus without `n` has no 5/(2N) floor, which affects pooling in
  forensicgenetics and can overflow `forensics.matchLikelihoodRatio` for tiny
  frequencies (see the limitations page).
- The `[sources]` entry goes once forensicgenetics is published in the
  registry.

## Dependencies on the interpreter

- Floor `jennifer >=0.28.0` (the calls 0.29.0 removes are replaced by their 0.28.0 forms), also declared for `jennifer-tiny`: the tests
  use `strings.replicate` and `testing.assertThrowsArgs`, new in 0.27.0.
- Built-in libraries `xml` (decode, depth cap), `regex`, `decimal` (exact
  value comparison of repeat counts), `convert`, `strings`, `maps`, `lists`.
- `@deckyard/forensicgenetics` `>=0.1.0`, vendored from its released tag:
  `forensics.db`, `forensics.withLocus`, `forensics.FrequencyDb`.
