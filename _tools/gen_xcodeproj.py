#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
EdgeVolume.xcodeproj 生成器
============================
用途：生成 EdgeVolume.xcodeproj/project.pbxproj 与共享 scheme，
      使工程不依赖 xcodegen，双击即可编译。

特点：
  - 确定性 UUID（同一输入永远得到同一工程文件，git diff 友好）
  - 生成后自动用内置 OpenStep plist 解析器做结构自检
  - 私有框架（FrontBoard 等）通过 OTHER_LDFLAGS 以 .tbd 链接

用法：python3 gen_xcodeproj.py            # 在项目根目录执行
"""
import hashlib
import os
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC_DIR = ROOT / "EdgeVolume"
PROJ_DIR = ROOT / "EdgeVolume.xcodeproj"

TARGET_NAME = "EdgeVolume"
BUNDLE_ID = "com.edgevolume.app"
DEPLOYMENT_TARGET = "16.0"
PRODUCT_NAME = "EdgeVolume"

SDK_FRAMEWORKS = [
    "UIKit.framework",
    "Foundation.framework",
    "CoreGraphics.framework",
    "QuartzCore.framework",
    "AVFoundation.framework",
    "MediaPlayer.framework",
]

TBD_LIBS = [
    "FrontBoard.tbd",
    "FrontBoardServices.tbd",
    "RunningBoardServices.tbd",
    "AppleAccount.tbd",
]

# ---------------------------------------------------------------- 工具

def uuid24(seed: str) -> str:
    """确定性 24 位大写十六进制 UUID（Xcode 风格）。"""
    return hashlib.sha1(seed.encode("utf-8")).hexdigest()[:24].upper()


_SAFE_BARE = re.compile(r"^[A-Za-z0-9_$.@/+-]+$")


def fmt_scalar(v) -> str:
    if isinstance(v, bool):
        return "YES" if v else "NO"
    if isinstance(v, (int, float)):
        return str(v)
    s = str(v)
    if _SAFE_BARE.match(s):
        return s
    return '"%s"' % s.replace('\\', '\\\\').replace('"', '\\"')


def fmt_key(k: str) -> str:
    return fmt_scalar(k)


def render(v, ind: int) -> str:
    """渲染 OpenStep plist 值。ind 为当前层级缩进深度（tab 数）。"""
    pad = "\t" * ind
    close = "\t" * (ind - 1)
    if isinstance(v, dict):
        if not v:
            return "{\n%s}" % close
        lines = ["%s%s = %s;" % (pad, fmt_key(k), render(val, ind + 1))
                 for k, val in v.items()]
        return "{\n" + "\n".join(lines) + "\n%s}" % close
    if isinstance(v, list):
        if not v:
            return "(\n%s)" % close
        lines = ["%s%s," % (pad, render(x, ind + 1)) for x in v]
        return "(\n" + "\n".join(lines) + "\n%s)" % close
    return fmt_scalar(v)


# ---------------------------------------------------------------- 收集源文件

def collect_sources():
    sources, headers, tbds = [], [], []
    for p in sorted(SRC_DIR.rglob("*")):
        if not p.is_file():
            continue
        rel = p.relative_to(SRC_DIR)
        if p.suffix == ".m":
            sources.append(str(rel))
        elif p.suffix == ".h":
            headers.append(str(rel))
        elif p.suffix == ".tbd":
            tbds.append(str(rel))
    return sources, headers, tbds


# ---------------------------------------------------------------- 生成

def build_objects():
    sources, headers, tbds = collect_sources()

    ids = {}
    def ID(name):
        if name not in ids:
            ids[name] = uuid24("EdgeVolume/" + name)
        return ids[name]

    objs = {}          # uuid -> (comment, dict)
    def add(name, comment, d):
        u = ID(name)
        assert u not in objs, "UUID collision: %s" % name
        objs[u] = (comment, d)
        return u

    # ---- PBXFileReference
    # 注意：Private/ 下的文件位于 path=Private 的组内，FileReference.path 必须用
    # 相对该组的 basename，否则组路径会叠加成 Private/Private/...
    file_refs = {}
    for rel in sources + headers:
        ft = "sourcecode.c.objc" if rel.endswith(".m") else "sourcecode.c.h"
        path = rel[len("Private/"):] if rel.startswith("Private/") else rel
        u = add("file:" + rel, path, {
            "isa": "PBXFileReference",
            "fileEncoding": 4,
            "lastKnownFileType": ft,
            "path": path,
            "sourceTree": "<group>",
        })
        file_refs[rel] = u

    appicon_ref = add("file:Assets.xcassets", "Assets.xcassets", {
        "isa": "PBXFileReference",
        "lastKnownFileType": "folder.assetcatalog",
        "path": "Assets.xcassets",
        "sourceTree": "<group>",
    })
    file_refs["Assets.xcassets"] = appicon_ref

    fw_refs = {}
    for fw in SDK_FRAMEWORKS:
        u = add("fw:" + fw, fw, {
            "isa": "PBXFileReference",
            "lastKnownFileType": "wrapper.framework",
            "name": fw,
            "path": "System/Library/Frameworks/" + fw,
            "sourceTree": "SDKROOT",
        })
        fw_refs[fw] = u

    for t in tbds:
        name = t.split("/")[-1]
        u = add("tbd:" + t, name, {
            "isa": "PBXFileReference",
            "lastKnownFileType": "sourcecode.text-based-dylib-standard-file",
            "path": name,
            "sourceTree": "<group>",
        })
        file_refs[t] = u

    product_ref = add("product", TARGET_NAME + ".app", {
        "isa": "PBXFileReference",
        "explicitFileType": "wrapper.application",
        "includeInIndex": 0,
        "path": TARGET_NAME + ".app",
        "sourceTree": "BUILT_PRODUCTS_DIR",
    })

    # ---- PBXBuildFile
    build_files = []
    for rel in sources:
        u = add("bf:src:" + rel, "%s in Sources" % rel, {
            "isa": "PBXBuildFile",
            "fileRef": file_refs[rel],
        })
        build_files.append((u, "%s in Sources" % rel))
    for fw in SDK_FRAMEWORKS:
        u = add("bf:fw:" + fw, "%s in Frameworks" % fw, {
            "isa": "PBXBuildFile",
            "fileRef": fw_refs[fw],
        })
        build_files.append((u, "%s in Frameworks" % fw))
    u = add("bf:res:assets", "Assets.xcassets in Resources", {
        "isa": "PBXBuildFile",
        "fileRef": appicon_ref,
    })
    build_files.append((u, "Assets.xcassets in Resources"))

    # ---- Groups
    src_children = [file_refs[r] for r in sources + headers]
    src_children.append(file_refs["Assets.xcassets"])
    private_children = [file_refs[t] for t in tbds] + \
                       [file_refs[h] for h in headers if h.startswith("Private/")]

    private_group = add("group:Private", "Private", {
        "isa": "PBXGroup",
        "children": private_children,
        "path": "Private",
        "sourceTree": "<group>",
    })

    src_group = add("group:" + TARGET_NAME, TARGET_NAME, {
        "isa": "PBXGroup",
        "children": [file_refs[r] for r in sources
                     if not r.startswith("Private/")]
                    + [file_refs[h] for h in headers if not h.startswith("Private/")]
                    + [file_refs["Assets.xcassets"], private_group],
        "path": TARGET_NAME,
        "sourceTree": "<group>",
    })

    fw_group = add("group:Frameworks", "Frameworks", {
        "isa": "PBXGroup",
        "children": [fw_refs[fw] for fw in SDK_FRAMEWORKS],
        "name": "Frameworks",
        "sourceTree": "<group>",
    })

    products_group = add("group:Products", "Products", {
        "isa": "PBXGroup",
        "children": [product_ref],
        "name": "Products",
        "sourceTree": "<group>",
    })

    main_group = add("group:main", None, {
        "isa": "PBXGroup",
        "children": [src_group, fw_group, products_group],
        "sourceTree": "<group>",
    })

    # ---- Build phases
    sources_phase = add("phase:Sources", "Sources", {
        "isa": "PBXSourcesBuildPhase",
        "buildActionMask": 2147483647,
        "files": [u for u, c in build_files if c.endswith("in Sources")],
        "runOnlyForDeploymentPostprocessing": 0,
    })
    fw_phase = add("phase:Frameworks", "Frameworks", {
        "isa": "PBXFrameworksBuildPhase",
        "buildActionMask": 2147483647,
        "files": [u for u, c in build_files if c.endswith("in Frameworks")],
        "runOnlyForDeploymentPostprocessing": 0,
    })
    res_phase = add("phase:Resources", "Resources", {
        "isa": "PBXResourcesBuildPhase",
        "buildActionMask": 2147483647,
        "files": [u for u, c in build_files if c.endswith("in Resources")],
        "runOnlyForDeploymentPostprocessing": 0,
    })

    # ---- Configurations
    ldflags = ["$(inherited)"] + \
              ["$(SRCROOT)/EdgeVolume/Private/" + t for t in TBD_LIBS]

    def target_settings(cfg):
        s = {
            "ARCHS": "arm64",
            "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
            "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
            "CLANG_ANALYZER_NONNULL": True,
            "CLANG_ENABLE_MODULES": True,
            "CLANG_ENABLE_OBJC_ARC": True,
            "CLANG_WARN_BOOL_CONVERSION": True,
            "CLANG_WARN_CONSTANT_CONVERSION": True,
            "CLANG_WARN_EMPTY_BODY": True,
            "CLANG_WARN_ENUM_CONVERSION": True,
            "CLANG_WARN_INFINITE_RECURSION": True,
            "CLANG_WARN_INT_CONVERSION": True,
            "CLANG_WARN_NON_LITERAL_NULL_CONVERSION": True,
            "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF": True,
            "CLANG_WARN_OBJC_LITERAL_CONVERSION": True,
            "CLANG_WARN_OBJC_ROOT_CLASS": True,
            "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": True,
            "CLANG_WARN_RANGE_LOOP_ANALYSIS": True,
            "CLANG_WARN_STRICT_PROTOTYPES": True,
            "CLANG_WARN_SUSPICIOUS_MOVE": True,
            "CLANG_WARN_UNREACHABLE_CODE": True,
            "CLANG_WARN__DUPLICATE_METHOD_MATCH": True,
            "CODE_SIGN_ENTITLEMENTS": "EdgeVolume/entitlements.plist",
            "CODE_SIGN_STYLE": "Automatic",
            "CURRENT_PROJECT_VERSION": 1,
            "ENABLE_USER_SCRIPT_SANDBOXING": True,
            "GCC_C_LANGUAGE_STANDARD": "gnu17",
            "GCC_NO_COMMON_BLOCKS": True,
            "GCC_WARN_64_TO_32_BIT_CONVERSION": True,
            "GCC_WARN_ABOUT_RETURN_TYPE": True,
            "GCC_WARN_UNDECLARED_SELECTOR": True,
            "GCC_WARN_UNINITIALIZED_AUTOS": True,
            "GCC_WARN_UNUSED_FUNCTION": True,
            "GCC_WARN_UNUSED_VARIABLE": True,
            "INFOPLIST_FILE": "EdgeVolume/Info.plist",
            "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
            "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
            "MARKETING_VERSION": "1.0",
            "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE" if cfg == "Debug" else "NO",
            "ONLY_ACTIVE_ARCH": True if cfg == "Debug" else False,
            "OTHER_LDFLAGS": ldflags,
            "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
            "PRODUCT_NAME": "$(TARGET_NAME)",
            "SDKROOT": "iphoneos",
            "TARGETED_DEVICE_FAMILY": "1,2",
        }
        if cfg == "Debug":
            s["DEBUG_INFORMATION_FORMAT"] = "dwarf"
            s["GCC_DYNAMIC_NO_PIC"] = False
            s["GCC_OPTIMIZATION_LEVEL"] = "0"
            s["GCC_PREPROCESSOR_DEFINITIONS"] = ["DEBUG=1", "$(inherited)"]
            s["ENABLE_TESTABILITY"] = True
        else:
            s["DEBUG_INFORMATION_FORMAT"] = "dwarf-with-dsym"
            s["GCC_OPTIMIZATION_LEVEL"] = "s"
            s["VALIDATE_PRODUCT"] = True
        return s

    def project_settings(cfg):
        s = {
            "ALWAYS_SEARCH_USER_PATHS": False,
            "CLANG_ANALYZER_NONNULL": True,
            "CLANG_ENABLE_MODULES": True,
            "CLANG_WARN_BOOL_CONVERSION": True,
            "CLANG_WARN_CONSTANT_CONVERSION": True,
            "CLANG_WARN_EMPTY_BODY": True,
            "CLANG_WARN_ENUM_CONVERSION": True,
            "CLANG_WARN_INFINITE_RECURSION": True,
            "CLANG_WARN_INT_CONVERSION": True,
            "CLANG_WARN_NON_LITERAL_NULL_CONVERSION": True,
            "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF": True,
            "CLANG_WARN_OBJC_LITERAL_CONVERSION": True,
            "CLANG_WARN_OBJC_ROOT_CLASS": True,
            "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": True,
            "CLANG_WARN_RANGE_LOOP_ANALYSIS": True,
            "CLANG_WARN_STRICT_PROTOTYPES": True,
            "CLANG_WARN_SUSPICIOUS_MOVE": True,
            "CLANG_WARN_UNREACHABLE_CODE": True,
            "CLANG_WARN__DUPLICATE_METHOD_MATCH": True,
            "COPY_PHASE_STRIP": False,
            "ENABLE_USER_SCRIPT_SANDBOXING": True,
            "GCC_C_LANGUAGE_STANDARD": "gnu17",
            "GCC_WARN_64_TO_32_BIT_CONVERSION": True,
            "GCC_WARN_ABOUT_RETURN_TYPE": True,
            "GCC_WARN_UNDECLARED_SELECTOR": True,
            "GCC_WARN_UNINITIALIZED_AUTOS": True,
            "GCC_WARN_UNUSED_FUNCTION": True,
            "GCC_WARN_UNUSED_VARIABLE": True,
            "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
            "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "/usr/lib/swift",
                                        "@executable_path/Frameworks"],
            "SDKROOT": "iphoneos",
        }
        if cfg == "Debug":
            s["DEBUG_INFORMATION_FORMAT"] = "dwarf"
            s["ENABLE_STRICT_OBJC_MSGSEND"] = False
            s["GCC_DYNAMIC_NO_PIC"] = False
            s["GCC_OPTIMIZATION_LEVEL"] = "0"
            s["ONLY_ACTIVE_ARCH"] = True
        else:
            s["DEBUG_INFORMATION_FORMAT"] = "dwarf-with-dsym"
            s["ENABLE_NS_ASSERTIONS"] = False
            s["GCC_OPTIMIZATION_LEVEL"] = "s"
            s["ONLY_ACTIVE_ARCH"] = False
            s["VALIDATE_PRODUCT"] = True
        return s

    target_cfgs = []
    for cfg in ("Debug", "Release"):
        u = add("cfg:target:" + cfg, None, {
            "isa": "XCBuildConfiguration",
            "buildSettings": target_settings(cfg),
            "name": cfg,
        })
        target_cfgs.append(u)

    project_cfgs = []
    for cfg in ("Debug", "Release"):
        u = add("cfg:project:" + cfg, None, {
            "isa": "XCBuildConfiguration",
            "buildSettings": project_settings(cfg),
            "name": cfg,
        })
        project_cfgs.append(u)

    target_cfg_list = add("cfglist:target", None, {
        "isa": "XCConfigurationList",
        "buildConfigurations": target_cfgs,
        "defaultConfigurationIsVisible": 0,
    })
    project_cfg_list = add("cfglist:project", None, {
        "isa": "XCConfigurationList",
        "buildConfigurations": project_cfgs,
        "defaultConfigurationIsVisible": 0,
        "defaultConfigurationName": "Release",
    })

    target = add("target", None, {
        "isa": "PBXNativeTarget",
        "buildConfigurationList": target_cfg_list,
        "buildPhases": [sources_phase, fw_phase, res_phase],
        "buildRules": [],
        "dependencies": [],
        "name": TARGET_NAME,
        "productName": TARGET_NAME,
        "productReference": product_ref,
        "productType": "com.apple.product-type.application",
    })

    project = add("project", "Project object", {
        "isa": "PBXProject",
        "attributes": {
            "BuildIndependentTargetsInParallel": 1,
            "LastSwiftUpdateCheck": "1600",
            "LastUpgradeCheck": "1600",
            "TargetAttributes": {
                target: {"CreatedOnToolsVersion": "16.0"},
            },
        },
        "buildConfigurationList": project_cfg_list,
        "compatibilityVersion": "Xcode 14.0",
        "developmentRegion": "en",
        "hasScannedForEncodings": 0,
        "knownRegions": ["en", "Base"],
        "mainGroup": main_group,
        "productRefGroup": products_group,
        "projectDirPath": "",
        "projectRoot": "",
        "targets": [target],
    })

    return objs, project


def render_pbxproj(objs, project_uuid):
    sections = [
        ("PBXBuildFile", lambda d: d["isa"] == "PBXBuildFile"),
        ("PBXFileReference", lambda d: d["isa"] == "PBXFileReference"),
        ("PBXFrameworksBuildPhase", lambda d: d["isa"] == "PBXFrameworksBuildPhase"),
        ("PBXGroup", lambda d: d["isa"] == "PBXGroup"),
        ("PBXNativeTarget", lambda d: d["isa"] == "PBXNativeTarget"),
        ("PBXProject", lambda d: d["isa"] == "PBXProject"),
        ("PBXResourcesBuildPhase", lambda d: d["isa"] == "PBXResourcesBuildPhase"),
        ("PBXSourcesBuildPhase", lambda d: d["isa"] == "PBXSourcesBuildPhase"),
        ("XCBuildConfiguration", lambda d: d["isa"] == "XCBuildConfiguration"),
        ("XCConfigurationList", lambda d: d["isa"] == "XCConfigurationList"),
    ]
    out = ["// !$*UTF8*$!", "{"]
    out.append("\tarchiveVersion = 1;")
    out.append("\tclasses = {")
    out.append("\t};")
    out.append("\tobjectVersion = 56;")
    out.append("\tobjects = {")
    for title, pred in sections:
        out.append("")
        out.append("/* Begin %s section */" % title)
        for u in sorted(objs):
            comment, d = objs[u]
            if not pred(d):
                continue
            c = " /* %s */" % comment if comment else ""
            out.append("\t\t%s%s = %s;" % (u, c, render(d, 4)))
        out.append("/* End %s section */" % title)
    out.append("\t};")
    out.append("\trootObject = %s /* Project object */;" % project_uuid)
    out.append("}")
    return "\n".join(out) + "\n"


def render_scheme(target_uuid):
    def bref(extra=""):
        return (
            '<BuildableReference\n'
            '               BuildableIdentifier = "primary"\n'
            '               BlueprintIdentifier = "%s"\n'
            '               BuildableName = "%s.app"\n'
            '               BlueprintName = "%s"\n'
            '               ReferencedContainer = "container:%s.xcodeproj">\n'
            '            </BuildableReference>\n'
            % (target_uuid, TARGET_NAME, TARGET_NAME, TARGET_NAME)
        )
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<Scheme\n'
        '   version = "1.7">\n'
        '   <BuildAction\n'
        '      parallelizeBuildables = "YES"\n'
        '      buildImplicitDependencies = "YES">\n'
        '      <BuildActionEntries>\n'
        '         <BuildActionEntry\n'
        '            buildForTesting = "YES"\n'
        '            buildForRunning = "YES"\n'
        '            buildForProfiling = "YES"\n'
        '            buildForArchiving = "YES"\n'
        '            buildForAnalyzing = "YES">\n'
        '            ' + bref() +
        '         </BuildActionEntry>\n'
        '      </BuildActionEntries>\n'
        '   </BuildAction>\n'
        '   <TestAction\n'
        '      buildConfiguration = "Debug"\n'
        '      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"\n'
        '      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"\n'
        '      shouldUseLaunchSchemeArgsEnv = "YES">\n'
        '      <Testables>\n'
        '      </Testables>\n'
        '   </TestAction>\n'
        '   <LaunchAction\n'
        '      buildConfiguration = "Debug"\n'
        '      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"\n'
        '      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"\n'
        '      launchStyle = "0"\n'
        '      useCustomWorkingDirectory = "NO"\n'
        '      ignoresPersistentStateOnLaunch = "NO"\n'
        '      debugDocumentVersioning = "YES"\n'
        '      debugServiceExtension = "internal"\n'
        '      allowLocationSimulation = "YES">\n'
        '      <BuildableProductRunnable\n'
        '         runnableDebuggingMode = "0">\n'
        '         ' + bref() +
        '      </BuildableProductRunnable>\n'
        '   </LaunchAction>\n'
        '   <ProfileAction\n'
        '      buildConfiguration = "Release"\n'
        '      shouldUseLaunchSchemeArgsEnv = "YES"\n'
        '      savedToolIdentifier = ""\n'
        '      useCustomWorkingDirectory = "NO"\n'
        '      debugDocumentVersioning = "YES">\n'
        '      <BuildableProductRunnable\n'
        '         runnableDebuggingMode = "0">\n'
        '         ' + bref() +
        '      </BuildableProductRunnable>\n'
        '   </ProfileAction>\n'
        '   <AnalyzeAction\n'
        '      buildConfiguration = "Debug">\n'
        '   </AnalyzeAction>\n'
        '   <ArchiveAction\n'
        '      buildConfiguration = "Release"\n'
        '      revealArchiveInOrganizer = "YES">\n'
        '   </ArchiveAction>\n'
        '</Scheme>\n'
    )


# ---------------------------------------------------------------- 自检

def tokenize(s):
    i, n, toks = 0, len(s), []
    while i < n:
        c = s[i]
        if c in " \t\r\n":
            i += 1
            continue
        if s.startswith("/*", i):
            j = s.find("*/", i + 2)
            assert j > 0, "未闭合注释"
            i = j + 2
            continue
        if s.startswith("//", i):
            j = s.find("\n", i)
            i = n if j < 0 else j + 1
            continue
        if c == '"':
            j, buf = i + 1, ""
            while j < n:
                if s[j] == "\\":
                    buf += s[j:j + 2]
                    j += 2
                    continue
                if s[j] == '"':
                    break
                buf += s[j]
                j += 1
            assert j < n, "未闭合字符串"
            toks.append(("str", buf))
            i = j + 1
            continue
        if c in "{}()=;,":
            toks.append(("punct", c))
            i += 1
            continue
        j = i
        while j < n and s[j] not in " \t\r\n{}()=;,\"":
            if s.startswith("/*", j) or s.startswith("//", j):
                break
            j += 1
        toks.append(("bare", s[i:j]))
        i = j
    return toks


class PlistParser:
    def __init__(self, toks):
        self.t, self.i = toks, 0

    def peek(self):
        return self.t[self.i] if self.i < len(self.t) else (None, None)

    def next(self):
        tok = self.peek()
        self.i += 1
        return tok

    def expect(self, p):
        k, v = self.next()
        assert (k, v) == ("punct", p), "期望 %r，实际 %r" % (p, (k, v))

    def value(self):
        k, v = self.peek()
        if (k, v) == ("punct", "{"):
            self.next()
            d = {}
            while True:
                k2, v2 = self.peek()
                if (k2, v2) == ("punct", "}"):
                    self.next()
                    break
                assert k2 in ("bare", "str"), "非法键: %r" % ((k2, v2),)
                self.next()
                self.expect("=")
                d[v2] = self.value()
                k3, v3 = self.peek()
                if (k3, v3) == ("punct", ";"):
                    self.next()
            return d
        if (k, v) == ("punct", "("):
            self.next()
            arr = []
            while True:
                k2, v2 = self.peek()
                if (k2, v2) == ("punct", ")"):
                    self.next()
                    break
                arr.append(self.value())
                k3, v3 = self.peek()
                if (k3, v3) == ("punct", ","):
                    self.next()
            return arr
        self.next()
        return v


def parse_osplist(text):
    p = PlistParser(tokenize(text))
    d = p.value()
    assert p.i == len(p.t), "解析未覆盖全部 token，剩余 %r" % (p.t[p.i:p.i + 5],)
    return d


def lint_pbxproj(path):
    text = path.read_text(encoding="utf-8")
    root = parse_osplist(text)
    problems = []

    def check(cond, msg):
        if not cond:
            problems.append(msg)

    check(root["objectVersion"] == "56", "objectVersion 应为 56")
    objects = root["objects"]
    check(root["rootObject"] in objects, "rootObject 不存在")
    proj = objects[root["rootObject"]]
    check(proj["isa"] == "PBXProject", "rootObject 不是 PBXProject")

    uuids = list(objects.keys())
    check(len(set(uuids)) == len(uuids), "存在重复 UUID")
    for u in uuids:
        check(bool(re.fullmatch(r"[0-9A-F]{24}", u)), "非法 UUID: %s" % u)

    targets = proj["targets"]
    check(len(targets) == 1, "应有且仅有 1 个 target")
    target = objects[targets[0]]
    check(target["isa"] == "PBXNativeTarget", "target 类型错误")
    check(target["name"] == TARGET_NAME, "target 名称错误")
    check(target["productType"] == "com.apple.product-type.application",
          "productType 错误")

    # 引用完整性
    ref_keys = ("fileRef", "productReference", "mainGroup", "productRefGroup",
                "buildConfigurationList", "remoteGlobalIDString")
    def walk(v):
        if isinstance(v, dict):
            for k, val in v.items():
                if k in ref_keys and isinstance(val, str):
                    check(val in objects, "引用不存在的对象: %s -> %s" % (k, val))
                walk(val)
        elif isinstance(v, list):
            for x in v:
                walk(x)
    for u, d in objects.items():
        walk(d)

    for key in ("targets",):
        for t in proj[key]:
            check(t in objects, "%s 引用缺失" % key)

    # build phases
    for phase_uuid in target["buildPhases"]:
        phase = objects[phase_uuid]
        check(phase["isa"].startswith("PBX") and phase["isa"].endswith("BuildPhase"),
              "非法的 build phase: %s" % phase["isa"])
        for bf in phase["files"]:
            check(bf in objects and objects[bf]["isa"] == "PBXBuildFile",
                  "phase 中存在非 BuildFile 项: %s" % bf)

    # configurations
    for list_key, owner in (("buildConfigurationList", target),):
        cl = objects[owner[list_key]]
        check(cl["isa"] == "XCConfigurationList", "配置列表类型错误")
        names = []
        for cfg_uuid in cl["buildConfigurations"]:
            cfg = objects[cfg_uuid]
            check(cfg["isa"] == "XCBuildConfiguration", "配置类型错误")
            check(isinstance(cfg["buildSettings"], dict), "buildSettings 应为字典")
            names.append(cfg["name"])
        check(names == ["Debug", "Release"], "target 配置应为 Debug/Release，实际 %r" % names)

    tcfg = objects[objects[target["buildConfigurationList"]]["buildConfigurations"][1]]
    bs = tcfg["buildSettings"]
    check(bs["PRODUCT_BUNDLE_IDENTIFIER"] == BUNDLE_ID, "bundle id 错误")
    check(bs["INFOPLIST_FILE"] == "EdgeVolume/Info.plist", "INFOPLIST_FILE 错误")
    check(bs["CODE_SIGN_ENTITLEMENTS"] == "EdgeVolume/entitlements.plist",
          "CODE_SIGN_ENTITLEMENTS 错误")
    check(bs["TARGETED_DEVICE_FAMILY"] == "1,2", "设备族错误")
    for t in TBD_LIBS:
        check(("$(SRCROOT)/EdgeVolume/Private/" + t) in bs["OTHER_LDFLAGS"],
              "OTHER_LDFLAGS 缺少 %s" % t)
    for fw in SDK_FRAMEWORKS:
        found = any(
            isinstance(d.get("path"), str) and d["path"].endswith(fw)
            for d in objects.values() if d.get("isa") == "PBXFileReference")
        check(found, "缺少框架引用: %s" % fw)

    # 源文件全部进入 Sources phase
    src_phase = objects[target["buildPhases"][0]]
    m_count = len([1 for d in objects.values()
                   if d.get("isa") == "PBXBuildFile"
                   and objects[d["fileRef"]].get("lastKnownFileType") == "sourcecode.c.objc"])
    check(len(src_phase["files"]) == m_count,
          "Sources phase 应有 %d 个文件，实际 %d" % (m_count, len(src_phase["files"])))

    # 磁盘文件存在性（group 型引用；Private 组内文件用 basename，需叠加组路径）
    for d in objects.values():
        if d.get("isa") != "PBXFileReference":
            continue
        if d.get("sourceTree") != "<group>":
            continue
        rel = d.get("path", "")
        if rel in ("", "Assets.xcassets"):
            continue
        candidates = [SRC_DIR / rel, SRC_DIR / "Private" / rel]
        check(any(p.exists() for p in candidates),
              "引用的文件不存在: %s（尝试过 %s）" % (rel, candidates))

    # scheme 检查
    scheme_path = PROJ_DIR / "xcshareddata" / "xcschemes" / (TARGET_NAME + ".xcscheme")
    check(scheme_path.exists(), "缺少 scheme 文件")
    if scheme_path.exists():
        tree = ET.parse(scheme_path)
        bp = tree.getroot().find(".//BuildableReference")
        check(bp is not None, "scheme 缺少 BuildableReference")
        if bp is not None:
            check(bp.get("BlueprintIdentifier") == targets[0],
                  "scheme 的 BlueprintIdentifier 与 target 不一致")
            check(bp.get("BlueprintName") == TARGET_NAME, "scheme BlueprintName 错误")
    return problems


# ---------------------------------------------------------------- main

def main():
    objs, project_uuid = build_objects()
    PROJ_DIR.mkdir(parents=True, exist_ok=True)
    (PROJ_DIR / "xcshareddata" / "xcschemes").mkdir(parents=True, exist_ok=True)

    pbx = PROJ_DIR / "project.pbxproj"
    pbx.write_text(render_pbxproj(objs, project_uuid), encoding="utf-8")
    scheme = PROJ_DIR / "xcshareddata" / "xcschemes" / (TARGET_NAME + ".xcscheme")
    scheme.write_text(render_scheme(targets_uuid(objs)), encoding="utf-8")

    problems = lint_pbxproj(pbx)
    n = len([u for u in objs])
    if problems:
        print("!! 自检未通过：")
        for p in problems:
            print("   -", p)
        sys.exit(1)
    print("OK  %s（%d 个对象，%d 字节）" % (pbx, n, pbx.stat().st_size))
    print("OK  %s" % scheme)
    print("OK  结构自检全部通过")


def targets_uuid(objs):
    for u, (_, d) in objs.items():
        if d.get("isa") == "PBXNativeTarget":
            return u
    raise AssertionError("未找到 target")


if __name__ == "__main__":
    os.chdir(ROOT)
    main()
