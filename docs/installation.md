# Installing the deck

Requires Jennifer 0.25.0 or newer and `@deckyard/forensicgenetics`.

## With jvc

```sh
jvc source @deckyard/strider https://github.com/deckyard/deck-strider-frequency-converter.git
jvc add @deckyard/strider
jvc install
```

Neither this deck nor `@deckyard/forensicgenetics` is in the public registry
yet, so both resolve from their git remotes by tag. The `source` line points jvc
at this deck; its manifest already has the `[sources]` entry for the
dependency. Once both are published, `jvc add @deckyard/strider` and
`jvc install` are enough.

`jvc install` pins what it resolved in `camcorder.lock`, so an install on
another machine gets the same versions.

## By hand

The vendor tree is a plain directory layout. Copy `src/` from a checkout or a
release archive (`deckyard-strider-<version>.tar.gz`):

```sh
mkdir -p vendor/deckyard/strider vendor/deckyard/forensicgenetics
cp path/to/deck-strider-frequency-converter/src/*.j vendor/deckyard/strider/
cp path/to/deck-forensicgenetics/src/*.j            vendor/deckyard/forensicgenetics/
rm -f vendor/*/*/*_test.j
```

```
your-project/
  app.j
  vendor/
    deckyard/
      strider/
        strider.j
      forensicgenetics/
        forensicgenetics.j
        kinship.j
        pedigree.j
        lineage.j
```

The tree is flat: `@deckyard/strider/` expands to the package-named entry
`strider/strider.j`.

```jennifer
import "@deckyard/strider/" as strider;
import "@deckyard/forensicgenetics/" as forensics;
```

The vendor root is `--vendor DIR`, else `JENNIFER_VENDOR`, else the nearest
`vendor/` above the program.

## Working in this repository

The checkout has its own git-ignored `vendor/`. `tools/vendor-deps.sh` fills it
from the manifest: `[decks]` gives the constraint, `[sources]` the git remote,
and it vendors the highest satisfying release tag. CI runs the same script
because its interpreter image has no jvc. Then, from the deck root:

```sh
jennifer test src/strider_test.j
jennifer run examples/readtable.j
```
