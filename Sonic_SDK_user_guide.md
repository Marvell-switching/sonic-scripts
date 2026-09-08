# Marvell SONiC Build Toolset

<a href="https://www.marvell.com/"><img src="https://www.marvell.com/content/dam/marvell/en/rebrand/marvell-logo3.svg" alt="Marvell Technologies" width="200"></a>

## Contents

- [General & Purpose](#general-purpose)
- [Boards / Platforms](#boards--platforms)
- [GitHub Links](#github-links)
- [Build Server Requirements](#build-server-requirements)
- [Build Flows](#build-flows)
- [Toolset Tree](#toolset-tree)
- [`sonic_build_script.sh` Command-Line Options](#sonic-build-script-command-line-options)
- [Build SONiC on Top of a Specific Commit ID](#build-sonic-on-top-of-a-specific-commit-id)
- [Marvell-SAI Package Binding into SONiC Build](#marvell-sai-package-binding-into-sonic-build)
- [Customer Release Package — Create and Use](#customer-release-package--create-and-use)
- [**Frequently Asked Questions (FAQ)**](#frequently-asked-questions-faq)

<a id="general-purpose"></a>

## General & Purpose

This README describes the **Marvell SONiC build toolset** (Toolset):

- Upstream: [Marvell-switching/sonic-scripts](https://github.com/Marvell-switching/sonic-scripts.git)

The build process for `marvell-prestera` and `marvell-teralynx` platforms is complex and includes these steps:

1. Clone [sonic-buildimage](https://github.com/sonic-net/sonic-buildimage.git) branch into a new directory with a time-stamped name
2. Set the requested SONiC commit ID (if required)
3. Save the SONiC commit ID into the SONiC version descriptor before the next steps
4. Git-apply patches (and/or PRs) that are still not merged for sonic-buildimage
5. Initialize SONiC submodules (`make init`)
6. Git-apply patches for submodules
7. Apply HWSKU
8. `make configure ...parameters...`
9. `make ...parameters...`
10. Save resulting artifacts

The main purpose is to make this complicated build process easy to use while producing correct and reproducible results.

The Toolset is used for SONiC builds in:

- Marvell development and release
- Build automation
- Customer builds

## Boards / Platforms

| ASIC | SONiC device | CPU | Architecture (`-a`) | Platform (`-p`) |
|------|--------------|-----|---------------------|-----------------|
| AC5X-RD | `arm64-marvell_rd98DX35xx_cn9131-r0` | CN913x | `arm64` | `marvell-prestera` |
| AC5P-RD | `arm64-marvell_rd98DX45xx_cn9131-r0` | CN913x | `arm64` | `marvell-prestera` |
| AC3X | `armhf-nokia_ixs7215_52x-r0` | CN913x | `armhf` | `marvell-prestera` |
| Falcon-12.8T | `x86_64-marvell_db98cx8580_16cd-r0` | Xeon | `amd64` | `marvell-prestera` |
| Falcon-6.4T | `x86_64-marvell_db98cx8580_32cd-r0` | Xeon | `amd64` | `marvell-prestera` |
| Falcon-3.2T | `x86_64-marvell_db98cx8514_10cc-r0` | Xeon | `amd64` | `marvell-prestera` |
| Falcon-2T | `x86_64-marvell_db98cx8522_10cc-r0` | Xeon | `amd64` | `marvell-prestera` |
| Teralynx-10 | `x86_64-marvell_dbmvtx9180-r0` | Xeon D15xx | `amd64` | `marvell-teralynx` |

## GitHub Links

- [sonic-net/sonic-buildimage](https://github.com/sonic-net/sonic-buildimage.git)
- [Marvell-switching/sonic-scripts](https://github.com/Marvell-switching/sonic-scripts.git) — **only the `master` branch; no other branches**

## Build Server Requirements

- Only **native** builds are supported by SONiC:
  - `arm64` / `armhf` on ARM server/machine
  - `amd64` on x86/AMD64 server/machine
- 12 CPUs minimum
- 32 GB RAM
- 300 GB free disk space minimum
- High-speed disk (build takes 3–4 hours)

## Build Flows

The Toolset automates the full Marvell SONiC build. The same end goal can also be reached manually with a **canonical (clean SONiC)** build, but in that case patch-apply and HWSKU-apply must be done manually (if needed).

The table below compares both flows step by step. **Yes** means the step is performed; **—** means it is not part of that flow.

| Step | Toolset<br>(`sonic_build_script.sh`) | Canonical<br>(clean SONiC) |
|------|:---------------------------------:|:-----------------------:|
| Clear previously built objects -- if needed<br>(`docker system prune -a --volumes -f`) | Yes | — |
| Clone SONiC branch and `cd` into `sonic-buildimage` | Yes | Yes |
| Patch `sonic-buildimage` | Yes (`marvell_sonic_patch_script.sh`) | — |
| `make init` | Yes | Yes |
| `git submodule update --init --recursive` | Yes | — |
| Patch submodules | Yes (`marvell_sonic_patch_script.sh`) | — |
| Apply HWSKU | Yes (`marvell_sonic_patch_script.sh`) | — |
| `make configure PLATFORM=marvell-prestera PLATFORM_ARCH=arm64` | Yes | Yes |
| `make target/sonic-marvell-prestera-arm64.bin` | Yes | Yes |
| Retry on failure or change (loop back to patching / configure) | Yes | — |
| Check build result | Script prints **OK** / **ERROR** | Manual: `echo $?` |
| Save resulting artifacts | Yes | — |
| Build logging (`build_patches.log`, `build_cmd.txt`) | Yes | — |

The same canonical build can be obtained with the Toolset by invoking `sonic_build_script.sh` without the `--patch_script` command-line option. In that case, patch-apply, submodule patching, and HWSKU-apply are skipped; Toolset automation for cleanup, artifacts, and logging still applies.

### Build Logs (Toolset only)

| File | Description |
|------|-------------|
| `<sonic-buildimage>/build_patches.log` | Successfully applied patches |
| `<sonic-buildimage>/build_cmd.txt` | Main steps/commands with parameters |

## Toolset Tree

```
build-utils/*.sh                    # utilities to create release packages
sonic_build_script.sh               # main script
marvell_sonic_patch_script.sh       # secondary script applying patches
files/                              # <BRANCH> containers
  ├─ 202405/...
  ├─ 202411/...
  ├─ 202505/
  │   ├── nnnn-PATCHES.patch
  │   ├── series_marvell-prestera_amd64
  │   ├── series_marvell-prestera_arm64
  │   ├── series_marvell-prestera_armhf
  │   ├── series_marvell-teralynx_amd64
  │   ├── prestera_hwsku.tgz
  │   └── teralynx_hwsku.tgz
  │
  ├─ 202511/
  │   ├── nnnn-PATCHES.patch
  │   ├── prestera_hwsku.tgz
  │   ├── series_marvell-prestera
  │   ├── series_marvell-teralynx_amd64
  │   ├── 1/                              # customer(1) extra.patch-SET
  │   │   ├── nnnn-PATCHES-extra.patch
  │   │   └── series
  │   ├── 2/                              # customer(2) extra.patch-SET
  │   ├── 3/                              # customer(3) extra.patch-SET
  │   └── tl/                             # Teralynx extra patches
  │       ├── nnnn-Teralynx-PATCHES.patch
  │       └── series
  │
  ├─ 202605/
  │   ├── nnnn-PATCHES.patch
  │   ├── prestera_hwsku.tgz
  │   └── series_marvell-prestera
  │
  ├─ master/
  │   ├── nnnn-PATCHES.patch
  │   ├── esai/
  │   │   ├── nnnn-PATCHES-relevant-for-eSAI-ONLY.patch
  │   │   └── series
  │   ├── prestera_hwsku-esai.tgz
  │   ├── prestera_hwsku.tgz
  │   └── series_marvell-prestera
  │
  ├── mrvl_sonic_hwsku_dbmvtx9180.tgz       # teralynx
  ├── mrvl_sonic_master_hwsku_tl7.tgz       # teralynx
  └── mrvl_sonic_platform_dbmvtx9180.tgz    # teralynx
```

<a id="faq-series"></a>

### `series*` Patch-List Format

A PATCH file together with a `series*` file is a standard, general-purpose (not SONiC-specific) way to add changes into a project. Patching is applied according to the `series*` patch-list.

In general, patches may be applied with `patch -p1 < PATCH` or with `git am PATCH`. SONiC and the Toolset use the `git am PATCH` approach.

As a result, patched files are tracked in git — but note that the top-level git commit ID becomes **private** and differs for each build.

#### Toolset `series*` format rules

- Each line contains 3 fields: `PATCH.patch`, pipe character `|`, path to submodule
- Lines must not have leading spaces
- Spaces inside a line are acceptable
- Blank lines are acceptable
- A line starting with `#` is a comment

Example:

```
# comment
# _____patch-name____"|" path to git where "git am" to be applied
nnnn-PATCHES.patch    |sonic-buildimage
nnnn-PATCHES.patch    |platform/marvell-prestera/mrvl-prestera
```

<a id="sonic-build-script-command-line-options"></a>

## `sonic_build_script.sh` Command-Line Options

```bash
$ ./sonic_build_script.sh -h
```

```
Usage:

 ./sonic_build_script.sh -b <branch> -p <platform> -a <arch>
   [-c <sonic-buildimage_commit>]
   [--patch_script <http or full_local path_of_patch_script>]
              \__if Not present go with canonic build without patching
   [--SAI_VER <virsion number 1.NN.1-K>]
   [--SAI <URL or absolute local path to mrvllibsai_*.deb>]
   [--eSAI]
   [-s] [-r] [--no-cache] [--verify_patches]
   [--admin_password <password>] [--other_build_options <sonic_build_options>]
   [--mark_no_del_ws] [--clean_dockers] [--clean_ws]

    --eSAI: Build with eSAI hwsku and mrvllibsai*.deb
    -s : Build docker saiserver v2
    -r : ENABLE_SYNCD_RPC=y
    -c : checkout commit id
    -C : clone, patching, make-CONFIGURE and exit before full make
                             (for inspection and re-config)
    --tl  -1  -2  -3     Apply Extra patches from customers directories
    --no-cache: Build without any pre cache
    --other_build_options: Other sonic build options like INCLUDE_ICCPD=y
    --verify_patches:    Apply patches, don't compile. Abort on failure
        export DEVEL=y   Ignore patch apply failures but continue
    --admin_password: Set admin password
    --clean_dockers: clean stopped containers
    --mark_no_del_ws: Do not cleanup ws during cleanup
```

### Examples

```bash
./sonic_build_script.sh -b 202411 -p marvell -a arm64 \
  --patch_script https://github.com/Marvell-switching/sonic-scripts/raw/refs/heads/master/marvell_sonic_patch_script.sh -r \
  -c 021569412

./sonic_build_script.sh -b master -p marvell-prestera -a arm64 \
  --patch_script https://github.com/Marvell-switching/sonic-scripts/raw/refs/heads/master/marvell_sonic_patch_script.sh -r \
  --SAI_VER 1.18.1-1

./sonic_build_script.sh -b 202511 -p marvell-prestera -a amd64 \
  --patch_script /local-scripts-path/marvell_sonic_patch_script.sh -r

./sonic_build_script.sh -b 202511 -p marvell-prestera -a arm64 \
  --patch_script /local-scripts-path/marvell_sonic_patch_script.sh -r \
  --SAI http://192.168.1.2:8080/<path>/mrvllibsai_1.17.1-1_arm64.deb

./sonic_build_script.sh -b 202511 -p marvell-prestera -a arm64 \
  --patch_script /local-scripts-path/marvell_sonic_patch_script.sh -r \
  --SAI /local-path/mrvllibsai_1.17.1-1_arm64.deb
```

**Artifacts:** `sonic-buildimage/target/sonic-marvell-prestera-arm64.bin`, `build_cmd.txt`, `build_patches.log`

> **Note:** `sonic_build_script.sh` must be present on the build machine locally. It can be downloaded from:
> [sonic_build_script.sh (master)](https://github.com/Marvell-switching/sonic-scripts/raw/refs/heads/master/sonic_build_script.sh)

<a id="faq-sonic-commit-id"></a>

## Build SONiC on Top of a Specific Commit ID

Use the `-c commit-id` option, for example:

```bash
-c 021569412
```

## Marvell-SAI Package Binding into SONiC Build

Marvell-SAI is a separate project built outside the sonic-buildimage tree as:

```
mrvllibsai-<SAIver>-<mvReleaseNumber>_<ARCH>.deb
```

For example: `mrvllibsai-1.18.1-2_arm64.deb`

### Release

When a new official `mrvllibsai*<ARCH>.deb` release is delivered, it should be bound into SONiC at two points:

1. Save `mrvllibsai*<ARCH>.deb` in the public repo [Marvell-switching/sonic-marvell-binaries](https://github.com/Marvell-switching/sonic-marvell-binaries.git):
   - `amd64/sai-plugin/master/mrvllibsai_1.18.1-2_amd64.deb`
   - `arm64/sai-plugin/master/mrvllibsai_1.18.1-2_arm64.deb`
   - `armhf/sai-plugin/master/mrvllibsai_1.18.1-2_armhf.deb`

2. Create a PR into [sonic-net/sonic-buildimage](https://github.com/sonic-net/sonic-buildimage.git) on the required branch, updating `platform/marvell-prestera/sai.mk` with the new index `mrvllibsai_1.18.1-2_<ARCH>.deb`. As a result, `sai.mk` will point to the file from step 1.

> **Note:** `sonic-marvell-binaries.git` has **no branches**, but sonic-buildimage branches may have different `sai.mk` files pointing to different `mrvllibsai` versions.

### Development

For development purposes, `mrvllibsai*.deb` may be overridden via build options.

<a id="faq-sai-ver"></a>

#### Override with `--SAI_VER` (public marvell-binaries release)

Use when another `mrvllibsai-<RELEASE-NUMBER>.deb` is already published in [sonic-marvell-binaries](https://github.com/Marvell-switching/sonic-marvell-binaries.git) but not yet bound into the SONiC branch `sai.mk` default:

```bash
--SAI_VER 1.18.1-10
```

<a id="faq-sai"></a>

#### Override with `--SAI` (URL or local full path)

Use for a private or pre-release `mrvllibsai*.deb` variant — specify an HTTP(S) URL or an absolute local path:

```bash
--SAI /local-path/mrvllibsai_1.18.1-10_arm64.deb
--SAI http://192.168.1.2:8080/<path>/mrvllibsai_1.18.1-10_arm64.deb
```

### Automatic CI build

Auto-CI/Jenkins may use one of two approaches:

**a. Command-line option**

```bash
--mvsai "curl hash URL full command to get from Nightly-CI"
```

**b. Bash environment variables**

```bash
export LIBSAI_GET_ENA=Y
export LIBSAI_GET_CMD="curl hash URL full command to get from Nightly-CI"
```

<a id="faq-customer-release"></a>

## Customer Release Package — Create and Use

```
build-utils/
  ├── create-script-tarball-p701.sh
  ├── README_series_r_p701.txt
  ├── sbuild_r_p701.sh
  ├── sbuild_r_p701_armhf.sh
  │
  ├── create-script-tarball-p800.sh
  ├── README_series_r_p800.txt
  ├── sbuild_r_p800.sh
  └── sbuild_r_p800_armhf.sh
```

To create a new release package (for example P8.0.0):

1. Copy and adjust `README_series_r_p800.txt`, `sbuild_r_p800.sh`, `sbuild_r_p800_armhf.sh`, and `create-script-tarball-p800.sh`
2. Run `./build-utils/create-script-tarball-p800.sh` to create the package

Resulting tarball `r_p800.tar.gz`:

```
r_p800.tar.gz
  ├── sonic_build_script.sh
  ├── marvell_sonic_patch_script.sh
  ├── files/202601/***
  ├── README_series_r_p800.txt
  ├── sbuild_r_p800.sh
  └── sbuild_r_p800_armhf.sh
```

All build properties are hardcoded at the beginning of `sbuild_r_p800.sh`:

```bash
################################################################
##############################################################
# <<  Release build-configuration
SONIC_BRANCH=202605
SONIC_COMMIT_ID=63f17ae50
#MRVLLIBSAI_VER=1.18.1-1     - already set as 202605 Default
##CANONIC_BUILD=Y
#MV_EXTRA_PATCH_SETS=Y
# >>
# echo/print is at the end
##############################################################
################################################################
```

In practice, `sbuild_r_p800.sh` is a wrapper that generates options and calls `./sonic_build_script.sh ...options...`.

Architecture (`arm64` vs `amd64`) is detected automatically by `sbuild_r_p800.sh`, but `armhf` must be declared explicitly. For ARMHF builds, use `sbuild_r_p800_armhf.sh`.

## Frequently Asked Questions (FAQ)

* [How to build on a specific SONiC commit-id?](#faq-sonic-commit-id)
* [How to build `mrvllibsai-<RELEASE-NUMBER>.deb` with another RELEASE-NUMBER present on the public marvell-binaries repo?](#faq-sai-ver)
* [How to build `mrvllibsai-<RELEASE-NUMBER>.deb` with another private variant (URL or local full path)?](#faq-sai)
* [How to add a new patch into the build?](#faq-add-patch)
* [How to exclude a patch from the build?](#faq-exclude-patch)
* [How to make free-hand code changes before full build execution?](#faq-free-code-change)
* [What if a customer does not want any patch or wants its own patch?](#faq-customer-patches)
* [How does Marvell deliver and build per-customer patch(es)?](#faq-per-customer-patches)
* [How to enable/disable SONiC features?](#faq-sonic-features)
* [Why is a Toolset with patching needed but not a SONiC GitHub repo?](#faq-toolset-vs-sonic-repo)

<a id="faq-add-patch"></a>

### How to add a new patch into the build?

Place the patch into `./files/<branch>/` (or into `./files/<branch>/<extra-set>/`) and register it in the appropriate [`series*` file](#faq-series).

<a id="faq-exclude-patch"></a>

### How to exclude a patch from the build?

Comment out the patch line with `#`, or remove the line from the appropriate [`series*` file](#faq-series).

<a id="faq-free-code-change"></a>

### How to make free-hand code changes before full build execution?

Use or add the `-C` command-line option. It instructs the Toolset to clone, apply patching, run `make configure`, and **exit before the full `make`**.

A developer can then change anything inside the full SONiC tree, take the last `make ...parameters...` line from `sonic-buildimage/build_cmd.txt`, and run that line manually.

<a id="faq-customer-patches"></a>

### What if a customer does not want any patch or wants its own patch?

Marvell release quality is guaranteed only by a patch-SET (not a single patch, but the full SET) with all patches delivered with the Toolset (see [Customer Release Package — Create and Use](#faq-customer-release)).

A customer may add and/or remove patches as described above, but at the customer's own responsibility.

<a id="faq-per-customer-patches"></a>

### How does Marvell deliver and build per-customer patch(es)?

Toolset options to **add** a per-customer patch-SET:

```text
--tl  -1  -2  -3     Apply extra patches from customer directories
```

An extra set only **adds** patches; it does not remove them.

<a id="faq-sonic-features"></a>

### How to enable/disable SONiC features?

Enabling or disabling SONiC features is a pure SONiC capability. In SONiC, it is done by exporting a bash environment variable `<FEATURE-NAME>=y` or `=n`. The default `y`/`n` value is also defined by pure SONiC implementation.

For example, the default is `INCLUDE_ICCPD=n`, but it may be changed with:

```bash
export INCLUDE_ICCPD=y
```

The Toolset does not change this capability; it keeps it as in the canonical build — an **optional** build variant, available but not enabled by default.

If a feature is supported by SONiC, required by a customer, and **officially** supported/verified by Marvell, it may be set as the default or as a special release variant.

<a id="faq-toolset-vs-sonic-repo"></a>

### Why is a Toolset with patching needed but not a SONiC GitHub repo?

The SONiC repo is an open project with many submodules that change frequently — every day, even on "old" branches.

Toolset patches cannot be merged into a local mirror copy of the project; they must be applied **on top of** the latest `sonic-buildimage` or submodules — which is exactly what the Toolset does with minimal but guaranteed effort.

It is simply easier to manage changes in the `sonic-buildimage` and submodule trees this way.

Plus, without the Toolset, the SONiC version would report a **private-repo** SONiC commit ID.

### Why are patches needed (or may be needed)?

- The merge cycle for a patch/PR pushed into the community can take months, but the patch may be needed now.
- A patch may be required for Marvell platform(s) only and would not be accepted by the global community.
- A patch may still be under development and test trial.

### Why is HWSKU needed?

HWSKU contains profiles, buffers, timeouts, and XML configuration for Marvell platform(s) and devices. It is a historical way to expose these configurations to customers, as an alternative to saving them in the appropriate GitHub repos.

If all configurations are already up-to-date in GitHub repos, the HWSKU may not be present.

