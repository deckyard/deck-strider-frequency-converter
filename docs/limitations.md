# Limitations

**Validated against one export, not against every export.** The reader has been
run over a full STRidER download - 45 loci across 33 populations, 704
locus-by-population cells, every locus summing to 1.0 within the six significant
figures published, and all 33 populations converting cleanly. That is one
snapshot of one format. Exports change, so check your own download with
`allFrequencySums` - that check exists because a misread table is
plausible-looking rather than obviously broken.

**The bundled table is synthetic, and no real one can be bundled.**
`testdata/frequencies.xml` is made-up numbers for the tests and the example.
The real tables belong to their authors, and STRidER's
[terms of use](https://strider.online/terms_of_use) reserve redistribution:

> The reproduction, duplication, editing, dissemination and all type of
> utilization beyond the copyright require written approval of the respective
> author or producer. Downloads and copies of these pages are only for private
> and not for commercial use.

So the download is yours to make, from
<https://strider.online/frequencies/xml>. That permission covers private,
non-commercial use; a commercial or published use is a question for the rights
holder.

**A locus with no stated `N` gets `0`.** No sample size means no `5/(2N)`
floor is available for that locus, so a rare or unobserved allele has nothing
holding it off zero. Check `forensics.sampleSize` if the document's `N` handling
is uncertain.

**Only one format.** This deck reads STRidER-style XML. Another source needs
another reader; they all converge on the same `forensics.FrequencyDb`, which is
the point of the split.

**No population combination here.** Pooling and uncertain-population estimators
operate on `FrequencyDb` values and live in the core deck. See
[Choosing a dataset](datasets.md) - and note that pooling and the
law-of-total-probability form give different answers, only one of which fits
the "donor was German or Austrian" question.

**Not a validated forensic tool.** Neither this deck nor the core has been
through the validation any jurisdiction requires of software used in casework.
Treat both as libraries for research, teaching and cross-checking.
