#!/bin/bash

# This script is used to automate the build process of Sonic for Marvell platforms
# NOTE: Change CACHE_DIR and ARTIFACTS_DIR as per your requirement.

# arguments
BUILD_SAISERVER="N"
BUILD_RPC="N"
OTHER_BUILD_OPTIONS=""
NO_CACHE="N"
VERIFY_PATCHES="N"
DEBIAN="bookworm"

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
# Set MIRROR to the public mirror for the build
MIRROR="publicmirror.azurecr.io"
VERSION_CONTROL_COMPONENTS="deb,py2,py3,web,git,docker"
REL_BUILD_TSTAMP=$(date +'%d-%m-%Y_%H-%M')
CACHE_DIR=/var/cache/sonic-mrvl
ARTIFACTS_DIR=/sonic-artifacts

# Script-debug/trace option "-e"
#set -e

print_usage()
{
    echo "Usage:"
    echo ""
    echo " $0 -b <branch> -p <platform> -a <arch>"
    echo "   [-c <sonic-buildimage_commit>]"
    echo "   [--patch_script <http or full_local path_of_patch_script>]"
    echo "   [--url <sonic-buildimage_url>]"
    echo "   [-s] [-r] [--mark_no_del_ws] [--no-cache]"
    echo "   [--admin_password <password>] [--other_build_options <sonic_build_options>]"
    echo "   [--verify_patches] [--clean_dockers] [--clean_ws]"
    echo ""
    echo "    -s : Build docker saiserver v2"
    echo "    -r : ENABLE_SYNCD_RPC=y"
    echo "    -c : checkout commit id"
    echo "    --no-cache: Build without any pre cache"
    echo "    --mark_no_del_ws: Do not cleanup ws during cleanup"
    echo "    --admin_password: Set admin password"
    echo "    --other_build_options: Other sonic build options"
    echo "    --verify_patches:    Apply patches, don't compile. Abort on failure"
    echo "        export DEVEL=y   Ignore patch apply failures but continue"
    echo "    --clean_dockers: clean up build dockers"
echo """
Example:
./sonic_build_script.sh -b 202411 -p marvell -a arm64 \\
  --patch_script https://github.com/Marvell-switching/sonic-scripts/raw/refs/heads/master/marvell_sonic_patch_script.sh -r \\
  -c 021569412
./sonic_build_script.sh -b master -p marvell -a arm64 \\
  --patch_script https://github.com/Marvell-switching/sonic-scripts/raw/refs/heads/master/marvell_sonic_patch_script.sh -r
./sonic_build_script.sh -b master -p marvell -a arm64 \\
  --patch_script /wrk/sonic-scripts/marvell_sonic_patch_script.sh -r
"""
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
                BUILD_PLATFORM="$2"
                shift # past argument
                shift # past value
                ;;
            -a|--arch)
                BUILD_PLATFORM_ARCH="$2"
                shift # past argument
                shift # past value
                ;;
            -c|--commit)
                BRANCH_COMMIT="$2"
                shift # past argument
                shift # past value
                ;;
            -s|--saiserver)
                BUILD_SAISERVER="Y"
                shift # past argument
                ;;
            -r|--rpc)
                BUILD_RPC="Y"
                shift # past argument
                ;;
            --no-cache)
                NO_CACHE="Y"
                shift # past argument
                ;;
            --mark_no_del_ws)
                NO_DEL_WS="Y"
                shift # past argument
                ;;
            --patch_script)
                PATCH_SCRIPT_URL="$2"
                shift # past argument
                shift # past value
                ;;
            --url)
                GIT_HUB_URL="$2"
                shift # past argument
                shift # past value
                ;;
            --admin_password)
                ADMIN_PASSWORD="$2"
                shift # past argument
                shift # past value
                ;;
            --other_build_options)
                OTHER_BUILD_OPTIONS="$2"
                shift # past argument
                shift # past value
                ;;
            --verify_patches)
                VERIFY_PATCHES="Y"
                shift # past argument
                ;;
            --clean_dockers)
                CLEAN_DOCKERS="Y"
                shift # past argument
                ;;
            --clean_ws)
                CLEAN_WS="Y"
                shift # past argument
                ;;
            -h|--help)
                print_usage
                exit 1
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

    if [ -z "${BUILD_PLATFORM}" ]; then
        echo "Platform target is not set. Please check usage."
        print_usage
        exit 0
    fi

    if [ -z "${BUILD_PLATFORM_ARCH}" ]; then
        echo "Architecture target is not set. Please check usage."
        print_usage
        exit 0
    fi

    if [ -z "${GIT_HUB_URL}" ]; then
        GIT_HUB_URL="https://github.com/sonic-net/sonic-buildimage.git"
    fi

    if [ "${BUILD_PLATFORM}" == "marvell" ] || [ "${BUILD_PLATFORM}" == "marvell-arm64" ] || [ "${BUILD_PLATFORM}" == "marvell-armhf" ]; then
        PLATFORM_SHORT_NAME="mrvl"
    fi

    if [ "$BUILD_PLATFORM" == "innovium" ]; then
        PLATFORM_SHORT_NAME="invm"
    fi

    if [ "$BUILD_PLATFORM" == "marvell-teralynx" ]; then
        PLATFORM_SHORT_NAME="mrvl-teralynx"
    fi

    if [ "$BUILD_PLATFORM" == "marvell-prestera" ]; then
        PLATFORM_SHORT_NAME="mrvl-prestera"
    fi
}

