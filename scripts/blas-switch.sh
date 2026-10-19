#!/usr/bin/env bash
# Switch the system BLAS/LAPACK used by R (and numpy if linked to libblas.so.3).
#
#   blas-switch                 show current selection
#   blas-switch list            list available implementations
#   blas-switch <impl>          select: openblas-pthread | openblas-openmp |
#                               openblas-serial | blis-pthread | blis-openmp |
#                               reference
#
# Requires root (or sudo, enabled with GRANT_SUDO=yes). Restart R afterwards.
set -euo pipefail

arch="$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || echo "$(uname -m)-linux-gnu")"
libdir="/usr/lib/${arch}"
blas_alt="libblas.so.3-${arch}"
lapack_alt="liblapack.so.3-${arch}"

impls="openblas-pthread openblas-openmp openblas-serial blis-pthread blis-openmp reference"

status() {
  echo "BLAS:   $(readlink -f "${libdir}/libblas.so.3")"
  echo "LAPACK: $(readlink -f "${libdir}/liblapack.so.3")"
}

paths_for() {
  case "$1" in
    openblas|openblas-pthread) echo "openblas-pthread/libblas.so.3 openblas-pthread/liblapack.so.3" ;;
    openblas-openmp)           echo "openblas-openmp/libblas.so.3 openblas-openmp/liblapack.so.3" ;;
    openblas-serial)           echo "openblas-serial/libblas.so.3 openblas-serial/liblapack.so.3" ;;
    blis|blis-pthread)         echo "blis-pthread/libblas.so.3 lapack/liblapack.so.3" ;;
    blis-openmp)               echo "blis-openmp/libblas.so.3 lapack/liblapack.so.3" ;;
    reference)                 echo "blas/libblas.so.3 lapack/liblapack.so.3" ;;
    *) return 1 ;;
  esac
}

as_root() {
  if [ "$(id -u)" -eq 0 ]; then "$@"
  elif command -v sudo >/dev/null && sudo -n true 2>/dev/null; then sudo "$@"
  else echo "blas-switch: root required (start container with GRANT_SUDO=yes)" >&2; exit 1
  fi
}

case "${1:-status}" in
  status) status ;;
  list)
    for i in ${impls}; do
      read -r b l <<<"$(paths_for "$i")"
      if [ -e "${libdir}/${b}" ] && [ -e "${libdir}/${l}" ]; then echo "  $i"; fi
    done
    ;;
  -h|--help|help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//' ;;
  *)
    if ! p="$(paths_for "$1")"; then
      echo "blas-switch: unknown implementation '$1' (try: blas-switch list)" >&2; exit 1
    fi
    read -r b l <<<"$p"
    for f in "${libdir}/${b}" "${libdir}/${l}"; do
      [ -e "$f" ] || { echo "blas-switch: missing $f" >&2; exit 1; }
    done
    prev_b="$(readlink -f "${libdir}/libblas.so.3")"
    prev_l="$(readlink -f "${libdir}/liblapack.so.3")"
    prev_o="$(readlink -f "${libdir}/libopenblas.so.0" 2>/dev/null || true)"
    prev_x="$(readlink -f "${libdir}/libblis.so.4" 2>/dev/null || true)"
    # The OpenBLAS/BLIS libblas.so.3 wrappers link to libopenblas.so.0 /
    # libblis.so.4, which are separate alternatives and must match the variant.
    variant="${b%%/*}"
    set_alts() {
      as_root update-alternatives --set "${blas_alt}" "$1" >/dev/null
      as_root update-alternatives --set "${lapack_alt}" "$2" >/dev/null
      [ -n "$3" ] && as_root update-alternatives --set "libopenblas.so.0-${arch}" "$3" >/dev/null
      [ -n "$4" ] && as_root update-alternatives --set "libblis.so.4-${arch}" "$4" >/dev/null
      return 0
    }
    new_o=""; new_x=""
    case "${variant}" in
      openblas-*) new_o="${libdir}/${variant}/libopenblas.so.0" ;;
      blis-*)     new_x="${libdir}/${variant}/libblis.so.4" ;;
    esac
    set_alts "${libdir}/${b}" "${libdir}/${l}" "${new_o}" "${new_x}"
    # Sanity check: make sure R still loads and can do a matrix product
    if ! Rscript -e 'stopifnot(all(crossprod(matrix(1, 2, 2)) == 2), all(solve(diag(2)) == diag(2)))' >/dev/null 2>&1; then
      echo "blas-switch: R failed with '$1', reverting" >&2
      set_alts "${prev_b}" "${prev_l}" "${prev_o}" "${prev_x}"
      status
      exit 1
    fi
    status
    ;;
esac
