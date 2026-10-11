#!/bin/bash

set -e

VER="${1:-test}"  # donor firmware version: ./build.sh [version], default test
HERE="$(cd "$(dirname "$0")" && pwd)"
IMAGE="$HERE/odm.img"

[ -f "$IMAGE" ] || { echo "No 6t odm image"; exit 1; }

PATHS=(
    # 6T camera: macan* sensors, EIS, DNG profiles, front camera
    "/lib64/camera"
    "/etc/camera/config"
    "/etc/camera/dng"
    "/etc/camera/camera_engmode.xml"
    "/etc/camera/CameraHWConfiguration.config"
    "/etc/camera/oplus_eis_camera.vcfg"
    "/etc/camera/eis_camera.vcfg"
    "/etc/camera/settings_fdc.txt"
    "/etc/camera/settings_fdc_lite.txt"
    "/etc/camera/fwk_config.json"
    "/etc/camera/vainr_cfg.json"
    "/etc/camera/facerestore/InitParams.json"
    "/etc/camera/facerestore/fr_models/F_SE_A.bin"
    "/etc/camera/facerestore/fr_models/F_SE_B.bin"
    "/etc/camera/facerestore/fr_models/F_SL_A.bin"
    "/etc/camera/facerestore/fr_models/F_SL_B.bin"
    "/etc/camera/Owl_Algo_model/Owl_Algo_F_FHD.bin"
    "/etc/camera/Owl_Algo_model/Owl_Algo_F_UHD.bin"
    # 8300 mAh battery
    "/etc/power_profile"
    # Charging: 6T battery currents/thermal compensation
    "/etc/devices_config/devices_config.json"
    "/firmware/fastchg/bms_heating_config.txt"
    "/firmware/fastchg/charging_thermal_config_default.txt"
    "/firmware/fastchg/smart_chg_config_table.txt"
    "/firmware/fastchg/batt_dchg_ctrl_config_table.txt"
    "/firmware/fastchg/batt_eis_config.txt"
    "/firmware/fastchg/batt_si_loss_config_table.txt"
    "/firmware/fastchg/24855/charging_hyper_mode_config.txt"
    # Thermal protection for 6T hardware
    "/etc/temperature_profile/sys_thermal_control_config.xml"
    "/etc/temperature_profile/sys_high_temp_protect_OPPO_24855.xml"
    "/etc/temperature_profile/sys_thermal_zoom_window_restrict_list.xml"
    # Sensors: 6T board SEE calibrations
    "/etc/sensor/sensor_config.json"
    "/etc/sensor/config/json_list"
    "/etc/sensor/config/oplus_rotation_detect.json"
    "/etc/sensor/config/molokai_mtp_mxg4300_0.json"
)

# Masks: remove foreign 15R hardware from the overlay
TOUCH_FILES=(
    "/lib64/camera/.replace"
    "/etc/camera/config/.replace"
    "/etc/camera/dng/.replace"
    # Foreign 15R silicon/project in charging
    "/firmware/fastchg/silicon_x25_X2_batt_dchg_ctrl_config_table.txt"
    "/firmware/fastchg/silicon_x25_X2_batt_eis_config.txt"
    "/firmware/fastchg/silicon_x25_X2_batt_si_loss_config_table.txt"
    "/firmware/fastchg/silicon_x25_X2_bms_heating_config.txt"
    "/firmware/fastchg/silicon_x25_X2_smart_chg_config_table.txt"
    "/firmware/fastchg/24877/charging_hyper_mode_config.txt"
    # Foreign 15R thermal profile
    "/etc/temperature_profile/sys_high_temp_protect_OPPO_24877.xml"
    # Phantom 15R barometer: BMP5 config + feature
    "/etc/sensor/config/molokai_mtp_bmp5_0.json"
    "/etc/permissions/sku_15/android.hardware.sensor.barometer.xml"
    # DISABLED: rc/manifest/json masks caused a boot error — keeping stock 15R files
    # "/etc/init/esim@1.0-service.rc"
    # "/etc/vintf/manifest/manifest_oplus_esim.xml"
    # "/etc/devices_config/silicon_x25_X2_devices_config.json"
    # "/etc/init/lowi-server.rc"
    # "/etc/hal_uuid_map_15.xml"
)

