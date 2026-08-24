# Marvell eSAI 1.1.0 SONiC Build Toolset

<a href="https://www.marvell.com/"><img src="https://www.marvell.com/content/dam/marvell/en/rebrand/marvell-logo3.svg" alt="Marvell Technologies" width="200"></a>

## Marvell portal deliverables

Upload the following files to the Marvell customer portal:

**My Products → Switching → Software → SAI → SAI-Campus → SAI-C1-1-0**

| File | Description |
|------|-------------|
| `create-script-tarball-e110.sh` | Builds `r_e110.tar.gz` from the `sonic-scripts` repo (`build-utils/create-script-tarball-e110.sh`). |
| `sbuild_r_e110.sh` | Release build wrapper with frozen eSAI 1.1.0 defaults; calls `sonic_build_script.sh`. Also included inside `r_e110.tar.gz`. |
| `r_e110.tar.gz` | SONiC eSAI 1.1.0 build toolset (scripts, patches, HWSKU). See [Package contents](#package-contents-r_e110targz). |
| `README_eSAI.md` | User guide (this document). Also included inside `r_e110.tar.gz`. |
| `mrvllibsai_1.18.1-110_arm64.deb` | eSAI binary package (`libsai.so`) for arm64. Used at build time via `--SAI`; see [eSAI Package Binding](#esai-package-binding-into-sonic-build). |
| `sonic-marvell-prestera-arm64.bin` | Pre-built SONiC image for ONIE install on AC5X-RD / AC5P-RD (optional; customers may build their own with `r_e110.tar.gz`). |

**Portal scope:** arm64, AC5X-RD (qualified) and AC5P-RD (not yet qualified). See [Supported Boards](#supported-boards).

**Not uploaded to the portal** (hosted on GitHub for build references):

| Item | Location |
|------|----------|
| `sonic-scripts` (patches, toolset source) | Branch `esai-202605-c110-aug12-candidate` |
| `sonic-marvell-binaries` (eSAI deb mirror) | Branch `esai-202605-c110-aug12-candidate` |
| Upstream SONiC base | `sonic-buildimage` branch `202605`, commit `3d22ec9` |

## Contents

- [Marvell portal deliverables](#marvell-portal-deliverables)
- [Quick Start](#quick-start)
- [General & Purpose](#general--purpose)
- [Supported Boards](#supported-boards)
- [GitHub Links](#github-links)
- [Marvell GitHub Repositories](#marvell-github-repositories)
- [Build Server Requirements](#build-server-requirements)
- [Getting Started](#getting-started)
- [Build Flows](#build-flows)
- [Toolset Tree](#toolset-tree)
- [Patch Sets](#patch-sets)
- [`sonic_build_script.sh` Command-Line Options](#sonic_build_scriptsh-command-line-options)
- [Advanced build with `sonic_build_script.sh`](#advanced-build-with-sonic_build_scriptsh)
- [eSAI Package Binding into SONiC Build](#esai-package-binding-into-sonic-build)
- [Customer Release Package — Create and Use](#customer-release-package--create-and-use)
- [Build Output and Workspace](#build-output-and-workspace)
- [Install on AC5X-RD / AC5P-RD](#install-on-ac5x-rd--ac5p-rd)
- [Troubleshooting](#troubleshooting)
- [Frequently Asked Questions (FAQ)](#frequently-asked-questions-faq)

## Quick Start

**Scope:** arm64 only — **AC5X-RD** (qualified) and **AC5P-RD** (not yet qualified). See [Supported Boards](#supported-boards).

### Build SONiC image

On a native **ARM64** build server (see [Build Server Requirements](#build-server-requirements)):

```bash
tar xzf r_e110.tar.gz
cd <extract-dir>
./sbuild_r_e110.sh
```

Output: `ABP-202605-*-esai/sonic-buildimage/target/sonic-marvell-prestera-arm64.bin` (~3–4 hours).

Optional first step: run with `--verify_patches` to apply patches only — see [Getting Started](#getting-started).

For manual options and flags, see [Recommended build command](#recommended-build-command) and [Advanced build with `sonic_build_script.sh`](#advanced-build-with-sonic_build_scriptsh).

### Install on board

Serve the `.bin` over HTTP and from **ONIE**:

```bash
onie-nos-install http://<server>/sonic-marvell-prestera-arm64.bin
```

Then `show platform summary` and `show version`. Details: [Install on AC5X-RD / AC5P-RD](#install-on-ac5x-rd--ac5p-rd).

### If Marvell supplies a pre-built image

Skip the build step and install `sonic-marvell-prestera-arm64.bin` directly via ONIE.

### Problems?

See [Troubleshooting](#troubleshooting).

## General & Purpose

This document describes the **Marvell eSAI 1.1.0 SONiC build toolset** for **AC5X-RD** and **AC5P-RD** on **arm64**.

eSAI (enhanced Switch Abstraction Interface) is Marvell's next-generation SAI implementation for Prestera switching silicon. It implements the open [SAI API](https://github.com/opencomputeproject/SAI) and integrates with SONiC via `libsai.so`.

The build process for `marvell-prestera` / arm64 includes:

1. Clone [sonic-buildimage](https://github.com/sonic-net/sonic-buildimage.git) branch `202605` into a new time-stamped workspace
2. Check out the verified upstream SONiC commit (`3d22ec9`)
3. Git-apply base Marvell Prestera patches (`files/202605/series_marvell-prestera`)
4. Git-apply eSAI overlay patches (`files/202605/esai/series`, enabled with `--eSAI`)
5. Initialize SONiC submodules (`make init`)
6. Apply eSAI HWSKU (`prestera_hwsku-esai-1.18.1-110.tgz`)
7. Bind the eSAI `mrvllibsai_1.18.1-110_arm64.deb` package (`--SAI`)
8. `make configure` and `make target/sonic-marvell-prestera-arm64.bin`
9. Save resulting artifacts and build logs

The Toolset automates these steps to produce correct and reproducible eSAI SONiC images.

Toolset source: [Marvell-switching/sonic-scripts](https://github.com/Marvell-switching/sonic-scripts.git) — branch `esai-202605-c110-aug12-candidate`.

## Supported Boards

| Board | SONiC device | CPU | Architecture (`-a`) | Platform (`-p`) | Qualification |
|-------|--------------|-----|---------------------|-----------------|---------------|
| AC5X-RD | `arm64-marvell_rd98DX35xx_cn9131-r0` | CN913x (external) | `arm64` | `marvell-prestera` | **Qualified** |
| AC5P-RD | `arm64-marvell_rd98DX45xx_cn9131-r0` | CN913x (external) | `arm64` | `marvell-prestera` | **Not yet qualified** |

> **Note:** eSAI 1.1.0 supports **arm64 only** on AC5X-RD and AC5P-RD with external CN913x CPU. **AC5X-RD** is qualified for this release. **AC5P-RD** is included as a supported target platform for build and bring-up, but has **not yet completed Marvell qualification** — use at your own risk outside of AC5X-RD qualified scope.

## GitHub Links

- [sonic-net/sonic-buildimage](https://github.com/sonic-net/sonic-buildimage.git) — branch `202605`
- [Marvell-switching/sonic-scripts](https://github.com/Marvell-switching/sonic-scripts.git) — branch `esai-202605-c110-aug12-candidate`
- [Marvell-switching/sonic-marvell-binaries](https://github.com/Marvell-switching/sonic-marvell-binaries.git) — branch `esai-202605-c110-aug12-candidate`

## Marvell GitHub Repositories

Three repositories are involved in an eSAI 1.1.0 SONiC build. Each has a distinct role:

| Repository | Role |
|------------|------|
| [sonic-net/sonic-buildimage](https://github.com/sonic-net/sonic-buildimage.git) | Upstream SONiC OS source. The build clones branch `202605` and checks out commit `3d22ec9`. |
| [Marvell-switching/sonic-scripts](https://github.com/Marvell-switching/sonic-scripts.git) | Build toolset: `sonic_build_script.sh`, patch sets (`files/202605/`), and eSAI HWSKU (`prestera_hwsku-esai-*.tgz`). Delivered to customers as `r_e110.tar.gz`. |
| [Marvell-switching/sonic-marvell-binaries](https://github.com/Marvell-switching/sonic-marvell-binaries.git) | Prebuilt SAI/eSAI Debian packages (`mrvllibsai_*.deb`). Contains `libsai.so` and related firmware — **not** source code, patches, or HWSKU. |

**Why `sonic-marvell-binaries` is separate:** eSAI is compiled outside the SONiC tree (CPSS, XPS, PHY stack). The resulting binary is published as a `.deb` so customers can build SONiC without compiling SAI from source, and can pin or override the eSAI version via `--SAI`.

For eSAI 1.1.0 the relevant package is:

```
arm64/sai-plugin/202605/mrvllibsai_1.18.1-110_arm64.deb
```

SONiC pulls this in during the image build (via `--SAI` or the default in `platform/marvell-prestera/sai.mk`). At runtime, `syncd` and `gbsyncd` load `libsai.so` from that package to program the switch ASIC and external PHY.

## Build Server Requirements

- **Native arm64 build only** — build must run on an ARM64 machine (no cross-compile)
- 12 CPUs minimum
- 32 GB RAM
- 300 GB free disk space minimum
- High-speed disk (build takes 3–4 hours)
- **Docker** installed and running; build user in the `docker` group (not root)
- Ubuntu 20.04 or 22.04 on the build host (see `build-utils/GETTING-STARTED-BuildMachine.sh.txt` for package setup)

> **Important:** The build **must** run on a native **ARM64** machine. x86/amd64 hosts cannot build an arm64 SONiC image — `sonic_build_script.sh` rejects mismatched arch, and `sbuild_r_e110.sh` exits immediately on non-arm64.

## Getting Started

### 1. Prepare the build machine

On a native **ARM64** server, install SONiC build prerequisites. Marvell provides a helper script in the `sonic-scripts` repo:

```bash
# Review and run on a fresh Ubuntu 20.04/22.04 arm64 host (requires sudo)
less build-utils/GETTING-STARTED-BuildMachine.sh.txt
```

Minimum checklist:

- Docker running (`docker ps` works without root)
- `git`, `curl`, `python3`, build tools installed
- At least **300 GB** free disk (`df -h`)
- Do **not** run the build as `root`

Optional: limit parallel compile jobs if RAM is tight:

```bash
export SONIC_BUILD_JOBS=8
```

### 2. Obtain the toolset

**Option A — Customer release package (recommended)**

```bash
tar xzf r_e110.tar.gz
cd <extract-dir>
./sbuild_r_e110.sh
```

**Option B — From git (engineering / latest branch)**

```bash
git clone -b esai-202605-c110-aug12-candidate \
  https://github.com/Marvell-switching/sonic-scripts.git
cd sonic-scripts
./sonic_build_script.sh -b 202605 -p marvell-prestera -a arm64 \
  --eSAI \
  --patch_script "$(realpath ./marvell_sonic_patch_script.sh)" \
  -r --no-cache \
  -c 3d22ec9 \
  --SAI https://github.com/Marvell-switching/sonic-marvell-binaries/raw/refs/heads/esai-202605-c110-aug12-candidate/arm64/sai-plugin/202605/mrvllibsai_1.18.1-110_arm64.deb
```

Both paths use the same scripts and `files/202605/` patch/HWSKU content.

### 3. Validate patches (recommended before first full build)

On native arm64, run patch + HWSKU apply only — no compile (~10–20 minutes):

```bash
./sonic_build_script.sh -b 202605 -p marvell-prestera -a arm64 \
  --eSAI --verify_patches \
  --patch_script "$(realpath ./marvell_sonic_patch_script.sh)" \
  -c 3d22ec9 \
  --SAI https://github.com/Marvell-switching/sonic-marvell-binaries/raw/refs/heads/esai-202605-c110-aug12-candidate/arm64/sai-plugin/202605/mrvllibsai_1.18.1-110_arm64.deb
```

On success the script exits after patching. Check `ABP-202605-*-esai/sonic-buildimage/build_patches.log` for applied patches.

### 4. Run the full build

```bash
./sbuild_r_e110.sh
```

Or use the [recommended build command](#recommended-build-command) directly. Expect **3–4 hours** on a well-provisioned arm64 host.

If disk space is low before starting:

```bash
docker system prune -a --volumes -f
```

Or pass `--clean_dockers` to `sonic_build_script.sh`.


The Toolset automates the full eSAI SONiC build. A **canonical (clean SONiC)** build without Marvell patches is not supported for eSAI 1.1.0 — patching and eSAI HWSKU apply are required.

| Step | Toolset (`sonic_build_script.sh`) |
|------|:---------------------------------:|
| Clone SONiC branch `202605` and check out commit `3d22ec9` | Yes |
| Apply base Prestera patches | Yes (`marvell_sonic_patch_script.sh`) |
| Apply eSAI overlay patches (`--eSAI`) | Yes |
| `make init` + submodule update | Yes |
| Apply eSAI HWSKU | Yes (`prestera_hwsku-esai-1.18.1-110.tgz`) |
| Bind eSAI deb (`--SAI`) | Yes |
| `make configure PLATFORM=marvell-prestera PLATFORM_ARCH=arm64` | Yes |
| `make target/sonic-marvell-prestera-arm64.bin` | Yes |
| Build logging (`build_patches.log`, `build_cmd.txt`) | Yes |

### Build Logs

| File | Description |
|------|-------------|
| `<sonic-buildimage>/build_patches.log` | Successfully applied patches |
| `<sonic-buildimage>/build_cmd.txt` | Main steps/commands with parameters |

## Toolset Tree

```
build-utils/
  ├── create-script-tarball-e110.sh   # create r_e110.tar.gz
  └── sbuild_r_e110.sh                # release wrapper
sonic_build_script.sh                 # main script
marvell_sonic_patch_script.sh         # patch + HWSKU apply
README_eSAI.md                        # user guide
files/202605/
  ├── series_marvell-prestera         # base patch manifest
  ├── esai/
  │   ├── series                      # eSAI overlay manifest
  │   └── 0201–0207-*.patch
  └── prestera_hwsku-esai-1.18.1-110.tgz
```

## Patch Sets

Patches are applied with `git am` in the order listed in each `series*` file. Lines starting with `#` are comments.

### `series*` format

```
PATCH_NAME.patch    |path/to/submodule
```

### Base patches (`files/202605/series_marvell-prestera`)

Applied for every eSAI 1.1.0 build. Patches relevant to **AC5X-RD / AC5P-RD arm64**:

| Patch | Submodule | Purpose |
|-------|-----------|---------|
| `0042-grub2-nocheck-no-tests-in-build` | `sonic-buildimage` | Skip flaky GRUB unit tests during build |
| `0104-platform-X-arm64-mrvl-pcie-ep-check-reboot-on-EP-miss` | `mrvl-prestera` | Reboot if Prestera PCIe EP missing at boot (CN9131) |
| `0013-sonic_installer-add-sync-before-migration` | `src/sonic-utilities` | `sync` before image migration |
| `0065-fix-kernel-Add-dev-ID-reprogram-iATU-on-failure` | `mrvl-prestera` | AC5X kernel iATU / device-ID fix |
| `28010-marvell-platfrom-add-SAI-dependency-to-DOCKER_MGMT_F` | `sonic-buildimage` | SAI deb build-dependency for `libsai.so` consumers |
| `0043-marvell-prestera-rpc-pin-ptf_nn_agent.py-to-use-nnpy` | `sonic-buildimage` | RPC/PTF fix (when `-r` is used) |

> Patches for other platforms (Falcon/amd64, Nokia/armhf) exist in the series file but are not applicable to AC5X-RD / AC5P-RD arm64. The eSAI deb from `--SAI` overrides the default pSAI pin in patch `28251`.

### eSAI overlay (`files/202605/esai/series`)

Applied when `--eSAI` is set. Required for AC5X-RD; applicable to AC5P-RD (not yet qualified):

| Patch | Submodule | Purpose |
|-------|-----------|---------|
| `0201-mvcpss-build-arm64-with-DMA2-enabled` | `sonic-platform-marvell` | Enable MVDMA2 kernel driver (required for eSAI) |
| `0202-marvell-gbsyncd-phy-add-docker-gbsyncd-mrvl` | `sonic-buildimage` | gbsyncd container for external PHY |
| `0203-marvell-gbsyncd-phy-enable-docker-in-marvell-prester` | `sonic-buildimage` | Enable gbsyncd in prestera build rules |
| `0204-marvell-gbsyncd-phy-add-rd98DX35xx_cn9131-device-hws` | `sonic-buildimage` | AC5X-RD-ext (CN9131) HWSKU / gearbox / PHY configs (AC5P-RD HWSKU from `prestera_hwsku-esai-*.tgz`) |
| `0205-marvell-gbsyncd-phy-fix-gbsyncd.service-gearbox-Cond` | `sonic-buildimage` | gbsyncd start when `gearbox_config.json` present |
| `0206-sairedis-marvell-syncd-with-mdio_access_use_npu` | `src/sonic-sairedis` | MDIO access via NPU in syncd |
| `0207-marvell-prestera-sswsyncd` | `sonic-buildimage` | sswsyncd / dsserve shared diagnostic socket |

### HWSKU

`prestera_hwsku-esai-1.18.1-110.tgz` contains board profiles, buffers, timeouts, and XML configuration for eSAI on supported Prestera arm64 boards (including AC5X-RD and AC5P-RD). It is extracted into `sonic-buildimage/device/` after patching. The version `1.18.1-110` is matched from the eSAI deb filename passed via `--SAI`.

## `sonic_build_script.sh` Command-Line Options

```bash
$ ./sonic_build_script.sh -h
```

Key options for eSAI 1.1.0:

| Option | Description |
|--------|-------------|
| `-b 202605` | SONiC branch |
| `-p marvell-prestera` | Platform |
| `-a arm64` | Architecture (only supported arch) |
| `-c 3d22ec9` | Pin upstream `sonic-buildimage` commit before patching |
| `--eSAI` | Apply eSAI overlay patches and eSAI HWSKU |
| `--patch_script <absolute-path>` | Path to `marvell_sonic_patch_script.sh` — **must be absolute** (`realpath`) |
| `--SAI <URL-or-path>` | eSAI `mrvllibsai_*.deb` — overrides default pSAI in `sai.mk` |
| `-r` | `ENABLE_SYNCD_RPC=y` — RPC syncd for PTF/COPP testing |
| `--no-cache` | Clean build without Debian package cache |
| `-C` | Clone, patch, `make configure`, then exit (for inspection) |
| `--verify_patches` | Apply patches only, abort on failure |

### Recommended build command

```bash
./sonic_build_script.sh -b 202605 -p marvell-prestera -a arm64 \
  --eSAI \
  --patch_script "$(realpath ./marvell_sonic_patch_script.sh)" \
  -r --no-cache \
  -c 3d22ec9 \
  --SAI https://github.com/Marvell-switching/sonic-marvell-binaries/raw/refs/heads/esai-202605-c110-aug12-candidate/arm64/sai-plugin/202605/mrvllibsai_1.18.1-110_arm64.deb
```

If you downloaded `mrvllibsai_1.18.1-110_arm64.deb` from the [Marvell portal](#marvell-portal-deliverables), place it next to the scripts and use a local path instead of the GitHub URL:

```bash
  --SAI "$(realpath ./mrvllibsai_1.18.1-110_arm64.deb)"
```

| Option | Why |
|--------|-----|
| `--patch_script $(realpath ...)` | Build runs inside a cloned workspace; relative paths break patch/HWSKU lookup |
| `-r` | Build RPC-enabled syncd (PTF/testing) |
| `--no-cache` | Reproducible release build without stale cached debs |
| `-c 3d22ec9` | Verified upstream SONiC commit for eSAI 1.1.0 |
| `--SAI <URL or local path>` | Bind eSAI `libsai.so` deb and matching HWSKU version `1.18.1-110`. Use the GitHub URL above, or the `mrvllibsai_1.18.1-110_arm64.deb` file from the Marvell portal. |

**Artifacts:** `sonic-buildimage/target/sonic-marvell-prestera-arm64.bin`, `build_cmd.txt`, `build_patches.log`

### Advanced build with `sonic_build_script.sh`

`sonic_build_script.sh` is included in the build-toolset package (`r_e110.tar.gz`). It automates the full eSAI 1.1.0 SONiC image build on a native **arm64** host.

The script performs these steps:

a) Create directory `ABP-<branch>-<timestamp>-<commitID>-esai` and enter it

b) `git clone https://github.com/sonic-net/sonic-buildimage -b 202605` with `-c 3d22ec9` if specified

c) Save the original SONiC repo commit ID for runtime `show version`

d) Apply base Marvell Prestera patches in the top-level `sonic-buildimage` git tree (`files/202605/series_marvell-prestera`)

e) Apply eSAI overlay patches (`files/202605/esai/series`) when `--eSAI` is set

f) `make init` and initialize git submodules

g) Apply patches in git submodule directories

h) Update HWSKU from `prestera_hwsku-esai-1.18.1-110.tgz` (version matched from the eSAI deb via `--SAI`)

i) Bind the eSAI `mrvllibsai_1.18.1-110_arm64.deb` package into `platform/marvell-prestera/sai.mk`

j) `make configure` and `make target/sonic-marvell-prestera-arm64.bin`

k) If the build fails, retry once (unless `--no-cache` is set)

l) Save artifacts to the NFS server `/sonic-artifacts/` directory, if that mount is present

Each step is logged in `sonic-buildimage/build_cmd.txt` and can be replayed manually one by one.

For a release build, use `./sbuild_r_e110.sh` (wrapper around `sonic_build_script.sh` with frozen defaults) or the [recommended build command](#recommended-build-command) above.

## eSAI Package Binding into SONiC Build

eSAI is delivered as a Debian package outside the `sonic-buildimage` tree:

```
mrvllibsai_<SAIver>_<ARCH>.deb
```

For eSAI 1.1.0: `mrvllibsai_1.18.1-110_arm64.deb`

The package contains `libsai.so` (eSAI), which syncd and gbsyncd load at runtime.

### Override with `--SAI` (URL or local absolute path)

```bash
--SAI https://github.com/Marvell-switching/sonic-marvell-binaries/raw/refs/heads/esai-202605-c110-aug12-candidate/arm64/sai-plugin/202605/mrvllibsai_1.18.1-110_arm64.deb

--SAI /absolute/path/mrvllibsai_1.18.1-110_arm64.deb
```

`sonic_build_script.sh` patches `platform/marvell-prestera/sai.mk` to fetch the deb from the given URL or local staging path. The patch script uses the version parsed from the deb filename (`1.18.1-110`) to select `prestera_hwsku-esai-1.18.1-110.tgz`.

## Customer Release Package — Create and Use

### Package contents (`r_e110.tar.gz`)

```
r_e110.tar.gz
  ├── sonic_build_script.sh
  ├── marvell_sonic_patch_script.sh
  ├── sbuild_r_e110.sh
  ├── README_eSAI.md
  └── files/202605/
      ├── series_marvell-prestera
      ├── esai/series + patches
      └── prestera_hwsku-esai-1.18.1-110.tgz
```

### Create the package

From the `sonic-scripts` repository:

```bash
./build-utils/create-script-tarball-e110.sh
```

### Build from the package

```bash
tar xzf r_e110.tar.gz
cd <extract-dir>
./sbuild_r_e110.sh
```

`sbuild_r_e110.sh` is a wrapper with frozen release defaults:

```bash
SONIC_BRANCH=202605
SONIC_COMMIT_ID=3d22ec9
MRVLLIBSAI_VER=1.18.1-110
SAI_BINARIES_BRANCH=esai-202605-c110-aug12-candidate
```

It calls `sonic_build_script.sh` with `--eSAI`, `-r`, `--no-cache`, absolute `--patch_script`, and `--SAI` pointing to the eSAI deb. Only **arm64** is accepted.

To override the eSAI deb locally, place `mrvllibsai_1.18.1-110_arm64.deb` next to the scripts before running `sbuild_r_e110.sh`.

## Build Output and Workspace

### Workspace directory

Each build creates a new top-level workspace next to where you run the script:

```
ABP-202605-<timestamp>-3d22ec9-esai/
└── sonic-buildimage/
    ├── build_patches.log      # patches applied
    ├── build_cmd.txt          # full command history
    ├── commit_log.txt         # upstream + patched commit info
    └── target/
        └── sonic-marvell-prestera-arm64.bin   # installable image
```

The `-esai` suffix is added automatically when `--eSAI` is set.

On failure, the workspace is renamed to `ABP-202605-...-esai-err` for inspection.

### Successful build output

| Output | Location |
|--------|----------|
| SONiC image | `ABP-.../sonic-buildimage/target/sonic-marvell-prestera-arm64.bin` |
| Patch log | `.../sonic-buildimage/build_patches.log` |
| Command log | `.../sonic-buildimage/build_cmd.txt` |
| Version info | Printed at end of build (`sonic_version.yml`) |

Serve the `.bin` over HTTP/HTTPS from a machine reachable by the board management network for ONIE installation.

## Install on AC5X-RD / AC5P-RD

After the image is built, install it on the target board via **ONIE** (board must be in ONIE install mode).

> **AC5P-RD:** Installation steps are the same as AC5X-RD, but AC5P-RD is **not yet qualified** for eSAI 1.1.0. Marvell release quality is guaranteed for **AC5X-RD** only.

### AC5X-RD (qualified)

```bash
cat /etc/machine.conf
```

Expected fields for AC5X-RD with external CN913x:

```
onie_machine=rd98DX35xx_cn9131
onie_platform=arm64-marvell_rd98DX35xx_cn9131-r0
```

### AC5P-RD (not yet qualified)

```bash
cat /etc/machine.conf
```

Expected fields for AC5P-RD with external CN913x:

```
onie_machine=rd98DX45xx_cn9131
onie_platform=arm64-marvell_rd98DX45xx_cn9131-r0
```

### Install the image (ONIE shell)

From the ONIE shell, pointing at your HTTP server:

```bash
onie-nos-install http://<server>/<path>/sonic-marvell-prestera-arm64.bin
```

ONIE downloads the image, writes it to the target partition, and reboots into SONiC.

### Verify after boot

Log in to SONiC and confirm platform and version:

```bash
show platform summary
show version
```

The image should report the eSAI-enabled build (`-esai` in version string when built with `--eSAI`).

## Troubleshooting

| Symptom | Likely cause | Action |
|---------|--------------|--------|
| `ERROR: eSAI 1.1.0 (r_e110) supports arm64 only` | Build started on x86/amd64 host | Use a native **ARM64** build machine |
| `Wrong input. Only NATIVE-ARCH build supported` | `-a arm64` on x86 (or vice versa) | Match `-a` to host CPU architecture |
| `ERROR: Series file series_marvell-prestera not found` | Relative `--patch_script` path | Use `$(realpath ./marvell_sonic_patch_script.sh)` |
| `ERROR: eSAI build must have prestera_hwsku-esai.tgz` | HWSKU tarball missing next to `files/202605/` | Ensure `prestera_hwsku-esai-1.18.1-110.tgz` is present; check `--SAI` deb version matches |
| `PATCH ERROR: Failed to apply` | SONiC commit drift or corrupt patch dir | Confirm `-c 3d22ec9`; use matching `sonic-scripts` branch; retry with fresh workspace |
| `SAI-URL check` / curl failure | eSAI deb URL unreachable | Verify network access to `sonic-marvell-binaries` branch URL; or use local `--SAI /absolute/path/mrvllibsai_1.18.1-110_arm64.deb` |
| Docker / disk errors mid-build | Insufficient disk or stale containers | `docker system prune -a --volumes -f`; ensure ≥300 GB free |
| Build as root rejected | Script refuses privileged user | Run as normal user in `docker` group |

### Inspect after patch failure

```bash
cd ABP-202605-*-esai/sonic-buildimage
cat build_patches.log
cat build_cmd.txt
```

### Dry-run configure without full compile

Use `-C` to stop after `make configure` for manual tree inspection:

```bash
./sonic_build_script.sh ... -C
# then run the last make line from build_cmd.txt manually
```

## Frequently Asked Questions (FAQ)

### How to build on a specific SONiC commit?

Use `-c <commit-id>`. For eSAI 1.1.0 the verified commit is `3d22ec9`.

### How to add or exclude a patch?

Place the patch under `files/202605/` (or `files/202605/esai/`) and add a line to the appropriate `series*` file. To exclude, comment out the line with `#`.

### How to inspect the tree before full build?

Use `-C` — clones, patches, runs `make configure`, then exits. Edit the tree manually and run the last `make` line from `build_cmd.txt`.

### Why is a Toolset with patching needed?

SONiC is a fast-moving open project. Marvell eSAI changes (gbsyncd, DMA2, sswsyncd, AC5X HWSKU) are not yet fully upstream. The Toolset applies a verified patch set on top of a pinned SONiC commit.

### Why is HWSKU needed?

HWSKU bundles per-board SAI XML profiles, buffer configs, gearbox/PHY JSON, and `sai.profile` settings for supported arm64 boards. For eSAI 1.1.0 this is delivered as `prestera_hwsku-esai-1.18.1-110.tgz`. AC5X-RD is qualified; AC5P-RD is supported but not yet qualified.
