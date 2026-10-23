import pathlib

r = pathlib.Path('_remote.pbxproj').read_bytes()
l = pathlib.Path('EdgeVolume.xcodeproj/project.pbxproj').read_bytes()
BS = b'\\'
print('远端大小:', len(r), '| 本地大小:', len(l))
print('远端反斜杠数:', r.count(BS), '| 本地:', l.count(BS))
print('远端 CRLF:', r.count(b'\r\n'), '| 本地:', l.count(b'\r\n'))
print('远端 BOM:', r.startswith(b'\xef\xbb\xbf'), '| 本地:', l.startswith(b'\xef\xbb\xbf'))
print('逐字节一致' if r == l else '不一致')

if r != l:
    import difflib
    rl = r.decode('utf-8', 'replace').splitlines()
    ll = l.decode('utf-8', 'replace').splitlines()
    d = list(difflib.unified_diff(rl, ll, 'remote', 'local', lineterm='', n=1))
    print('--- 差异（前 60 行）---')
    print('\n'.join(d[:60]))