# $1 = payload root (the dir directly holding lib64/, etc/, firmware/).
# Shared by both targets: same file set, only the packaging differs.
fill_payload() {
    local root="$1" path dest file
    for path in "${PATHS[@]}"; do
        dest="$root$path"
        echo "Extracting $path ..."
        mkdir -p "$(dirname "$dest")"
        if fsck.erofs --extract="$dest" --path="$path" "$IMAGE"; then
            :
        else
            echo "Extraction failed for $path"
        fi
    done

    for file in "${TOUCH_FILES[@]}"; do
        dest="$root$file"
        mkdir -p "$(dirname "$dest")"
        touch "$dest"
    done
}

label_tree() {
    local ctx="$1" dir="$2" val
    [ -d "$dir" ] || return 0
    val="0s$(printf '%s\0' "$ctx" | base64)"
    sudo find "$dir" -exec setfattr -h -n security.selinux -v "$val" {} +
}

build_image() {
    local root="$1" img="$2" d
    command -v mkfs.erofs >/dev/null || { echo "mkfs.erofs not found (erofs-utils)"; exit 1; }
    command -v setfattr   >/dev/null || { echo "setfattr not found (package attr)"; exit 1; }

    echo "Setting owner/mode/labels/xattrs ..."
    sudo chown -R 0:0 "$root"
    sudo chmod -R 755 "$root"

    label_tree u:object_r:vendor_file:s0 "$root/lib64/camera"
    label_tree u:object_r:vendor_configs_file:s0 "$root/etc"
    label_tree u:object_r:vendor_configs_file:s0 "$root/firmware/fastchg"

    for d in etc/camera/config etc/camera/dng; do
        [ -d "$root/$d" ] && sudo setfattr -n trusted.overlay.opaque -v y "$root/$d"
    done

    echo "Compiling erofs..."
    rm -f "$img"
    sudo mkfs.erofs -z lz4hc,12 -C 65536 -E fragments "$img" "$root"
    sudo chown "$(id -u):$(id -g)" "$img"
    echo "Image created: $img ($(du -h "$img" | cut -f1))"
}

# $1 = staging dir, $2 = archive path, $3 = module.prop name-line pattern.
# Each target cleans only its own staging dir and archive.
# pack_module() {
#     local out="$1" archive="$2" name_re="$3"
#     echo "Creating zip archive..."
#     rm -f "$archive"
#     (
#         cd "$out"
#         zip -r -9 -y "$archive" .
#     )
#     # Version into module.prop (name + version)
#     sed -i -E -e "s/^($name_re)( [^ ]*)?$/\1 $VER/" -e "s/^version=.*/version=$VER/" "$out/module.prop"
#     zip -j -9 "$archive" "$out/module.prop" >/dev/null
#     echo "Archive created: $archive"
# }

pack_module() {
    local out="$1" archive="$2" name_re="$3"
    # Version into module.prop (name + version) — before zipping
    sed -i -E -e "s/^($name_re)( [^ ]*)?$/\1 $VER/" -e "s/^version=.*/version=$VER/" "$out/module.prop"
    echo "Creating zip archive..."
    rm -f "$archive"
    (
        cd "$out"
        zip -r -9 -y "$archive" .
    )
    echo "Archive created: $archive"
}

# Target 1: nomount (Magisk/KSU magic-mount, no runtime mounts)
OUT="$HERE/odm-6t-hw-nomount"

rm -rf "$OUT"
mkdir -p "$OUT/system/odm"

fill_payload "$OUT/system/odm"
[ -d "$HERE/template-nomount" ] || { echo "Template dir $HERE/template-nomount not found"; exit 1; }

cp -a "$HERE/template-nomount"/. "$OUT"/
pack_module "$OUT" "$HERE/odm-6t-hw-$VER-nomount.zip" "name=Ace 6T ODM HW pack for 15R"

# Target 2: overlay (odm.img compiled at install, overlayfs at boot)
[ -d "$HERE/template" ] || { echo "Template dir $HERE/template not found"; exit 1; }

PAYLOAD="$HERE/.odm-payload"
OUT="$HERE/odm-6t-hw"

trap 'sudo rm -rf "$PAYLOAD"' EXIT
sudo rm -rf "$PAYLOAD" "$OUT"
mkdir -p "$PAYLOAD" "$OUT"
fill_payload "$PAYLOAD"
build_image "$PAYLOAD" "$OUT/odm.img"

cp -a "$HERE/template"/. "$OUT"/
pack_module "$OUT" "$HERE/odm-6t-hw-$VER.zip" "name=Ace 6T ODM HW pack for 15R"
