import re, sys

files = [
 'EdgeVolume/AppDelegate.h','EdgeVolume/AppDelegate.m','EdgeVolume/SceneDelegate.m',
 'EdgeVolume/EdgeTouchWindow.m','EdgeVolume/PassThroughWindow.m',
 'EdgeVolume/OverlayRootViewController.m','EdgeVolume/SettingsViewController.m',
 'EdgeVolume/Info.plist'
]
ok = True
for f in files:
    src = open(f, 'rb').read()
    crlf = src.count(b'\r\n'); lone = src.count(b'\r') - crlf
    if crlf or lone:
        print(f'{f}: line-ending issue CRLF={crlf} loneCR={lone}'); ok = False
    if f.endswith(('.m', '.h')):
        s = src.decode('utf-8')
        s = re.sub(r'//[^\n]*', '', s)
        s = re.sub(r'/\*.*?\*/', '', s, flags=re.S)
        # strip ObjC string literals
        s = re.sub(r'@"(\\.|[^"\\])*"', '""', s)
        # strip char literals
        s = re.sub(r"'(\\.|[^'\\])*'", "''", s)
        for a, b in [('{', '}'), ('(', ')'), ('[', ']')]:
            ca, cb = s.count(a), s.count(b)
            if ca != cb:
                print(f'{f}: {a}{b} unbalanced {ca} vs {cb}'); ok = False
print('ALL CHECKS PASSED' if ok else 'ISSUES FOUND')
