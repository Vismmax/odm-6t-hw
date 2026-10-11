#!/system/bin/sh

REPLACE="/system/odm/lib64/camera /system/odm/etc/camera/config /system/odm/etc/camera/dng"

chown -R 0:0 "$MODPATH" 2>/dev/null
find "$MODPATH" -type d -exec chmod 755 {} + 2>/dev/null
find "$MODPATH" -type f -exec chmod 644 {} + 2>/dev/null
find "$MODPATH" -name "*.so" -exec chmod 755 {} + 2>/dev/null

ODM="$MODPATH/system/odm"

if [ -d "$ODM" ]; then chcon -R u:object_r:vendor_file:s0 "$ODM"; fi
if [ -d "$ODM/etc" ]; then chcon -R u:object_r:vendor_configs_file:s0 "$ODM/etc"; fi
if [ -d "$ODM/firmware" ]; then chcon -R u:object_r:vendor_configs_file:s0 "$ODM/firmware"; fi
