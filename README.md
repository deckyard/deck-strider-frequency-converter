# @deckyard/strider

[![test](https://github.com/deckyard/deck-strider-frequency-converter/actions/workflows/test.yml/badge.svg)](https://github.com/deckyard/deck-strider-frequency-converter/actions/workflows/test.yml)
[![docs](https://github.com/deckyard/deck-strider-frequency-converter/actions/workflows/docs.yml/badge.svg)](https://github.com/deckyard/deck-strider-frequency-converter/actions/workflows/docs.yml)
[![release](https://img.shields.io/github/v/release/deckyard/deck-strider-frequency-converter)](https://github.com/deckyard/deck-strider-frequency-converter/releases/latest)

Reads a [STRidER](https://strider.online/) STR allele-frequency export in XML,
which holds every population at once, and converts the population you choose
into the `FrequencyDb` that
[`@deckyard/forensicgenetics`](https://github.com/deckyard/deck-forensicgenetics)
computes with. Frequencies are kept as published.

Manual: **<https://deckyard.github.io/deck-strider-frequency-converter/>**

## Install

Requires Jennifer 0.25.0 or newer. Neither this deck nor its dependency is in
the public registry yet, so point jvc at this repository; the manifest carries
the `[sources]` entry for `@deckyard/forensicgenetics`:

```sh
jvc source @deckyard/strider https://github.com/deckyard/deck-strider-frequency-converter.git
jvc add @deckyard/strider
jvc install
```

This vendors both decks under `vendor/deckyard/`. Without jvc, copy the `src/`
of both (from a checkout or a `deckyard-strider-<version>.tar.gz` release
archive):

```sh
mkdir -p vendor/deckyard/strider vendor/deckyard/forensicgenetics
cp path/to/deck-strider-frequency-converter/src/*.j vendor/deckyard/strider/
cp path/to/deck-forensicgenetics/src/*.j            vendor/deckyard/forensicgenetics/
rm -f vendor/*/*/*_test.j
```

## Example

```jennifer
use fs;
import "@deckyard/strider/" as strider;
import "@deckyard/forensicgenetics/" as forensics;

def t as strider.Table init strider.parse(fs.readString("strider.xml"));
strider.populations($t);                  # ["Entire Database", "Europe", "AUSTRIA", ...]
strider.frequencySums($t, "AUSTRIA");     # locus -> sum, each ~1.0 for a sound table
def db as forensics.FrequencyDb init strider.toFrequencyDb($t, "AUSTRIA", "STRidER AT");
```

## Data

The deck ships no real STRidER table. STRidER's
[terms of use](https://strider.online/terms_of_use) reserve redistribution and
permit downloads for private, non-commercial use only; download the XML
yourself from <https://strider.online/frequencies/xml>. `testdata/frequencies.xml`
is synthetic.

## Tests

```sh
jennifer test src/strider_test.j
jennifer run examples/readtable.j [export.xml] ["POPULATION"]
```

## Licence

LGPL-3.0-only, see [LICENSE](LICENSE). Copyright (C) 2026 mplx &lt;mplx@jennifer-lang.dev&gt;.
