#!/bin/zsh
# Issue 0011: build the local source tarball for the hermetic formula test
# and patch its fresh sha256 into dist/nutorch.rb (the committed sha is a
# documented last-known value — a tarball of HEAD contains the formula, so
# the committed sha can never match a re-archive of its own commit).
set -e
cd "$(dirname "$0")/.."

VERSION=$(rg -o 'version = "([0-9.]+)"' -r '$1' Cargo.toml | head -1)
OUT=/tmp/nutorch-src
mkdir -p $OUT
git archive --format=tar.gz --prefix="nutorch-$VERSION/" -o "$OUT/nutorch-$VERSION.tar.gz" HEAD
SHA=$(shasum -a 256 "$OUT/nutorch-$VERSION.tar.gz" | awk '{print $1}')
# Patch the sha into the working-tree formula (line: sha256 "...").
python3 - "$SHA" <<'PY'
import re, sys
sha = sys.argv[1]
path = "dist/nutorch.rb"
s = open(path).read()
s, n = re.subn(r'^  sha256 "[^"]*"$', f'  sha256 "{sha}"', s, count=1, flags=re.M)
assert n == 1, "sha256 line not found"
open(path, "w").write(s)
PY
echo "tarball: $OUT/nutorch-$VERSION.tar.gz"
echo "sha256:  $SHA (patched into dist/nutorch.rb)"
