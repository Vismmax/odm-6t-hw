#!/system/bin/sh

[ "$(id -u)" != "0" ] && exit 1

MODDIR=${0%/*}
IMG_FILE="$MODDIR/odm.img"
MNT_DIR="/mnt/odm6t/odm"
EMPTY="/mnt/odm6t/empty"

mkdir -p "$MNT_DIR" "$EMPTY"

mount -o ro,loop -t erofs "$IMG_FILE" "$MNT_DIR"
mount -t overlay overlay-odm -o lowerdir="$MNT_DIR/etc:/odm/etc" "/odm/etc"
mount -t overlay overlay-odm -o lowerdir="$MNT_DIR/lib64/camera:$EMPTY" "/odm/lib64/camera"
mount -t overlay overlay-odm -o lowerdir="$MNT_DIR/firmware/fastchg:/odm/firmware/fastchg" "/odm/firmware/fastchg"

exit 0
