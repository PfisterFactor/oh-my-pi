#!/usr/bin/env bash
# Build a single-arch .deb for the omp CLI binary.
#
# Runs natively on the Ubuntu runner (no docker — Ubuntu already ships the
# Debian-family tooling). Invoked by the workflow as:
#   env DEB_VERSION=... DEB_BUILDNUM=... DEB_SHORTSHA=... \
#       DEB_ARCH=amd64|arm64 GH_OWNER=... \
#       bash packaging/deb/build-deb.sh
#
# Expects these files staged under $PWD/packaging/deb/sources/:
#   omp, LICENSE
#
# Outputs the .deb into $PWD/packaging/deb/out/.

set -euo pipefail

: "${DEB_VERSION:?}"
: "${DEB_BUILDNUM:?}"
: "${DEB_SHORTSHA:?}"
: "${DEB_ARCH:?}"
: "${GH_OWNER:?}"

WORK=$(pwd)
TEMPLATE_DIR="${WORK}/packaging/deb"
SOURCES_DIR="${TEMPLATE_DIR}/sources"
OUT="${WORK}/packaging/deb/out"

# Mirror the RPM Release format (`<ver>-0.<buildnum>.git<sha>`); legal Debian
# upstream-revision shape and sorts monotonically per push.
DEB_FULL_VERSION="${DEB_VERSION}-0.${DEB_BUILDNUM}.git${DEB_SHORTSHA}"
DEB_NAME="omp_${DEB_FULL_VERSION}_${DEB_ARCH}.deb"

STAGE=$(mktemp -d)
PKGROOT="${STAGE}/omp_${DEB_FULL_VERSION}_${DEB_ARCH}"
trap 'rm -rf "${STAGE}"' EXIT

mkdir -p "${PKGROOT}/DEBIAN" \
         "${PKGROOT}/usr/bin" \
         "${PKGROOT}/usr/share/doc/omp"

install -m 0755 "${SOURCES_DIR}/omp"     "${PKGROOT}/usr/bin/omp"
install -m 0644 "${SOURCES_DIR}/LICENSE" "${PKGROOT}/usr/share/doc/omp/copyright"

sed -e "s|@VERSION@|${DEB_FULL_VERSION}|g" \
    -e "s|@ARCH@|${DEB_ARCH}|g" \
    -e "s|@OWNER@|${GH_OWNER}|g" \
    "${TEMPLATE_DIR}/control.template" > "${PKGROOT}/DEBIAN/control"

mkdir -p "${OUT}"
rm -f "${OUT}/${DEB_NAME}"

dpkg-deb --root-owner-group --build "${PKGROOT}" "${OUT}/${DEB_NAME}"

ls -lh "${OUT}/"
