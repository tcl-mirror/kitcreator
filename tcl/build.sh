#! /bin/bash

if [ ! -f 'build.sh' ]; then
	echo 'ERROR: This script must be run from the directory it is in' >&2

	exit 1
fi
if [ -z "${TCLVERS}" ]; then
	echo 'ERROR: The TCLVERS environment variable is not set' >&2

	exit 1
fi

SRC="src/tcl${TCLVERS}.tar.gz"
SRCURL="http://prdownloads.sourceforge.net/tcl/tcl${TCLVERS}-src.tar.gz"
BUILDDIR="$(pwd)/build/tcl${TCLVERS}"
OUTDIR="$(pwd)/out"
INSTDIR="$(pwd)/inst"
PATCHSCRIPTDIR="$(pwd)/patchscripts"
export SRC SRCURL BUILDDIR OUTDIR INSTDIR PATCHSCRIPTDIR

rm -rf 'build' 'out' 'inst'
mkdir 'build' 'out' 'inst' || exit 1

if [ ! -f "${SRC}" ]; then
	mkdir 'src' >/dev/null 2>/dev/null

	if echo "${TCLVERS}" | grep '^cvs_' >/dev/null; then
		CVSTAG=$(echo "${TCLVERS}" | sed 's/^cvs_//g')
		export CVSTAG

		(
			cd src || exit 1

			cvs -z3 -d:pserver:anonymous@tcl.cvs.sourceforge.net:/cvsroot/tcl co -r "${CVSTAG}" -P tcl

			mv tcl "tcl${TCLVERS}"

			tar -cf - "tcl${TCLVERS}" | gzip -c > "../${SRC}"
		)
	else
		rm -f "${SRC}.tmp"
		wget -O "${SRC}.tmp" "${SRCURL}" || exit 1
		mv "${SRC}.tmp" "${SRC}"
	fi
fi

(
	cd 'build' || exit 1

	if [ ! -d '../buildsrc' ]; then
		gzip -dc "../${SRC}" | tar -xf -
	else
		cp -rp ../buildsrc/* './'
	fi

	cd "${BUILDDIR}" || exit 1

	# Apply patch scripts if needed
	for patchscript in "${PATCHSCRIPTDIR}"/*.sh; do
		if [ -f "${patchscript}" ]; then
			echo "Running patch script: ${patchscript}"

			(
				. "${patchscript}"
			)
		fi
	done

	# Patch Win32 builds to always provide DllMain if we are building KitDLL
	if [ "${KITTARGET}" = "kitdll" ]; then
		## DllMain is needed when building KitDLL
		for filetopatch in win/tclWin32Dll.c win/tclWinInit.c; do
			echo "Undefining STATIC_BUILD in \"${filetopatch}\""

			sed 's@STATIC_BUILD@NEVER_STATIC_BUILD@g' "${filetopatch}" > "${filetopatch}.new" && cat "${filetopatch}.new" > "${filetopatch}"
			rm -f "${filetopatch}.new"
		done
	fi

	for dir in unix win macosx __fail__; do
		if [ "${dir}" = "__fail__" ]; then
			# If we haven't figured out how to build it, reject.

			exit 1
		fi

		# Remove previous directory's "tclConfig.sh" if found
		rm -f 'tclConfig.sh'

		cd "${BUILDDIR}/${dir}" || exit 1

		echo "Running: ./configure --disable-shared --with-encoding=utf-8 --prefix=\"${INSTDIR}\" ${CONFIGUREEXTRA}"
		./configure --disable-shared --with-encoding=utf-8 --prefix="${INSTDIR}" ${CONFIGUREEXTRA}

		echo "Running: ${MAKE:-make}"
		${MAKE:-make} || continue

		echo "Running: ${MAKE:-make} install"
		${MAKE:-make} install || (
			# Work with Tcl 8.6.x's TCLSH_NATIVE solution for
			# cross-compile installs

			echo "Running: ${MAKE:-make} install TCLSH_NATIVE=\"${TCLKIT:-tclkit}\""
			${MAKE:-make} install TCLSH_NATIVE="${TCLKIT:-tclkit}"
		) || (
			# Make install can fail if cross-compiling using Tcl 8.5.x
			# because the Makefile calls "$(TCLSH)".  We can't simply
			# redefine TCLSH because it also uses TCLSH as a build target
			sed 's@^$(TCLSH)@blah@' Makefile > Makefile.new
			cat Makefile.new > Makefile
			rm -f Makefile.new

			echo "Running: ${MAKE:-make} install TCLSH=\"../../../../../../../../../../../../../../../../../$(which "${TCLKIT:-tclkit}")\""
			${MAKE:-make} install TCLSH="../../../../../../../../../../../../../../../../../$(which "${TCLKIT:-tclkit}")"
		) || (
			# Make install can fail if cross-compiling using Tcl 8.5.9
			# because the Makefile calls "${TCL_EXE}".  We can't simply
			# redefine TCL_EXE because it also uses TCL_EXE as a build target
			sed 's@^${TCL_EXE}@blah@' Makefile > Makefile.new
			cat Makefile.new > Makefile
			rm -f Makefile.new

			echo "Running: ${MAKE:-make} install TCL_EXE=\"../../../../../../../../../../../../../../../../../$(which "${TCLKIT:-tclkit}")\""
			${MAKE:-make} install TCL_EXE="../../../../../../../../../../../../../../../../../$(which "${TCLKIT:-tclkit}")"
		) || exit 1

		mkdir "${OUTDIR}/lib" || exit 1
		cp -r "${INSTDIR}/lib"/* "${OUTDIR}/lib/"
		rm -rf "${OUTDIR}/lib/pkgconfig"
		rm -f "${OUTDIR}"/lib/* >/dev/null 2>/dev/null
		find "${OUTDIR}" -name '*.a' | xargs rm -f >/dev/null 2>/dev/null

		# Clean up packages that are not needed
		if [ -n "${KITCREATOR_MINBUILD}" ]; then
			find "${OUTDIR}" -name "tcltest*" -type d | xargs rm -rf
		fi

		# Clean up encodings
		if [ -n "${KITCREATOR_MINENCODINGS}" ]; then
			KEEPENCODINGS=" ascii.enc cp1252.enc iso8859-1.enc iso8859-15.enc iso8859-2.enc koi8-r.enc macRoman.enc "
			export KEEPENCODINGS
			find "${OUTDIR}/lib" -name 'encoding' -type d | while read encdir; do
				(
					cd "${encdir}" || exit 1

					for file in *; do
						if echo " ${KEEPENCODINGS} " | grep " ${file} " >/dev/null; then
							continue
						fi

						rm -f "${file}"
					done
				)
			done
		fi

		break
	done
) || exit 1

exit 0
