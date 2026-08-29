# Installing the deck

Requires Jennifer 0.25.0 or newer and `@jennifer/forensicgenetics`.

## With jvc

[jvc](https://github.com/jennifer-language/jvc) is the deck manager. It reads
the manifest, resolves the dependency graph, and writes the `vendor/` tree the
`@scope/package` resolver addresses:

```sh
jvc source @mplx/strider https://github.com/mplx/deck-strider-frequency-converter.git
jvc add @mplx/strider
jvc install
```

`jvc install` pins what it resolved in a `camcorder.lock`, so a later install on
another machine reproduces the same versions rather than re-resolving.

The `source` line is what makes this work today: neither this deck nor
`@jennifer/forensicgenetics` has been published to the public registry yet, so
they resolve from their git remotes (by tag) rather than by name. This deck's
manifest already carries a `[sources]` entry for its dependency, so only this
deck needs pointing at. When both are published, `jvc add @mplx/strider`
followed by `jvc install` is the whole procedure.

## By hand

The vendor tree is a plain directory layout, so it can also be populated by
copying - which is what this repository's CI does, since the interpreter image
it builds in does not carry jvc:

```
your-project/
  app.j
  vendor/
    mplx/
      strider/
        strider.j
    jennifer/
      forensicgenetics/
        forensicgenetics.j
        kinship.j
        pedigree.j
        lineage.j
```

```sh
mkdir -p vendor/mplx/strider vendor/jennifer/forensicgenetics
cp path/to/deck-strider-frequency-converter/src/*.j vendor/mplx/strider/
cp path/to/deck-forensicgenetics/src/*.j            vendor/jennifer/forensicgenetics/
rm -f vendor/*/*/*_test.j
```

The installed tree is **flat**: the entry file sits at the root of the package
directory, because `@mplx/strider/` expands to the package-named entry
`strider/strider.j`.

```jennifer
import "@mplx/strider/" as strider;
import "@jennifer/forensicgenetics/" as forensics;
```

Either way the result is the same tree. The vendor root is found by
`--vendor DIR`, then `JENNIFER_VENDOR`, then the nearest `vendor/` above the
program.

## Working in this repository

The checkout carries its own git-ignored `vendor/` populated the same way, so
`jennifer test src/strider_test.j` and `jennifer run examples/readtable.j` work
from the deck root. `tools/vendor-deps.sh` populates it from the manifest: it
reads `[decks]` for the constraint and `[sources]` for the git remote, then
vendors the highest tag satisfying it. CI runs the same script, so a local tree
and CI's agree by construction, and a dependency resolves to a release tag
rather than to a moving `main`.
