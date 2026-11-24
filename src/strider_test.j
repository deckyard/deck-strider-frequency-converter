# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

# White-box test overlay for strider.j. Run with `jennifer test strider_test.j`.
#
# The reader targets the layout STRidER actually publishes: locus-major, with
# every population nested inside each locus as an <origin>. These cases are that
# shape, cut down to two or three alleles so the arithmetic stays checkable by
# eye.
use testing;
use math;
use meta;
use fs;
use strings;
use time;
use convert;

def const TOL as float init 0.000000001;
# The bundled fixture publishes six significant figures, exactly as the real
# export does, so a locus sums to 1.0 only to within that rounding.
def const SUM_TOL as float init 0.00001;

# testdata/frequencies.xml, inline: a consumer runs this overlay from its own
# tree, where testdata/ does not exist. testSampleMatchesTestdata keeps the two
# copies equal.
def const SAMPLE as string init '<?xml version="1.0" encoding="UTF-8"?>
<!--
  SYNTHETIC illustrative allele frequencies - NOT real population data.
  Every number here is made up; only the *shape* is real, mirroring the
  STRidER export at https://strider.online/frequencies/xml so the reader
  is exercised against the layout it actually has to parse.
  Download a real table from STRidER before computing anything you intend
  to rely on - it is not redistributable, see docs/limitations.md.
