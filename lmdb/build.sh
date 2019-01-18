#! /usr/bin/env bash

# BuildCompatible: KitCreator

version="0.4.0"
url="https://github.com/ray2501/tcl-lmdb/archive/${version}.tar.gz"
sha256='d19a19376da6716a1ed159a918e631030491f8b6a4ef9e72a4221481b24b2e40'

function postinstall() {
	local name

	find "${installdir}" -type -f -name '*.a' | while IFS='' read -r name; do
		echo '-lntdll' > "${name}.linkadd"
	done
}
