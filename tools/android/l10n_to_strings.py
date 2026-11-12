#!/usr/bin/env python3
"""The Android app's strings.xml (cs, en) from the iOS app's L10n.swift.

L10n.swift is the one place the app's copy is written. Every entry of the
simple shapes becomes a string resource with the same name:

    static var key: String { "Same in both" }
    static var key: String { switch lang { case .cs: return "…" case .en: return "…" } }
    static func key(_ show: String, count: Int) -> String { switch lang { … "\\(show) \\(count)" … } }

Interpolated parameters become positional placeholders in the order of the
function's parameters (%1$s for String, %1$d for Int), so the Czech and
English text can put them in a different order.

Entries with logic in them (plurals, optional parts, tables, date
formatting) are listed as skipped; the Android app has them in Kotlin
(android/app/src/main/kotlin/cz/slowdownradijo/app/l10n/L10nLogic.kt).

android/l10n-overrides.json replaces the text of a key on Android, for the
few strings that name iOS.

    python3 tools/android/l10n_to_strings.py          # write the files
    python3 tools/android/l10n_to_strings.py --check  # fail if they are stale (CI)
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from xml.sax.saxutils import escape as xml_escape

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "SlowDownRadijo/Services/L10n.swift"
OVERRIDES = ROOT / "android/l10n-overrides.json"
RES = ROOT / "android/app/src/main/res"
OUTPUTS = {"cs": RES / "values/strings.xml", "en": RES / "values-en/strings.xml"}
LANGS = ("cs", "en")

DECL = re.compile(
    r"static\s+(?P<kind>var|func)\s+(?P<name>\w+)\s*"
    r"(?:\((?P<params>[^)]*)\))?\s*(?::\s*String|->\s*String)\s*\{"
)


class Skip(Exception):
    pass


def strip_comments(code: str) -> str:
    """Drop // comments that are outside string literals."""
    out, i, in_str = [], 0, False
    while i < len(code):
        c = code[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < len(code):
                out.append(code[i + 1])
                i += 2
                continue
            if c == '"':
                in_str = False
        elif c == '"':
            in_str = True
            out.append(c)
        elif code.startswith("//", i):
            while i < len(code) and code[i] != "\n":
                i += 1
            continue
        else:
            out.append(c)
        i += 1
    return "".join(out)


def block_end(code: str, start: int) -> int:
    """Index just past the brace that closes the one opened before `start`."""
    depth, i, in_str = 1, start, False
    while i < len(code):
        c = code[i]
        if in_str:
            if c == "\\":
                i += 2
                continue
            if c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    raise ValueError("unbalanced braces")


def parse_params(raw: str | None) -> list[tuple[str, str]]:
    """[(name used inside the body, type)] for `_ duration: String, hours: Int`."""
    if not raw or not raw.strip():
        return []
    params = []
    for part in raw.split(","):
        label_names, _, type_ = part.partition(":")
        names = label_names.split()
        params.append((names[-1], type_.strip()))
    return params


def parse_literal(src: str, params: list[tuple[str, str]]) -> str:
    """A whole Swift string literal `"…"` as Android string text."""
    src = src.strip()
    if len(src) < 2 or src[0] != '"' or src[-1] != '"':
        raise Skip(f"not a single string literal: {src[:40]}")
    body = src[1:-1]
    index = {name: (i + 1, type_) for i, (name, type_) in enumerate(params)}
    out, i = [], 0
    while i < len(body):
        c = body[i]
        if c == '"':
            raise Skip("more than one literal")
        if c != "\\":
            out.append(("text", c))
            i += 1
            continue
        nxt = body[i + 1]
        if nxt == "(":
            close = body.index(")", i)
            expr = body[i + 2 : close].strip()
            if expr not in index:
                raise Skip(f"interpolates an expression: {expr}")
            pos, type_ = index[expr]
            out.append(("arg", f"%{pos}${'d' if type_ == 'Int' else 's'}"))
            i = close + 1
        elif nxt == "u":
            close = body.index("}", i)
            out.append(("text", chr(int(body[i + 3 : close], 16))))
            i = close + 1
        else:
            out.append(("text", {"n": "\n", "t": "\t", '"': '"', "\\": "\\", "'": "'"}[nxt]))
            i += 2
    has_args = any(kind == "arg" for kind, _ in out)
    text = "".join(
        value if kind == "arg" else (value.replace("%", "%%") if has_args else value)
        for kind, value in out
    )
    return text


def literal_per_lang(body: str, params) -> dict[str, str]:
    body = " ".join(body.split())
    if body.startswith('"'):
        text = parse_literal(body, params)
        return {lang: text for lang in LANGS}
    if body.startswith("return "):
        text = parse_literal(body[len("return ") :], params)
        return {lang: text for lang in LANGS}
    m = re.fullmatch(r"switch lang \{(?P<cases>.*)\}", body)
    if not m:
        raise Skip("logic outside a language switch")
    cases = re.split(r"case \.(cs|en):", m.group("cases"))
    if cases[0].strip():
        raise Skip("unexpected text in the switch")
    result = {}
    for lang, case_body in zip(cases[1::2], cases[2::2]):
        case_body = case_body.strip()
        if not case_body.startswith("return "):
            raise Skip(f"logic in case .{lang}")
        result[lang] = parse_literal(case_body[len("return ") :], params)
    if set(result) != set(LANGS):
        raise Skip("missing a language")
    return result


def android_escape(text: str) -> str:
    text = text.replace("\\", "\\\\").replace("'", "\\'").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")
    text = xml_escape(text)
    if text[:1] in ("@", "?"):
        text = "\\" + text
    return text


def extract(source: str):
    code = strip_comments(source)
    entries: dict[str, dict] = {}
    skipped: list[tuple[str, str]] = []
    for m in DECL.finditer(code):
        name = m.group("name")
        end = block_end(code, m.end())
        body = code[m.end() : end - 1].strip()
        params = parse_params(m.group("params"))
        try:
            texts = literal_per_lang(body, params)
        except Skip as reason:
            skipped.append((name, str(reason)))
            continue
        entries[name] = {"texts": texts, "params": params}
    return entries, skipped


def render(entries, lang: str) -> str:
    lines = [
        '<?xml version="1.0" encoding="utf-8"?>',
        "<!-- Generated from SlowDownRadijo/Services/L10n.swift by",
        "     tools/android/l10n_to_strings.py. Do not edit: change L10n.swift",
        "     (or android/l10n-overrides.json) and run the script. -->",
        '<resources xmlns:tools="http://schemas.android.com/tools" tools:ignore="UnusedResources,MissingTranslation,Typos">',
    ]
    for name, entry in entries.items():
        text = entry["texts"][lang]
        attrs = ""
        if not entry["params"] and "%" in text:
            attrs = ' formatted="false"'
        lines.append(f'    <string name="{name}"{attrs}>{android_escape(text)}</string>')
    lines.append("</resources>")
    return "\n".join(lines) + "\n"


def main() -> int:
    check = "--check" in sys.argv
    entries, skipped = extract(SOURCE.read_text(encoding="utf-8"))
    overrides = json.loads(OVERRIDES.read_text(encoding="utf-8")) if OVERRIDES.exists() else {}
    for name, texts in overrides.items():
        if name.startswith("_"):
            continue
        if name not in entries:
            print(f"override for unknown key {name}", file=sys.stderr)
            return 1
        entries[name]["texts"].update(texts)

    stale = []
    for lang, path in OUTPUTS.items():
        content = render(entries, lang)
        if check:
            if not path.exists() or path.read_text(encoding="utf-8") != content:
                stale.append(path)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")

    print(f"{len(entries)} strings, {len(skipped)} with logic (in L10nLogic.kt):")
    for name, reason in skipped:
        print(f"  {name}: {reason}")
    if stale:
        for path in stale:
            print(f"stale: {path.relative_to(ROOT)}; run tools/android/l10n_to_strings.py", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