on_error()
{
    set +x
    cd $DIR
    mv $SONIC_SOURCE_DIR $SONIC_SOURCE_DIR-err
    echo -e "\n\n--- `date` --- Build Error ---------\n\n"
    exit 1
}

check_error()
{
    if [ $1 -ne 0 ]; then
        set +x
        echo "Error in building - $2"
        on_error
    else
        echo -e "\n--------- $2   passed ---------\n\n\n"
    fi
}

check_error_with_retry()
{
    set +x
    if [ $1 -ne 0 ]; then
        sync
        echo 3 | sudo tee /proc/sys/vm/drop_caches
        echo -e "\n----------------------------------------------------------------------"
        echo "Error in building $2, going to retry in 30 sec (to abort press CTRL-C)"
        sleep 10
        echo "Error in building $2, going to retry in 20 sec (to abort press CTRL-C)"
        sleep 10
        echo "Error in building $2, going to retry in 10 sec (to abort press CTRL-C)"
        sleep 10
        echo "----------------------------------------------------------------------"
        echo -e "     Retry build $2 started \n\n"
        export SONIC_BUILD_JOBS=1
        eval "$3"
        check_error $? $2
    fi
}

check_free_space()
{
    local dir=$1
    local ALERT=$2

	if [ -v CLEAN_WS ]; then
	  df -H $dir | grep -vE '^Filesystem' | awk '{ print $5 " " $1 }' | while read -r output;
	  do
		echo "$output"
		usep=$(echo "$output" | awk '{ print $1}' | cut -d'%' -f1 )
		partition=$(echo "$output" | awk '{ print $2 }' )
		if [ $usep -ge $ALERT ]; then
			echo "Running out of space \"$partition ($usep%)\" on $(hostname) as on $(date)" |
				ls -1  | grep "ABT-" | grep "-err" | while read -r dir_name;
						do
							echo "Removing $dir_name"
							if [ ! -f $dir_name/no_del_ws ]; then
								sudo rm -rf $dir_name
							fi
						done
						# Check space again after removing errored build
						df -H $dir | grep -vE '^Filesystem' | awk '{ print $5 " " $1 }' | while read -r output_new;
					do
						echo "$output_new"
						usep=$(echo "$output_new" | awk '{ print $1}' | cut -d'%' -f1 )
						if [ $usep -ge $ALERT ]; then
							# Remove build dirs
							ls -1  | grep "ABT-" | while read -r dir_name;
						do
							echo "Removing $dir_name"
							if [ ! -f $dir_name/no_del_ws ]; then
								sudo rm -rf $dir_name
							fi
						done
						fi
					done
		fi
	  done
	fi

df -H $dir | grep -vE '^Filesystem' | awk '{ print $5 " " $1 }' | while read -r output;
do
    usep=$(echo "$output" | awk '{ print $1}' | cut -d'%' -f1 )
    if [ $usep -ge $ALERT ]; then
        echo "Not enough space. Please check build server to free space."
        echo "Optionally you can use --clean_dockers or --clean_ws after pushing your local changes"
        exit 1
    fi
done
}

