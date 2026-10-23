"""交叉核对：.m 中所有 [self xxx] / [weakSelf xxx] 调用是否已在
.h 或 .m 内的 class extension 中声明。ObjC 中未声明的 selector 是编译 error。"""
import pathlib
import re
import sys

SRC = pathlib.Path(__file__).resolve().parent.parent / "EdgeVolume"

# 匹配 [receiver selectorPart:...] 形式，取出 selector 关键字列表
CALL = re.compile(r'\[\s*(\w+)\s+((?:[\w:]+\s*:\s*[^\]]*?)+)\]', re.S)
KEY = re.compile(r'([\w:]+)\s*:')


def selectors_of(call_body):
    """从调用体里抽出 selector 片段（参数部分可能含嵌套[]，这里用括号深度辅助）"""
    # 去掉嵌套的 [...] 与 (...)
    depth = 0
    out = []
    buf = []
    for ch in call_body:
        if ch in '([':
            depth += 1
        elif ch in ')]':
            if depth == 0:
                break
            depth -= 1
        if depth == 0:
            buf.append(ch)
    s = ''.join(buf)
    # s 形如 "foo:bar:baz" 或 "foo"
    parts = [p.strip() for p in s.split(':')]
    sel = parts[0] if parts else ''
    for p in parts[1:]:
        if p:
            sel += ':'
    return sel


problems = []
for m in sorted(SRC.glob("*.m")):
    src = m.read_text(encoding="utf-8")
    # 收集声明：.h 文件 + 本 .m 的 class extension(@interface X ())
    decls = set()
    h = m.with_suffix(".h")
    if h.exists():
        decls |= set(re.findall(r'^\s*[-+]\s*\([^)]*\)\s*([\w:]+)', h.read_text(encoding="utf-8"), re.M))
    for mm in re.finditer(r'@interface\s+\w+\s*\(\)(.*?)@end', src, re.S):
        decls |= set(re.findall(r'^\s*[-+]\s*\([^)]*\)\s*([\w:]+)', mm.group(1), re.M))
    # 本文件内的定义也算已知（允许后定义——只要声明过就行，这里两者都算）
    decls |= set(re.findall(r'^\s*[-+]\s*\([^)]*\)\s*([\w:]+)\s*\{', src, re.M))

    for cm in CALL.finditer(src):
        recv, body = cm.group(1), cm.group(2)
        if recv not in ("self", "weakSelf", "strongSelf"):
            continue
        sel = selectors_of(body)
        if not sel or ':' not in sel and sel in decls:
            continue
        if sel in decls:
            continue
        # 逐段匹配（selector 可能只写前几段）
        if any(d == sel or d.startswith(sel) or sel.startswith(d) for d in decls):
            continue
        line = src[:cm.start()].count("\n") + 1
        problems.append("%s:%d  未声明的 selector: [%s %s]" % (m.name, line, recv, sel))

if problems:
    print("发现 %d 处可疑调用：" % len(problems))
    for p in problems:
        print("  ", p)
    sys.exit(1)
print("全部 [self/weakSelf/strongSelf ...] 调用均已有声明")
