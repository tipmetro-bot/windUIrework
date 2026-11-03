#!/usr/bin/env python3
"""
WindUI Rework bundler
=====================

Builds a single, loadstring()-able `dist/main.lua` directly from `src/`
without needing Rojo / darklua / any external binary.

It walks `require("...")` calls starting at `src/Init.lua`, resolves the
relative paths, and inlines every module behind a small lazy module loader
(same idea as darklua's `require_mode: path`, but readable).

Usage:
    python3 tools/bundle.py                  # writes dist/main.lua
    python3 tools/bundle.py --check         # fails if dist/main.lua is stale
    python3 tools/bundle.py --output X.lua  # custom output path

The GitHub API is used by the maintainer to pull the upstream sources
(`gh api repos/Footagesus/WindUI/git/trees/main?recursive=1`), but building
is completely offline.
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENTRY = "src/Init.lua"
HEADER_TEMPLATE = ROOT / "build" / "header.lua"
PACKAGE_JSON = ROOT / "package.json"
PACKAGE_LUA = ROOT / "build" / "package.lua"
DEFAULT_OUTPUT = ROOT / "dist" / "main.lua"

REQUIRE_RE = re.compile(r"require\s*\(\s*([\"'])[^\"']*?\1\s*\)")
STRING_ARG_RE = re.compile(r"([\"'])(.*?)\1", re.S)
LONG_BRACKET_OPEN = re.compile(r"\[(=*)\[")


def mask_lua(src: str) -> str:
    """Return src with comments and string *contents* blanked.

    Offsets/newlines are preserved, so matches found in the masked text can
    be cut out of the original text. This stops commented-out `require(...)`
    calls (there are a few upstream) from being bundled.
    """
    out = list(src)
    n = len(src)
    i = 0

    def blank(start: int, end: int) -> None:
        for k in range(start, min(end, n)):
            if out[k] != "\n":
                out[k] = " "

    while i < n:
        ch = src[i]

        # -- comments (line or long bracket)
        if ch == "-" and i + 1 < n and src[i + 1] == "-":
            open_match = LONG_BRACKET_OPEN.match(src, i + 2)
            if open_match:
                level = len(open_match.group(1))
                close = "]" + ("=" * level) + "]"
                close_at = src.find(close, open_match.end())
                end = n if close_at == -1 else close_at + len(close)
                blank(i, end)
                i = end
                continue
            end = src.find("\n", i)
            end = n if end == -1 else end
            blank(i, end)
            i = end
            continue

        # short strings
        if ch in ("'", '"'):
            quote = ch
            j = i + 1
            while j < n:
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j] == quote:
                    j += 1
                    break
                if src[j] == "\n":  # unterminated, bail out gracefully
                    break
                j += 1
            blank(i + 1, j - 1)
            i = j
            continue

        # long bracket strings [[...]] / [=[...]=]
        if ch == "[":
            open_match = LONG_BRACKET_OPEN.match(src, i)
            if open_match:
                level = len(open_match.group(1))
                close = "]" + ("=" * level) + "]"
                close_at = src.find(close, open_match.end())
                end = n if close_at == -1 else close_at
                blank(open_match.end(), end)
                i = n if close_at == -1 else close_at + len(close)
                continue

        i += 1
    return "".join(out)


def resolve(relative_to: str, argument: str) -> str:
    base = (Path(relative_to).parent / argument).as_posix()
    base = os.path.normpath(base).replace("\\", "/")
    if not base.endswith(".lua"):
        base += ".lua"
    path = ROOT / base
    if not path.is_file():
        raise FileNotFoundError(f"{relative_to}: require({argument!r}) -> {base} not found")
    return base


def transform(module_id: str, source: str, seen: dict) -> str:
    masked = mask_lua(source)
    matches = list(REQUIRE_RE.finditer(masked))
    pieces = []
    last = 0
    for match in reversed(matches):
        original = source[match.start():match.end()]
        arg_match = STRING_ARG_RE.search(original)
        if not arg_match:
            raise ValueError(f"{module_id}: cannot parse require: {original!r}")
        argument = arg_match.group(2)
        target = resolve(module_id, argument)
        if target not in seen:
            collect(target, seen)
        pieces.append((match.start(), match.end(), f'__WINDUI_REQUIRE("{target}")'))

    result = source
    for start, end, replacement in sorted(pieces, reverse=True):
        result = result[:start] + replacement + result[end:]

    # Sanity: no unresolved require() calls left (ignoring comments/strings).
    leftover = [m.group(0) for m in REQUIRE_RE.finditer(mask_lua(result))]
    if leftover:
        raise ValueError(f"{module_id}: unresolved require calls: {leftover[:3]}")
    return result


def collect(module_id: str, seen: dict) -> None:
    if module_id in seen:
        return
    source = (ROOT / module_id).read_text(encoding="utf-8")
    seen[module_id] = None  # cycle guard
    seen[module_id] = transform(module_id, source, seen)


def regenerate_package_lua() -> None:
    package = json.loads(PACKAGE_JSON.read_text(encoding="utf-8"))
    text = json.dumps(package, indent=4, ensure_ascii=False)
    PACKAGE_LUA.write_text(
        "-- Generated from package.json | tools/bundle.py\n\nreturn [[\n"
        + text
        + "\n]]\n",
        encoding="utf-8",
    )
    return package


def build_header(package: dict) -> str:
    template = HEADER_TEMPLATE.read_text(encoding="utf-8")
    values = {
        "{{VERSION}}": str(package.get("version", "0.0.0")),
        "{{BUILD_DATE}}": datetime.date.today().isoformat(),
        "{{DESCRIPTION}}": str(package.get("description", "")),
        "{{REPOSITORY}}": str(package.get("repository", "")),
        "{{DISCORD}}": str(package.get("discord", "")),
        "{{LICENSE}}": str(package.get("license", "MIT")),
    }
    for key, value in values.items():
        template = template.replace(key, value)
    extra = (
        "\n--[[\n"
        "    WindUI REWORK\n"
        "      * open/close button works on PC, phones and gamepads\n"
        "      * zero-safe sliders (Min/Default/Max/Step = 0)\n"
        "      * smooth, configurable animations\n"
        "      * Neverlose-style bottom-left profile panel\n"
        "    Source / docs: README.md\n"
        "    Original library by Footagesus (MIT).\n"
        "]]\n"
    )
    return template.rstrip() + "\n" + extra


def build_bundle() -> str:
    regenerate_package_lua()
    seen: dict = {}
    collect(ENTRY, seen)

    # Stable order: entry first, then alphabetical. Deterministic output.
    ids = [ENTRY] + sorted(k for k in seen if k != ENTRY)

    lines = [
        build_header(json.loads(PACKAGE_JSON.read_text(encoding="utf-8"))),
        "",
        "-- Auto-generated by `python3 tools/bundle.py`. Do not edit by hand.",
        "-- Each module is lazily evaluated and cached, exactly like a require().",
        "local __WINDUI_MODULES = {}",
        "local __WINDUI_CACHE = {}",
        "local __WINDUI_LOADING = {}",
        "",
        "local function __WINDUI_REQUIRE(id)",
        "\tif __WINDUI_CACHE[id] ~= nil then",
        "\t\treturn __WINDUI_CACHE[id]",
        "\tend",
        "\tlocal loader = __WINDUI_MODULES[id]",
        '\tif not loader then error("[WindUI] missing bundled module: " .. tostring(id)) end',
        "\tif __WINDUI_LOADING[id] then",
        '\t\twarn("[WindUI] circular require: " .. tostring(id))',
        "\t\treturn nil",
        "\tend",
        "\t__WINDUI_LOADING[id] = true",
        "\tlocal result = loader()",
        "\t__WINDUI_LOADING[id] = nil",
        "\t__WINDUI_CACHE[id] = result",
        "\treturn result",
        "end",
        "",
    ]

    for module_id in ids:
        lines.append(f'__WINDUI_MODULES["{module_id}"] = function()')
        lines.append(seen[module_id].rstrip())
        lines.append("end")
        lines.append("")

    lines.append(f'return __WINDUI_REQUIRE("{ENTRY}")')
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Bundle WindUI Rework into one Lua file")
    parser.add_argument("--check", action="store_true", help="fail if dist/main.lua is out of date")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT), help="output .lua path")
    args = parser.parse_args()

    try:
        bundle = build_bundle()
    except (FileNotFoundError, ValueError) as exc:
        print(f"[bundle] ERROR: {exc}", file=sys.stderr)
        return 1

    output = Path(args.output)
    if not output.is_absolute():
        output = ROOT / output
    output.parent.mkdir(parents=True, exist_ok=True)

    if args.check:
        current = output.read_text(encoding="utf-8") if output.exists() else ""
        if current != bundle:
            print(f"[bundle] {output.relative_to(ROOT)} is stale; run `python3 tools/bundle.py`", file=sys.stderr)
            return 1
        print(f"[bundle] {output.relative_to(ROOT)} is up to date ({len(bundle)} bytes)")
        return 0

    output.write_text(bundle, encoding="utf-8")
    print(f"[bundle] wrote {output.relative_to(ROOT)} ({len(bundle)} bytes, {bundle.count(chr(10))} lines)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
