# `strider`

```jennifer
import "@deckyard/strider/" as strider;
```

Signatures and struct fields are in the [cheatsheet](cheatsheet.md), the
document shape in [Reading a table](reading-a-table.md#the-shape-it-reads).
Every accessor copies the whole `Table`; see
[the cost table](reading-a-table.md#parse-check-convert) before looping one.

## Errors

| Condition | `kind` | Thrown by |
| --- | --- | --- |
| no `<marker>` element in the document | `strider` | `parse`, `load` |
| markers present but none carries population data | `strider` | `parse`, `load` |
| a marker with no `<name>` child | `strider` | `parse`, `load` |
| an `<origin>` with no `name` attribute | `strider` | `parse`, `load` |
| a `<frequency>` with no `allele` attribute, or no value | `strider` | `parse`, `load` |
| an allele listed twice in one population's locus | `strider` | `parse`, `load` |
| a locus listed twice for one population | `strider` | `parse`, `load` |
| malformed XML, or a frequency or `n` that is not a number | `runtime` | `parse`, `load` |
| unknown population | `strider` | every function taking `population` |
| unknown locus | `strider` | `sampleSize`, `frequencySum` |
| a frequency outside `(0, 1]`, a locus summing above 1.05, or a negative `n` | `forensicgenetics` | `toFrequencyDb`, `load` |

`parse` accepts any number as a frequency, zero and negative values included.
They are rejected only on conversion, by `forensics.withLocus`; that is also
where a percentage-scaled table is caught instead of producing probabilities
above 1.
