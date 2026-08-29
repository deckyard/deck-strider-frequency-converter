# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * STRidER STR allele-frequency table parsing.
 *
 * Reads a published autosomal-STR allele-frequency export in XML and returns
 * plain per-population, per-locus allele -> frequency maps plus each locus's
 * sample size `N`. It deliberately returns *data*, not a
 * `forensics.FrequencyDb`: keeping this module free of the core's structs
 * allows `forensicgenetics.j` to import it without an import cycle.
 *
 * The reader targets the layout STRidER actually publishes at
 * <https://strider.online/frequencies/xml>, which is **locus-major with the
 * populations nested inside each locus**:
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
 * One export therefore carries **many populations at once** - the whole
 * database, each continent, and each contributing country - so `parse` reads
 * them all and the population is chosen afterwards, by name, at the point a
 * `FrequencyDb` is built. `Table` is stored population-major, which is the
 * orientation every consumer wants, so the fold happens once during the parse
 * rather than at each lookup.
 *
 * Not every locus is typed in every population: the number of `<origin>`
 * blocks varies from locus to locus, and a locus with none contributes
 * nothing. So `loci` is asked per population rather than of the table.
 *
 * `parse` returns the frequencies exactly as published - no floor, no
 * renormalisation. `toFrequencyDb` converts one population into the deck's
 * generic `forensics.FrequencyDb`, after which `forensics.alleleFrequency`
 * applies the 5/2N floor on read.
 * @module strider
 * @see https://strider.online/ - the ENFSI STRidER reference database
 * @example
 * import "@mplx/strider/" as strider;
 * def t as strider.Table init strider.parse(fs.readString("strider.xml"));
 * strider.populations($t);                     # ["Entire Database", ...]
 * strider.frequencySum($t, "AUSTRIA", "TH01"); # should be ~1.0
 *
 * # ... or straight to the generic database the estimators take:
 * def db as forensics.FrequencyDb init strider.load($doc, "AUSTRIA", "STRidER AT");
 */
use xml;
use strings;
use maps;
use convert;

import "@jennifer/forensicgenetics/" as forensics;

/**
 * One population's frequencies, as published for that population alone.
 * @field name {string} the population label, verbatim from the `origin` element
 * @field counts {map of string to int} locus -> number of individuals typed (N), 0 if unstated
 * @field frequencies {map of string to map of string to float} locus -> allele label ->
 *   published frequency
 */
export def struct Population {
    name as string,
    counts as map of string to int,
    frequencies as map of string to map of string to float
};

/**
 * A parsed export: every population the document carries, keyed by name.
 * @field created {string} the document's `created_timestamp`, "" if it carried none
 * @field validity {string} the document's `validity` date, "" if it carried none
 * @field byPopulation {map of string to Population} population label -> its frequencies,
 *   in the order the document first mentions each
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
 * Reads every population the document carries and returns them population-major,
 * with frequencies exactly as published. A document with no `<marker>` elements
 * is an error - that is almost always the wrong file rather than an empty
 * export.
 * @param doc {string} the XML document text
 * @return {Table} every population the export describes
 * @throws {Error} kind "strider" on malformed XML, a marker with no name, an
 *   origin with no name, a duplicated allele or locus, an unparseable
 *   frequency, or a document with no markers
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
 * The populations an export carries, in the order it first mentions each.
 *
 * A STRidER export bundles the whole database, each continent and each
 * contributing country, so this is the list of labels the other calls accept.
 * @param t {Table} the parsed export
 * @return {list of string} the population labels
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
 * The loci typed in one population, in document order.
 *
 * Asked per population rather than of the export as a whole, because the set
 * differs: a country contributing few samples carries fewer loci than the whole
 * database does.
 * @param t {Table} the parsed export
 * @param population {string} the population label
 * @return {list of string} the locus names
 * @throws {Error} kind "strider" if the export has no such population
 */
export func loci(t as Table, population as string) {
    def p as Population init find($t, $population);
    return maps.keys($p.frequencies);
}

/**
 * The number of individuals typed at one locus in one population.
 *
 * `0` means the export stated no `N` for that cell, and therefore that no
 * `5/(2N)` frequency floor is available for it.
 * @param t {Table} the parsed export
 * @param population {string} the population label
 * @param locus {string} the locus name
 * @return {int} the sample size N
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
 * Sum the published frequencies at one locus in one population.
 *
 * A well-formed table sums to ~1.0 per locus; a sum far off that is the usual
 * sign of a truncated download or a percentage-scaled table, so this is the
 * cheap sanity check to run after `parse`.
 * @param t {Table} the parsed export
 * @param population {string} the population label
 * @param locus {string} the locus name
 * @return {float} the sum of that locus's published allele frequencies
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
 * Sum the published frequencies at every locus in one population.
 *
 * The bulk form of `frequencySum`, and the one to use for the check that should
 * follow every parse. A `Table` is a value, so passing it to an accessor copies
 * the whole export - all 33 populations of a real download. Calling
 * `frequencySum` once per locus therefore pays that copy once per locus, which
 * costs far more than the parse it is checking. This pays it once for the whole
 * population instead.
 * @param t {Table} the parsed export
 * @param population {string} the population label
 * @return {map of string to float} locus -> the sum of its published frequencies,
 *   in document order; each should be ~1.0
 * @throws {Error} kind "strider" if the export has no such population
 */
export func frequencySums(t as Table, population as string) {
    def p as Population init find($t, $population);
    return sumsFor($p);
}

/**
 * Sum every locus in every population, in one pass over the export.
 *
 * The whole-export form of `frequencySums`. Looping `frequencySums` over
 * `populations` copies the Table once per population; this copies it once
 * in total, which measures about twice as fast over a real download - and about
 * 30x faster than looping the single-locus `frequencySum`. Use it when auditing
 * a fresh download end to end; use `frequencySums` when you care about the one
 * population you are going to compute with.
 * @param t {Table} the parsed export
 * @return {map of string to map of string to float} population -> locus -> the sum
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
 * Convert one population out of a parsed export into the generic database.
 *
 * This is the one direction the dependency runs: the reader knows the generic
 * type, the generic type knows nothing about STRidER. Frequencies cross over
 * exactly as published - `forensics.alleleFrequency` applies the 5/2N floor on
 * read, so the table keeps its original numbers.
 *
 * Which population a calculation used is part of the result, so `name` labels
 * the dataset. Pass `""` to fall back to the population's own label.
 * @param t {Table} the parsed export
 * @param population {string} the population label to convert
 * @param name {string} the dataset label, or "" to use the population's own
 * @return {forensics.FrequencyDb} the generic database
 * @throws {Error} kind "strider" if the export has no such population, or kind
 *   "forensicgenetics" if a locus fails the generic type's validation - a
 *   frequency outside (0, 1], or a locus summing far above 1.0
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
 * Parse an export and convert one population straight into a generic database.
 *
 * `parse` then `toFrequencyDb` in one call. Use the two steps separately when
 * you want to run `frequencySum` over the parsed export first, which is the
 * check that catches a misread download before it reaches a calculation - and
 * when you want more than one population out of a single document, since a
 * STRidER export carries them all and re-parsing it per population is wasteful.
 * @param doc {string} the XML document text
 * @param population {string} the population label to convert
 * @param name {string} the dataset label, or "" to use the population's own
 * @return {forensics.FrequencyDb} the generic database
 * @throws {Error} kind "strider" if the document does not parse or has no such
 *   population, or kind "forensicgenetics" if a locus fails validation
 */
export func load(doc as string, population as string, name as string) {
    return toFrequencyDb(parse($doc), $population, $name);
}
