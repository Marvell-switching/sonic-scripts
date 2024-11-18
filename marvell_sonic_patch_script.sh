#!/bin/bash

# Copyright (c) Marvell, Inc. All rights reservered. Confidential.
# Description: Applying open PRs needed for compilation
#
# Sonic patch script for Marvell board
#

#
# CONFIGURATIONS:-
#

#
# END of CONFIGURATIONS
#


# PREDEFINED VALUES
CUR_DIR=$(basename `pwd`)
LOG_FILE=patches_result.log
FULL_PATH=`pwd`

log()
{
	echo $@
	echo $@ >> ${FULL_PATH}/${LOG_FILE}
}

print_usage()
{
	log "Usage:"
	log ""
	log " bash $0 --branch <> --platform <marvell|innovium> --arch <amd64|arm64> --release-tag <>"
	log ""
	log ""
}

pre_patch_help()
{
	log "STEPS TO BUILD:"
	log "git clone https://github.com/sonic-net/sonic-buildimage.git -b <sonic_branch>"
	log "cd sonic-buildimage"
	log "make init"
	log ""
	log "<<Apply patches using patch script>>"
	print_usage
	log "PLATFORM: marvell"
	log "<<FOR ARM64>> make configure PLATFORM=marvell PLATFORM_ARCH=arm64"
	log "<<FOR ARM64>> make target/sonic-marvell-arm64.bin"
	log "<<FOR INTEL>> make configure PLATFORM=marvell"
	log "<<FOR INTEL>> make target/sonic-marvell.bin"
	log ""
	log "PLATFORM: innovium"
	log "<<FOR INTEL>> make configure PLATFORM=innovium"
	log "<<FOR INTEL>> make target/sonic-innovium.bin"
	log ""
}

parse_arguments()
{
	while [[ $# -gt 0 ]]; do
		case $1 in
			-b|--branch)
				BRANCH="$2"
				shift # past argument
				shift # past value
				;;
			-p|--platform)
				PLATFORM="$2"
				shift # past argument
				shift # past value
				;;
			-a|--arch)
				ARCH="$2"
				shift # past argument
				shift # past value
				;;
			-t|--release-tag)
				GIT_TAG="$2"
				shift # past argument
				shift # past value
				;;
			--url)
				URL="$2"
				shift # past argument
				shift # past value
				;;
			-h|--help)
				print_usage
				exit 0
				;;
			*)
				echo "ERROR: Unknown option '$1'"
				print_usage
				exit 1
				;;
		esac
	done

	if [ -z "${BRANCH}" ]; then
		echo "Branch is not set. Please check usage."
		print_usage
		exit 0
	fi

	if [ -z "${ARCH}" ]; then
		echo "Arch is not set. Please check usage."
		print_usage
		exit 0
	fi

	if [[ -z "${GIT_TAG}" && -z "${URL}" ]]; then
		echo "Github release tag is not set. Please check usage."
		print_usage
		exit 0
	fi

	if [ -z "${PLATFORM}" ]; then
		echo "Platform is not set. Please check usage."
		print_usage
		exit 0
	fi

	if [ -z "${URL}" ]; then
		WGET_PATH="https://raw.githubusercontent.com/Marvell-switching/sonic-scripts/$GIT_TAG/files/$BRANCH/"
	else
		WGET_PATH=$URL/files/$BRANCH
	fi
}

apply_sonicbuildimage_patches()
{
	( set -e
	cat series_${PLATFORM}_${ARCH}  | grep sonic-buildimage | cut -f 1 -d'|' | while read -r patch_file
do
	echo $patch_file
	pushd patches
	wget --timeout=2 -c $WGET_PATH/$patch_file
	popd
	git am patches/$patch_file
done)
}

apply_submodule_patches()
{
	CWD=`pwd`
	( set -e
	cat series_${PLATFORM}_${ARCH}  | grep -v sonic-buildimage | while read -r line
do
	patch=`echo $line | cut -f 1 -d'|'`
	dir=`echo $line | cut -f 2 -d'|'`
	pushd patches
	wget --timeout=2 -c $WGET_PATH/${patch}
	popd
	pushd ${dir}
	git am $CWD/patches/${patch}
	popd
done)
}

apply_hwsku_changes()
{
	if [ "$PLATFORM" == "marvell" ]; then
		# Download hwsku
		wget --timeout=2 -c $WGET_PATH/prestera_hwsku.tgz
		if [ $? -eq 0 ]; then
			rm -fr device/marvell/x86_64-marvell_db* || true
			tar -C device/ -xzf prestera_hwsku.tgz
		fi
	fi
	if [ "$PLATFORM" == "innovium" ]; then
		# Download hwsku
		wget -c --timeout=2 $WGET_PATH/teralynx_hwsku.tgz
		if [ $? -eq 0 ]; then
			rm -fr device/celestica/x86_64-cel_midstone-r0 || true
			rm -fr device/wistron || true
			tar -C device/ -xzf teralynx_hwsku.tgz
		fi
	fi
}

main()
{
	if [ "$CUR_DIR" != "sonic-buildimage" ]; then
		log "ERROR: Need to be at sonic-builimage git clone path"
		pre_patch_help
		exit 1
	fi
	parse_arguments $@

	date > ${FULL_PATH}/${LOG_FILE}
	[ -d patches ] || mkdir patches

	# wget patch series file
	wget --timeout=2 -c $WGET_PATH/series_${PLATFORM}_${ARCH}
	if [ ! -f series_${PLATFORM}_${ARCH} ]; then
		log "ERROR: Series file series_${PLATFORM}_${ARCH} not found"
		exit 1
	fi

	# Apply patch
	log "Apply sonicbuildimage patches"
	apply_sonicbuildimage_patches
	if [ $? -ne 0 ]; then
		log "ERROR: Failed to apply sonicbuildimage patch"
		exit 1
	fi
	git submodule update --init --recursive
	log "Apply submodule patches"
	# Apply submodule patches
	apply_submodule_patches
	if [ $? -ne 0 ]; then
		log "ERROR: Failed to apply submodule patch"
		exit 1
	fi
	log "Apply hwsku changes"
	# Apply hwsku changes
	apply_hwsku_changes
	log "Patch script - DONE"
}

main $@