-->
<frequencies created_timestamp="2026-01-15T09:00:00+01:00" validity="2026-01-01T00:00:00+01:00">
  <marker>
    <name>D3S1358</name>
    <alleles>12, 13, 14, 15, 16, 17, 18, 19</alleles>
    <origin name="Entire Database" n="17479">
      <frequency allele="12">1.35127e-01</frequency>
      <frequency allele="13">7.82777e-02</frequency>
      <frequency allele="14">2.07941e-01</frequency>
      <frequency allele="15">1.45961e-01</frequency>
      <frequency allele="16">1.95766e-02</frequency>
      <frequency allele="17">2.11882e-01</frequency>
      <frequency allele="18">3.57246e-02</frequency>
      <frequency allele="19">1.65510e-01</frequency>
    </origin>
    <origin name="Europe" n="9001">
      <frequency allele="12">1.33721e-02</frequency>
      <frequency allele="13">2.41649e-01</frequency>
      <frequency allele="14">1.51585e-01</frequency>
      <frequency allele="15">4.52012e-02</frequency>
      <frequency allele="16">1.12787e-01</frequency>
      <frequency allele="17">1.41475e-01</frequency>
      <frequency allele="18">2.48346e-01</frequency>
      <frequency allele="19">4.55853e-02</frequency>
    </origin>
    <origin name="AUSTRIA" n="1223">
      <frequency allele="12">1.17129e-01</frequency>
      <frequency allele="13">1.78756e-01</frequency>
      <frequency allele="14">1.86410e-01</frequency>
      <frequency allele="15">1.45612e-01</frequency>
      <frequency allele="16">1.53580e-01</frequency>
      <frequency allele="17">7.90736e-03</frequency>
      <frequency allele="18">1.53719e-01</frequency>
      <frequency allele="19">5.68861e-02</frequency>
    </origin>
  </marker>
  <marker>
    <name>vWA</name>
    <alleles>14, 15, 16, 17, 18, 19, 20</alleles>
    <origin name="Entire Database" n="17479">
      <frequency allele="14">8.32570e-02</frequency>
      <frequency allele="15">1.07872e-01</frequency>
      <frequency allele="16">2.34485e-01</frequency>
      <frequency allele="17">1.12517e-01</frequency>
      <frequency allele="18">2.17498e-01</frequency>
      <frequency allele="19">9.17665e-02</frequency>
      <frequency allele="20">1.52605e-01</frequency>
    </origin>
    <origin name="Europe" n="9001">
      <frequency allele="14">1.58198e-01</frequency>
      <frequency allele="15">1.00196e-01</frequency>
      <frequency allele="16">2.35203e-01</frequency>
      <frequency allele="17">1.96570e-01</frequency>
      <frequency allele="18">2.73959e-01</frequency>
      <frequency allele="19">9.66733e-03</frequency>
      <frequency allele="20">2.62057e-02</frequency>
    </origin>
    <origin name="AUSTRIA" n="1223">
      <frequency allele="14">3.52918e-01</frequency>
      <frequency allele="15">4.04617e-02</frequency>
      <frequency allele="16">1.49354e-01</frequency>
      <frequency allele="17">3.73204e-02</frequency>
      <frequency allele="18">1.83368e-01</frequency>
      <frequency allele="19">2.72659e-02</frequency>
      <frequency allele="20">2.09311e-01</frequency>
    </origin>
  </marker>
  <marker>
    <name>FGA</name>
    <alleles>19, 20, 21, 22, 23, 24, 25, 26</alleles>
    <origin name="Entire Database" n="17479">
      <frequency allele="19">1.57160e-01</frequency>
      <frequency allele="20">1.90240e-01</frequency>
      <frequency allele="21">1.75941e-01</frequency>
      <frequency allele="22">1.39787e-02</frequency>
      <frequency allele="23">2.31257e-02</frequency>
      <frequency allele="24">1.62314e-01</frequency>
      <frequency allele="25">2.64044e-02</frequency>
      <frequency allele="26">2.50835e-01</frequency>
    </origin>
    <origin name="Europe" n="9001">
      <frequency allele="19">1.80250e-01</frequency>
      <frequency allele="20">8.13102e-02</frequency>
      <frequency allele="21">1.16739e-01</frequency>
      <frequency allele="22">7.57361e-02</frequency>
      <frequency allele="23">1.72037e-01</frequency>
      <frequency allele="24">1.37494e-01</frequency>
      <frequency allele="25">1.42837e-02</frequency>
      <frequency allele="26">2.22149e-01</frequency>
    </origin>
    <origin name="AUSTRIA" n="1223">
      <frequency allele="19">1.19042e-01</frequency>
      <frequency allele="20">2.51484e-01</frequency>
      <frequency allele="21">2.37992e-01</frequency>
      <frequency allele="22">6.69843e-02</frequency>
      <frequency allele="23">6.83519e-02</frequency>
      <frequency allele="24">7.98879e-02</frequency>
      <frequency allele="25">1.63847e-01</frequency>
      <frequency allele="26">1.24098e-02</frequency>
    </origin>
  </marker>
  <marker>
    <name>TH01</name>
    <alleles>5, 6, 7, 8, 9, 9.3, 10</alleles>
    <origin name="Entire Database" n="17479">
      <frequency allele="5">2.10719e-01</frequency>
      <frequency allele="6">5.71222e-02</frequency>
      <frequency allele="7">1.10885e-01</frequency>
      <frequency allele="8">9.34080e-02</frequency>
      <frequency allele="9">2.55804e-02</frequency>
      <frequency allele="9.3">1.82624e-01</frequency>
      <frequency allele="10">3.19662e-01</frequency>
    </origin>
    <origin name="AUSTRIA" n="1223">
      <frequency allele="5">2.59646e-01</frequency>
      <frequency allele="6">8.33473e-02</frequency>
      <frequency allele="7">2.67995e-01</frequency>
      <frequency allele="8">1.35463e-01</frequency>
      <frequency allele="9">6.49725e-02</frequency>
      <frequency allele="9.3">5.56788e-02</frequency>
      <frequency allele="10">1.32897e-01</frequency>
    </origin>
  </marker>
  <marker>
    <name>D22S1045</name>
    <alleles>11, 12, 13, 14, 15, 16, 17</alleles>
  </marker>
</frequencies>';

func near(actual as float, expected as float) {
    testing.assertTrue(math.abs($actual - $expected) < TOL);
}

func nearSum(actual as float, expected as float) {
    testing.assertTrue(math.abs($actual - $expected) < SUM_TOL);
}

# doc wraps a body in the export's root element, so each case shows only the
# markers it is about.
func doc(body as string) {
    return '<frequencies created_timestamp="2026-01-15T09:00:00+01:00" ' +
        'validity="2026-01-01T00:00:00+01:00">' + $body + '</frequencies>';
}

# cell builds one origin of locus A in population P with the given `n` attribute
# text ("" for none) and frequency elements.
func cell(n as string, frequencies as string) {
    def stated as string init "";
    if (len($n) > 0) {
        $stated = ' n="' + $n + '"';
    }
    return doc('<marker><name>A</name><origin name="P"' + $stated + '>' + $frequencies +
        '</origin></marker>');
}

func freq(allele as string, value as string) {
    return '<frequency allele="' + $allele + '">' + $value + '</frequency>';
}

