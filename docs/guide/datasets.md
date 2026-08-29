# Choosing a dataset

STRidER publishes frequencies **per country, per continent, and for the whole
database**. These are different tables giving different numbers, so a match
probability is not a property of a profile alone - it is a property of a
profile *and* a chosen reference population. A single export carries all of
them, so the population is picked by name after the parse:

```jennifer
def t as strider.Table init strider.parse($xml);

def at as forensics.FrequencyDb init strider.toFrequencyDb($t, "AUSTRIA", "STRidER AT");
def eu as forensics.FrequencyDb init strider.toFrequencyDb($t, "Europe", "STRidER Europe");
def all as forensics.FrequencyDb init strider.toFrequencyDb($t, "Entire Database", "");
```

`strider.populations($t)` lists what a given export offers. The label lands in
`FrequencyDb.name` and travels with the table, so a result can say which dataset
produced it - and because one parse serves every population, comparing them
costs nothing extra.

## Two or more populations

Suppose the donor could be German or Austrian. There are two operations, they
give different answers, and only one of them answers that question.

### Pooling - one merged population

`forensics.combineFrequencies` sums observed allele counts across tables,
weighted by sample size:

```jennifer
def pooled as forensics.FrequencyDb init forensics.combineFrequencies(
    [$de, $at], "DE+AT");
```

Only loci that **every** input carries are pooled. The result describes one
merged population, and that is the honest use for it - a genuinely admixed
reference group.

### The uncertain donor - the law of total probability

This is the right tool for "German *or* Austrian":

```jennifer
def p as float init forensics.randomMatchProbabilityAcross(
    [$de, $at], [0.5, 0.5], $suspect, forensics.THETA_GENERAL);
def lr as float init forensics.matchLikelihoodRatioAcross(
    [$de, $at], [0.5, 0.5], $suspect, forensics.THETA_GENERAL);
```

It computes the match probability **within** each population and averages the
results, weighted by how likely the donor is to come from each. The weights are
priors and must sum to 1; equal weights say only "one of these, no reason to
prefer either".

### Why they differ, and which one is dangerous

Pooling averages *allele frequencies*; the across form averages *genotype
probabilities*. Those are not the same operation, and the gap is the **Wahlund
effect**: merging populations whose frequencies differ leaves the pool short of
heterozygotes relative to Hardy-Weinberg. Since the match probability assumes
Hardy-Weinberg, a pooled table biases it downwards - which overstates the
evidence, the direction that favours the prosecution.

A worked case from the test suite. Two populations, one locus, equal sample
sizes:

| | allele 6 | allele 9.3 |
| --- | --- | --- |
| population A | 0.8 | 0.2 |
| population B | 0.2 | 0.8 |
| pooled | 0.5 | 0.5 |

For a `6,6` homozygote, with no theta correction:

| Method | Match probability |
| --- | --- |
| pooled table, `0.5²` | **0.25** |
| across, `0.5(0.8²) + 0.5(0.2²)` | **0.34** |

The pooled table overstates that match by a third. On a full multi-locus
profile the discrepancy compounds across every locus.

### The conservative alternative

Often you do not need to pick at all. Compute the match probability in each
candidate population and report the largest:

```jennifer
for (def db in [$de, $at, $europe]) {
    io.printf("%s: %f\n", $db.name,
        forensics.randomMatchProbability($db, $suspect, forensics.THETA_GENERAL));
}
```

If the conclusion holds across every plausible population, the choice of
population stops being a point of dispute. Where it does not hold, that is
itself the finding.

## Theta is the other half

The NRC II `theta` correction exists for sub-population structure *within* a
reference population, and `randomMatchProbabilityAcross` applies it inside each
one. It is not a substitute for choosing the right population, and choosing the
right population is not a substitute for it.