cleanup_server()
{
    if [ -v CLEAN_DOCKERS ]; then
        # Remove all stopped containers
        docker system prune -a --volumes -f
    fi

    # check for disk space and cleanup
    check_free_space . 65
}

clone_ws()
{
    # Clone the Sonic source code
    if [ -z $BRANCH_COMMIT ]; then
        SONIC_SOURCE_DIR=ABT-$BRANCH-$REL_BUILD_TSTAMP
    else
        SONIC_SOURCE_DIR=ABT-$BRANCH-$BRANCH_COMMIT
    fi
    sudo rm -rf $SONIC_SOURCE_DIR
    mkdir $SONIC_SOURCE_DIR
    cd $SONIC_SOURCE_DIR
    if [ -v NO_DEL_WS ]; then
        touch no_del_ws
    fi
    git clone -b $BRANCH $GIT_HUB_URL
    check_error $? "git-clone"
    cd sonic-buildimage
    echo "##Only if needed - clear caches to free disk space:" > build_cmd.txt
    echo "##   docker system prune -a --volumes -f" >> build_cmd.txt
    echo "##   sudo rm -rf /var/cache/sonic-mrvl/"  >> build_cmd.txt
    echo "##OR use --clean_dockers option"   >> build_cmd.txt
    echo "git clone -b $BRANCH $GIT_HUB_URL" >> build_cmd.txt
    if [[ -v BRANCH_COMMIT && $BRANCH_COMMIT != $BRANCH ]]; then
        echo "git checkout $BRANCH_COMMIT" >> build_cmd.txt
        git checkout $BRANCH_COMMIT
        check_error $? "git-checkout-commit"
    fi
    git log -1 > commit_log.txt

    if [ "${BRANCH}" == "202311" ] || [ "${BRANCH}" == "202305" ] || [ "${BRANCH}" == "202211" ]; then
        DEBIAN="bullseye"
    else
        DEBIAN="bookworm"
    fi
}

patch_ws()
{
    if [ -v PATCH_SCRIPT_URL ]; then
        if [[ "$PATCH_SCRIPT_URL" == *:* ]]; then
            isUrl=1
        else
            isUrl=
        fi
        URL=${PATCH_SCRIPT_URL%marvell_sonic_patch_script.sh}
        if [ "$isUrl" = "1" ]; then
            wget --timeout=2 -c $PATCH_SCRIPT_URL
        else
            cp $PATCH_SCRIPT_URL .
        fi
        echo "bash marvell_sonic_patch_script.sh --branch ${BRANCH} --platform ${BUILD_PLATFORM} --arch ${BUILD_PLATFORM_ARCH} --url ${URL}" >> build_cmd.txt
        bash marvell_sonic_patch_script.sh --branch ${BRANCH} --platform ${BUILD_PLATFORM} --arch ${BUILD_PLATFORM_ARCH} --url ${URL}
        check_error $? "patch_script"
    fi
}