# synthetic builds `loci` markers L0.. for population P, each with `alleles`
# alleles of frequency 0.01, wrapped in `depth` levels of <a>.
func synthetic(loci as int, alleles as int, depth as int) {
    def row as string init "";
    for (def a in 0..$alleles) {
        $row = $row + freq(convert.toString($a), "1.0e-2");
    }
    def body as string init "";
    for (def i in 0..$loci) {
        $body = $body + '<marker><name>L' + convert.toString($i) + '</name>' +
            '<origin name="P" n="10">' + $row + '</origin></marker>';
    }
    return doc(strings.replicate("<a>", $depth) + $body + strings.replicate("</a>", $depth));
}

func elapsedMs(startedAt as time.Time, endedAt as time.Time) {
    return (time.unixNanos($endedAt) - time.unixNanos($startedAt)) / 1000000.0;
}

# messageOf returns the message `parse(d)` throws, or "" if it does not throw.
func messageOf(d as string) {
    try {
        parse($d);
    } catch (e) {
        return $e.message;
    }
    return "";
}

# --- the published shape ----------------------------------------------------

func testCanonicalExportParses() {
    def t as Table init parse(doc('<marker><name>D3S1358</name>' +
        '<alleles>15, 16</alleles>' +
        '<origin name="AUSTRIA" n="1223">' +
        '<frequency allele="15">2.50000e-1</frequency>' +
        '<frequency allele="16">7.50000e-1</frequency>' +
        '</origin></marker>'));
    testing.assertEqual(populations($t), ["AUSTRIA"]);
    testing.assertEqual(loci($t, "AUSTRIA"), ["D3S1358"]);
    testing.assertEqual(sampleSize($t, "AUSTRIA", "D3S1358"), 1223);
    near($t.byPopulation["AUSTRIA"].frequencies["D3S1358"]["15"], 0.25);
    near(frequencySum($t, "AUSTRIA", "D3S1358"), 1.0);
}

func testOneExportCarriesManyPopulations() {
    # The property the whole API is shaped around: a single download holds the
    # whole database, each continent and each country, so the population is
    # chosen after the parse rather than before it.
    def t as Table init parse(doc('<marker><name>TH01</name>' +
        '<origin name="Entire Database" n="17479">' +
        '<frequency allele="6">4.00000e-1</frequency>' +
        '<frequency allele="9.3">6.00000e-1</frequency></origin>' +
        '<origin name="AUSTRIA" n="1223">' +
        '<frequency allele="6">3.00000e-1</frequency>' +
        '<frequency allele="9.3">7.00000e-1</frequency></origin></marker>'));
    testing.assertEqual(populations($t), ["Entire Database", "AUSTRIA"]);
    near($t.byPopulation["Entire Database"].frequencies["TH01"]["6"], 0.4);
    near($t.byPopulation["AUSTRIA"].frequencies["TH01"]["6"], 0.3);
    testing.assertEqual(sampleSize($t, "Entire Database", "TH01"), 17479);
    testing.assertEqual(sampleSize($t, "AUSTRIA", "TH01"), 1223);
}

func testLocusNameComesFromTheNameChild() {
    # STRidER states the locus name as an element, not an attribute - the one
    # detail that makes an attribute-first reader find nothing.
    def t as Table init parse(doc('<marker><name>D21S11</name>' +
        '<origin name="A" n="10"><frequency allele="28">1.00000e0</frequency>' +
        '</origin></marker>'));
    testing.assertEqual(loci($t, "A"), ["D21S11"]);
}

func testLociDifferPerPopulation() {
    # Not every locus is typed in every population, which is why `loci` is asked
    # per population rather than of the export.
    def t as Table init parse(doc('<marker><name>A</name>' +
        '<origin name="Wide" n="10"><frequency allele="1">1.00000e0</frequency></origin>' +
        '<origin name="Narrow" n="10"><frequency allele="1">1.00000e0</frequency></origin>' +
        '</marker><marker><name>B</name>' +
        '<origin name="Wide" n="10"><frequency allele="1">1.00000e0</frequency></origin>' +
        '</marker>'));
    testing.assertEqual(loci($t, "Wide"), ["A", "B"]);
    testing.assertEqual(loci($t, "Narrow"), ["A"]);
}

