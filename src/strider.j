# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * Reader for STRidER autosomal-STR allele-frequency exports in XML.
 *
 * `parse` returns per-population, per-locus allele -> frequency maps with each
 * locus's sample size `N`; `toFrequencyDb` converts one population into
 * `forensics.FrequencyDb` from `@deckyard/forensicgenetics`. The dependency
 * runs one way: the core does not import this module.
 *
 * The reader targets the layout published at
 * <https://strider.online/frequencies/xml>: locus-major, with the populations
 * nested inside each locus (the numbers below are illustrative):
 *
 * ```xml
 * <frequencies created_timestamp="..." validity="...">
 *   <marker>
 *     <name>D3S1358</name>
 *     <alleles>15, 16, 17</alleles>
 *     <origin name="Entire Database" n="20000">
 *       <frequency allele="15">2.50000e-1</frequency>
 *     </origin>
 *     <origin name="AUSTRIA" n="500">
 *       <frequency allele="15">3.00000e-1</frequency>
 *     </origin>
 *   </marker>
 * </frequencies>
 * ```
 *
 * One export carries the whole database, each continent and each
 * contributing country. `parse` reads them all into a population-major
 * `Table`; the population is chosen afterwards by name. Loci are typed
 * unevenly across populations, so `loci` is asked per population.
 *
 * Frequencies are kept as published, with no floor and no renormalisation;
 * `forensics.alleleFrequency` applies the 5/(2N) floor on read.
 * @module strider
 * @see https://strider.online/ - the ENFSI STRidER reference database
 * @example
 * import "@deckyard/strider/" as strider;
 * def t as strider.Table init strider.parse(fs.readString("strider.xml"));
 * strider.populations($t);                     # ["Entire Database", ...]
 * strider.frequencySum($t, "AUSTRIA", "TH01"); # ~1.0 for a sound table
 *
 * # or parse and convert in one call:
 * def db as forensics.FrequencyDb init strider.load($doc, "AUSTRIA", "STRidER AT");
 */
use xml;
use strings;
use maps;
use convert;

import "@deckyard/forensicgenetics/" as forensics;

/**
 * One population's frequencies, as published.
 * @field name {string} population label from the `<origin>` `name`, trimmed
 * @field counts {map of string to int} locus -> individuals typed (N), 0 if unstated
 * @field frequencies {map of string to map of string to float} locus -> allele label ->
 *   published frequency
 */
export def struct Population {
    name as string,
    counts as map of string to int,
    frequencies as map of string to map of string to float
};

/**
 * A parsed export: every population the document carries, keyed by label.
 * @field created {string} root element's `created_timestamp`, "" if absent
 * @field validity {string} root element's `validity`, "" if absent
 * @field byPopulation {map of string to Population} population label -> its frequencies,
 *   in order of first mention
 */
export def struct Table {
    created as string,
    validity as string,
    byPopulation as map of string to Population
};

# Origin is one population's block inside one locus, before the population-major
# fold; Marker is one locus with all of its blocks.
def struct Origin {
    population as string,
    n as int,
    freqs as map of string to float
};

def struct Marker {
    name as string,
    origins as list of Origin
};

# --- errors -----------------------------------------------------------------

func fail(msg as string) {
    throw Error{kind: "strider", message: $msg, file: "", line: 0, col: 0};
}

# where builds the "'locus' / 'population'" suffix every read error carries, so
# a bad allele in a 45-locus, 33-population export says which cell it was in.
func where(marker as string, population as string) {
    return " in '" + $marker + "' / '" + $population + "'";
}

# --- element helpers --------------------------------------------------------

# attrOf returns `e`'s attribute named `want`, or "" when it carries none. XML
# attribute names are case-sensitive; the lookup folds case so a re-cased export
# still reads.
func attrOf(e as xml.Value, want as string) {
    for (def a in xml.attrs($e)) {
        if (strings.lower($a) == $want) {
            return xml.attr($e, $a);
        }
    }
    return "";
}

# isTag reports whether `e` is an element with the given lower-cased tag.
func isTag(e as xml.Value, want as string) {
    if (xml.typeOf($e) != "element") {
        return false;
    }
    return strings.lower(xml.tag($e)) == $want;
}

# --- reading ----------------------------------------------------------------

# markerName reads the locus name out of the `<name>` child. STRidER states it
# as an element rather than an attribute, and it is the only place it appears.
func markerName(e as xml.Value) {
    for (def c in xml.children($e)) {
        if (isTag($c, "name")) {
            return strings.trim(xml.text($c));
        }
    }
    return "";
}

