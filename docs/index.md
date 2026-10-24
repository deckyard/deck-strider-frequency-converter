# @deckyard/strider

Reads a [STRidER](https://strider.online/) STR allele-frequency export in XML
and converts one population of it into the `FrequencyDb` that
[`@deckyard/forensicgenetics`](https://deckyard.github.io/deck-forensicgenetics/)
computes with.

This deck is part of [Deckyard](https://github.com/deckyard), community decks for [Jennifer](https://jennifer-lang.dev/).

```jennifer
import "@deckyard/strider/" as strider;
import "@deckyard/forensicgenetics/" as forensics;

def t as strider.Table init strider.parse($xml);
strider.populations($t);   # the whole database, each continent, each country

def db as forensics.FrequencyDb init
    strider.toFrequencyDb($t, "AUSTRIA", "STRidER AT");
```

The forensicgenetics core defines `FrequencyDb` and reads no published format.
This deck converts one source into it; the core does not import it, so a reader
for another source can sit beside it without touching the estimators.

The deck does not:

- fetch anything: you pass the document text
- bundle real data: STRidER's terms forbid redistribution, see
  [Reading a table](reading-a-table.md#getting-the-table)
- combine populations: that operates on `FrequencyDb` values and lives in the
  core, see [Choosing a dataset](datasets.md)
- apply a frequency floor: `forensics.alleleFrequency` does that on read
