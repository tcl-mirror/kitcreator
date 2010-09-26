#! /bin/bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

SRC="src/tk${TCLVERS}.tar.gz"
SRCURL="http://prdownloads.sourceforge.net/tcl/tk${TCLVERS}-src.tar.gz"
BUILDDIR="$(pwd)/build/tk${TCLVERS}"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
export SRC SRCURL BUILDDIR OUTDIR INSTDIR

rm -rf 'build' 'out' 'inst'
mkdir 'build' 'out' 'inst' || exit 1

if [ ! -f "${SRC}" ]; then
	mkdir 'src' >/dev/null 2>/dev/null

	wget -O "${SRC}" "${SRCURL}" || exit 1
fi

(
	cd 'build' || exit 1

	gzip -dc "../${SRC}" | tar -xf -

	cd "${BUILDDIR}" || exit 1
	for dir in unix win macosx; do
		# Remove previous directory's "tkConfig.sh" if found
		rm -f 'tkConfig.sh'

		cd "${BUILDDIR}/${dir}" || exit 1

		./configure --enable-shared --prefix="${INSTDIR}" --with-tcl="${TCLCONFIGDIR}" ${CONFIGUREEXTRA}

		"${MAKE:-make}" || continue

		"${MAKE:-make}" install

		# Update pkgIndex to load libtk from the local directory rather
		# than the parent directory
		for pkgIndex in "${INSTDIR}"/lib/tk*/pkgIndex.tcl; do
			sed 's@ \.\. @ @g' "${pkgIndex}" > "${pkgIndex}.new"
			mv "${pkgIndex}.new" "${pkgIndex}"
		done

		mkdir "${OUTDIR}/lib" || exit 1
		cp -r "${INSTDIR}/lib"/tk*/ "${OUTDIR}/lib/"
		cp -r "${INSTDIR}/lib"/libtk* "${OUTDIR}/lib"/tk*/

		break
	done
) || exit 1

exit 0
