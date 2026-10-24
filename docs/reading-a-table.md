# Reading a table

## Getting the table

The deck ships no real data. The published frequencies belong to their
authors, and STRidER's [terms of use](https://strider.online/terms_of_use)
reserve redistribution:

> The reproduction, duplication, editing, dissemination and all type of
> utilization beyond the copyright require written approval of the respective
> author or producer. Downloads and copies of these pages are only for private
> and not for commercial use.

Download the XML yourself from <https://strider.online/frequencies/xml>. That
permission covers private, non-commercial use; anything beyond it is a question
for the rights holder. `testdata/frequencies.xml` is synthetic and carries no
STRidER content.

```jennifer
use fs;
def xml as string init fs.readString("strider.xml");
```

## One export, many populations

A download holds 33 tables in one document: the whole database, each continent
and each contributing country. `parse` reads them all; you choose the
population afterwards by name:

```jennifer
def t as strider.Table init strider.parse($xml);
strider.populations($t);   # ["Entire Database", "Africa", ..., "AUSTRIA", ...]
```

A country with few samples carries fewer loci than the whole database, so
`loci` is asked per population.

## Parse, check, convert

```jennifer
def sums as map of string to float init strider.frequencySums($t, "AUSTRIA");
for (def locus in $sums) {
    if (math.abs($sums[$locus] - 1.0) > 0.01) {
        io.printf("locus %s sums to %f, not 1.0\n", $locus, $sums[$locus]);
    }
}

def db as forensics.FrequencyDb init
    strider.toFrequencyDb($t, "AUSTRIA", "STRidER AT");
```

A locus far from 1.0 was read wrongly: a truncated download, a
percentage-scaled table, or the wrong value taken as the frequency. Conversion
rejects a locus summing above 1.05, but a locus summing to 0.6 converts without
complaint; only this check catches it.

Use the bulk sum accessors, not a loop over `frequencySum`. A `Table` is a
value, so each accessor call copies the whole export, every population
included. Over a real download, the same 704 sums cost:

| Form | `Table` copies | ms |
| --- | ---: | ---: |
| `frequencySum` per locus | 704 | 1379 |
| `frequencySums` per population | 33 | 100 |
| `allFrequencySums` once | 1 | 48 |

`allFrequencySums($t)` audits the whole export, `frequencySums` the population
you will compute with, and `frequencySum` a single locus.

`load` parses and converts in one call:

```jennifer
def db as forensics.FrequencyDb init strider.load($xml, "AUSTRIA", "STRidER AT");
```

It skips the check, and calling it per population parses the whole document
(about half a megabyte) each time. For more than one population, parse once
and call `toFrequencyDb` for each.

## The shape it reads

Locus-major, with the populations nested inside each locus (numbers
illustrative):

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

| Field | Read from |
| --- | --- |
| locus name | text of the `<name>` child element of `<marker>` |
| population | `name` attribute of `<origin>` |
| `N` | `n` attribute of `<origin>`, `0` if absent |
| allele label | `allele` attribute of `<frequency>`, kept as text (`9.3` and `9` are distinct) |
| frequency | text of `<frequency>`, in scientific notation |
| `Table.created`, `Table.validity` | `created_timestamp` and `validity` on the root element |

Tag and attribute names match in any case, and markers are found at any depth.
The `<alleles>` list is ignored. A marker with no `<origin>` is a locus typed
in no population; it contributes nothing. The real export has one.

## Frequencies are kept as published

No floor and no renormalisation: the `Table` holds the document's numbers, so
`frequencySum` is meaningful. The NRC II 5/(2N) floor is applied on read by
`forensics.alleleFrequency`, which is why a `FrequencyDb` keeps a per-locus `N`.
