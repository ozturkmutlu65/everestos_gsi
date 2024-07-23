#!/bin/bash

echo
echo "--------------------------------------"
echo "       ProjectEverest 1.4 Buildbot    "
echo "             ProjectEverest           "
echo "             by mrgebesturtle         "
echo "--------------------------------------"
echo

set -e

BL=$PWD/everestos_gsi
BD=$HOME/builds
BV=treble_arm64_bvN
LMD=.repo/local_manifests

initRepos() {
    echo "--> Initializing workspace"
    repo init -u https://github.com/ProjectEverest/manifest -b qpr3 --git-lfs
    echo

    echo "--> Preparing local manifest"
    if [ -d "$LMD" ]; then
        echo "Deleting old local manifests"
          rm -r $LMD
    fi
    echo "Fetching new local manifests"
    mkdir -p .repo/local_manifests
    cp $BL/build/default.xml .repo/local_manifests/default.xml
    cp $BL/build/remove.xml .repo/local_manifests/remove.xml
    echo
}

syncRepos() {
    echo "--> Syncing repos"
    repo sync -c --force-sync --no-clone-bundle --no-tags -j16 || repo sync -c --force-sync --no-clone-bundle --no-tags -j16
    echo
}

clonePriv() {
    echo "Import signing keys if you want"
    read -p "Clone your private signing keys repo now in another terminal and after that press any key here to continue"
}

applyPatches() {
    echo "--> Applying TrebleDroid patches"
    bash $BL/patch.sh $BL trebledroid
    echo

    echo "--> Applying personal patches"
    bash $BL/patch.sh $BL personal
    echo

    echo "--> Generating makefiles"
    cd device/phh/treble
    cp $BL/build/everest.mk .
    bash generate.sh everest
    cd ../../..
    echo
}

setupEnv() {
    echo "--> Setting up build environment"
    source build/envsetup.sh &>/dev/null
    mkdir -p $BD
    echo
}

buildTrebleApp() {
    echo "--> Building treble_app"
    cd treble_app
    bash build.sh release
    cp TrebleApp.apk ../vendor/hardware_overlay/TrebleApp/app.apk
    cd ..
    echo
}

buildVariant() {
    echo "--> Building $1"
    lunch "$1"-userdebug
    make -j$(nproc --all) installclean
    make -j$(nproc --all) systemimage
    mv $OUT/system.img $BD/system-"$1".img
    echo
}

buildVariants() {
    buildVariant treble_a64_bvN
    buildVariant treble_a64_bgN
    buildVariant treble_arm64_bvN
    buildVariant treble_arm64_bgN
    buildVndkliteVariant treble_a64_bvN
    buildVndkliteVariant treble_a64_bgN
    buildVndkliteVariant treble_arm64_bvN
    buildVndkliteVariant treble_arm64_bgN
}

generatePackages() {
    echo "--> Generating packages"
    buildDate="$(date +%Y%m%d)"
    find $BD/ -name "system-treble_*.img" | while read file; do
        filename="$(basename $file)"
        [[ "$filename" == *"_a64"* ]] && arch="arm32_binder64" || arch="arm64"
        [[ "$filename" == *"_bvN"* ]] && variant="vanilla" || variant="gapps"
        [[ "$filename" == *"-vndklite"* ]] && vndk="-vndklite" || vndk=""
        name="ImbrogliOS_aosp-${arch}-ab-${variant}${vndk}-14.0-$buildDate"
        xz -cv "$file" -T0 > $BD/"$name".img.xz
    done
    rm -rf $BD/system-*.img
    echo
}

START=$(date +%s)

initRepos
syncRepos
clonePriv
applyPatches
setupEnv
buildTrebleApp
[ ! -z "$BV" ] && buildVariant "$BV" || buildVariants
generatePackages

END=$(date +%s)
ELAPSEDM=$(($(($END-$START))/60))
ELAPSEDS=$(($(($END-$START))-$ELAPSEDM*60))

echo "--> Buildbot completed in $ELAPSEDM minutes and $ELAPSEDS seconds"
echo
