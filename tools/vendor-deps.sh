#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
#
# Populate vendor/ with this deck's `[decks]` dependencies before anything that
# has to load them - lint, the suites, the examples.
#
# This is the one place deck-strider differs from the shared workflows. jvc is
# the real resolver and does this properly, but the interpreter image CI runs in
# does not ship it, and installing a deck manager to fetch a single dependency
# costs more than it saves. When the image carries jvc, delete this script and
# call `jvc install` instead.
#
# What it does: for every `[decks]` entry that also has a `[sources]` git URL,
# clone at the highest tag satisfying the constraint and copy its `src/` into
# vendor/<scope>/<deck>/, which is the layout the interpreter's @scope/package
# resolver reads. Test overlays are not vendored - a consumer's tree carries
# library code only, exactly as jvc would install it.
#
# Limitations, stated rather than hidden:
#   - Only `>=X.Y.Z`, `X.Y.Z` and `*` constraints are understood. Caret and
#     tilde ranges are jvc's job, not a shell script's.
#   - A dependency with no `[sources]` entry is an error here. Registry
#     resolution is not something this should attempt to imitate.
#
# Usage: tools/vendor-deps.sh
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=tools/deck-lib.sh
source tools/deck-lib.sh
deck_load

# Emit "name<TAB>constraint<TAB>url" per runtime dependency, whichever of the
# four manifest formats the deck uses.
deck_requirements() {
    python3 - "$DECK_MANIFEST" <<'PY'
import json, sys, pathlib

path = pathlib.Path(sys.argv[1])
text = path.read_text()
if path.suffix == ".json":
    doc = json.loads(text)
elif path.suffix in (".yaml", ".yml"):
    import yaml
    doc = yaml.safe_load(text)
else:
    import tomllib
    doc = tomllib.loads(text)

decks = doc.get("decks") or {}
sources = doc.get("sources") or {}
for name, constraint in decks.items():
    print("\t".join([name, str(constraint), sources.get(name, "")]))
PY
}

# The highest tag satisfying the constraint. Tags are the candidate versions a
# git-sourced deck offers, which is how jvc reads a git remote too.
pick_tag() {
    local url="$1" constraint="$2" floor tags
    floor="$(sed -E 's/^[>=~^[:space:]]*//' <<<"$constraint")"
    tags="$(git ls-remote --tags --refs "$url" \
        | sed -E 's#.*refs/tags/##' \
        | sed -E 's/^v//' \
        | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
        | sort -V)"
    [[ -n "$tags" ]] || deck_die "no release tags at $url"

    if [[ "$constraint" == "*" || -z "$floor" ]]; then
        tail -1 <<<"$tags"
        return 0
    fi
    # Highest tag >= floor.
    local best=""
    while read -r tag; do
        if [[ "$(printf '%s\n%s\n' "$floor" "$tag" | sort -V | head -1)" == "$floor" ]]; then
            best="$tag"
        fi
    done <<<"$tags"
    [[ -n "$best" ]] || deck_die "no tag at $url satisfies '$constraint' (have: $(tr '\n' ' ' <<<"$tags"))"
    printf '%s\n' "$best"
}

count=0
while IFS=$'\t' read -r name constraint url; do
    [[ -n "$name" ]] || continue
    [[ -n "$url" ]] || deck_die "$name has no [sources] entry - this script cannot resolve from a registry"

    scope="${name#@}"; scope="${scope%%/*}"
    slug="${name##*/}"
    tag="$(pick_tag "$url" "$constraint")"

    echo "--- ${name} ${constraint} -> ${tag} (${url})"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$tag" "$url" "$tmp/src" \
        || git -c advice.detachedHead=false clone --quiet --depth 1 --branch "v$tag" "$url" "$tmp/src" \
        || deck_die "could not clone $url at $tag"

    [[ -d "$tmp/src/src" ]] || deck_die "$name at $tag has no src/ directory"
    dest="vendor/${scope}/${slug}"
    rm -rf "$dest"
    mkdir -p "$dest"
    cp "$tmp/src/src/"*.j "$dest/"
    rm -f "$dest"/*_test.j
    rm -rf "$tmp"
    trap - EXIT

    echo "    vendored $(find "$dest" -name '*.j' | wc -l) modules into ${dest}/"
    count=$((count + 1))
done < <(deck_requirements)

if (( count == 0 )); then
    echo "no [decks] dependencies in $DECK_MANIFEST - nothing to vendor"
else
    echo "vendored $count dependency/dependencies"
fi