build_ws()
{
    local startTime=$SECONDS

    # Set the build options
    mkdir -p $CACHE_DIR/$BRANCH/$BUILD_PLATFORM_ARCH
    BUILD_OPTIONS=""
    if [ "$NO_CACHE" == "N" ]; then
        BUILD_OPTIONS="DEFAULT_CONTAINER_REGISTRY=${MIRROR} SONIC_VERSION_CONTROL_COMPONENTS=${VERSION_CONTROL_COMPONENTS} SONIC_DPKG_CACHE_METHOD=rwcache SONIC_DPKG_CACHE_SOURCE=$CACHE_DIR/$BRANCH/$BUILD_PLATFORM_ARCH/"
    fi
    if [ "$BUILD_RPC" == "Y" ]; then
        if [ "$BUILD_PLATFORM_ARCH" != "armhf" ]; then
            BUILD_OPTIONS="${BUILD_OPTIONS} ENABLE_SYNCD_RPC=y"
        fi
    fi
    if [[ ! -z ${OTHER_BUILD_OPTIONS} ]]; then
        BUILD_OPTIONS="${BUILD_OPTIONS} ${OTHER_BUILD_OPTIONS}"
    fi
    if [[ ! -z ${ADMIN_PASSWORD} ]]; then
        BUILD_OPTIONS="${BUILD_OPTIONS} DEFAULT_PASSWORD=${ADMIN_PASSWORD}"
    fi

    # Check the init has already been done by marvell_sonic_patch_script.sh
    if [ ! -d .git/modules/ ]; then
        echo "make init" >> build_cmd.txt
        make init
        check_error $? "make_init"
        # Fetch/expose advanced submodule hashes which are not taken by "make init"
        git submodule foreach --recursive 'git fetch --all'
    fi

    # Build Sonic
    echo $BUILD_OPTIONS > build_args.txt
    echo "" >> build_cmd.txt
    if [ "$BUILD_PLATFORM_ARCH" == "amd64" ]; then
        echo "ENABLE_DOCKER_BASE_PULL=y make configure PLATFORM=${BUILD_PLATFORM} $BUILD_OPTIONS" >> build_cmd.txt
        ENABLE_DOCKER_BASE_PULL=y make configure PLATFORM=${BUILD_PLATFORM} $BUILD_OPTIONS
        check_error $? "configure"
        echo "" >> build_cmd.txt
        echo "make $BUILD_OPTIONS target/sonic-${BUILD_PLATFORM}.bin" >> build_cmd.txt
        sync
        echo 3 | sudo tee /proc/sys/vm/drop_caches
        make $BUILD_OPTIONS target/sonic-${BUILD_PLATFORM}.bin
        check_error_with_retry $? "sonic-${BUILD_PLATFORM}.bin" "make $BUILD_OPTIONS target/sonic-${BUILD_PLATFORM}.bin"
    else
        echo "ENABLE_DOCKER_BASE_PULL=y make configure PLATFORM=${BUILD_PLATFORM} PLATFORM_ARCH=${BUILD_PLATFORM_ARCH} $BUILD_OPTIONS" >> build_cmd.txt
        ENABLE_DOCKER_BASE_PULL=y make configure PLATFORM=${BUILD_PLATFORM} PLATFORM_ARCH=${BUILD_PLATFORM_ARCH} $BUILD_OPTIONS
        check_error $? "configure"
        if [ "${BUILD_PLATFORM}" == "marvell-arm64" ] || [ "${BUILD_PLATFORM}" == "marvell-armhf" ]; then
            echo "" >> build_cmd.txt
            echo "make $BUILD_OPTIONS target/sonic-${BUILD_PLATFORM}.bin" >> build_cmd.txt
            sync
            echo 3 | sudo tee /proc/sys/vm/drop_caches
            make $BUILD_OPTIONS target/sonic-${BUILD_PLATFORM}.bin
            check_error_with_retry $? "sonic-${BUILD_PLATFORM}.bin" "make $BUILD_OPTIONS target/sonic-${BUILD_PLATFORM}.bin"
        else
            echo "" >> build_cmd.txt
            echo "make $BUILD_OPTIONS target/sonic-${BUILD_PLATFORM}-${BUILD_PLATFORM_ARCH}.bin" >> build_cmd.txt
            sync
            echo 3 | sudo tee /proc/sys/vm/drop_caches
            make $BUILD_OPTIONS target/sonic-${BUILD_PLATFORM}-${BUILD_PLATFORM_ARCH}.bin
            check_error_with_retry $? "sonic-${BUILD_PLATFORM}-${BUILD_PLATFORM_ARCH}.bin" "make $BUILD_OPTIONS target/sonic-${BUILD_PLATFORM}-${BUILD_PLATFORM_ARCH}.bin"
        fi
    fi

    # Build SAI Server
    if [ "$BUILD_SAISERVER" == "Y" ]; then
        if [ "$BUILD_PLATFORM_ARCH" != "armhf" ]; then
            echo "make $BUILD_OPTIONS SAITHRIFT_V2=y target/docker-saiserverv2-${PLATFORM_SHORT_NAME}.gz" >> build_cmd.txt
            make $BUILD_OPTIONS SAITHRIFT_V2=y target/docker-saiserverv2-${PLATFORM_SHORT_NAME}.gz
            check_error $? "saiserver"
        fi
    fi

    set +x
    local endTime=$SECONDS
    local elapsedseconds=$(( endTime - startTime ))
    echo    "***************************************************"
    printf ' Build took - %dh:%dm:%ds\n' $((elapsedseconds/3600)) $((elapsedseconds%3600/60)) $((elapsedseconds%60))
    echo -e "***************************************************\n\n"
}