# readOrigin turns one `<origin>` into a population's row for this locus.
# Duplicate allele labels are an error rather than a silent last-wins, because a
# block that lists an allele twice is one whose frequencies no longer sum
# sensibly.
func readOrigin(e as xml.Value, marker as string) {
    def population as string init strings.trim(attrOf($e, "name"));
    if (len($population) == 0) {
        fail("an origin in '" + $marker + "' carries no name attribute");
    }
    def n as int init 0;
    def stated as string init strings.trim(attrOf($e, "n"));
    if (len($stated) > 0) {
        $n = convert.toInt($stated);
    }
    def freqs as map of string to float init {};
    for (def c in xml.children($e)) {
        if (isTag($c, "frequency")) {
            def allele as string init strings.trim(attrOf($c, "allele"));
            if (len($allele) == 0) {
                fail("a frequency carries no allele attribute" + where($marker, $population));
            }
            if (maps.has($freqs, $allele)) {
                fail("duplicate allele '" + $allele + "'" + where($marker, $population));
            }
            def published as string init strings.trim(xml.text($c));
            if (len($published) == 0) {
                fail("allele '" + $allele + "' carries no frequency" +
                    where($marker, $population));
            }
            $freqs[$allele] = convert.toFloat($published);
        }
    }
    return Origin{population: $population, n: $n, freqs: $freqs};
}

# readMarker turns one `<marker>` into its locus name and every population block
# beneath it. A locus typed in no population is kept with no origins; the fold
# in `parse` then contributes nothing for it, which is how the export spells a
# locus it has no data for.
func readMarker(e as xml.Value) {
    def name as string init markerName($e);
    if (len($name) == 0) {
        fail("a marker element carries no <name> child");
    }
    def origins as list of Origin init [];
    for (def c in xml.children($e)) {
        if (isTag($c, "origin")) {
            $origins[] = readOrigin($c, $name);
        }
    }
    return Marker{name: $name, origins: $origins};
}

# readMarkers recurses depth-first and returns every locus found beneath `e`, so
# the reader does not depend on how deeply the export nests its markers.
#
# It returns its findings rather than accumulating into a table passed down the
# recursion. Threading the table through would copy every locus read so far on
# each call, which is quadratic in the size of the document.
func readMarkers(e as xml.Value) {
    def out as list of Marker init [];
    if (isTag($e, "marker")) {
        $out[] = readMarker($e);
        return $out;
    }
    for (def c in xml.children($e)) {
        if (xml.typeOf($c) == "element") {
            for (def m in readMarkers($c)) {
                $out[] = $m;
            }
        }
    }
    return $out;
}

# sumsFor totals every locus of one already-extracted population. Both public sum
# accessors go through it, so they cannot drift apart.
func sumsFor(p as Population) {
    def out as map of string to float init {};
    for (def locus in $p.frequencies) {
        def row as map of string to float init $p.frequencies[$locus];
        def total as float init 0.0;
        for (def a in $row) {
            $total = $total + $row[$a];
        }
        $out[$locus] = $total;
    }
    return $out;
}

# --- public surface ---------------------------------------------------------

/**
 * Parse a STRidER XML allele-frequency export.
 *
 * Tag and attribute names match in any case, and `<marker>` elements are
 * found at any depth. A marker with no `<origin>` contributes nothing.
 * Frequencies are kept as published. A document with no markers is rejected:
 * it is almost always the wrong file.
 * @param doc {string} XML document text
 * @return {Table} every population the export describes
 * @throws {Error} kind "strider" on a document with no markers or no
 *   population data, a marker with no `<name>`, an origin with no `name`, a
 *   frequency with no `allele` or no value, or a duplicated allele or locus;
 *   kind "runtime" on malformed XML or a non-numeric frequency or `n`
 */
export func parse(doc as string) {
    def root as xml.Value init xml.decode($doc);
    def found as list of Marker init readMarkers($root);
    if (len($found) == 0) {
        fail("no <marker> elements found in the document");
    }
    def out as Table init Table{
        created: strings.trim(attrOf($root, "created_timestamp")),
        validity: strings.trim(attrOf($root, "validity")),
        byPopulation: {}
    };
    for (def m in $found) {
        for (def o in $m.origins) {
            if (not maps.has($out.byPopulation, $o.population)) {
                $out.byPopulation[$o.population] = Population{
                    name: $o.population,
                    counts: {},
                    frequencies: {}
                };
            }
            def p as Population init $out.byPopulation[$o.population];
            if (maps.has($p.frequencies, $m.name)) {
                fail("duplicate locus '" + $m.name + "' for population '" +
                    $o.population + "'");
            }
            $p.frequencies[$m.name] = $o.freqs;
            $p.counts[$m.name] = $o.n;
            $out.byPopulation[$o.population] = $p;
        }
    }
    if (len(maps.keys($out.byPopulation)) == 0) {
        fail("the document's markers carry no population data");
    }
    return $out;
}

/**
 * The population labels the other calls accept, in order of first mention.
 * @param t {Table} parsed export
 * @return {list of string} population labels
 */
export func populations(t as Table) {
    return maps.keys($t.byPopulation);
}

# find returns one population's row, failing with the label the caller passed.
func find(t as Table, population as string) {
    if (not maps.has($t.byPopulation, $population)) {
        fail("no such population in the export: '" + $population + "'");
    }
    return $t.byPopulation[$population];
}

