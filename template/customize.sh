#!/system/bin/sh

REPLACE="/system/odm/lib64/camera /system/odm/etc/camera/config /system/odm/etc/camera/dng"

chown -R 0:0 "$MODPATH" 2>/dev/null
find "$MODPATH" -type d -exec chmod 755 {} + 2>/dev/null
find "$MODPATH" -type f -exec chmod 644 {} + 2>/dev/null
find "$MODPATH" -name "*.so" -exec chmod 755 {} + 2>/dev/null
