# sonic-scripts

[![Marvell Technologies](https://www.marvell.com/content/dam/marvell/en/rebrand/marvell-logo3.svg)](https://www.marvell.com/)

# Description

Marvell patch script to do git patch/apply all open PRs required to build SONIC image

### Teralynx-10 Platform

* SONIC Device: 
    * x86_64-marvell_dbmvtx9180-r0
    	ARCH        | CPU
    	------------|-----------
    	x86_64      | Xeon D15xx

Port: 6.4T

### AC5X-RD Platform
* SONIC Device: 
    * x86_64-marvell_rd98DX35xx-r0
    	ARCH        | CPU
    	------------|-----------
    	x86_64      | Xeon

	* arm64-marvell_rd98DX35xx-r0
    	ARCH       | CPU
    	-----------|--------------
    	ARM64      | ARM-v8.2 A55

	* arm64-marvell_rd98DX35xx_cn9131-r0
    	ARCH       | CPU
    	-----------|-----------
    	ARM64      | CN913x


* Port: 32x1G+16x2.5G+6x25G

### Falcon Platform
* SONIC Device: 
    * x86_64-marvell_db98cx8580_16cd-r0 
    * x86_64-marvell_db98cx8580_32cd-r0
	* x86_64-marvell_db98cx8514_10cc-r0

    ARCH        | CPU
    ------------|--------
    X86_64      | Xeon

* Port: 12.8T, 6.4T, 2T


### Patch script
```sh
	bash marvell_sonic_patch_script.sh --branch <> --platform <> --arch <> --release-tag <>

		--branch      : sonic branch name
		--platform    : marvell / innovium
		--arch        : amd64 / arm64
		--release-tag : sonic-script github release tag name

	Ex: bash marvell_sonic_patch_script.sh --branch 202405 --platform marvell --arch amd64 --release-tag 202405_01
```