/**
 * The loci typed in one population, in document order. The set differs
 * between populations: a country with few samples carries fewer loci than the
 * whole database.
 * @param t {Table} parsed export
 * @param population {string} population label
 * @return {list of string} locus names
 * @throws {Error} kind "strider" if the export has no such population
 */
export func loci(t as Table, population as string) {
    def p as Population init find($t, $population);
    return maps.keys($p.frequencies);
}

/**
 * The number of individuals typed at one locus in one population. 0 means the
 * export stated no `N`, so no 5/(2N) floor is available for that locus.
 * @param t {Table} parsed export
 * @param population {string} population label
 * @param locus {string} locus name
 * @return {int} sample size N
 * @throws {Error} kind "strider" if the export has no such population or locus
 */
export func sampleSize(t as Table, population as string, locus as string) {
    def p as Population init find($t, $population);
    if (not maps.has($p.counts, $locus)) {
        fail("population '" + $population + "' has no locus '" + $locus + "'");
    }
    return $p.counts[$locus];
}

/**
 * Sum the published frequencies at one locus in one population. A sound table
 * sums to ~1.0; a sum far off is the usual sign of a truncated download or a
 * percentage-scaled table. Each call copies the whole `Table`, so to check
 * many loci use `frequencySums` or `allFrequencySums`.
 * @param t {Table} parsed export
 * @param population {string} population label
 * @param locus {string} locus name
 * @return {float} sum of the locus's published allele frequencies
 * @throws {Error} kind "strider" if the export has no such population or locus
 */
export func frequencySum(t as Table, population as string, locus as string) {
    def p as Population init find($t, $population);
    if (not maps.has($p.frequencies, $locus)) {
        fail("population '" + $population + "' has no locus '" + $locus + "'");
    }
    def total as float init 0.0;
    def row as map of string to float init $p.frequencies[$locus];
    for (def a in $row) {
        $total = $total + $row[$a];
    }
    return $total;
}

/**
 * Sum the published frequencies at every locus in one population: the bulk
 * form of `frequencySum`, and the check to run after `parse`. A `Table` is a
 * value, so every accessor call copies the whole export (33 populations in a
 * real download); this pays the copy once instead of once per locus.
 * @param t {Table} parsed export
 * @param population {string} population label
 * @return {map of string to float} locus -> sum of its published frequencies,
 *   in document order; each should be ~1.0
 * @throws {Error} kind "strider" if the export has no such population
 */
export func frequencySums(t as Table, population as string) {
    def p as Population init find($t, $population);
    return sumsFor($p);
}

/**
 * Sum every locus in every population, copying the `Table` once. Over a real
 * download this is about twice as fast as looping `frequencySums` over
 * `populations` and about 30x faster than looping `frequencySum`. Use it to
 * audit a fresh download.
 * @param t {Table} parsed export
 * @return {map of string to map of string to float} population -> locus -> sum
 *   of its published frequencies, both in document order; each should be ~1.0
 */
export func allFrequencySums(t as Table) {
    def out as map of string to map of string to float init {};
    for (def population in $t.byPopulation) {
        def p as Population init $t.byPopulation[$population];
        $out[$population] = sumsFor($p);
    }
    return $out;
}

/**
 * Convert one population of a parsed export into a `forensics.FrequencyDb`.
 * Frequencies and `N` cross over as published; `forensics.alleleFrequency`
 * applies the 5/(2N) floor on read. The label becomes `FrequencyDb.name`, so a
 * result records which dataset produced it.
 * @param t {Table} parsed export
 * @param population {string} population label to convert
 * @param name {string} dataset label, or "" for the population's own label
 * @return {forensics.FrequencyDb} the converted population
 * @throws {Error} kind "strider" if the export has no such population; kind
 *   "forensicgenetics" if a frequency is outside (0, 1] or a locus sums above
 *   `forensics.MAX_FREQUENCY_SUM` (1.05)
 */
export func toFrequencyDb(t as Table, population as string, name as string) {
    def p as Population init find($t, $population);
    def label as string init $name;
    if (len($label) == 0) {
        $label = $p.name;
    }
    def out as forensics.FrequencyDb init forensics.db($label);
    for (def locus in $p.frequencies) {
        $out = forensics.withLocus($out, $locus, $p.counts[$locus], $p.frequencies[$locus]);
    }
    return $out;
}

/**
 * `parse` then `toFrequencyDb`. Use the two steps instead to check the sums
 * with `frequencySums` before converting, or to take more than one population
 * from a document without parsing it again.
 * @param doc {string} XML document text
 * @param population {string} population label to convert
 * @param name {string} dataset label, or "" for the population's own label
 * @return {forensics.FrequencyDb} the converted population
 * @throws {Error} kind "strider" or "runtime" when `parse` fails, kind
 *   "strider" if there is no such population, kind "forensicgenetics" if a
 *   locus fails `FrequencyDb` validation
 */
export func load(doc as string, population as string, name as string) {
    return toFrequencyDb(parse($doc), $population, $name);
}
