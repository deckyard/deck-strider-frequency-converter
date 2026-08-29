# @mplx/strider

Reads a published **STRidER**-style STR allele-frequency table in XML and
converts it into the generic `FrequencyDb` that
[`@jennifer/forensicgenetics`](https://jennifer-language.github.io/deck-forensicgenetics/)
computes with.

```jennifer
import "@mplx/strider/" as strider;
import "@jennifer/forensicgenetics/" as forensics;

def t as strider.Table init strider.parse($xml);
strider.populations($t);   # one export holds the whole database and every country

def db as forensics.FrequencyDb init
    strider.toFrequencyDb($t, "AUSTRIA", "STRidER AT");
```

## Where this sits

The forensicgenetics core is deliberately **vendor-independent**: it defines
`FrequencyDb` and reads no published format at all. A reader like this one
converts a particular source into that type. The dependency runs one way - this
deck imports the core, the core knows nothing about STRidER - which is what
lets a reader for any other source slot in beside it without touching the
estimators.

## What it does not do

- It does not fetch anything. You supply the document text.
- It does not bundle real data, and cannot: STRidER's
  [terms of use](https://strider.online/terms_of_use) reserve
  redistribution, so you download the XML yourself from
  <https://strider.online/frequencies/xml>. The bundled
  `testdata/frequencies.xml` is synthetic.
- It does not combine populations. That is a question about `FrequencyDb`
  values, so it lives in the core - see
  [Choosing a dataset](datasets.md).
- It applies no frequency floor. `forensics.alleleFrequency` does that on read.
