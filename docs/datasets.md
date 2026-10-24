# Choosing a dataset

STRidER publishes frequencies per country, per continent and for the whole
database. They give different numbers, so a match probability belongs to a
profile and a chosen reference population together. One export carries all of
them; pick by name after the parse:

```jennifer
def t as strider.Table init strider.parse($xml);

def at as forensics.FrequencyDb init strider.toFrequencyDb($t, "AUSTRIA", "STRidER AT");
def eu as forensics.FrequencyDb init strider.toFrequencyDb($t, "Europe", "STRidER Europe");
def all as forensics.FrequencyDb init strider.toFrequencyDb($t, "Entire Database", "");
```

`strider.populations($t)` lists what an export offers. The label becomes
`FrequencyDb.name`, so a result can say which dataset produced it. One parse
serves every population.

## Two or more populations

If the donor could be German or Austrian, there are two operations. They give
different answers, and only one answers that question.

### Pooling: one merged population

`forensics.combineFrequencies` sums observed allele counts across tables,
weighted by sample size:

```jennifer
def pooled as forensics.FrequencyDb init forensics.combineFrequencies(
    [$de, $at], "DE+AT");
```

Only loci that every input carries are pooled. The result describes one merged
population; use it for a genuinely admixed reference group.

### Uncertain donor: the law of total probability

For "German or Austrian":

```jennifer
def p as float init forensics.randomMatchProbabilityAcross(
    [$de, $at], [0.5, 0.5], $suspect, forensics.THETA_GENERAL);
def lr as float init forensics.matchLikelihoodRatioAcross(
    [$de, $at], [0.5, 0.5], $suspect, forensics.THETA_GENERAL);
```

This computes the match probability within each population and averages the
results, weighted by the prior probability that the donor comes from each. The
weights must sum to 1; equal weights say only "one of these, no reason to
prefer either".

### Why pooling is the dangerous one

Pooling averages allele frequencies; the across form averages genotype
probabilities. The gap between them is the Wahlund effect: merging populations
whose frequencies differ leaves the pool short of heterozygotes relative to
Hardy-Weinberg. The match probability assumes Hardy-Weinberg, so a pooled table
biases it downwards and overstates the evidence, in the direction that favours
the prosecution.

A case from the forensicgenetics test suite: two populations, one locus, equal
sample sizes.

| | allele 6 | allele 9.3 |
| --- | --- | --- |
| population A | 0.8 | 0.2 |
| population B | 0.2 | 0.8 |
| pooled | 0.5 | 0.5 |

For a `6,6` homozygote, with no theta correction:

| Method | Match probability |
| --- | --- |
| pooled table, `0.5²` | 0.25 |
| across, `0.5(0.8²) + 0.5(0.2²)` | 0.34 |

The pooled likelihood ratio (4.0) is about a third higher than the correct one
(2.9). Over a multi-locus profile the error compounds at every locus.

### The conservative alternative

Compute the match probability in each candidate population and report the
largest:

```jennifer
for (def db in [$de, $at, $europe]) {
    io.printf("%s: %f\n", $db.name,
        forensics.randomMatchProbability($db, $suspect, forensics.THETA_GENERAL));
}
```

If the conclusion holds in every plausible population, the choice of
population stops being a point of dispute. If it does not, that is itself the
finding.

## Theta

The NRC II theta correction covers sub-population structure within a reference
population, and `randomMatchProbabilityAcross` applies it inside each one. It
does not replace choosing the right population, and the right population does
not replace it.
