"""Native acceptance against the running SelectionFixture and installed Kamihi Lens.
Requires user-approved Screen Recording. Never changes macOS permission settings.
Build NativeDriver.swift with an explicit macOS 15 target to /tmp/kamihi-native-driver.
"""
from pathlib import Path
import json
import subprocess
import time

DRIVER = '/tmp/kamihi-native-driver'
APP = 'studio.kamihi.mandarinlens.v31'
FIXTURE = 'studio.kamihi.selectionfixture'
ROOT = Path(__file__).resolve().parents[1]

def driver(app, *args):
    return subprocess.check_output([DRIVER, '--app', app, *args], text=True)

def frames(app=APP):
    return json.loads(driver(app, '--frames'))

def wait_for(check, description, seconds=20):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        result = check()
        if result:
            return result
        time.sleep(.1)
    raise AssertionError(description)

def key(code, option=False):
    command = f'tell application "System Events" to key code {code}'
    if option:
        command += ' using option down'
    subprocess.run(['osascript', '-e', command], check=True)

def activate():
    key(49, option=True)
    wait_for(lambda: any('selection' in f['title'] for f in frames()), 'Selector did not open')

def clear(code=53):
    key(code, option=code == 49)
    wait_for(lambda: not frames(), 'Selector/highlight did not clear')

def select(target):
    activate()
    window = 'Kamihi Lens selection 1'
    xy = f"{target['x']},{target['y']}"
    driver(APP, '--window', window, '--point-at', xy)
    wait_for(lambda: target['word'] in driver(APP, '--window', window, '--dump'), 'Expected raster word was not recognized')
    driver(APP, '--window', window, '--point-at', xy, '--mouse-click')
    def highlight_only():
        current = frames()
        return current if len(current) == 1 and current[0]['title'] == 'Kamihi Lens highlight' else None
    selected = wait_for(highlight_only, 'Only a small highlight should remain')
    bounds = selected[0]['bounds']
    assert bounds['X'] <= target['x'] <= bounds['X'] + bounds['Width']
    assert bounds['Y'] <= target['y'] <= bounds['Y'] + bounds['Height']
    assert bounds['Width'] < 180 and bounds['Height'] < 80

def main():
    targets = [t for t in json.loads(Path('/tmp/kamihi-selection-targets.json').read_text()) if t['screen'] == 0]
    coffee = next(t for t in targets if t['word'] == 'coffee')
    chinese = next(t for t in targets if t['word'] == '学习')
    source = next(f for f in frames(FIXTURE) if f['title'] == 'Raster words 0')
    assert 'AXImage Controlled image-only text' in driver(FIXTURE, '--window', 'Raster words 0', '--dump')
    assert not frames(), 'Close the full app before starting this test'
    activate()
    clear()
    time.sleep(.5)
    assert not frames(), 'Cancelled OCR must not restore a selector'
    print('PASS: Escape cancels while preparing/choosing; no late selector resurrection.', flush=True)
    select(coffee)
    clear()
    print('PASS: image-only coffee selects a bounded highlight; Escape clears it; no lookup/app popup.', flush=True)
    select(chinese)
    shot = ROOT / 'screenshots/kamihi-3.8-selected-word.png'
    rect = source['bounds']
    subprocess.run(['screencapture', '-x', '-R' + ','.join(str(round(rect[k])) for k in ['X', 'Y', 'Width', 'Height']), str(shot)], check=True)
    clear(49)
    print('PASS: image-only 学习 selects a bounded highlight; Option–Space again clears it.', flush=True)
    for _ in range(3):
        activate()
        clear(49)
    time.sleep(.5)
    assert not frames()
    driver(APP, '--option-only')
    time.sleep(.2)
    assert not frames()
    print('PASS: repeated start/cancel leaves no overlays; ordinary Option alone does not activate.', flush=True)
    subprocess.run(['open', str(Path.home() / 'Applications/Kamihi Lens.app')], check=True)
    body = wait_for(lambda: (s if 'AXStaticText Study\n' in (s := driver(APP, '--window', 'Kamihi Lens', '--dump')) else None), 'Explicit app opening did not translate the selected word')
    assert 'AXTextArea Text to translate | 学习' in body and 'AXStaticText xué xí' in body
    assert all('selection' not in f['title'] and 'highlight' not in f['title'] for f in frames())
    print('PASS: explicit app opening retains 学习, translates to Study with pinyin, and clears selection UI.', flush=True)

if __name__ == '__main__':
    main()
