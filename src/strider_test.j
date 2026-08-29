# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
# pragma-jennifer-version: >=0.25.0

# White-box test overlay for strider.j. Run with `jennifer test strider_test.j`.
#
# The reader targets the layout STRidER actually publishes: locus-major, with
# every population nested inside each locus as an <origin>. These cases are that
# shape, cut down to two or three alleles so the arithmetic stays checkable by
# eye.
use testing;
use math;
use fs;

def const TOL as float init 0.000000001;
# The bundled fixture publishes six significant figures, exactly as the real
# export does, so a locus sums to 1.0 only to within that rounding.
def const SUM_TOL as float init 0.00001;

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

func testMissingSampleSizeBecomesZero() {
    def t as Table init parse(doc('<marker><name>A</name>' +
        '<origin name="P"><frequency allele="1">1.00000e0</frequency></origin></marker>'));
    testing.assertEqual(sampleSize($t, "P", "A"), 0);
}

# --- the bundled sample -----------------------------------------------------

func testBundledSampleExportParses() {
    def t as Table init parse(fs.readString("testdata/frequencies.xml"));
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
    def caught as string init "";
    try {
        malformedXml();
    } catch (e) {
        $caught = $e.kind;
    }
    testing.assertTrue(len($caught) > 0);
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
