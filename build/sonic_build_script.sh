#!/bin/bash

# This script is used to automate the build process of Sonic for Marvell platforms
# NOTE: Change CACHE_DIR and ARTIFACTS_DIR as per your requirement.

# arguments
BUILD_SAISERVER="N"
BUILD_RPC="N"
OTHER_BUILD_OPTIONS=""
NO_CACHE="N"

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
# Set MIRROR to the public mirror for the build
MIRROR="publicmirror.azurecr.io"
VERSION_CONTROL_COMPONENTS="deb,py2,py3,web,git,docker"
REL_BUILD_TSTAMP=$(date +%s)
CACHE_DIR=/var/cache/sonic-mrvl
ARTIFACTS_DIR=/sonic-artifacts

#set -e

print_usage()
{
    echo "Usage:"
    echo ""
    echo " $0 -b <branch> -p <platform> -a <arch> [-c <sonic-buildimage_commit>] [--patch_script <http_path_of_patch_script>] [--url <sonic-buildimage_url>] [-s] [-r] [--mark_no_del_ws] [--no-cache] [--admin_password <password>] [--other_build_options <sonic_build_options>]"
    echo ""
    echo "				-s : Build docker saiserver v2"
    echo "				-r : ENABLE_SYNCD_RPC=y"
    echo "				-c : checkout commit id"
    echo "				--no-cache: Build without any pre cache"
    echo "				--mark_no_del_ws: Do not cleanup ws during cleanup"
    echo "				--admin_password: Set admin password"
    echo "				--other_build_options: Other sonic build options"
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

    if [ "$BUILD_PLATFORM" == "marvell" ]; then
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
    cd $DIR
    mv $SONIC_SOURCE_DIR $SONIC_SOURCE_DIR-err
    echo "\n\nBuild Error\n\n"
    exit 1
}

check_error()
{
    if [ $1 -ne 0 ]; then
        echo "Error in building - $2"
        on_error
    fi
}

check_free_space()
{
    local dir=$1
    local ALERT=$2

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

df -H $dir | grep -vE '^Filesystem' | awk '{ print $5 " " $1 }' | while read -r output;
do
    usep=$(echo "$output" | awk '{ print $1}' | cut -d'%' -f1 )
    if [ $usep -ge $ALERT ]; then
        echo "Not enough space. Please check build server to free space."
        exit 1
    fi
done
}

cleanup_server()
{
    # Remove all stopped containers
    docker system prune -a --volumes -f

    # check for disk space and cleanup
    check_free_space . 65
}

clone_ws()
{
    # Clone the Sonic source code
    SONIC_SOURCE_DIR=ABT-$BRANCH-$REL_BUILD_TSTAMP
    sudo rm -rf $SONIC_SOURCE_DIR
    mkdir $SONIC_SOURCE_DIR
    cd $SONIC_SOURCE_DIR
    if [ -v NO_DEL_WS ]; then
        touch no_del_ws
    fi
    git clone -b $BRANCH $GIT_HUB_URL
    check_error $? "git-clone"
    cd sonic-buildimage
    if [ -v BRANCH_COMMIT ]; then
        git checkout $BRANCH_COMMIT
    fi
    make init
    check_error $? "make_init"
    git log -1 > commit_log.txt
}

patch_ws()
{
    if [ -v PATCH_SCRIPT_URL ]; then
        wget --timeout=2 -c $PATCH_SCRIPT_URL
        URL=${PATCH_SCRIPT_URL%marvell_sonic_patch_script.sh}
        if [ "$BRANCH" == "master" ]; then
            PATCH_BRANCH="master-bookworm"
        else
            PATCH_BRANCH=${BRANCH}
        fi
        bash marvell_sonic_patch_script.sh --branch ${PATCH_BRANCH} --platform ${BUILD_PLATFORM} --arch ${BUILD_PLATFORM_ARCH} --url ${URL}
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

    # Build Sonic
    echo $BUILD_OPTIONS > build_args.txt
    if [ "$BUILD_PLATFORM_ARCH" == "amd64" ]; then
        ENABLE_DOCKER_BASE_PULL=y make configure PLATFORM=${BUILD_PLATFORM} $BUILD_OPTIONS
        check_error $? "configure"
        make $BUILD_OPTIONS target/sonic-${BUILD_PLATFORM}.bin
        check_error $? "sonic-${BUILD_PLATFORM}.bin"
    else
        ENABLE_DOCKER_BASE_PULL=y make configure PLATFORM=${BUILD_PLATFORM} PLATFORM_ARCH=${BUILD_PLATFORM_ARCH} $BUILD_OPTIONS
        check_error $? "configure"
        make $BUILD_OPTIONS target/sonic-${BUILD_PLATFORM}-${BUILD_PLATFORM_ARCH}.bin
        check_error $? "sonic-${BUILD_PLATFORM}-${BUILD_PLATFORM_ARCH}.bin"
    fi

    # Build SAI Server
    if [ "$BUILD_SAISERVER" == "Y" ]; then
        make $BUILD_OPTIONS SAITHRIFT_V2=y target/docker-saiserverv2-${PLATFORM_SHORT_NAME}.gz
        check_error $? "saiserver"
    fi

    local endTime=$SECONDS
    local elapsedseconds=$(( endTime - startTime ))
    echo "***************************************************"
    printf ' Build took - %dh:%dm:%ds\n' $((elapsedseconds/3600)) $((elapsedseconds%3600/60)) $((elapsedseconds%60))
    echo "***************************************************"
}

# TODO: Enhance script to delete these artifacts periodically
# TODO: Artifacts list can be improved
copy_build_artifacts()
{
    if [ "$BRANCH" == "202311" ] | [ "$BRANCH" == "202305" ] | [ "$BRANCH" == "202211" ]; then
        DEBIAN="bullseye"
    else
        DEBIAN="bookworm"
    fi
    BUILD_ARTIFACTS_DIR=$ARTIFACTS_DIR/$BUILD_PLATFORM_ARCH/$BRANCH/$SONIC_SOURCE_DIR/
    mkdir -p $BUILD_ARTIFACTS_DIR
    cp commit_log.txt $BUILD_ARTIFACTS_DIR
    cp build_args.txt $BUILD_ARTIFACTS_DIR
    if [ "$BUILD_PLATFORM_ARCH" == "amd64" ]; then
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

    set -x
    cleanup_server

    clone_ws

    patch_ws

    build_ws
    set +x

    copy_build_artifacts

    echo "\n\n Build Successful \n\n"
    exit 0
}

main $@
