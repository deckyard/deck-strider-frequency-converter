# @mplx/strider

[![test](https://github.com/mplx/deck-strider-frequency-converter/actions/workflows/test.yml/badge.svg)](https://github.com/mplx/deck-strider-frequency-converter/actions/workflows/test.yml)
[![docs](https://github.com/mplx/deck-strider-frequency-converter/actions/workflows/docs.yml/badge.svg)](https://github.com/mplx/deck-strider-frequency-converter/actions/workflows/docs.yml)
[![release](https://img.shields.io/github/v/release/mplx/deck-strider-frequency-converter)](https://github.com/mplx/deck-strider-frequency-converter/releases/latest)

Reads a published **STRidER**-style STR allele-frequency table in XML and
converts it into the generic `FrequencyDb` that
[`@jennifer/forensicgenetics`](https://github.com/jennifer-language/deck-forensicgenetics)
computes with.

## Documentation

**<https://mplx.github.io/deck-strider-frequency-converter/>**

## At a glance

```jennifer
import "@mplx/strider/" as strider;
import "@jennifer/forensicgenetics/" as forensics;

# One export holds every population - read it once.
def t as strider.Table init strider.parse($xml);
strider.populations($t);                      # ["Entire Database", "Europe", "AUSTRIA", ...]

# Parse, check, then convert - the check is the part people skip.
strider.frequencySums($t, "AUSTRIA");             # locus -> sum, each ~1.0

def db as forensics.FrequencyDb init strider.toFrequencyDb($t, "AUSTRIA", "STRidER AT");

# ...or in one call, when you already trust the file:
def db2 as forensics.FrequencyDb init strider.load($xml, "AUSTRIA", "STRidER AT");
```

| Function | Returns |
| --- | --- |
| `parse(doc)` | `Table` - every population in the export |
| `populations(t)` | `list of string`, in document order |
| `loci(t, population)` | `list of string` - the loci typed in that population |
| `sampleSize(t, population, locus)` | `int` - N, `0` if unstated |
| `frequencySum(t, population, locus)` | `float` - should be ≈ 1.0 |
| `frequencySums(t, population)` | `map of string to float` - every locus at once; use this to check |
| `allFrequencySums(t)` | `map of string to map of string to float` - every population at once |
| `toFrequencyDb(t, population, name)` | `forensics.FrequencyDb` |
| `load(doc, population, name)` | `parse` then `toFrequencyDb` |

## The shape it reads

STRidER publishes one locus-major document, with every population nested inside
each locus as an `<origin>`:

```xml
<frequencies created_timestamp="..." validity="...">
  <marker>
    <name>D3S1358</name>
    <alleles>15, 16, 17</alleles>
    <origin name="Entire Database" n="20000">
      <frequency allele="15">2.50000e-1</frequency>
    </origin>
    <origin name="AUSTRIA" n="500">
      <frequency allele="15">3.00000e-1</frequency>
    </origin>
  </marker>
</frequencies>
```

The locus name is a `<name>` **child element**, not an attribute; `N` sits on
the `<origin>`; frequencies are in scientific notation. Tags and attribute names
match case-insensitively, and markers are found at any depth.

## Choosing a population

A single download is **33 populations** - the whole database, each continent,
and each contributing country. Which one a calculation used is part of the
result, so it is chosen by name and the resulting database is labelled with it:

```jennifer
def t as strider.Table init strider.parse($xml);

strider.toFrequencyDb($t, "AUSTRIA", "STRidER AT");   # relabelled
strider.toFrequencyDb($t, "AUSTRIA", "");             # keeps the export's own label
```

Not every locus is typed in every population, so `loci` is asked per population
rather than of the export. Converting a second population needs no second parse.

Combining several populations is a question for the core deck, not this one -
see `forensics.combineFrequencies` and `forensics.randomMatchProbabilityAcross`.

## Installing

Requires Jennifer 0.25.0 or newer. Install with
[jvc](https://github.com/jennifer-language/jvc), the deck manager:

```sh
jvc source @mplx/strider https://github.com/mplx/deck-strider-frequency-converter.git
jvc add @mplx/strider
jvc install
```

That vendors this deck and its one dependency into `vendor/`, after which
`import "@mplx/strider/" as strider;` resolves with no path.

The `source` line is needed because neither this deck nor
`@jennifer/forensicgenetics` is in the public registry yet, so both resolve from
their git remotes rather than by name. This deck's own manifest already carries
the `[sources]` entry for its dependency, so you only have to point jvc at
*this* deck. Once both are published, `jvc add @mplx/strider` alone is enough.

### By hand, without jvc

The vendor tree is a plain directory layout, so it can be populated by copying:

```sh
mkdir -p vendor/mplx/strider vendor/jennifer/forensicgenetics
cp path/to/deck-strider-frequency-converter/src/*.j vendor/mplx/strider/
cp path/to/deck-forensicgenetics/src/*.j            vendor/jennifer/forensicgenetics/
rm -f vendor/*/*/*_test.j
```

This repository's own `vendor/` is populated that way and is git-ignored; CI
recreates it from the forensicgenetics repository on every run, because the
interpreter image it builds in does not carry jvc.

## Getting the frequency data

**This repository ships no real STRidER table, and cannot.** The published
frequencies belong to their authors, and STRidER's
[terms of use](https://strider.online/terms_of_use) reserve redistribution:

> The reproduction, duplication, editing, dissemination and all type of
> utilization beyond the copyright require written approval of the respective
> author or producer. Downloads and copies of these pages are only for private
> and not for commercial use.

So the download is yours to make rather than this deck's to vendor. Take the
XML straight from STRidER and point the reader at it:

**<https://strider.online/frequencies/xml>**

```jennifer
use fs;
def db as forensics.FrequencyDb init strider.load(
    fs.readString("strider.xml"), "AUSTRIA", "STRidER AT");
```

That permission covers **private, non-commercial** use; anything beyond it is a
question for the rights holder, not one this deck can answer for you.

## Tests and examples

```sh
jennifer test src/strider_test.j
jennifer run examples/readtable.j                     # the bundled fixture
jennifer run examples/readtable.j strider.xml        # your own download
jennifer run examples/readtable.j strider.xml AUSTRIA
```

Both example arguments are optional: the export defaults to the bundled fixture,
the population to the first the export offers. Labels can contain spaces, so
quote them - `"Entire Database"`, `"SAUDI ARABIA"`.

19 tests. The bundled `testdata/frequencies.xml` is **synthetic** - invented
numbers in the real export's shape, carrying no STRidER content. For real tables
see [Getting the frequency data](#getting-the-frequency-data).

## Before you quote a number

- **Check your own download.** The reader has been run against a full STRidER
  export - 45 loci across 33 populations, every locus summing to 1.0 within
  rounding - but exports change. `frequencySum` is the cheap check: a locus that
  does not sum to ~1.0 was read wrongly.
- Frequencies come back **exactly as published**: no floor, no renormalisation.
  The `5/(2N)` floor is applied on read by `forensics.alleleFrequency`.
- A locus that states no `N` gets `0`, which means no floor is available for it.

## Licence

LGPL-3.0-only.
