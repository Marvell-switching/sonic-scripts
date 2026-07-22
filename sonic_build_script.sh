#!/bin/bash

# This script is used to automate the build process of Sonic for Marvell platforms
# NOTE: Change CACHE_DIR and ARTIFACTS_DIR as per your requirement.

# arguments
INPUT=$@
BUILD_SAISERVER="${BUILD_SAISERVER:-N}"
BUILD_RPC="${BUILD_RPC:-N}"
OTHER_BUILD_OPTIONS="${OTHER_BUILD_OPTIONS:-}"
NO_CACHE="${NO_CACHE:-N}"
VERIFY_PATCHES="N"
PATCHING_CONFIG_AND_STOP="N"
# l_ -- local to avoid potential collision with sonic-buildimage project rules
l_DEBIAN="bookworm"

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
# Set MIRROR to the public mirror for the build
MIRROR="publicmirror.azurecr.io"
VERSION_CONTROL_COMPONENTS="deb,py2,py3,web,git,docker"
REL_BUILD_TSTAMP=$(date +'%d-%m-%Y_%H-%M')
CACHE_DIR=/var/cache/sonic-mrvl
ARTIFACTS_DIR=/sonic-artifacts
DIR_PREFIX="ABU"
ENABLE_DOCKER_BASE_PULL_YN="ENABLE_DOCKER_BASE_PULL=y"


# Script-debug/trace option "-e"
#set -e

