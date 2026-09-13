# libffi: reproducible platform builds

This guide describes the InsightOS fork/import and the scripts in this checkout.
The validated distribution from this repository is **Linux x86_64 musl**. glibc
and macOS source recipes below are native development builds, not a claim that
this fork publishes or has requalified those binaries. The complete installer
selects different binary formats and dependency locks for each platform.

## Source and tools

Validated musl tag: [`musl-v3.5.2-2`](https://github.com/insightos-community/libffi/releases/tag/musl-v3.5.2-2);
source commit: `63e1a907afd2a4192b29532621cef7106fea6015`. Use a normal clone so container packaging can read `.git`.

```bash
git clone https://github.com/insightos-community/libffi.git libffi-repro
cd libffi-repro
git checkout --detach musl-v3.5.2-2
test "$(git rev-parse HEAD)" = 63e1a907afd2a4192b29532621cef7106fea6015
```

Native build prerequisites: C/C++ compiler, Autoconf, Automake, Libtool, Texinfo and DejaGNU. A git checkout needs `autogen.sh` before configure.

## Linux glibc

Run on a native Linux x86_64 glibc build host (Ubuntu 24.04 is the project CI
baseline). Install the prerequisites above. This native recipe uses the host
compiler and libraries; it does not apply the musl-only patches or emit a
portable/manylinux wheel.

```bash
sh autogen.sh
mkdir build-glibc
(cd build-glibc
 ../configure --prefix="$PWD/../prefix-glibc" --disable-docs --disable-static
 make -j2
 make check
 make install
)
```

## Linux musl: reproduce the Release

The authoritative pipeline is [musl-release.yml](.github/workflows/musl-release.yml),
with [build.sh](ci/musl/build.sh) as its local entry point. Run from the checked-out
repository root on a Linux x86_64 Docker host. Building requires network access
for pinned sources and package downloads; the output directory must be fresh.

```bash
REPRO_IMAGE='python:3.13-alpine3.23@sha256:75f27d686432419c9d42420b2b9ef605868c7a0682a6be10a6601fad46c2df01'
REPRO_WORK="$(mktemp -d "${TMPDIR:-/tmp}/libffi-musl.XXXXXXXX")"
docker run --rm --platform linux/amd64 --cpus=2 --memory=12g --memory-swap=12g --pids-limit=1024 \
  --mount "type=bind,src=$PWD,dst=/src,readonly" \
  --mount "type=bind,src=$REPRO_WORK,dst=/work" \
  "$REPRO_IMAGE" sh /src/ci/musl/build.sh
```

Repeat the published relocation/install probe in a clean container without network:

```bash
docker run --rm --platform linux/amd64 --network none \
  --mount "type=bind,src=$PWD,dst=/src,readonly" \
  --mount "type=bind,src=$REPRO_WORK,dst=/work" \
  "$REPRO_IMAGE" sh /src/ci/musl/clean.sh
```

Outputs are in `$REPRO_WORK/dist/`; build/test logs and package inventories are
in `$REPRO_WORK/logs/`. Retain `build-manifest.json` and `SHA256SUMS` alongside:

- `libffi-3.5.2-musl-x86_64-prefix.tar.gz`

```bash
(cd "$REPRO_WORK/dist" && sha256sum -c SHA256SUMS)
```

Repository-local input/metadata manifests: [`project.json`](ci/musl/project.json).

The pinned Python/Alpine image does not freeze every subsequently installed APK
or pip package. Preserve the emitted package inventory; the result is a musl
build, not a completely static application or a bit-for-bit reproducibility claim.

## macOS / macosx

Use a fresh checkout on Apple Silicon, Xcode Command Line Tools and native arm64
versions of the prerequisites. Do not reuse Linux build directories or `$ORIGIN`
RPATHs. The following is a source-development recipe; it is not the macOS installer
release recipe or a universal/x86_64 qualification.

```bash
sh autogen.sh
mkdir build-macos
(cd build-macos
 ../configure --prefix="$PWD/../prefix-macos" --disable-docs --disable-static
 make -j2
 make check
 make install
)
```

This fork’s musl Release is not used as a macOS binary dependency. Native builds here are optional development tools/libraries; the installer uses its locked macOS wheel or bundled/system library set.

## Run the same build on GitHub

A manual dispatch builds/tests artifacts without publishing. Select the immutable
release tag to reproduce its scripts (GitHub CLI and workflow permission required):

```bash
gh workflow run musl-release.yml --repo insightos-community/libffi --ref musl-v3.5.2-2
gh run list --repo insightos-community/libffi --workflow musl-release.yml --limit 5
# Set REPRO_RUN_ID to the run ID printed above.
gh run watch "$REPRO_RUN_ID" --repo insightos-community/libffi --exit-status
gh run download "$REPRO_RUN_ID" --repo insightos-community/libffi --name musl-dist --dir downloaded-dist
```

## Reproduction evidence

Build in a fresh checkout and a separate output directory for each ABI. Preserve
source commits, compiler/tool versions, dependency locks, package inventories and
test logs. Fixed source revisions and a container digest reproduce the recipe;
unlocked OS packages, runner images, timestamps and build tools can still change
archive bytes. Compare a downloaded release against its published `SHA256SUMS`;
do not expect a local rebuild to have the same digest.

See the [complete installer and repository index](https://github.com/insightos-community/quick-start/blob/main/README.build.md) for assembly order,
platform locks and end-to-end validation. Local build commands do not publish a
Release. Publishing requires repository write access and a new version tag;
existing release tags/assets should not be replaced.
