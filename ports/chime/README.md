# Redmi 9T / 9 Power / Note 9 4G / POCO M3 (`chime`, SM6115): how the BlueOS build is made

Official LineageOS for `chime` stops at 23.2: [Joe7500's device tree](https://github.com/Joe7500/device_xiaomi_chime),
[vendor blobs](https://github.com/Joe7500/vendor_xiaomi_chime) and
[kernel](https://github.com/Joe7500/kernel_xiaomi_chime) (main branch, already made Android-16-compatible)
have no `lineage-24.0` branches. The BlueOS build takes the device tree, blobs and kernel from their newest
branches and everything else from 24.0 — the same model as the
[Galaxy S20 FE port](https://github.com/GDmio/BlueOS/tree/main/ports/r8q). Booted and worked on a Redmi 9T.

Joe7500 also ships unofficial builds for this family on
[SourceForge](https://sourceforge.net/projects/joes-android-builds/) (LineageOS 17–24, PixelOS 16.2/17.0,
crDroid, axion, risingOS…). His `lineage-24.0-UNOFFICIAL-chime` zip is a useful reference: if a BlueOS build
misbehaves, flash it to tell platform problems from BlueOS problems. A BlueOS GSI (DSU) can also be tried over
his PixelOS 17 build without wiping data.

## Sources
`.repo/local_manifests/chime.xml` (plus BlueOS's own manifest), on top of a LineageOS 24.0 tree:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <project path="device/xiaomi/chime" remote="github" name="Joe7500/device_xiaomi_chime" revision="lineage-23.2" />
  <project path="vendor/xiaomi/chime" remote="github" name="Joe7500/vendor_xiaomi_chime" revision="lineage-23.2" clone-depth="1" />
  <project path="kernel/xiaomi/chime" remote="github" name="Joe7500/kernel_xiaomi_chime" revision="main" />
  <!-- the tree's lineage.dependencies points at old branches; pin hardware/xiaomi to 24.0 -->
  <project path="hardware/xiaomi" remote="github" name="LineageOS/android_hardware_xiaomi" revision="lineage-24.0" />
</manifest>
```

## Fixes
`apply-chime-fixes.sh` (run from the top of the tree after `repo sync`; idempotent, commits locally in
`device/xiaomi/chime` and `vendor/xiaomi/chime`):
- **protobuf vendorcompat.** LineageOS 24.0 dropped `prebuilts/misc/protobuf_vendorcompat`, so
  `libprotobuf-cpp-{full,lite}-3.9.1-vendorcompat` no longer exist. Removed from `device.mk` PRODUCT_PACKAGES
  and as `shared_libs` of the prebuilt modules in `vendor/xiaomi/chime/Android.bp`. The blobs ship
  `libprotobuf-cpp-{full,lite}-3.9.1.so` themselves, so nothing is missing at runtime.
- **per_boot_file sepolicy.** AOSP declares `per_boot_file` in `system/sepolicy/private` since 24.0, and
  vendor policy cannot see system-private types. Removed the tree's own declaration and every vendor
  reference (init/kernel/toolbox allows, file_contexts) — the system policy manages `/data/per_boot` on
  its own now.
- **HIDL IR HAL.** Android 17 removed `android.hardware.ir@1.0-impl` / `-service` from AOSP; the blobs only
  carry the legacy `consumerir.bengal.so`. Dropped both modules and the vintf manifest declaration.
  **Known limitation: the IR blaster is offline** until an AIDL ConsumerIr HAL over the legacy lib is ported.

## Notes
- `device.mk` includes `vendor/lineage-priv/keys/keys.mk` unconditionally: generate signing keys
  (wiki LineageOS: «Signing builds») or comment the include out.
- Do not redefine `PRODUCT_MAINLINE_BLUETOOTH_SEPOLICY_DEV_CERTIFICATES` in the keys dir; LineageOS derives
  it from `PRODUCT_DEFAULT_DEV_CERTIFICATE`, and a hand-made copy makes the seinfo build fail.
- `lunch` needs a release on this branch: `lunch lineage_chime-cp2a-userdebug`.
- The boot animation is 1080p-ready already (`TARGET_BOOT_ANIMATION_RES := 1080`); widget thresholds are
  screen-dependent as usual — see [PORTING.md](../../PORTING.md).

## License
The port follows the [BlueOS license](../../LICENSE): if you distribute builds or code from here, keep the
[NOTICE](../../NOTICE) file and state that the work is based on BlueOS by GDmio with a link to
https://github.com/GDmio/BlueOS . Device tree, kernel and blobs remain under their own licenses (Joe7500 /
TheMuppets-style sources).