print_usage()
{
    echo "Usage:"
    echo ""
    echo " $0 -b <branch> -p <platform> -a <arch>"
    echo "   [-c <sonic-buildimage_commit>]"
    echo "   [--patch_script <http or full_local path_of_patch_script>]"
    echo "              \__if Not present go with canonic build without patching"
    echo "   [--SAI_VER <virsion number 1.NN.1-K>]"
    echo "   [--SAI <URL or absolute local path to mrvllibsai_*.deb>]"
    echo "   [--eSAI]"
    echo "   [-s] [-r] [--no-cache] [--verify_patches]"
    echo "   [--admin_password <password>] [--other_build_options <sonic_build_options>]"
    echo "   [--mark_no_del_ws] [--clean_dockers] [--clean_ws]"
    echo ""
    echo "    --eSAI: Build with eSAI hwsku and mrvllibsai*.deb"
    echo "    -s : Build docker saiserver v2"
    echo "    -r : ENABLE_SYNCD_RPC=y"
    echo "    -c : checkout commit id"
    echo "    -C : clone, patching, make-CONFIGURE and exit before full make"
    echo "                             (for inspection and re-config)"
    echo "    --tl  -1  -2  -3     Apply Extra patches from customers directories"
    echo "    --no-cache: Build without any pre cache"
    echo "    --other_build_options: Other sonic build options like INCLUDE_ICCPD=y"
    echo "    --verify_patches:    Apply patches, don't compile. Abort on failure"
    echo "        export DEVEL=y   Ignore patch apply failures but continue"
    echo "    --admin_password: Set admin password"
    echo "    --clean_dockers: clean stopped containers"
    echo "    --mark_no_del_ws: Do not cleanup ws during cleanup"
echo """Examples:
./sonic_build_script.sh -b 202411 -p marvell -a arm64 \\
  --patch_script https://github.com/Marvell-switching/sonic-scripts/raw/refs/heads/master/marvell_sonic_patch_script.sh -r \\
  -c 021569412
./sonic_build_script.sh -b master -p marvell-prestera -a arm64 \\
  --patch_script https://github.com/Marvell-switching/sonic-scripts/raw/refs/heads/master/marvell_sonic_patch_script.sh -r \\
  --SAI_VER 1.18.1-1
./sonic_build_script.sh -b 202511 -p marvell-prestera -a amd64 \\
  --patch_script /local-scripts-path/marvell_sonic_patch_script.sh -r
./sonic_build_script.sh -b 202511 -p marvell-prestera -a arm64 \\
  --patch_script /local-scripts-path/marvell_sonic_patch_script.sh -r \\
  --SAI http://192.168.1.2:8080/<path>/mrvllibsai_1.17.1-1_arm64.deb
./sonic_build_script.sh -b 202511 -p marvell-prestera -a arm64 \\
  --patch_script /local-scripts-path/marvell_sonic_patch_script.sh -r \\
  --SAI /local-path/mrvllibsai_1.17.1-1_arm64.deb
"""
echo -e "ARTIFACTS: sonic-buildimage/target/sonic-marvell-prestera-arm64.bin ; build_cmd.txt, build_patches.log\n"
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
            -C)
                PATCHING_CONFIG_AND_STOP="Y"
                shift # past argument
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
            --tl)
                export PATCH_CUSTOM_TL="Y"
                shift # past argument
                ;;
            -1)
                export PATCH_CUSTOM_1="Y"
                shift # past argument
                ;;
            -2)
                export PATCH_CUSTOM_2="Y"
                shift # past argument
                ;;
            -3)
                export PATCH_CUSTOM_3="Y"
                shift # past argument
                ;;
            --url)
                GIT_HUB_URL="$2"
                shift # past argument
                shift # past value
                ;;
            --SAI_VER)
                SAI_VERSION="$2"
                shift # past argument
                shift # past value
                ;;
            --SAI)
                SAI_URL_PATH="$2"
                shift # past argument
                shift # past value
                ;;
            --mvsai) # full command "curl hash URL"
                mvsai_setup "$2"
                shift # past argument
                shift # past value
                ;;
            --eSAI)
                export SAI_SET_ESAI="Y"
                shift # past argument
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

    if [ -z "${LIBSAI_GET_ENA:-}" ] \
        && { [ "${CI_LIBSAI_GET_ENA}" = "Y" ] || [ "${CI_LIBSAI_GET_ENA}" = "y" ]; }; then
        LIBSAI_GET_ENA=Y
        LIBSAI_GET_CMD="${CI_LIBSAI_GET_CMD:-}"
    fi

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
        DIR_PREFIX="ABM"
    fi

    if [ "$BUILD_PLATFORM" == "innovium" ]; then
        PLATFORM_SHORT_NAME="invm"
        DIR_PREFIX="ABI"
    fi

    if [ "$BUILD_PLATFORM" == "marvell-teralynx" ]; then
        PLATFORM_SHORT_NAME="mrvl-teralynx"
        DIR_PREFIX="ABT"
    fi

    if [ "$BUILD_PLATFORM" == "marvell-prestera" ]; then
        PLATFORM_SHORT_NAME="mrvl-prestera"
        DIR_PREFIX="ABP"
    fi

    # TRIXIE overrides
    if [ "${BRANCH}" == "master" ] || [ "${BRANCH}" = "202511" ] || [ "${BRANCH}" = "202601" ]; then
        l_DEBIAN="trixie"
    fi
}

check_privilege_and_arch()
{
    if [[ $EUID -eq 0 ]]; then
        echo "ERROR: build should not run as privileged/root user"
        exit 1
    fi

    # Determine "wrong" architecture sub-string vs MACHINE_ARCH
    MACHINE_ARCH=$(uname -m)
    case "$MACHINE_ARCH" in
        x86_64|i386|i686)
            ARCH_WRONG_SSTR="arm"
            ;;
        aarch64|armv7l|armv8l)
            ARCH_WRONG_SSTR="amd"
            ;;
        *)
            ARCH_WRONG_SSTR="UNKNOWN"
            ;;
    esac
    if [[ "$INPUT" == *"$ARCH_WRONG_SSTR"* ]]; then
        echo "Wrong input. Only NATIVE-ARCH build supported. Check arm vs amd"
        exit 1
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
    n=0
    res=$1

    if [[ "x$NO_CACHE" = "xY" ]]; then
        # Retry would not help, check error directly
        check_error $res $2
        return $res
    fi
    #set +x
    if [[ $res -ne 0 && $SONIC_BUILD_JOBS -ge 1 ]]; then
        sync
        echo 3 | sudo tee /proc/sys/vm/drop_caches
        ((n=n+1))
        echo -e "\n--SONIC_BUILD_JOBS=$SONIC_BUILD_JOBS --------------------------------------------------"
        echo "Error in building $2, going to retry-$n in 20 sec (to abort press CTRL-C)"
        sleep 10
        echo "Error in building $2, going to retry-$n in 10 sec (to abort press CTRL-C)"
        sleep 10
        echo "----------------------------------------------------------------------"
        echo -e "     Retry build $2 started \n\n"
        eval "$3"
        res=$?
    fi
    if [ $res -ne 0 ]; then
        sync
        echo 3 | sudo tee /proc/sys/vm/drop_caches
        ((n=n+1))
        echo -e "\n----------------------------------------------------------------------"
        echo "Error in building $2, going to retry-$n in 20 sec (to abort press CTRL-C)"
        sleep 10
        echo "Error in building $2, going to retry-$n in 10 sec (to abort press CTRL-C)"
        sleep 10
        echo "----------------------------------------------------------------------"
        echo -e "     Retry build $2 started \n\n"
        export SONIC_BUILD_JOBS=1
        eval "$3"
        check_error $? $2
    fi
}

