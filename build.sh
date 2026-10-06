#!/bin/bash

set -e

VER="${1:-test}"  # donor firmware version: ./build.sh [version], default test
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/odm-6t-hw"
IMAGE="$HERE/odm.img"
TARGET="$OUT/system/odm"
TEMPLATE="$HERE/template"
ARCHIVE="$HERE/odm-6t-hw-$VER.zip"

[ -f "$IMAGE" ] || { echo "No 6t odm image"; exit 1; }

rm -rf "$OUT"
mkdir -p "$TARGET"


PATHS=(
    # 6T camera: macan* sensors, EIS, DNG profiles, front camera
    "/lib64/camera"
    "/etc/camera/config"
    "/etc/camera/camera_engmode.xml"
    "/etc/camera/CameraHWConfiguration.config"
    "/etc/camera/oplus_eis_camera.vcfg"
    "/etc/camera/eis_camera.vcfg"
    "/etc/camera/dng"
    "/etc/camera/settings_fdc.txt"
    "/etc/camera/settings_fdc_lite.txt"
    "/etc/camera/fwk_config.json"
    "/etc/camera/vainr_cfg.json"
    "/etc/camera/facerestore"
    "/etc/camera/Owl_Algo_model"
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
    "/etc/sensor/config/json_list"
    "/etc/sensor/config/oplus_rotation_detect.json"
    "/etc/sensor/config/molokai_mtp_mxg4300_0.json"
)

for path in "${PATHS[@]}"; do
    dest="$TARGET$path"
    echo "Extracting $path ..."
    mkdir -p "$(dirname "$dest")"
    if fsck.erofs --extract="$dest" --path="$path" "$IMAGE"; then
        :
    else
        echo "Extraction failed for $path"
    fi
done

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

for file in "${TOUCH_FILES[@]}"; do
    dest="$TARGET$file"
    mkdir -p "$(dirname "$dest")"
    touch "$dest"
done

[ -d "$TEMPLATE" ] || { echo "Template dir $TEMPLATE not found"; exit 1; }
cp -a "$TEMPLATE"/. "$OUT"/

echo "Creating zip archive..."
rm -f "$ARCHIVE" "$HERE"/odm-6t-hw-*.zip
(
    cd "$OUT"
    zip -r -9 -y "$ARCHIVE" .
)
# Version into module.prop (name + version)
sed -i -E -e "s/^(name=Ace 6T ODM HW pack for 15R)( [^ ]*)?$/\1 $VER/" -e "s/^version=.*/version=$VER/" "$OUT/module.prop"
zip -j -9 "$ARCHIVE" "$OUT/module.prop" >/dev/null
echo "Archive created: $ARCHIVE"
