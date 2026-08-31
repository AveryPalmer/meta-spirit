#!/usr/bin/env bash
# Syntax-check SPIRIT DTS/DTSI with dtc.
# Kernel board includes are not in this repo; a CI stub stands in for
# bcm2712-rpi-5-b.dts. See .github/dtc-stubs/ and KERNEL.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DTSDIR="${ROOT}/recipes-kernel/linux/files/spirit-phone-cm5"
STUBDIR="${ROOT}/.github/dtc-stubs"
DTS="${DTSDIR}/bcm2712-spirit-phone-cm5.dts"
DTSI="${DTSDIR}/spirit-phone-cm5.dtsi"

if ! command -v dtc >/dev/null 2>&1; then
	echo "error: device-tree-compiler (dtc) is not installed" >&2
	exit 1
fi

if [[ ! -f "${DTS}" ]]; then
	echo "error: missing ${DTS}" >&2
	exit 1
fi

echo "==> dtc $(dtc --version 2>&1 | head -n1)"

# Preprocess #include, then compile. Do not pass -f here: we want real
# syntax errors to fail CI. The kernel board DTS is stubbed.
echo "==> syntax-check ${DTS} (kernel include stubbed)"
cpp -nostdinc -undef -x assembler-with-cpp \
	-I "${STUBDIR}" -I "${DTSDIR}" \
	"${DTS}" | dtc -I dts -O dtb -o /dev/null -

# DTSI is an overlay fragment (root reference); wrap a dummy root so dtc can
# parse it without the board file.
if [[ -f "${DTSI}" ]]; then
	echo "==> syntax-check ${DTSI} (wrapped fragment)"
	{
		echo '/dts-v1/;'
		echo '/ {};'
		cat "${DTSI}"
	} | cpp -nostdinc -undef -x assembler-with-cpp -I "${DTSDIR}" \
		| dtc -I dts -O dtb -o /dev/null -
fi

echo "==> dtc syntax check passed"