# TODO: Enhance script to delete these artifacts periodically
# TODO: Artifacts list can be improved
copy_build_artifacts()
{
    # Ensure that artifacts is a NFS mount, to avoid modifying permissions of local directories
    if ! grep -s " ${ARTIFACTS_DIR} " /proc/mounts | grep -q "nfs"; then
        echo "$ARTIFACTS_DIR is not an NFS mount. Copy to artifacts directory failed"
        return 1
    fi

    BUILD_ARTIFACTS_DIR=${ARTIFACTS_DIR}/${BUILD_PLATFORM_ARCH}/${BRANCH}/${SONIC_SOURCE_DIR}/
    # $ARTIFACTS_DIR is a shared mount across different Linux users.
    # If any user creates a directory with read-only permissions all subsequent inner directory creation fails,
    # to avoid such issues, set permissions before any copy.
    sudo chmod -R 777 ${ARTIFACTS_DIR} 2>&-
    mkdir -p $BUILD_ARTIFACTS_DIR
    cp commit_log.txt $BUILD_ARTIFACTS_DIR
    cp build_args.txt $BUILD_ARTIFACTS_DIR
    if [ "${BUILD_PLATFORM_ARCH}" == "amd64" ] || [ "${BUILD_PLATFORM}" == "marvell-arm64" ] || [ "${BUILD_PLATFORM}" == "marvell-armhf" ]; then
        cp target/sonic-${BUILD_PLATFORM}.bin $BUILD_ARTIFACTS_DIR
    else
        cp target/sonic-${BUILD_PLATFORM}-${BUILD_PLATFORM_ARCH}.bin $BUILD_ARTIFACTS_DIR
    fi
    cp target/debs/${DEBIAN}/swss-dbg_1.0.0_*.deb $BUILD_ARTIFACTS_DIR
    cp target/debs/${DEBIAN}/sonic-platform-*.deb $BUILD_ARTIFACTS_DIR
    if [ "$BUILD_SAISERVER" == "Y" ]; then
        cp target/docker-saiserverv2-${PLATFORM_SHORT_NAME}.gz $BUILD_ARTIFACTS_DIR
    fi
}

main()
{
    parse_arguments $@
    # Shell-script DEBUG setting
    # set -x

    cleanup_server

    clone_ws

    patch_ws
    if [ "$VERIFY_PATCHES" == "Y" ]; then
        exit 0
    fi
    if [ "${DEBIAN}" == "bookworm" ]; then
        echo "export NOJESSIE=1"   >> build_cmd.txt
        echo "export NOSTRETCH=1"  >> build_cmd.txt
        echo "export NOBUSTER=1"   >> build_cmd.txt
        echo "export NOBULLSEYE=1" >> build_cmd.txt
        export NOJESSIE=1
        export NOSTRETCH=1
        export NOBUSTER=1
        export NOBULLSEYE=1
    fi
    build_ws
    set +x

    copy_build_artifacts

    echo -e "\n\n Build Successful \n\n"
    exit 0
}

main $@
