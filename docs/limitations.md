# Limitations

**Validated against one export.** The reader has been run over one full
STRidER download: 45 loci across 33 populations, 704 locus-by-population cells,
every locus summing to 1.0 within the six significant figures published, and
all 33 populations converting. Exports change, so check yours with
`allFrequencySums`; a misread table looks plausible rather than broken.

**No real table is bundled.** `testdata/frequencies.xml` is invented numbers
for the tests and the example. STRidER's terms of use reserve redistribution
and permit private, non-commercial use only; see
[Getting the table](reading-a-table.md#getting-the-table). Commercial or
published use is a question for the rights holder.

**A locus with no stated `N` gets `0`.** No sample size means no 5/(2N) floor,
so a rare or unobserved allele has nothing holding it off zero. Check
`forensics.sampleSize` if the export's `N` is in doubt.

Two consequences. Pooling needs a stated `N`: `forensics.combineFrequencies`
weights by `2N`, so in forensicgenetics 0.3.0 a population with `n = 0` is
silently dropped from the pool, and newer releases reject it. And without the
floor a published frequency near `1e-155` gives a match probability near
`1e-310`, and `forensics.matchLikelihoodRatio` (`1 / p`) throws a float-overflow
`runtime` error; use `forensics.log10RandomMatchProbability` (log10 LR is its
negation) for such tables.

**One format.** The deck reads STRidER XML only. Another source needs another
reader that converges on `forensics.FrequencyDb`.

**No population combination.** Pooling and uncertain-population estimators
operate on `FrequencyDb` values and live in the core. They give different
answers; see [Choosing a dataset](datasets.md).

**Not a validated forensic tool.** Neither this deck nor the core has been
through the validation any jurisdiction requires of software used in casework.
Use both for research, teaching and cross-checking.
