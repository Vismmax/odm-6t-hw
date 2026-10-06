#!/system/bin/sh
MODDIR=${0%/*}
ODM="$MODDIR/system/odm"

CHCON_DIRS="
lib64/camera:vendor_file
etc/camera:vendor_configs_file
etc/power_profile:vendor_configs_file
etc/devices_config:vendor_configs_file
etc/temperature_profile:vendor_configs_file
etc/sensor:vendor_configs_file
firmware:vendor_configs_file
etc/permissions:vendor_configs_file
etc/vintf:vendor_configs_file
etc/init:vendor_configs_file
etc/wifi:vendor_configs_file
etc/gps:vendor_configs_file
"

for spec in $CHCON_DIRS; do
    d="${spec%%:*}"
    ctx="${spec##*:}"
    [ -d "$ODM/$d" ] && chcon -R "u:object_r:${ctx}:s0" "$ODM/$d"
done

find "$ODM" -name "*.so" -exec chcon u:object_r:vendor_file:s0 {} + 2>/dev/null

chown -R 0:0 "$ODM" 2>/dev/null
find "$ODM" -type d -exec chmod 755 {} + 2>/dev/null
find "$ODM" -type f -exec chmod 644 {} + 2>/dev/null
find "$ODM" -name "*.so" -exec chmod 755 {} + 2>/dev/null