check_free_disk_space()
{
    local dir=$1
    local min_required_free_GB=$2

    # df -H Avail is like "85G" / "512M"; min_required_free_GB is a plain integer (GiB scale).
    local avail_GB
    avail_GB=$(df -h "$dir" | awk 'NR==2 {
        v = $4
        gsub(/,/, "", v)
        if (v ~ /^[0-9.]+G$/)  { sub(/G$/, "", v);  printf "%.0f", v+0;       exit }
        if (v ~ /^[0-9.]+T$/)  { sub(/T$/, "", v);  printf "%.0f", (v+0)*1000; exit }
        if (v ~ /^[0-9.]+M$/)  { sub(/M$/, "", v);  printf "%.0f", (v+0)/1000; exit }
        if (v ~ /^[0-9.]+k$/)  { sub(/k$/, "", v);  print 0;                   exit }
        if (v ~ /^[0-9.]+$/)  { print v+0; exit }
        print 0
    }')

    if ! [[ "$avail_GB" =~ ^[0-9]+$ ]] \
        || ! [[ "$min_required_free_GB" =~ ^[0-9]+$ ]] \
        || [ "$avail_GB" -lt "$min_required_free_GB" ]; then
        echo "Not enough free disk space (avail ~${avail_GB} GB, need >= ${min_required_free_GB} GB)"
        df -h "$dir" | awk '{ print $4 "   " $1 }'
        echo " Try to:"
        echo "  - remove old sonic-buildimage"
        echo "  - clean var-cache: sudo rm -rf /var/cache/sonic/"
        echo "  - clean docker-containers (in /var/lib)"
        echo "     sudo docker container prune -f"
        echo "     sudo docker builder prune -a -f"
        echo "     sudo docker image   prune -a -f"
        echo "     sudo docker volume  prune -a -f"
        echo "     sudo docker system prune -a --volumes -f #most aggressive"
        echo " Check free space after removing by the"
        echo "     df -h ."
        echo ""
        exit 1
    fi
}

cleanup_server()
{
    if [ -v CLEAN_DOCKERS ]; then
        # Remove all stopped containers (sometimes 'sudo' must)
        sudo docker system prune -a --volumes -f
    fi

    # check free disk-space <pwd> <min_required_free_GB>
    check_free_disk_space . 85 #GB
}

