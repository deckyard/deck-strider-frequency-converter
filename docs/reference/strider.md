# `strider`

```jennifer
import "@mplx/strider/" as strider;
```

Reads a STRidER XML allele-frequency export and converts one population out of
it into `forensics.FrequencyDb`. Errors are `Error{kind: "strider"}`; a
conversion that fails the generic type's validation raises
`kind: "forensicgenetics"`.

## Types

```jennifer
def struct Table {
    created as string,                             # the export's created_timestamp
    validity as string,                            # the export's validity date
    byPopulation as map of string to Population    # label -> that population's rows
};

def struct Population {
    name as string,                                           # the origin's label
    counts as map of string to int,                           # locus -> N, 0 if unstated
    frequencies as map of string to map of string to float    # locus -> allele -> frequency
};
```

One export carries **every population at once** - the whole database, each
continent, and each contributing country - so `parse` reads them all and the
population is chosen afterwards, by name. `parse` returns the frequencies
**exactly as published**: no floor, no renormalisation.

## Functions

| Signature | Returns |
| --- | --- |
| `parse(doc as string)` | `Table` - every population in the export |
| `populations(t)` | `list of string` - labels, in document order |
| `loci(t, population as string)` | `list of string` - the loci typed in that population |
| `sampleSize(t, population, locus as string)` | `int` - N, `0` if the export stated none |
| `frequencySum(t, population, locus as string)` | `float` - should be ≈ 1.0 |
| `toFrequencyDb(t, population, name as string)` | `forensics.FrequencyDb` - `name` labels the dataset, `""` uses the population's own |
| `load(doc, population, name as string)` | `forensics.FrequencyDb` - `parse` then `toFrequencyDb` |

`loci` is asked **per population** because the set differs: a country
contributing few samples carries fewer loci than the whole database does.

Use `parse` + `toFrequencyDb` rather than `load` when you want more than one
population out of a document - the export holds them all, so re-parsing it per
population is wasted work.

## Errors

| Condition | `kind` |
| --- | --- |
| no `<marker>` elements in the document | `strider` |
| markers present but none carries population data | `strider` |
| a marker with no `<name>` child | `strider` |
| an `<origin>` with no `name` attribute | `strider` |
| a `<frequency>` with no `allele` attribute, or no value | `strider` |
| duplicate allele within one population's locus | `strider` |
| duplicate locus for one population | `strider` |
| an unknown population or locus passed to any accessor | `strider` |
| a frequency outside `(0, 1]`, or a locus summing past 1.05 | `forensicgenetics` |

The last row is the generic type's own validation, raised through
`forensics.withLocus` during conversion - a percentage-scaled table is caught
there rather than silently producing probabilities above 1.
