#!/bin/bash

rom_fp="$(date +%y%m%d)"
originFolder="$(dirname "$(readlink -f -- "$0")")"
mkdir -p release/$rom_fp/
set -e

if [ -z "$USER" ];then
	export USER="$(id -un)"
fi
export LC_ALL=C

manifest_url="https://android.googlesource.com/platform/manifest"
aosp="android-13.0.0_r73"
phh="android-13.0"

build_target="$1"
manifest_url="https://android.googlesource.com/platform/manifest"

if [ "$build_target" = "android-14.0" ];then
    aosp="android-14.0.0_r37"
    phh="android-14.0"
    supp="-ap1a"
fi

if [ "$build_target" = "android-15.0" ];then
    aosp="android-15.0.0_r26"
    phh="android-15.0"
    supp="-bp1a"
fi

if [ "$build_target" = "android-16.0" ];then
    aosp="android-16.0.0_r2"
    phh="android-16.0"
    supp="-bp2a"
fi

repo init -u "$manifest_url" -b $aosp --depth=1
if [ -d .repo/local_manifests ] ;then
	( cd .repo/local_manifests; git fetch; git reset --hard; git checkout origin/$phh)
else
	git clone https://github.com/TrebleDroid/treble_manifest .repo/local_manifests -b $phh
fi
repo sync -c -j 1 --force-sync || repo sync -c -j1 --force-sync

(cd device/phh/treble; git clean -fdx; bash generate.sh)

. build/envsetup.sh

buildVariant() {
	lunch $1
	make RELAX_USES_LIBRARY_CHECK=true BUILD_NUMBER=$rom_fp installclean
	make RELAX_USES_LIBRARY_CHECK=true BUILD_NUMBER=$rom_fp -j8 systemimage
	make RELAX_USES_LIBRARY_CHECK=true BUILD_NUMBER=$rom_fp vndk-test-sepolicy
	xz -c $OUT/system.img -T0 > release/$rom_fp/system-${2}.img.xz
}

repo manifest -r > release/$rom_fp/manifest.xml
bash "$originFolder"/list-patches.sh
cp patches.zip release/$rom_fp/patches-for-developers.zip

if [ "$build_target" = "android-16.0" ];then
    buildVariant treble_arm64_bvS$supp-userdebug td-arm64-vanilla
    buildVariant treble_arm64_byS$supp-userdebug td-arm64-vanilla-old
    buildVariant treble_a64_bvS$supp-userdebug td-arm32_binder64-vanilla
    buildVariant treble_a64_byS$supp-userdebug td-arm32_binder64-vanilla-old
else
    (
        git clone https://github.com/TrebleDroid/sas-creator
        cd sas-creator

        git clone https://github.com/phhusson/vendor_vndk -b android-10.0
    )

    buildVariant treble_arm64_bvS$supp-userdebug td-arm64-ab-vanilla
    ( cd sas-creator; bash lite-adapter.sh 64; xz -c s.img -T0 > ../release/$rom_fp/system-td-arm64-ab-vndklite-vanilla.img.xz )

    buildVariant treble_a64_bvS$supp-userdebug td-arm32_binder64-ab-vanilla
    ( cd sas-creator; bash lite-adapter.sh 32; xz -c s.img -T0 > ../release/$rom)
fi