clone_ws()
{
    # Clone the Sonic source code
    if [ -z $BRANCH_COMMIT ]; then
        SONIC_SOURCE_DIR=$DIR_PREFIX-$BRANCH-$REL_BUILD_TSTAMP
    else
        SONIC_SOURCE_DIR=$DIR_PREFIX-$BRANCH-$REL_BUILD_TSTAMP-$BRANCH_COMMIT
    fi
    sudo rm -rf $SONIC_SOURCE_DIR
    mkdir $SONIC_SOURCE_DIR
    cd $SONIC_SOURCE_DIR
    if [ -v NO_DEL_WS ]; then
        touch no_del_ws
    fi
    git clone -b $BRANCH $GIT_BRANCH_PARAM $GIT_HUB_URL
    check_error $? "git-clone"
    cd sonic-buildimage
    echo "##Only if needed - clear caches to free disk space:" > build_cmd.txt
    echo "##   docker system prune -a --volumes -f" >> build_cmd.txt
    echo "##   sudo rm -rf /var/cache/sonic-mrvl/"  >> build_cmd.txt
    echo "##OR use --clean_dockers option"   >> build_cmd.txt
    echo "git clone -b $BRANCH $GIT_BRANCH_PARAM $GIT_HUB_URL" >> build_cmd.txt
    if [[ -v BRANCH_COMMIT && $BRANCH_COMMIT != $BRANCH ]]; then
        echo "git checkout $BRANCH_COMMIT" >> build_cmd.txt
        git checkout $BRANCH_COMMIT
        check_error $? "git-checkout-commit"
    fi
    git log -1 > commit_log.txt
}

# commit_id_*
# Function 1: Get and save upstream commit ID
# Function 2: Generate custom COMMIT_ID_STR and update files with sed
commit_id_get_upstream()
{
    export UPSTREAM_ID="$(git rev-parse --short HEAD)"
    export UPSTREAM_COMMIT="$(git log --pretty=format:'%h %cs %an : %s' -1)"
}

commit_id_update()
{
    if [[ -z "$UPSTREAM_ID" ]]; then
        return 0
    fi
    VER_SH_1=build_debian.sh
    VER_SH_2=platform/vs/sonic-version/build_sonic_version.sh
    HEAD_ID="$(git rev-parse --short HEAD)"
    PATCH_COUNT="$(git rev-list --count ${UPSTREAM_ID}..HEAD)"
    export COMMIT_ID_STR="${UPSTREAM_ID} + ${PATCH_COUNT} mrvl-patches"

    for ver_file in ${VER_SH_1} ${VER_SH_2}; do
        if [[ ! -f "$ver_file" ]]; then
            echo "Warning: $ver_file not found for version updated"
            continue
        fi
        sed -i -E "s|^(export commit_id=).*|\1\"${COMMIT_ID_STR}\"|"  "$ver_file"
        echo "Force commit_id: $COMMIT_ID_STR  in file $ver_file"
    done
    echo ""
}

sonic_get_version_patching()
{
    # Replace   local branch_name=$(git rev-parse --abbrev-ref HEAD) by the BRANCH
    local VER_SH=functions.sh
    sed -i "s|^[[:space:]]*local branch_name=.*|    local branch_name=${BRANCH}|" "$VER_SH"
    if [ "${SAI_SET_ESAI}" = "Y" ]; then
        # add "-esai" suffix to end
        sed -i 's#)}" | sed#)}-esai" | sed#' "$VER_SH"
        sed -i 's#${dirty}" | sed#${dirty}-esai" | sed#' "$VER_SH"
    fi
}

mvsai_setup()
{
    LIBSAI_GET_ENA=Y
    LIBSAI_GET_CMD="$1"
    [ -n "$LIBSAI_GET_CMD" ] || exit 1
}

