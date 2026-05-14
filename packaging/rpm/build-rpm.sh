#!/usr/bin/env bash
# Build an RPM inside a Fedora container.
#
# Invoked by the workflow as:
#   docker run --rm -v $PWD:/work -w /work \
#     -e RPM_VERSION=... -e RPM_BUILDNUM=... -e RPM_SHORTSHA=... \
#     -e GH_OWNER=... -e HOST_UID=... -e HOST_GID=... \
#     fedora:41 bash packaging/rpm/build-rpm.sh
#
# Expects these files staged under $PWD/packaging/rpm/sources/:
#   omp, LICENSE
#
# Outputs RPM(s) into $PWD/packaging/rpm/out/.

set -euo pipefail

: "${RPM_VERSION:?}"
: "${RPM_BUILDNUM:?}"
: "${RPM_SHORTSHA:?}"
: "${GH_OWNER:?}"
: "${HOST_UID:?}"
: "${HOST_GID:?}"

dnf install -y --setopt=install_weak_deps=False rpm-build >/dev/null

WORK=$(pwd)
TOPDIR="${WORK}/packaging/rpm/rpmbuild"
SOURCES_DIR="${WORK}/packaging/rpm/sources"
OUT="${WORK}/packaging/rpm/out"
SPEC=$(ls "${WORK}/packaging/rpm/"*.spec | head -1)

rm -rf "${TOPDIR}" "${OUT}"
mkdir -p "${TOPDIR}"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS} "${OUT}"

cp "${SOURCES_DIR}"/* "${TOPDIR}/SOURCES/"
cp "${SPEC}"          "${TOPDIR}/SPECS/"

rpmbuild \
    --define "_topdir ${TOPDIR}" \
    --define "_version ${RPM_VERSION}" \
    --define "_buildnum ${RPM_BUILDNUM}" \
    --define "_shortsha ${RPM_SHORTSHA}" \
    --define "_owner ${GH_OWNER}" \
    --define "_changelog_date $(LC_ALL=C date -u '+%a %b %d %Y')" \
    -bb "${TOPDIR}/SPECS"/*.spec

find "${TOPDIR}/RPMS" -name '*.rpm' -exec cp -v {} "${OUT}/" \;

# Chown back to the host UID so the runner can read / upload-artifact.
chown -R "${HOST_UID}:${HOST_GID}" "${TOPDIR}" "${OUT}"

ls -lh "${OUT}/"