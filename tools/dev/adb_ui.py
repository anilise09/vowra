"""Tiny adb UI driver for device walkthroughs:
python adb_ui.py <serial> dump | tap <text> [index] | type <text> | shot <file> | key <code>

Check the phone first (no call, see what is in front) and never open financial
apps. It deletes its on-device dump after every read."""
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

ADB = r'C:\Users\anili\AppData\Local\Android\Sdk\platform-tools\adb.exe'
serial, cmd, *args = sys.argv[1:]


def adb(*a, **kw):
    return subprocess.run([ADB, '-s', serial, *a], capture_output=True, **kw)


def nodes():
    for _ in range(6):
        adb('shell', 'uiautomator', 'dump', '/sdcard/ui.xml', timeout=60)
        xml = adb('exec-out', 'cat', '/sdcard/ui.xml', timeout=30).stdout.decode('utf-8', 'replace')
        adb('shell', 'rm', '-f', '/sdcard/ui.xml')
        if '<' in xml:
            break
        time.sleep(2)
    root = ET.fromstring(xml[xml.index('<'):])
    for n in root.iter('node'):
        label = (n.get('text') or '') or (n.get('content-desc') or '')
        b = [int(x) for x in re.findall(r'\d+', n.get('bounds'))]
        yield label, b, n


if cmd == 'dump':
    for label, b, n in nodes():
        if label.strip():
            print(f'{b} {label!r}' + (' [edit]' if n.get('class', '').endswith('EditText') else ''))
elif cmd == 'tap':
    want = args[0]
    exact = [x for x in nodes() if x[0] == want]
    hits = exact or [x for x in nodes() if want in x[0]]
    if not hits:
        sys.exit(f'not found: {want}')
    _, b, _ = hits[int(args[1]) if len(args) > 1 else 0]
    adb('shell', 'input', 'tap', str((b[0] + b[2]) // 2), str((b[1] + b[3]) // 2))
    time.sleep(1.2)
elif cmd == 'type':
    # adb input text drops @ and #; send those as key events.
    for part in re.split(r'([@#])', args[0]):
        if part == '@':
            adb('shell', 'input', 'keyevent', '77')
        elif part == '#':
            adb('shell', 'input', 'keyevent', '18')
        elif part:
            adb('shell', 'input', 'text', part.replace(' ', '%s'))
    time.sleep(0.6)
elif cmd == 'key':
    adb('shell', 'input', 'keyevent', args[0])
    time.sleep(0.6)
elif cmd == 'shot':
    open(args[0], 'wb').write(adb('exec-out', 'screencap', '-p').stdout)
