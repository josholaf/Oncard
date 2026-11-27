#!/usr/bin/env python3
"""Wires the daily revision reminder permissions into the freshly generated
android/ folder. The repo does not commit android/; CI regenerates it with
flutter create and then runs this script.

The flutter_local_notifications plugin registers its own receivers through
manifest merging, so the app manifest only needs the runtime notification
permission (Android 13+) and the boot permission so scheduled reminders
survive a device restart.
"""
import io
import os

MANIFEST = 'android/app/src/main/AndroidManifest.xml'

PERMISSIONS = [
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.RECEIVE_BOOT_COMPLETED',
    'android.permission.VIBRATE',
]

manifest = io.open(MANIFEST, encoding='utf-8').read()
for name in PERMISSIONS:
    if name in manifest:
        print('manifest: ' + name + ' already present')
        continue
    permission = '<uses-permission android:name="' + name + '" />\n    '
    patched = manifest.replace('<application', permission + '<application', 1)
    io.open(MANIFEST, 'w', encoding='utf-8').write(patched)
    manifest = patched
    print('manifest: ' + name + ' added')