mvsai_run_get_cmd()
{
    [ "${LIBSAI_GET_ENA}" = "Y" ] || return 0
    [ -n "${LIBSAI_GET_CMD:-}" ] || exit 1
    local url

    url=$(printf '%s\n' "$LIBSAI_GET_CMD" | grep -oE 'https?://[^[:space:]"'\''`]+' | tail -1)
    [ -n "$url" ] || exit 1
    LIBSAI_GET_FILE=$(basename "$url")
    LIBSAI_GET_VER=$(printf '%s\n' "$url" | grep -oE 'SAI_[^/]+' | head -1)
    echo "CI download: curl ${LIBSAI_GET_VER}/...${LIBSAI_GET_VER}" >> build_cmd.txt
    eval "$LIBSAI_GET_CMD"
    check_error $? "CI SAI download failed"
    SAI_URL_PATH="$(pwd)/${LIBSAI_GET_FILE}"
}

patch_sai_mk_path()
{
    SAI_MK_FILE=platform/${BUILD_PLATFORM}/sai.mk

    # Handle input --SAI_VER $SAI_VERSION and/or --SAI $SAI_URL_PATH
    #          --SAI_VER 1.17.1-21
    #   URL:   --SAI http://192.168.1.2:8080/<path>/mrvllibsai_1.17.1-1_arm64.deb
    #   Local: --SAI /local-path/mrvllibsai_1.17.1-21_amd64.deb

    if [[ -z "${SAI_VERSION}" && -z "${SAI_URL_PATH}" ]] \
        && [ "${LIBSAI_GET_ENA}" != "Y" ]; then
        return 0
    fi

    if ! [ -z "${SAI_VERSION}" ]; then
        safe_sai_version=${SAI_VERSION//&/\\&}
        sed -i -E \
            "s|^(MRVL_SAI_VERSION =) .*|\1 ${safe_sai_version}|" \
            "${SAI_MK_FILE}" >/dev/null 2>&1
        check_error $? "SAI-VERSION patching"
    fi

    if [ -z "${SAI_URL_PATH}" ] && [ "${LIBSAI_GET_ENA}" != "Y" ]; then
        return 0
    fi
    if [ "${LIBSAI_GET_ENA}" = "Y" ]; then
        mvsai_run_get_cmd
    fi
    if [ -z "${SAI_URL_PATH}" ]; then
        return 0
    fi
    # Local: SONIC_COPY_DEBS runs "cp" inside the Docker slave, host paths are not "visible" for it.
    # The $(CURDIR)/target path exists in the container, so copy the .deb into SAI_STAGE_REL=target/.mrvl-sai-staging
    SAI_DEB_URL=$(dirname "$SAI_URL_PATH")
    SAI_DEB_FILE=$(basename "$SAI_URL_PATH")

    # Escape ampersands for sed
    safe_url_path=${SAI_DEB_URL//&/\\&}
    safe_file_name=${SAI_DEB_FILE//&/\\&}

    if [[ "$SAI_URL_PATH" == /* ]] && [[ "$SAI_URL_PATH" != *"://"* ]]; then
        test -f "$SAI_URL_PATH" && test -r "$SAI_URL_PATH"
        check_error $? "SAI local path missing or not readable"

        SAI_STAGE_REL="${SAI_STAGE_REL:-platform/${BUILD_PLATFORM}/.mrvl-sai-staging}"
        mkdir -p "${SAI_STAGE_REL}"
        check_error $? "SAI local staging mkdir"
        cp -f "$SAI_URL_PATH" "${SAI_STAGE_REL}/${SAI_DEB_FILE}"
        check_error $? "SAI local staging cp"

        staging_mrvl_path="\$(CURDIR)/${SAI_STAGE_REL}"
        sed -i -E \
            -e "s|^MRVL_SAI_URL_PREFIX *=.*|MRVL_SAI_URL_PREFIX = ${staging_mrvl_path}|" \
            -e "s|^MRVL_SAI *=.*|MRVL_SAI = ${safe_file_name}|" \
            -e "s|^\\$\(MRVL_SAI\)_URL *=.*|\$\(MRVL_SAI\)_PATH = \$\(MRVL_SAI_URL_PREFIX\)|" \
            -e "s|^SONIC_ONLINE_DEBS \\+= \\$\(MRVL_SAI\)|SONIC_COPY_DEBS += \$\(MRVL_SAI\)|" \
            "${SAI_MK_FILE}" >/dev/null 2>&1
        check_error $? "SAI-PATH patching"
    else
        # Remote URL ==> sai.mk uses $(MRVL_SAI)_URL
        curl --connect-timeout 2 --max-time 2 -fsIL "$SAI_URL_PATH"
        check_error $? "SAI-URL check"

        sed -i -E \
            -e "s|^MRVL_SAI_URL_PREFIX *=.*|MRVL_SAI_URL_PREFIX = $safe_url_path|" \
            -e "s|^MRVL_SAI *=.*|MRVL_SAI = ${safe_file_name}|" \
            "${SAI_MK_FILE}" >/dev/null 2>&1
        check_error $? "SAI-URL patching"
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
            curl --connect-timeout 2 --speed-time 2 --speed-limit 1 -C - -fsSLO "$PATCH_SCRIPT_URL"
        else
            cp $PATCH_SCRIPT_URL .
        fi
        commit_id_get_upstream
        echo "bash marvell_sonic_patch_script.sh --branch ${BRANCH} --platform ${BUILD_PLATFORM} --arch ${BUILD_PLATFORM_ARCH} --url ${URL}" >> build_cmd.txt
        bash marvell_sonic_patch_script.sh --branch ${BRANCH} --platform ${BUILD_PLATFORM} --arch ${BUILD_PLATFORM_ARCH} --url ${URL}
        check_error $? "patch_script"
        commit_id_update
        sonic_get_version_patching

        patch_sai_mk_path
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
    echo -e "$INPUT\n" > build_args.txt
    echo $BUILD_OPTIONS >> build_args.txt
    echo "" >> build_cmd.txt

    if [ "$BUILD_PLATFORM_ARCH" == "amd64" ]; then
        PLATFORM_ARCH_PARAM=""
    else
        PLATFORM_ARCH_PARAM="PLATFORM_ARCH=${BUILD_PLATFORM_ARCH}"
    fi

    # make configure
    echo "${ENABLE_DOCKER_BASE_PULL_YN} make configure PLATFORM=${BUILD_PLATFORM} $BUILD_OPTIONS ${PLATFORM_ARCH_PARAM}" >> build_cmd.txt
    eval "${ENABLE_DOCKER_BASE_PULL_YN} make configure PLATFORM=${BUILD_PLATFORM} $BUILD_OPTIONS ${PLATFORM_ARCH_PARAM}"
    check_error $? "configure"
    echo "" >> build_cmd.txt

    # make target
    if [ "${BUILD_PLATFORM_ARCH}" == "amd64" ] || [ "${BUILD_PLATFORM}" == "marvell-arm64" ] || [ "${BUILD_PLATFORM}" == "marvell-armhf" ]; then
        TARGET_FILE=sonic-${BUILD_PLATFORM}.bin
        TARGET=target/sonic-${BUILD_PLATFORM}.bin
    else
        TARGET_FILE=sonic-${BUILD_PLATFORM}-${BUILD_PLATFORM_ARCH}.bin
        TARGET=target/sonic-${BUILD_PLATFORM}-${BUILD_PLATFORM_ARCH}.bin
    fi
    echo "make $BUILD_OPTIONS ${TARGET}" >> build_cmd.txt
    sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches
    if [ "$PATCHING_CONFIG_AND_STOP" == "Y" ]; then
        exit 0
    fi
    make $BUILD_OPTIONS ${TARGET}
    check_error_with_retry $? "${TARGET_FILE}" "make $BUILD_OPTIONS ${TARGET}"

    # Build SAI Server
    if [ "$BUILD_SAISERVER" == "Y" ] && [ "$BUILD_PLATFORM_ARCH" != "armhf" ]; then
        echo "make $BUILD_OPTIONS SAITHRIFT_V2=y target/docker-saiserverv2-${PLATFORM_SHORT_NAME}.gz" >> build_cmd.txt
              make $BUILD_OPTIONS SAITHRIFT_V2=y target/docker-saiserverv2-${PLATFORM_SHORT_NAME}.gz
        check_error $? "saiserver"
    fi

    set +x
    local endTime=$SECONDS
    local elapsedseconds=$(( endTime - startTime ))
    echo   "***************************************************"
    printf ' Build took - %dh:%dm:%ds\n' $((elapsedseconds/3600)) $((elapsedseconds%3600/60)) $((elapsedseconds%60))
    echo   "***************************************************"
    cat fsroot-marvell-prestera/etc/sonic/sonic_version.yml 2>/dev/null
    echo ""
    echo "" >> commit_log.txt
    cat fsroot-marvell-prestera/etc/sonic/sonic_version.yml >> commit_log.txt
}

# TODO: Enhance script to delete these artifacts periodically
# TODO: Artifacts list can be improved
copy_build_artifacts()
{
    # Ensure that artifacts is a NFS mount, to avoid modifying permissions of local directories
    if ! grep -s " ${ARTIFACTS_DIR} " /proc/mounts | grep -q "nfs"; then
        echo "-------------------------------------------------------------"
        echo "$ARTIFACTS_DIR is not an NFS mount. No copy_build_artifacts"
        echo "Use files <commit_log.txt>, <build_cmd.txt> and"
        echo "          <${TARGET}>"
        echo "-------------------------------------------------------------"
        return 0
    fi

    BUILD_ARTIFACTS_DIR=${ARTIFACTS_DIR}/${BUILD_PLATFORM_ARCH}/${BRANCH}/${SONIC_SOURCE_DIR}/
    echo "Copy artifacts to ${ARTIFACTS_DIR}/${BUILD_PLATFORM_ARCH}/${BRANCH}/${SONIC_SOURCE_DIR}/ ..."
    # $ARTIFACTS_DIR is a shared mount across different Linux users.
    # If any user creates a directory with read-only permissions all subsequent inner directory creation fails,
    # to avoid such issues, set permissions before any copy.
    # Caution: depending upon network the recursive -R for whole ARTIFACTS_DIR became blocking
    #if [ "$BUILD_PLATFORM" == "marvell-teralynx" ]; then
    #    sudo chmod -R 777 ${ARTIFACTS_DIR} 2>&-
    #fi
    sudo mkdir -p -m 777 $BUILD_ARTIFACTS_DIR  2>&-

    cp commit_log.txt $BUILD_ARTIFACTS_DIR
    cp build_args.txt $BUILD_ARTIFACTS_DIR
    cp build_cmd.txt $BUILD_ARTIFACTS_DIR
    cp ${TARGET} $BUILD_ARTIFACTS_DIR
    #cp target/debs/${l_DEBIAN}/sonic-platform-*.deb $BUILD_ARTIFACTS_DIR
    if [ "$BUILD_SAISERVER" == "Y" ]; then
        cp target/docker-saiserverv2-${PLATFORM_SHORT_NAME}.gz $BUILD_ARTIFACTS_DIR
    fi
    echo "                           copy artifacts done"
}

main()
{
    parse_arguments $INPUT
    check_privilege_and_arch
    # Shell-script DEBUG setting
    # set -x

    cleanup_server

    clone_ws

    patch_ws
    if [ "$VERIFY_PATCHES" == "Y" ]; then
        exit 0
    fi
    if [ "${l_DEBIAN}" == "bookworm" ] ||  [ "${l_DEBIAN}" == "trixie" ]; then
        echo "export NOJESSIE=1"   >> build_cmd.txt
        echo "export NOSTRETCH=1"  >> build_cmd.txt
        echo "export NOBUSTER=1"   >> build_cmd.txt
        echo "export NOBULLSEYE=1" >> build_cmd.txt
        export NOJESSIE=1
        export NOSTRETCH=1
        export NOBUSTER=1
        export NOBULLSEYE=1
        export SONIC_BUILD_JOBS="${SONIC_BUILD_JOBS:-8}"
        echo "export SONIC_BUILD_JOBS=${SONIC_BUILD_JOBS}" >> build_cmd.txt
        #export SONIC_IMAGE_VERSION=SONIC-OS-${SONIC_SOURCE_DIR}
        #echo "export SONIC_IMAGE_VERSION=SONIC-OS-${SONIC_SOURCE_DIR}" >> build_cmd.txt
        if [ "${l_DEBIAN}" == "trixie" ]; then
            echo "export NOBOOKWORM=0" >> build_cmd.txt
            echo "export NOTRIXIE=0" >> build_cmd.txt
            export NOBOOKWORM=0
            export NOTRIXIE=0
        fi
    fi
    build_ws
    set +x

    copy_build_artifacts

    echo -e "\n\n Build Successful \n\n"
    exit 0
}

main $INPUT
