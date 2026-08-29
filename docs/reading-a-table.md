# Reading a table

## Getting the table

The deck ships no real data and cannot. The published frequencies belong to
their authors, and STRidER's [terms of use](https://strider.online/terms_of_use)
reserve redistribution:

> The reproduction, duplication, editing, dissemination and all type of
> utilization beyond the copyright require written approval of the respective
> author or producer. Downloads and copies of these pages are only for private
> and not for commercial use.

So the download is yours to make. Take the XML from
<https://strider.online/frequencies/xml> and read it in:

```jennifer
use fs;
def xml as string init fs.readString("strider.xml");
```

That permission covers **private, non-commercial** use; anything beyond it is a
question for the rights holder. The `testdata/frequencies.xml` in the
repository is synthetic and carries no STRidER content.

## One export, many populations

A STRidER download is not one table but 33 - the whole database, each
continent, and each contributing country - all in one document. `parse` reads
them all at once, and the population is chosen afterwards by name:

```jennifer
def t as strider.Table init strider.parse($xml);
strider.populations($t);   # ["Entire Database", "Africa", ..., "AUSTRIA", ...]
```

Not every locus is typed in every population - a country contributing few
samples carries fewer than the whole database does - so `loci` is asked per
population rather than of the export.

## Parse, check, convert

The middle step is the one people skip.

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

`frequencySums` rather than a loop over `frequencySum` is deliberate. A `Table`
is a value, so passing it to an accessor copies the whole export - every
population, not just the one asked about. Checking locus by locus pays that copy
per locus and costs more than the parse it is checking: over a real download,
1379 ms against 100 ms for the same 704 sums.

To check the **whole** export rather than one population, `allFrequencySums($t)`
pays the copy once for everything and halves it again, to 48 ms.
`frequencySum` remains the right call for a single locus.

A locus that does not sum to roughly 1.0 was read wrongly - a truncated
download, a percentage-scaled table, or the wrong column taken as the
frequency. The conversion will still refuse anything summing past 1.05, but a
locus summing to 0.6 is a silent, plausible-looking error that only this check
catches.

When you already trust the file, `load` does both steps:

```jennifer
def db as forensics.FrequencyDb init strider.load($xml, "AUSTRIA", "STRidER AT");
```

Reach for the two-step form when you want more than one population, though: the
document already holds them all, so `load`-ing it twice parses half a megabyte
twice for nothing.

## The shape it reads

The export is locus-major, with the populations nested inside each locus:

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
| locus name | the `<name>` **child element** of `<marker>` |
| population | the `name` attribute of `<origin>` |
| `N` | the `n` attribute of `<origin>`, `0` if absent |
| allele label | the `allele` attribute of `<frequency>` |
| frequency | the text of `<frequency>`, in scientific notation |

Tags and attribute names match case-insensitively, and markers are found at any
depth, so a re-nested or re-cased export still reads. The `<alleles>` list on a
marker is the published ladder and is not needed to read frequencies, so it is
ignored. A marker with no `<origin>` children is a locus the export has typed in
no population; it contributes nothing rather than failing the parse.

## Frequencies are kept as published

No floor, no renormalisation - the `Table` holds the document's own numbers, so
`frequencySum` means something. The NRC II `5/(2N)` floor is applied later, on
read, by `forensics.alleleFrequency`, which is why a `FrequencyDb` keeps a
per-locus `N`.