func testMarkerWithNoOriginsContributesNothing() {
    # The real export names a locus it has typed in no population; it must be
    # skipped rather than rejected.
    def t as Table init parse(doc('<marker><name>A</name>' +
        '<origin name="P" n="10"><frequency allele="1">1.00000e0</frequency></origin>' +
        '</marker><marker><name>D22S1045</name><alleles>11, 12</alleles></marker>'));
    testing.assertEqual(loci($t, "P"), ["A"]);
}

func testDocumentMetadataIsCaptured() {
    def t as Table init parse(doc('<marker><name>A</name>' +
        '<origin name="P" n="10"><frequency allele="1">1.00000e0</frequency></origin>' +
        '</marker>'));
    testing.assertEqual($t.created, "2026-01-15T09:00:00+01:00");
    testing.assertEqual($t.validity, "2026-01-01T00:00:00+01:00");
}

func testMarkersAreFoundAtAnyDepth() {
    # The walk keys on the marker tag, not on a fixed path from the root.
    def t as Table init parse(doc('<meta><note>ignored</note></meta><group><set>' +
        '<marker><name>A</name>' +
        '<origin name="P" n="10"><frequency allele="1">1.00000e0</frequency></origin>' +
        '</marker></set></group>'));
    testing.assertEqual(loci($t, "P"), ["A"]);
}

func testMarkerOrderIsDocumentOrderAtAnyDepth() {
    # Pre-order: a marker nested deeper but earlier in the text comes first.
    def t as Table init parse(doc('<g><h><marker><name>A</name>' +
        '<origin name="P" n="1"><frequency allele="1">1.0e0</frequency></origin></marker></h>' +
        '<marker><name>B</name>' +
        '<origin name="P" n="1"><frequency allele="1">1.0e0</frequency></origin></marker></g>' +
        '<marker><name>C</name>' +
        '<origin name="P" n="1"><frequency allele="1">1.0e0</frequency></origin></marker>' +
        '<g><g><g><marker><name>D</name>' +
        '<origin name="P" n="1"><frequency allele="1">1.0e0</frequency></origin></marker>' +
        '</g></g></g>'));
    testing.assertEqual(loci($t, "P"), ["A", "B", "C", "D"]);
}

func testDeepNestingCostsNoMoreThanFlat() {
    # 990 wrapper levels (xml.decode allows 1000; 64 on jennifer-tiny, so 50
    # there). The old recursive walk copied every Marker once per enclosing
    # level: 20 loci took ~25x the flat parse. The iterative walk visits each
    # element once, so depth adds ~990 handles.
    def levels as int init 990;
    if (meta.BUILD == "tinygo") {
        $levels = 50;
    }
    def flat as string init synthetic(20, 10, 0);
    def deep as string init synthetic(20, 10, $levels);
    def t0 as time.Time init time.now();
    def a as Table init parse($flat);
    def t1 as time.Time init time.now();
    def b as Table init parse($deep);
    def t2 as time.Time init time.now();
    testing.assertEqual($b.byPopulation, $a.byPopulation);
    testing.assertTrue(elapsedMs($t1, $t2) < 4.0 * elapsedMs($t0, $t1) + 30.0);
}

func testScientificNotationIsRead() {
    # Every frequency in the real export is written this way.
    def t as Table init parse(doc('<marker><name>A</name>' +
        '<origin name="P" n="10">' +
        '<frequency allele="1">1.01722e-1</frequency>' +
        '<frequency allele="2">8.98278e-1</frequency></origin></marker>'));
    near($t.byPopulation["P"].frequencies["A"]["1"], 0.101722);
    near(frequencySum($t, "P", "A"), 1.0);
}

func testMicrovariantAllelesKeepTheirLabel() {
    # "9.3" must stay a distinct key from "9" - it is a real, common allele.
    def t as Table init parse(doc('<marker><name>TH01</name>' +
        '<origin name="P" n="100">' +
        '<frequency allele="9">4.00000e-1</frequency>' +
        '<frequency allele="9.3">6.00000e-1</frequency></origin></marker>'));
    testing.assertEqual(len(maps.keys($t.byPopulation["P"].frequencies["TH01"])), 2);
    near($t.byPopulation["P"].frequencies["TH01"]["9"], 0.4);
    near($t.byPopulation["P"].frequencies["TH01"]["9.3"], 0.6);
}

