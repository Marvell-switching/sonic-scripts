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
	DRY_RUN=$1
	RESULT=0
	cat series_${PLATFORM}_${ARCH}  | grep sonic-buildimage | cut -f 1 -d'|' | while read -r patch_file
do
	echo $patch_file
	pushd patches
	wget --timeout=2 -c $WGET_PATH/$patch_file
	popd
	if [[ $DRY_RUN -eq 1 ]]; then
		git apply --check patches/$patch_file
	else
		git am patches/$patch_file
	fi
	if [ $? -ne 0 ]; then
		log ""
		log "ERROR: Failed to apply patch $patch_file"
		log ""
		RESULT=1
	fi
done
if [ $RESULT -ne 0 ]; then
	exit 1
fi
}

apply_submodule_patches()
{
	DRY_RUN=$1
	RESULT=0
	CWD=`pwd`
	cat series_${PLATFORM}_${ARCH}  | grep -v sonic-buildimage | while read -r line
do
	patch=`echo $line | cut -f 1 -d'|'`
	dir=`echo $line | cut -f 2 -d'|'`
	pushd patches
	wget --timeout=2 -c $WGET_PATH/${patch}
	popd
	pushd ${dir}
	if [[ $DRY_RUN -eq 1 ]]; then
		git apply --check $CWD/patches/${patch}
	else
		git am $CWD/patches/${patch}
	fi
	if [ $? -ne 0 ]; then
		log ""
		log "ERROR: Failed to apply patch ${patch}"
		log ""
		RESULT=1
	fi
	popd
done
if [ $RESULT -ne 0 ]; then
	exit 1
fi
}

apply_hwsku_changes()
{
	if [ "$PLATFORM" == "marvell" ]; then
		# Download hwsku
		wget --timeout=2 -c $WGET_PATH/prestera_hwsku.tgz
		rm -fr device/marvell/x86_64-marvell_db* || true
		tar -C device/marvell/ -xzf prestera_hwsku.tgz
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

	# Dry run apply patch
	PATCH_FAIL=0
	apply_sonicbuildimage_patches 1
	if [ $? -ne 0 ]; then
		PATCH_FAIL=1
	fi
	apply_submodule_patches 1
	if [ $? -ne 0 ]; then
		PATCH_FAIL=1
	fi
	if [ $PATCH_FAIL -ne 0 ]; then
		log ""
		log "Failed patches might need porting to latest commit."
		exit 1
	fi

	# Apply patch
	apply_sonicbuildimage_patches 0
	git submodule update --init --recursive
	# Apply submodule patches
	apply_submodule_patches 0
	# Apply hwsku changes
	apply_hwsku_changes
}

main $@
