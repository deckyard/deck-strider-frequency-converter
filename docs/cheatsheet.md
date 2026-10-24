<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# strider cheatsheet

```jennifer
import "@deckyard/strider/" as strider;
```

Errors: [strider](strider.md). `tools/check-docs.sh` checks every signature and
field on this page against the code.

## `strider`

| Function | Returns | Does |
|---|---|---|
| `strider.parse(doc)` | `Table` | reads every population of an export, frequencies as published |
| `strider.populations(t)` | `list of string` | population labels, in order of first mention |
| `strider.loci(t, population)` | `list of string` | loci typed in that population, in document order |
| `strider.sampleSize(t, population, locus)` | `int` | N, `0` if the export states none |
| `strider.frequencySum(t, population, locus)` | `float` | sum at one locus, ~1.0 for a sound table |
| `strider.frequencySums(t, population)` | `map of string to float` | locus -> sum for one population; copies the `Table` once |
| `strider.allFrequencySums(t)` | `map of string to map of string to float` | population -> locus -> sum; copies the `Table` once |
| `strider.toFrequencyDb(t, population, name)` | `forensics.FrequencyDb` | converts one population; `name` `""` keeps its label |
| `strider.load(doc, population, name)` | `forensics.FrequencyDb` | `parse` then `toFrequencyDb` |

### `strider.Population`

| Field | Holds |
|---|---|
| `name as string` | population label from the `<origin>` `name` |
| `counts as map of string to int` | locus -> individuals typed (N), 0 if unstated |
| `frequencies as map of string to map of string to float` | locus -> allele label -> published frequency |

### `strider.Table`

| Field | Holds |
|---|---|
| `created as string` | root element's `created_timestamp`, `""` if absent |
| `validity as string` | root element's `validity`, `""` if absent |
| `byPopulation as map of string to Population` | population label -> its frequencies, in order of first mention |