func testTagsAndAttributesFoldCase() {
    def t as Table init parse(doc('<Marker><Name>A</Name>' +
        '<Origin NAME="P" N="300"><Frequency Allele="1">1.00000e0</Frequency>' +
        '</Origin></Marker>'));
    testing.assertEqual(sampleSize($t, "P", "A"), 300);
    near($t.byPopulation["P"].frequencies["A"]["1"], 1.0);
}

func testPlainNumberSpellingsAreRead() {
    # Each value is its literal: 5E-1 = 0.5, 2.5e+0 = 2.5 (rejected later, on
    # conversion, not here), 1 = 1.0; n "0042" is 42.
    def t as Table init parse(cell(
        "0042",
        freq("1", "5E-1") + freq("2", "2.5e+0") +
            freq("3", "1") + freq("4", "1.35127e-01")));
    def row as map of string to float init $t.byPopulation["P"].frequencies["A"];
    testing.assertEqual($row["1"], 0.5);
    testing.assertEqual($row["2"], 2.5);
    testing.assertEqual($row["3"], 1.0);
    testing.assertEqual($row["4"], 0.135127);
    testing.assertEqual(sampleSize($t, "P", "A"), 42);
}

func testNonNumericFrequencyIsARuntimeError() {
    # convert.toFloat alone accepted the hex, underscore and signed forms (0x1p-1
    # read as 0.5); the frequency must be plain unsigned decimal.
    for (def v in [
        "abc",
        "NaN",
        "Inf",
        "0x1p-1",
        "0.5_0",
        "+0.5",
        "-0.5",
        "-0.0",
        "0,5",
        ".5",
        "5.",
        "1e",
        "0.5 0.5"
    ]) {
        testing.assertThrowsArgs("parse", [cell("10", freq("1", $v))], "runtime");
    }
    # text in a child element was dropped by xml.text: "0.5<b>9</b>" read as 0.5
    testing.assertThrowsArgs("parse", [cell("10", freq("1", "0.5<b>9</b>"))], "runtime");
    # a comment is not content: "5<!--x-->e-1" is the text "5e-1"
    near(parse(cell("10", freq("1", "5<!--x-->e-1"))).byPopulation["P"].frequencies["A"]["1"], 0.5);
}

func testNonNumericSampleSizeIsARuntimeError() {
    # "+500" used to read as 500 and "-5" as -5; n is unsigned decimal digits.
    for (def n in ["abc", "+500", "-5", "500.0", "1e3", "0x10", "1_000", "5 0"]) {
        testing.assertThrowsArgs("parse", [cell($n, freq("1", "1.0e0"))], "runtime");
    }
}

func testNumericallyEqualAllelesAreDuplicates() {
    # "15" and "15.0" are one repeat count; read as two alleles they split its
    # frequency and a genotype written either way finds only half of it.
    for (def pair in [["15", "15.0"], ["9.3", "9.30"], ["9", "09"], ["10", "10.000"]]) {
        def d as string init cell("10", freq($pair[0], "5.0e-1") + freq($pair[1], "5.0e-1"));
        testing.assertThrowsArgs("parse", [$d], "strider");
        def msg as string init messageOf($d);
        testing.assertContains($msg, "'" + $pair[0] + "'");
        testing.assertContains($msg, "'" + $pair[1] + "'");
    }
    # distinct values, and non-numeric labels, are compared as text
    def t as Table init parse(cell(
        "10",
        freq("9", "2.0e-1") + freq("9.3", "2.0e-1") +
            freq("90", "2.0e-1") + freq("OL", "2.0e-1") + freq("ol", "2.0e-1")));
    testing.assertEqual(
        maps.keys($t.byPopulation["P"].frequencies["A"]),
        ["9", "9.3", "90", "OL", "ol"]);
}

func testLocusNamesDifferingInCaseAreDuplicates() {
    def d as string init doc('<marker><name>TH01</name>' +
        '<origin name="P" n="1"><frequency allele="1">1.0e0</frequency></origin></marker>' +
        '<marker><name>th01</name>' +
        '<origin name="P" n="1"><frequency allele="2">1.0e0</frequency></origin></marker>');
    testing.assertThrowsArgs("parse", [$d], "strider");
    testing.assertContains(messageOf($d), "'TH01'");
    # one spelling per population is fine, and is kept as written
    def t as Table init parse(doc('<marker><name>TH01</name>' +
        '<origin name="P" n="1"><frequency allele="1">1.0e0</frequency></origin></marker>' +
        '<marker><name>th01</name>' +
        '<origin name="Q" n="1"><frequency allele="1">1.0e0</frequency></origin></marker>'));
    testing.assertEqual(loci($t, "P"), ["TH01"]);
    testing.assertEqual(loci($t, "Q"), ["th01"]);
}

