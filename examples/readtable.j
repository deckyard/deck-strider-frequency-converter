# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# Read a STRidER export, check it, and convert one population into the generic
# frequency database the estimators take.
#
#   jennifer run examples/readtable.j                    # the synthetic fixture
#   jennifer run examples/readtable.j strider.xml        # your own download
#   jennifer run examples/readtable.j strider.xml AUSTRIA
#
# Both arguments are optional: the export defaults to the bundled fixture, and
# the population to the first the export offers. Population labels can contain
# spaces, so quote them - "Entire Database", "SAUDI ARABIA".
#
# It also reports how long the file takes to become a usable FrequencyDb -
# read, parse and convert - which on a full export is dominated by the parse.
#
# The fixture is made-up numbers in the real export's shape. Point it at your
# own download to see the real thing: 45 loci across 33 populations rather than
# 4 across 3. The real table is not redistributable, so it is not in this
# repository - fetch it yourself from https://strider.online/frequencies/xml

use io;
use os;
use fs;
use math;
use lists;
use time;

import "../src/strider.j" as strider;
import "@deckyard/forensicgenetics/" as forensics;

# elapsedMs reports a span in fractional milliseconds. time.milliseconds truncates
# to whole ones, which reads as a flat 0 for the small fixture, so the nanosecond
# accessor is used and scaled instead.
func elapsedMs(startedAt as time.Time, endedAt as time.Time) {
    return (time.unixNanos($endedAt) - time.unixNanos($startedAt)) / 1000000.0;
}

# --- step zero: which export to read ----------------------------------------

def path as string init "testdata/frequencies.xml";
if (len(os.ARGS) > 1) {
    $path = os.ARGS[1];
}
if (not fs.exists($path)) {
    io.printf("no such export: %s\n", $path);
    exit 1;
}
io.printf("reading %s\n\n", $path);

def readFrom as time.Time init time.now();
def xml as string init fs.readString($path);
def readTo as time.Time init time.now();

# --- step one: parse, and check what was parsed -----------------------------

def parseFrom as time.Time init time.now();
def t as strider.Table init strider.parse($xml);
def parseTo as time.Time init time.now();

io.printf("created  : %s\n", $t.created);
io.printf("validity : %s\n", $t.validity);

# One export carries many populations - the whole database, each continent, and
# each contributing country. They are all read by the single parse above.
def pops as list of string init strider.populations($t);
io.printf("populations: %d\n\n", len($pops));

# A locus that does not sum to roughly 1.0 was read wrongly - a truncated
# download, a percentage-scaled table, or the wrong column taken as the
# frequency. Always run this before the numbers reach a calculation.
def bad as int init 0;
# A Table is a value, so every accessor call copies the whole export - all 33
# populations of a real download. This surveys everything, so it takes the
# whole-export form: one copy for the lot. Looping frequencySums per population
# is about 2x slower here, and looping the single-locus frequencySum ~30x.
def all as map of string to map of string to float init strider.allFrequencySums($t);
for (def p in $all) {
    def sums as map of string to float init $all[$p];
    io.printf("  %s|pad=24 %d|pad=3 loci\n", $p, len($sums));
    for (def locus in $sums) {
        if (math.abs($sums[$locus] -1.0) > 0.01) {
            io.printf("  SUSPECT %s / %s sums to %f|prec=4\n", $p, $locus, $sums[$locus]);
            $bad = $bad + 1;
        }
    }
}
if ($bad == 0) {
    io.printf("\nevery locus sums to ~1.0 in every population\n\n");
}

# --- step two: convert one population ---------------------------------------

# Which population a calculation used is part of the result, so it is chosen by
# name and the resulting database is labelled with it. Converting a second one
# needs no second parse, only another toFrequencyDb call against the same
# Table, which is why the two-step form exists.
def chosen as string init $pops[0];
if (len(os.ARGS) > 2) {
    $chosen = os.ARGS[2];
    if (not lists.contains($pops, $chosen)) {
        # The survey above already listed every label this export carries, so
        # the error points at it rather than printing all 33 a second time.
        io.printf("no such population: %s\n", $chosen);
        io.printf("pick one of the %d listed above\n", len($pops));
        exit 1;
    }
}
def convertFrom as time.Time init time.now();
def db as forensics.FrequencyDb init strider.toFrequencyDb($t, $chosen, "");
def convertTo as time.Time init time.now();

# What it costs to get from a file on disk to a FrequencyDb ready to compute
# with. The survey loop above is deliberately outside this: it is the example
# reporting on the data, not work anyone needs to do to use the database.
def readMs as float init elapsedMs($readFrom, $readTo);
def parseMs as float init elapsedMs($parseFrom, $parseTo);
def convertMs as float init elapsedMs($convertFrom, $convertTo);
io.printf(
    "ready in %f|prec=1 ms  (read %f|prec=1 + parse %f|prec=1 + convert %f|prec=1)\n\n",
    $readMs + $parseMs + $convertMs,
    $readMs,
    $parseMs,
    $convertMs);

io.printf("database %s: %d loci\n", $db.name, len(forensics.loci($db)));
for (def locus in forensics.loci($db)) {
    io.printf(
        "  %s|pad=14 N = %d|pad=6 floor = %f|prec=6\n",
        $locus,
        forensics.sampleSize($db, $locus),
        forensics.minFrequency($db, $locus));
}
