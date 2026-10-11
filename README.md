# Ace 6T ODM HW pack for 15R

KernelSU Next / Magisk module: ODM calibrations of the **OnePlus Ace 6T** board over **OnePlus 15R** firmware.
Fixes camera (macan sensors, EIS, DNG, 16 MP front), 8300 mAh battery reporting,
charging tables, thermal profiles and sensor calibrations.

## Requirements

- Linux with `bash`, `zip`, `fsck.erofs` (erofs-utils ≥ 1.9)
- `odm.img` — ODM image extracted from Ace 6T firmware (place it next to `build.sh`)

## Build

```sh
./build.sh [version]
```

- Output: two KernelSU/Magisk flashable zips:
  - `odm-6t-hw-nomount-<version>.zip` (magic-mount, no runtime mounts)
  - `odm-6t-hw-<version>.zip` (overlayfs: `odm.img` compiled at install,
    overlay mounts at boot)
- The version is stamped into `module.prop` (`name` + `version`); the `template/`
  and `template-nomount/` sources are left untouched.

How it works:

1. Extracts the shared `PATHS` list (camera, power, charging, thermal, sensors)
   from `odm.img` via `fsck.erofs` — into `odm-6t-hw-nomount/system/odm` for the
   nomount target, into `odm-6t-hw/odm` for the overlay target.
2. Creates empty mask files (`TOUCH_FILES`) over foreign 15R hardware
   (`silicon_x25_X2_*`, `24877` charging profile, 24877 thermal profile,
   BMP5/barometer). Directories with sensor listings (`lib64/camera`,
   `etc/camera/config`, `etc/camera/dng`) are replaced wholesale via `.replace`.
3. Overlays the template (`module.prop`, `customize.sh`, `post-fs-data.sh`).
   Nomount applies magic-mount `REPLACE` + `chown 0:0`, perms `755` dirs /
   `644` files / `755` `.so`, SELinux contexts. Overlay compiles `odm/` into
   `odm.img` at install (`customize.sh`, `mkfs.erofs -z lz4hc,12`) and mounts
   overlayfs at boot (`post-fs-data.sh`): `etc/camera`, `power_profile`,
   `devices_config`, `fastchg`, `temperature_profile`, `sensor`,
   `permissions/sku_15` merged with stock, `camera/config`, `camera/dng`,
   `lib64/camera` replaced wholesale via an empty upper dir. All perms `0:0/755`.
4. Zips the result.