func testMissingSampleSizeBecomesZero() {
    def t as Table init parse(doc('<marker><name>A</name>' +
        '<origin name="P"><frequency allele="1">1.00000e0</frequency></origin></marker>'));
    testing.assertEqual(sampleSize($t, "P", "A"), 0);
}

# --- the bundled sample -----------------------------------------------------

func testBundledSampleExportParses() {
    def t as Table init parse(SAMPLE);
    testing.assertEqual(populations($t), ["Entire Database", "Europe", "AUSTRIA"]);
    # Europe is deliberately missing TH01, the whole database is not.
    testing.assertEqual(len(loci($t, "Entire Database")), 4);
    testing.assertEqual(len(loci($t, "Europe")), 3);
    testing.assertContains(loci($t, "Entire Database"), "TH01");
    testing.assertEqual(sampleSize($t, "AUSTRIA", "TH01"), 1223);
    for (def p in populations($t)) {
        for (def locus in loci($t, $p)) {
            # A well-formed table sums to 1 at every locus - the cheap check.
            nearSum(frequencySum($t, $p, $locus), 1.0);
        }
    }
}

func testFrequencySumsMatchesThePerLocusForm() {
    def t as Table init parse(doc('<marker><name>A</name>' +
        '<origin name="P" n="10">' +
        '<frequency allele="1">2.50000e-1</frequency>' +
        '<frequency allele="2">7.50000e-1</frequency></origin></marker>' +
        '<marker><name>B</name><origin name="P" n="10">' +
        '<frequency allele="1">1.00000e0</frequency></origin>' +
        '<origin name="Q" n="10">' +
        '<frequency allele="1">4.00000e-1</frequency>' +
        '<frequency allele="2">6.00000e-1</frequency></origin></marker>'));
    # The bulk form exists to avoid copying the Table once per locus; it must
    # agree with the single-locus form exactly, not merely closely.
    def sums as map of string to float init frequencySums($t, "P");
    testing.assertEqual(maps.keys($sums), ["A", "B"]);
    testing.assertEqual($sums["A"], frequencySum($t, "P", "A"));
    testing.assertEqual($sums["B"], frequencySum($t, "P", "B"));
    near($sums["A"], 1.0);

    # Scoped to the population asked for: Q carries B only.
    def qsums as map of string to float init frequencySums($t, "Q");
    testing.assertEqual(maps.keys($qsums), ["B"]);
    near($qsums["B"], 1.0);
}

func testAllFrequencySumsCoversEveryPopulation() {
    def t as Table init parse(doc('<marker><name>A</name>' +
        '<origin name="P" n="10">' +
        '<frequency allele="1">2.50000e-1</frequency>' +
        '<frequency allele="2">7.50000e-1</frequency></origin>' +
        '<origin name="Q" n="10">' +
        '<frequency allele="1">1.00000e0</frequency></origin></marker>' +
        '<marker><name>B</name><origin name="P" n="10">' +
        '<frequency allele="1">1.00000e0</frequency></origin></marker>'));
    def all as map of string to map of string to float init allFrequencySums($t);
    # Same populations and loci the per-population form reports, and the same
    # numbers - the whole-export form is an optimisation, not a variant.
    testing.assertEqual(maps.keys($all), populations($t));
    for (def p in populations($t)) {
        def one as map of string to float init frequencySums($t, $p);
        testing.assertEqual(maps.keys($all[$p]), maps.keys($one));
        for (def locus in $one) {
            testing.assertEqual($all[$p][$locus], $one[$locus]);
        }
    }
    # Q is typed at A only, P at both.
    testing.assertEqual(maps.keys($all["P"]), ["A", "B"]);
    testing.assertEqual(maps.keys($all["Q"]), ["A"]);
    near($all["P"]["A"], 1.0);
}

func sumsOfAnUnknownPopulation() {
    frequencySums(
        parse(doc('<marker><name>A</name>' +
            '<origin name="P" n="1"><frequency allele="1">1.0e0</frequency></origin>' +
            '</marker>')),
        "NOPE");
}

