from pathlib import Path
import re

manifest = Path('android/app/src/main/AndroidManifest.xml')
if not manifest.exists():
    raise SystemExit('AndroidManifest.xml was not generated. Run: flutter create --platforms=android .')
xml = manifest.read_text(encoding='utf-8')
permissions = [
    'android.permission.INTERNET',
    'android.permission.RECORD_AUDIO',
    'android.permission.MODIFY_AUDIO_SETTINGS',
    'android.permission.ACCESS_NETWORK_STATE',
    'android.permission.CHANGE_NETWORK_STATE',
]
for permission in permissions:
    declaration = f'    <uses-permission android:name="{permission}" />'
    if permission not in xml:
        xml = re.sub(r'(<manifest[^>]*>)', r'\1\n' + declaration, xml, count=1)
manifest.write_text(xml, encoding='utf-8')

# flutter_webrtc requires a recent Android API level.
for path in [Path('android/app/build.gradle.kts'), Path('android/app/build.gradle')]:
    if not path.exists():
        continue
    text = path.read_text(encoding='utf-8')
    text = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 23', text)
    text = re.sub(r'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 23', text)
    path.write_text(text, encoding='utf-8')

strings = Path('android/app/src/main/res/values/strings.xml')
if strings.exists():
    text = strings.read_text(encoding='utf-8')
    text = re.sub(r'(<string name="app_name">).*?(</string>)', r'\1Atheer AI\2', text, count=1, flags=re.S)
    strings.write_text(text, encoding='utf-8')

print('Android microphone, audio routing, and network permissions are ready.')
