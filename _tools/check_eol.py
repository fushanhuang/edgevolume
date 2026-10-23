import pathlib

files = [
    'EdgeVolume.xcodeproj/project.pbxproj',
    'EdgeVolume.xcodeproj/xcshareddata/xcschemes/EdgeVolume.xcscheme',
    'EdgeVolume.xcodeproj/project.xcworkspace/contents.xcworkspacedata',
    'build-ipa.sh',
    '.github/workflows/build.yml',
]
BS = b'\\'
for f in files:
    d = pathlib.Path(f).read_bytes()
    print('%-62s CRLF=%-4d 反斜杠=%-3d BOM=%s' % (
        f, d.count(b'\r\n'), d.count(BS), d.startswith(b'\xef\xbb\xbf')))