func testFrequencySumsRejectsAnUnknownPopulation() {
    testing.assertThrows("sumsOfAnUnknownPopulation", "strider");
}

# --- rejections -------------------------------------------------------------

func emptyDocument() {
    parse("<frequencies/>");
}

func markerWithNoName() {
    parse('<frequencies><marker>' +
        '<origin name="P" n="1"><frequency allele="1">1.0e0</frequency></origin>' +
        '</marker></frequencies>');
}

func originWithNoName() {
    parse('<frequencies><marker><name>A</name>' +
        '<origin n="1"><frequency allele="1">1.0e0</frequency></origin>' +
        '</marker></frequencies>');
}

func frequencyWithNoAllele() {
    parse('<frequencies><marker><name>A</name>' +
        '<origin name="P" n="1"><frequency>1.0e0</frequency></origin>' +
        '</marker></frequencies>');
}

func frequencyWithNoValue() {
    parse('<frequencies><marker><name>A</name>' +
        '<origin name="P" n="1"><frequency allele="1"></frequency></origin>' +
        '</marker></frequencies>');
}

func duplicateAllele() {
    parse('<frequencies><marker><name>A</name><origin name="P" n="1">' +
        '<frequency allele="1">5.0e-1</frequency>' +
        '<frequency allele="1">5.0e-1</frequency></origin></marker></frequencies>');
}

func duplicateLocus() {
    parse('<frequencies><marker><name>A</name>' +
        '<origin name="P" n="1"><frequency allele="1">1.0e0</frequency></origin></marker>' +
        '<marker><name>A</name>' +
        '<origin name="P" n="1"><frequency allele="2">1.0e0</frequency></origin></marker>' +
        '</frequencies>');
}

func markersButNoPopulations() {
    parse("<frequencies><marker><name>A</name></marker></frequencies>");
}

func malformedXml() {
    parse("<frequencies><marker><name>A</name>");
}

func testMalformedExportsAreRejected() {
    # A document with no markers is nearly always the wrong file - and a
    # duplicated locus or allele means the frequencies no longer sum sensibly,
    # so neither is quietly accepted.
    testing.assertThrows("emptyDocument", "strider");
    testing.assertThrows("markerWithNoName", "strider");
    testing.assertThrows("originWithNoName", "strider");
    testing.assertThrows("frequencyWithNoAllele", "strider");
    testing.assertThrows("frequencyWithNoValue", "strider");
    testing.assertThrows("duplicateAllele", "strider");
    testing.assertThrows("duplicateLocus", "strider");
    testing.assertThrows("markersButNoPopulations", "strider");
}

func testMalformedXmlPropagates() {
    # xml.decode's error is not wrapped: kind "runtime" before 0.28.0, "xml"
    # from 0.28.0 on; expect "xml" alone once the floor is 0.28.0
    def k as string init "";
    try {
        malformedXml();
    } catch (e) {
        $k = $e.kind;
    }
    testing.assertTrue($k == "xml" or $k == "runtime");
}

func unknownPopulation() {
    loci(
        parse(doc('<marker><name>A</name>' +
            '<origin name="P" n="1"><frequency allele="1">1.0e0</frequency></origin>' +
            '</marker>')),
        "NOPE");
}

func unknownLocus() {
    frequencySum(
        parse(doc('<marker><name>A</name>' +
            '<origin name="P" n="1"><frequency allele="1">1.0e0</frequency></origin>' +
            '</marker>')),
        "P",
        "NOPE");
}

func testUnknownPopulationAndLocusAreRejected() {
    testing.assertThrows("unknownPopulation", "strider");
    testing.assertThrows("unknownLocus", "strider");
}

# --- conversion into the generic database -----------------------------------

