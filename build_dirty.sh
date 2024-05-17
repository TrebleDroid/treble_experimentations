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
aosp="android-13.0.0_r35"
phh="android-13.0"

build_target="$1"
manifest_url="https://android.googlesource.com/platform/manifest"

. build/envsetup.sh

buildVariant() {
	lunch $1
	make RELAX_USES_LIBRARY_CHECK=true BUILD_NUMBER=$rom_fp installclean
	make RELAX_USES_LIBRARY_CHECK=true BUILD_NUMBER=$rom_fp -j8 systemimage
	make RELAX_USES_LIBRARY_CHECK=true BUILD_NUMBER=$rom_fp vndk-test-sepolicy
	xz -c $OUT/system.img -T0 > release/$rom_fp/system-${2}.img.xz
}

buildVariant treble_arm64_bgN-userdebug td-arm64-ab-gapps
( cd sas-creator; bash securize.sh $OUT/system.img; xz -c s-secure.img -T0 > ../release/$rom_fp/system-td-arm64-ab-gapps-secure.img.xz )
( cd sas-creator; bash lite-adapter.sh 64 $OUT/system.img; xz -c s.img -T0 > ../release/$rom_fp/system-td-arm64-ab-vndklite-gapps.img.xz )
( cd sas-creator; bash securize.sh s.img; xz -c s-secure.img -T0 > ../release/$rom_fp/system-td-arm64-ab-vndklite-gapps-secure.img.xz )