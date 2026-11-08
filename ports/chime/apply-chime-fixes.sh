#!/bin/bash
# Redmi 9T / 9 Power / Note 9 4G / POCO M3 (chime) on LineageOS 24.0: fixes for the 23.2 tree on the 24.0 platform.
# See README.md next to this file. Run from the top of the tree after `repo sync`. Idempotent; commits locally in
# device/xiaomi/chime and vendor/xiaomi/chime (a `repo sync` drops these commits: run the script again).
set -e
cd "${ANDROID_BUILD_TOP:-$PWD}"
D=device/xiaomi/chime
V=vendor/xiaomi/chime
[ -d $D ] && [ -d $V ] || { echo "run from the top of the tree, with $D and $V synced"; exit 1; }

python3 - <<'EOF'
import re
D, V = 'device/xiaomi/chime/', 'vendor/xiaomi/chime/'

# 1) protobuf vendorcompat is gone from LineageOS 24.0 (prebuilts/misc/protobuf_vendorcompat dropped);
#    the blobs ship libprotobuf-cpp-{full,lite}-3.9.1.so themselves.
p = D + 'device.mk'
s = open(p).read()
if 'vendorcompat' in s:
    s = '\n'.join(l for l in s.splitlines() if 'vendorcompat' not in l) + '\n'
    open(p, 'w').write(s)
    print('device.mk: protobuf vendorcompat removed')

p = V + 'Android.bp'
s = open(p).read()
if 'vendorcompat' in s:
    s = '\n'.join(l for l in s.splitlines() if 'vendorcompat' not in l) + '\n'
    open(p, 'w').write(s)
    print('vendor Android.bp: protobuf vendorcompat deps removed')

# 2) per_boot_file: AOSP declares it in system/sepolicy/private since 24.0, and vendor policy cannot
#    see system-private types. Drop the tree's own declaration and every vendor reference — the system
#    policy manages /data/per_boot (labeling and init access) on its own now.
p = D + 'sepolicy/vendor/file.te'
s = open(p).read()
if 'type per_boot_file' in s:
    s = '\n'.join(l for l in s.splitlines()
                  if not l.startswith('type per_boot_file,')) + '\n'
    open(p, 'w').write(s)
    print('vendor file.te: duplicate per_boot_file declaration removed')
for p in (D + 'sepolicy/vendor/init.te',
          D + 'sepolicy/vendor/kernel.te',
          D + 'sepolicy/vendor/toolbox.te',
          D + 'sepolicy/vendor/file_contexts'):
    s = open(p).read()
    if 'per_boot_file' in s:
        s = '\n'.join(l for l in s.splitlines() if 'per_boot_file' not in l) + '\n'
        open(p, 'w').write(s)
        print('vendor sepolicy: per_boot_file reference removed: ' + p.split('/')[-1])

# 3) Android 17 removed the HIDL IR HAL; the blobs only carry the legacy consumerir.bengal.so.
p = D + 'device.mk'
s = open(p).read()
if 'android.hardware.ir@1.0-impl' in s:
    old = ('# IR\n'
           'PRODUCT_PACKAGES += \\\n'
           '    android.hardware.ir@1.0-impl \\\n'
           '    android.hardware.ir@1.0-service\n\n')
    assert old in s, 'IR block found but in an unexpected shape'
    s = s.replace(old, '')
    open(p, 'w').write(s)
    print('device.mk: HIDL IR HAL removed')

p = D + 'configs/vintf/manifest.xml'
s = open(p).read()
if 'android.hardware.ir' in s:
    pat = re.compile(r'\n?\s*<hal format="hidl">\s*<name>android\.hardware\.ir</name>.*?</hal>\n', re.S)
    assert pat.search(s), 'vintf IR hal found but in an unexpected shape'
    s = pat.sub('\n', s)
    open(p, 'w').write(s)
    print('vintf manifest: HIDL IR HAL declaration removed')
EOF

if [ -n "$(git -C $D status --porcelain)" ]; then
  git -C $D add -A
  git -C $D commit -q -m 'chime: BlueOS: drop protobuf vendorcompat and the removed HIDL IR HAL for 24.0'
fi
if [ -n "$(git -C $V status --porcelain)" ]; then
  git -C $V add -A
  git -C $V commit -q -m 'chime: BlueOS: drop protobuf vendorcompat deps from prebuilt modules (removed in 24.0)'
fi
git -C $D log --oneline -n 1
git -C $V log --oneline -n 1
