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

repo init -u "$manifest_url" -b $aosp --depth=1
if [ -d .repo/local_manifests ] ;then
	( cd .repo/local_manifests; git fetch; git reset --hard; git checkout origin/$phh)
else
	git clone https://github.com/JonnyVR1/treble_manifest .repo/local_manifests -b $phh
fi
repo sync -c -j8 --force-sync || repo sync -c -j8 --force-sync

repo forall -r '.*opengapps.*' -c 'git lfs fetch && git lfs checkout'
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

(
	if [ -d sas-creator ] ;then
		( cd sas-creator; git fetch; git reset --hard)
	else
		git clone https://github.com/TrebleDroid/sas-creator
		cd sas-creator
	fi

	if [ -d vendor_vndk ] ;then
		( cd vendor_vndk; git fetch; git reset --hard; cd ../)
	else
		git clone https://github.com/phhusson/vendor_vndk -b android-10.0
	fi
)

buildVariant treble_arm64_bgN$supp-userdebug td-arm64-ab-gapps
( cd sas-creator; bash securize.sh $OUT/system.img; xz -c s-secure.img -T0 > ../release/$rom_fp/system-td-arm64-ab-gapps-secure.img.xz )
( cd sas-creator; bash lite-adapter.sh 64 $OUT/system.img; xz -c s.img -T0 > ../release/$rom_fp/system-td-arm64-ab-vndklite-gapps.img.xz )
( cd sas-creator; bash securize.sh s.img; xz -c s-secure.img -T0 > ../release/$rom_fp/system-td-arm64-ab-vndklite-gapps-secure.img.xz )
