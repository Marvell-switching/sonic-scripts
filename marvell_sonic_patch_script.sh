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
err_cnt=0
PATCH_SERIES_FILE=

# VERIFY_PATCHES=Y may be selected by MRVL sonic_build_script.sh
if [[ "$DEVEL" == "" || "$VERIFY_PATCHES" == "Y" ]]; then
  PATCH_ERR_SKIP=
else
  PATCH_ERR_SKIP=Y
fi

log()
{
	echo $@
	echo $@ >> ${FULL_PATH}/${LOG_FILE}
}

print_usage()
{
	log "Usage:"
	log ""
	log " bash $0 --branch <> --platform <marvell|marvell-prestera|innovium|marvell-teralynx> --arch <amd64|arm64> --release-tag <>"
	log ""
	log ""
}

pre_patch_help()
{
	log "STEPS TO BUILD:"
	log "git clone https://github.com/sonic-net/sonic-buildimage.git -b <sonic_branch>"
	log "cd sonic-buildimage"
	log "<<Apply patches using patch script for sonic-buildimage>>"
	log "make init"
	log "git submodule update --init --recursive (instead of make init)"
	log ""
	log "<<Apply patches using patch script for submodules>>"
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
	log "PLATFORM: marvell-teralynx"
	log "<<FOR INTEL>> make configure PLATFORM=marvell-teralynx"
	log "<<FOR INTEL>> make target/sonic-marvell-teralynx.bin"
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

wget_cp()
{
    if [[ "$1" == *:* ]]; then
        # Is URL - use wget     -P dstDir
        wget --timeout=2 -c $1  $2 $3
    else
        # Dir or File is on local path
        dstDir="${3:-.}"
        cp -r $1 $dstDir
    fi
}

apply_sonicbuildimage_patches()
{
 SERIES_FILE=$1
 CSD=$2
 PATCH_DIR=patches/$CSD
 if [ ! -f "$PATCH_DIR/$SERIES_FILE" ]; then
	log "ERROR: $PATCH_DIR/$SERIES_FILE file not found"
    exit 1
 fi
 cat $PATCH_DIR/$SERIES_FILE | grep -v -E '^#|^$' | grep sonic-buildimage | cut -f 1 -d'|' | while read -r patch_file
 do
	echo $patch_file
	pushd $PATCH_DIR
	wget_cp $WGET_PATH/$CSD/$patch_file
	popd
	git am $PATCH_DIR/$patch_file
	ret=$?
	if [ $ret -ne 0 ]; then
        ((err_cnt++))
		if [ "$PATCH_ERR_SKIP" == "" ]; then
			log "PATCH ERROR: Failed to apply sonicbuildimage $PATCH_DIR/$patch_file, abort"
			return $ret
		fi
		log "PATCH ERROR: Failed to apply sonicbuildimage $PATCH_DIR/$patch_file, skeep and continue"
		git am --skip
	fi
 done
}

apply_submodule_patches()
{
 SERIES_FILE=$1
 CSD=$2
 PATCH_DIR=patches/$CSD
 CWD=`pwd`
 cat $PATCH_DIR/$SERIES_FILE | grep -v -E '^#|^$' | grep -v sonic-buildimage | while read -r line
 do
	patch=`echo $line | cut -f 1 -d'|'`
	dir=`echo $line | cut -f 2 -d'|'`
	pushd $PATCH_DIR
	wget_cp $WGET_PATH/$CSD/${patch}
	popd
	pushd ${dir}
	git am $CWD/$PATCH_DIR/${patch}
	ret=$?
	if [ $ret -ne 0 ]; then
        ((err_cnt++))
		if [ "$PATCH_ERR_SKIP" == "" ]; then
			log "PATCH ERROR: Failed to apply submodule $CWD/$PATCH_DIR/${patch}, abort"
			return $ret
		fi
		log "PATCH ERROR: Failed to apply submodule $CWD/$PATCH_DIR/${patch}, skeep and continue"
		git am --skip
	fi
	popd
 done
}

apply_hwsku_changes()
{
	if [ "$PLATFORM" == "marvell" ] || [ "$PLATFORM" == "marvell-prestera" ]; then
		# Download hwsku
		wget_cp $WGET_PATH/prestera_hwsku.tgz -P ./patches/
		if [ $? -eq 0 ]; then
			rm -fr device/marvell/x86_64-marvell_db* || true
			tar -C device/ -xzf ./patches/prestera_hwsku.tgz
		fi
	fi
	if [ "$PLATFORM" == "innovium" ] || [ "$PLATFORM" == "marvell-teralynx" ]; then
		# Download hwsku
		wget_cp $WGET_PATH/teralynx_hwsku.tgz -P ./patches/
		if [ $? -eq 0 ]; then
			rm -fr device/celestica/x86_64-cel_midstone-r0 || true
			rm -fr device/wistron || true
			tar -C device/ -xzf ./patches/teralynx_hwsku.tgz
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
    PATCH_SERIES_FILE=series_${PLATFORM}_${ARCH}
	wget_cp $WGET_PATH/${PATCH_SERIES_FILE} -P ./patches/
	if [ ! -f ${PATCH_SERIES_FILE} ]; then
		PATCH_SERIES_FILE=series_${PLATFORM}
		wget_cp $WGET_PATH/${PATCH_SERIES_FILE} -P ./patches/
		if [ ! -f ./patches/${PATCH_SERIES_FILE} ]; then
			log "ERROR: Series file series_${PLATFORM}_${ARCH} not found"
		    exit 1
		fi
	fi

	# ----- Apply patches -------------------------------
	log "Apply sonicbuildimage patches"
    CSD=.
	apply_sonicbuildimage_patches $PATCH_SERIES_FILE "$CSD" || exit 1

    # CSD - Customer-Set-Directory
    for CSD in tl 1 2 3; do
        case "$CSD" in
            tl) var="PATCH_CUSTOM_TL" ;;
            *)  var="PATCH_CUSTOM_${CSD}" ;;
        esac
        [ "${!var}" = "Y" ] || continue
        wget_cp $WGET_PATH/$CSD/series -P ./patches/$CSD
        apply_sonicbuildimage_patches series "$CSD" || exit 1
    done

	echo "make init" >> build_cmd.txt
	make init
	git submodule sync --recursive
	git submodule update --init --recursive

	log "Apply submodule patches"
	# Apply submodule patches
    CSD=.
	apply_submodule_patches $PATCH_SERIES_FILE "$CSD" || exit 1

    # CSD - Customer-Set-Directory
    for CSD in tl 1 2 3; do
        case "$CSD" in
            tl) var="PATCH_CUSTOM_TL" ;;
            *)  var="PATCH_CUSTOM_${CSD}" ;;
        esac
        [ "${!var}" = "Y" ] || continue
        apply_submodule_patches series "$CSD" || exit 1
    done

	log "Apply hwsku changes"
	# Apply hwsku changes
	apply_hwsku_changes
	log "Patch script - DONE"
}

main $@
