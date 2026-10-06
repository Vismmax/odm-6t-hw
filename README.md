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

- Default version: `test` (pass the donor 15R firmware version, e.g. `./build.sh 16.0.10.500`).
- Output: `odm-6t-hw-<version>.zip` (KernelSU/Magisk flashable).
- The version is stamped into `module.prop` (`name` + `version`); the `template/`
  sources are left untouched.

How it works:

1. Extracts the `PATHS` list (camera, power, charging, thermal, sensors) from
   `odm.img` via `fsck.erofs` into `odm-6t-hw/system/odm`.
2. Creates empty mask files (`TOUCH_FILES`) over foreign 15R hardware
   (`silicon_x25_X2_*`, `24877` charging profile, 24877 thermal profile,
   BMP5/barometer). Directories with sensor listings (`lib64/camera`,
   `etc/camera/config`, `etc/camera/dng`) are replaced wholesale via `.replace`.
3. Overlays `template/` (`module.prop`, `customize.sh`, `post-fs-data.sh` —
   permissions `755` dirs / `644` files / `755` `.so`, SELinux contexts).
4. Zips the result.

## Install

Flash the zip in KernelSU Next (or Magisk) and reboot. To revert, disable or
remove the module and reboot — `/odm` is only overlaid, never modified.

## Layout

```text
build.sh        build script (PATHS + TOUCH_FILES + versioning)
template/       module skeleton (module.prop, customize.sh, post-fs-data.sh)
