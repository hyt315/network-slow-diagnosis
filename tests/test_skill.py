#!/usr/bin/env python3
"""Selftest for network-slow-diagnosis.

Run: python tests/test_skill.py
Zero-deps; also pytest-discoverable.
Exits 0 on RESULT PASS, 1 on RESULT FAIL.

Covers structural invariants, hygiene, references linkage, and
negative-case logic (incl. the skill-specific "must not contain proxy-config
instructions" rule)."""
import json
import re
import sys
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SKILL_MD = ROOT / "SKILL.md"
MANIFEST = ROOT / "manifest.json"
REFS_DIR = ROOT / "references"

NAME_RE = r"^[a-z0-9]+(-[a-z0-9]+)*$"
SEMVER_RE = r"^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$"
TRIGGER_RE = re.compile(r"Use when|when a|适用于|当", re.I)
FIRST_PERSON_RE = re.compile(r"\b(I can|I will|I'll|我可以|我会)\b")
XML_BRACKET_RE = re.compile(r"[<>]")
PERSONAL_PATH_RE = re.compile(r"C:\\Users\\|/home/[a-z]")  # skill-doctor: allow (regex pattern describing the detection rule itself)
# Skill-specific: body must NOT instruct configuring proxy/VPN/Clash.
PROXY_CONFIG_RE = re.compile(
    r"配置代理|开启\s*Clash|启用代理|set\s*up\s*(?:proxy|Clash)|enable\s*proxy|"
    r"开启\s*VPN|安装\s*Clash",
    re.I,
)


def name_ok(n: str) -> bool:
    return bool(re.match(NAME_RE, n)) and not re.search(r"anthropic|claude", n, re.I)


def desc_ok(d: str) -> bool:
    return (
        bool(d)
        and len(d) <= 1024
        and not XML_BRACKET_RE.search(d)
        and bool(TRIGGER_RE.search(d))
    )


failures: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        failures.append(msg)


# 1. SKILL.md frontmatter & body
text = SKILL_MD.read_text(encoding="utf-8")
fm_match = re.match(r"^---\n(.*?)\n---\n", text, re.S)
check(bool(fm_match), "SKILL.md frontmatter missing")
if fm_match:
    fm = fm_match.group(1)
    name_m = re.search(r"^name:\s*(\S+)\s*$", fm, re.M)
    desc_m = re.search(r"^description:\s*(.+?)(?=\n[a-z\-]+:|\Z)", fm, re.S | re.M)
    name = name_m.group(1) if name_m else ""
    desc = desc_m.group(1).strip() if desc_m else ""
    check(name_ok(name) and name == ROOT.name,
          f"name '{name}' invalid or != dir '{ROOT.name}'")
    check(desc_ok(desc), "description invalid (missing/oversize/XML/括号 or lacks trigger words)")
    check(not FIRST_PERSON_RE.search(desc), "description uses first person")
    body = text[fm_match.end():]
    check(not PROXY_CONFIG_RE.search(body),
          "body instructs configuring proxy/VPN/Clash (skill must exclude proxy topics)")
else:
    body = text

# 2. manifest.json
data = json.loads(MANIFEST.read_text(encoding="utf-8"))
for k in ("name", "version", "owner", "updated_at"):
    check(k in data, f"manifest missing '{k}'")
check(name_ok(data.get("name", "")), "manifest name pattern")
check(bool(re.match(SEMVER_RE, data.get("version", ""))), "manifest version not semver")
check(data.get("name") == ROOT.name, "manifest name != dir name")

# 3. references linkage (LK004: every references/ file must be linked in SKILL.md)
if REFS_DIR.exists():
    linked = set(re.findall(r"references/[\w\-]+\.md", text))
    actual = {f"references/{p.name}" for p in REFS_DIR.glob("*.md")}
    orphans = actual - linked
    check(not orphans, f"orphan references (not linked in SKILL.md): {sorted(orphans)}")

# 3b. Regression guards for diagnosis-coverage optimizations (locked after 2026-08-21 web review)
layer_checks = {
    "time_appconnect": "SKILL.md missing TLS handshake timing (time_appconnect)",
    "Get-NetAdapterStatistics": "SKILL.md missing NIC error/discard counters (Get-NetAdapterStatistics)",
    "Get-NetTCPSetting": "SKILL.md missing TCP global params (Get-NetTCPSetting)",
    "Get-NetRoute": "SKILL.md missing default-route/multi-NIC check (Get-NetRoute)",
    "安全 DNS": "SKILL.md missing browser DoH bypass note",
    "QUIC": "SKILL.md missing HTTP/3 QUIC note",
    "传递优化": "SKILL.md missing Windows 11 background-bandwidth pit",
}
for token, msg in layer_checks.items():
    check(token in text, msg)

# 4. Hygiene: no absolute personal paths in any file
for p in ROOT.rglob("*"):
    if p.is_file():
        s = p.read_text(encoding="utf-8", errors="ignore")
        check(not PERSONAL_PATH_RE.search(s), f"personal path found in {p.relative_to(ROOT)}")

# 5. DY002 negative cases — assert checker logic catches known-bad inputs
check(not name_ok("BadName"), "negative: 'BadName' should fail name regex")
check(not name_ok("claude-foo"), "negative: reserved-word 'claude-*' should fail (FM006)")
check(not desc_ok(""), "negative: empty description should fail")
check(not desc_ok("no trigger words here at all"), "negative: description w/o trigger words should fail")
check(not desc_ok("Use when <bad> brackets"), "negative: XML brackets in description should fail")
check(PROXY_CONFIG_RE.search("please 开启 Clash to continue"),
      "negative: proxy-config pattern must match a violating sample")

print("RESULT " + ("PASS" if not failures else "FAIL"))
for f in failures:
    print(" -", f)
sys.exit(0 if not failures else 1)