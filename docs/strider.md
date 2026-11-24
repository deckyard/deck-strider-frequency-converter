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
| an allele listed twice in one population's locus, as text or as a repeat count of equal value (`15` and `15.0`) | `strider` | `parse`, `load` |
| a locus listed twice for one population, names compared case-insensitively (`TH01` and `th01`) | `strider` | `parse`, `load` |
| malformed XML | `xml` (`runtime` before Jennifer 0.28.0) | `parse`, `load` |
| a frequency that is not unsigned decimal with an optional exponent (`-0.5`, `+0.5`, `0x1p-1`, `0.5_0`, `NaN`, `0,5`), or that contains a child element | `runtime` | `parse`, `load` |
| an `n` that is not unsigned decimal digits (`-5`, `+500`, `500.0`, `1e3`), or too large for an `int` | `runtime` | `parse`, `load` |
| unknown population | `strider` | every function taking `population` |
| unknown locus | `strider` | `sampleSize`, `frequencySum` |
| a frequency outside `(0, 1]`, or a locus summing above 1.05 | `forensicgenetics` | `toFrequencyDb`, `load` |

`parse` accepts any unsigned decimal as a frequency, zero and values above 1
included. They are rejected only on conversion, by `forensics.withLocus`; that
is also where a percentage-scaled table is caught instead of producing
probabilities above 1. A negative `n` or frequency cannot be spelled in an
accepted form, so `parse` rejects it.