func testToFrequencyDbCarriesLociSizesAndFrequencies() {
    def d as string init doc('<marker><name>D3S1358</name>' +
        '<origin name="AUSTRIA" n="1000">' +
        '<frequency allele="15">2.50000e-1</frequency>' +
        '<frequency allele="16">7.50000e-1</frequency></origin></marker>' +
        '<marker><name>TH01</name><origin name="AUSTRIA" n="500">' +
        '<frequency allele="9.3">4.00000e-1</frequency>' +
        '<frequency allele="6">6.00000e-1</frequency></origin></marker>');
    def fdb as forensics.FrequencyDb init load($d, "AUSTRIA", "STRidER AT");
    testing.assertEqual($fdb.name, "STRidER AT");
    testing.assertEqual(forensics.loci($fdb), ["D3S1358", "TH01"]);
    testing.assertEqual(forensics.sampleSize($fdb, "D3S1358"), 1000);
    testing.assertEqual(forensics.sampleSize($fdb, "TH01"), 500);
    near(forensics.alleleFrequency($fdb, "D3S1358", "15"), 0.25);
    near(forensics.alleleFrequency($fdb, "TH01", "9.3"), 0.4);
    # N = 1000 sets D3S1358's floor at 5/2000.
    near(forensics.minFrequency($fdb, "D3S1358"), 0.0025);
}

func testEachPopulationConvertsSeparately() {
    def t as Table init parse(doc('<marker><name>TH01</name>' +
        '<origin name="Entire Database" n="17479">' +
        '<frequency allele="6">4.00000e-1</frequency>' +
        '<frequency allele="9.3">6.00000e-1</frequency></origin>' +
        '<origin name="AUSTRIA" n="1223">' +
        '<frequency allele="6">3.00000e-1</frequency>' +
        '<frequency allele="9.3">7.00000e-1</frequency></origin></marker>'));
    # One parse, two databases - which is why `load` is the convenience form
    # and the two-step form is the one to reach for here.
    def wide as forensics.FrequencyDb init toFrequencyDb($t, "Entire Database", "");
    def at as forensics.FrequencyDb init toFrequencyDb($t, "AUSTRIA", "STRidER AT");
    near(forensics.alleleFrequency($wide, "TH01", "6"), 0.4);
    near(forensics.alleleFrequency($at, "TH01", "6"), 0.3);
    testing.assertEqual($at.name, "STRidER AT");
}

func testToFrequencyDbIsLinearInLoci() {
    # Looping withLocus over the growing database copied every locus added so
    # far: 32x the loci took ~1000x the time. Linear is ~32x; 64x allows noise.
    def small as Table init parse(synthetic(25, 2, 0));
    def large as Table init parse(synthetic(800, 2, 0));
    def t0 as time.Time init time.now();
    def a as forensics.FrequencyDb init toFrequencyDb($small, "P", "");
    def t1 as time.Time init time.now();
    def b as forensics.FrequencyDb init toFrequencyDb($large, "P", "");
    def t2 as time.Time init time.now();
    testing.assertEqual(len(forensics.loci($a)), 25);
    testing.assertEqual(len(forensics.loci($b)), 800);
    testing.assertEqual(forensics.loci($b)[799], "L799");
    testing.assertEqual($b.loci["L799"].alleles["1"], 0.01);
    testing.assertEqual(forensics.sampleSize($b, "L799"), 10);
    testing.assertTrue(elapsedMs($t1, $t2) < 64.0 * elapsedMs($t0, $t1) + 50.0);
}

func testDatasetLabelFallsBackToThePopulation() {
    def d as string init doc('<marker><name>TH01</name>' +
        '<origin name="AUSTRIA" n="1000">' +
        '<frequency allele="6">1.00000e0</frequency></origin></marker>');
    # Which population produced a number is part of the result, so the caller
    # may relabel it - or accept the export's own name for it.
    testing.assertEqual(load($d, "AUSTRIA", "STRidER AT").name, "STRidER AT");
    testing.assertEqual(load($d, "AUSTRIA", "").name, "AUSTRIA");
}

func misreadTable() {
    # A percentage-scaled table: the generic type rejects it rather than
    # yielding genotype "probabilities" above 1.
    load(
        doc('<marker><name>TH01</name><origin name="P" n="100">' +
            '<frequency allele="6">2.50000e1</frequency></origin></marker>'),
        "P",
        "");
}

func testMisreadTableIsRejectedByTheGenericType() {
    testing.assertThrows("misreadTable", "forensicgenetics");
}

# --- the inline fixture -------------------------------------------------------

# Run from the deck root, the inline copy must equal the file the example and the
# docs use; elsewhere (an installed deck) there is no file to compare against.
func testSampleMatchesTestdata() {
    if (not fs.isFile("testdata/frequencies.xml")) {
        return;
    }
    testing.assertEqual(SAMPLE + "\n", fs.readString("testdata/frequencies.xml"));
}
