<div align="center">

# 🐢 Windows 网络变慢排查 / Network Slow Diagnosis

**Read-only, layered, evidence-based: pinpoint exactly where "web pages load slowly / intermittently stall" — physical link, DNS, transport, app layer, or background hogs.**

**English · [简体中文](./README.md)**

[![License: MIT](https://img.shields.io/github/license/hyt315/network-slow-diagnosis)](LICENSE)
[![Release](https://img.shields.io/github/v/release/hyt315/network-slow-diagnosis?sort=semver)](https://github.com/hyt315/network-slow-diagnosis/releases)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-compatible-1f6feb)](SKILL.md)
[![Platform](https://img.shields.io/badge/Platform-Windows-blue)](SKILL.md)
[![Tests](https://github.com/hyt315/network-slow-diagnosis/actions/workflows/ci.yml/badge.svg)](https://github.com/hyt315/network-slow-diagnosis/actions)
[![Stars](https://img.shields.io/github/stars/hyt315/network-slow-diagnosis?style=social)](https://github.com/hyt315/network-slow-diagnosis/stargazers)

</div>

> **Scope**: slow web browsing on Windows caused by the local network layer or DNS (direct path).

---

## 📖 What is this?

Web pages sometimes load slowly, spin for ages, or stall intermittently — but you don't know where it's stuck? **Windows 网络变慢排查 (Network Slow Diagnosis)** is an AI Agent Skill that uses **read-only commands** (`ping` / `Test-NetConnection` / `Resolve-DnsName` / `curl -w` / `resmon` …) to gather evidence layer by layer — physical link → DNS → transport → app → resource usage — proving or ruling out each layer with "confirmed / ruled out", never "maybe". It **never changes any setting** (changes need your explicit consent).

### ✨ Core Features

| Feature | Description |
|---------|-------------|
| 🔍 **Layered read-only diagnosis** | From WiFi signal & gateway latency all the way to TLS handshake, TTFB, and background bandwidth hogs |
| 🧭 **DNS root-cause specialty** | Use `curl -w`'s `time_namelookup` to pin "slow" to DNS; cross-check public DNS for confirmation |
| 🔐 **TLS handshake pinpoint** | `time_appconnect - time_connect` exposes cert-chain / key-exchange time instead of blaming the server |
| 🛰️ **Multi-protocol** | IPv4/IPv6 fallback, MTU fragmentation, TCP globals (Auto-Tuning/ECN), wrong default-route on multi-NIC |
| 🧰 **Authoritative tools** | WinMTR / dnsdiag / namebench / pktmon / psping and other read-only diagnostics |
| 📋 **16 root causes + pitfalls** | Catches the "looks like A but is actually B" misjudgments |
| 🛡️ **Read-only first** | Zero changes during diagnosis; the only write (`Clear-DnsClientCache`) only in a controlled experiment, after telling the user |

---

## 📚 Example: a real "11-second stall" pinpointed

Real case (full record in [dns-root-cause-case.md](references/dns-root-cause-case.md)): the user reported "pages sometimes take forever". Catch one slow event:

```text
curl -4 --noproxy '*' -w "nl=%{time_namelookup} ct=%{time_connect} st=%{time_starttransfer} tt=%{time_total}"
baidu #1  nl=11.086766  ct=11.118662  st=11.184887  tt=11.185000
```

`nl` (DNS) ≈ `tt` (total) = 11 seconds; connect and first-byte complete instantly after DNS returns → **100% stuck at DNS**. Cross-check public DNS (223.5.5.5 steady at 25–31ms vs router forwarder cold queries of 800ms–11s) → root cause confirmed. After changing DNS, every site's `nl` dropped to 7–29ms and the stalls vanished.

That is the methodology: **every layer ends in "confirmed" or "ruled out" — never "maybe".**

---

## 🚀 Quick Start

> ✨ **One-liner install into your AI agent**: paste this to your AI assistant and it will install itself:
>
> ```text
> Please install the network-slow-diagnosis Skill: clone https://github.com/hyt315/network-slow-diagnosis into your skills directory (Claude Code: ~/.claude/skills/network-slow-diagnosis/; Cursor: ~/.cursor/skills/; Codex/ChatGPT: .agent/skills/ in your project), and verify that SKILL.md, references/, and tests/ are all present. Whenever I report "web pages load slowly / intermittent stalling / the network feels slow", follow the SKILL.md Workflow and diagnose layer by layer with read-only commands.
> ```

| Platform | Install |
|----------|---------|
| **Claude Code** | `git clone https://github.com/hyt315/network-slow-diagnosis.git ~/.claude/skills/network-slow-diagnosis` |
| **Cursor** | `git clone https://github.com/hyt315/network-slow-diagnosis.git ~/.cursor/skills/network-slow-diagnosis` |
| **Codex / ChatGPT** | `.agent/skills/network-slow-diagnosis/` in your project |
| **Generic** | Any agent's skills directory |

---

## 💬 When to trigger

Say any of these to your AI agent:

- "Web pages open slowly" / "sometimes stall for ages" / "intermittent spinning"
- "The network feels slow" / "is it DNS?"
- "Check whether WiFi / gateway / IPv6 fallback / background usage is slowing me down"

## ⚙️ Prerequisites

- **Windows 10 / 11** (PowerShell and curl built in, zero extra installs)
- Diagnosis needs **no admin rights** (fully read-only); only the fix stage changes settings, which requires admin + your explicit consent
- No third-party dependencies; optional tools (WinMTR / dnsdiag etc.) suggested only when deep-diving

## 📦 Deliverables

```text
📋 Layered verdict    — physical/DNS/transport/app/resource: each layer "confirmed" or "ruled out"
🎯 Root cause line    — verified, not guessed (e.g. "WLAN DNS is router 192.168.1.1, cold queries take 11s")
🛠️ Fix suggestion     — executed only with your explicit consent, often needing admin; this skill diagnoses, never modifies on its own
```

---

## 📥 Download / Install

```bash
# HTTPS
git clone https://github.com/hyt315/network-slow-diagnosis.git

# SSH
git clone git@github.com:hyt315/network-slow-diagnosis.git

# GitHub CLI
gh repo clone hyt315/network-slow-diagnosis

# ZIP
# https://github.com/hyt315/network-slow-diagnosis/archive/refs/heads/main.zip

# Single file (SKILL.md only)
curl -O https://raw.githubusercontent.com/hyt315/network-slow-diagnosis/main/SKILL.md
```

---

## 📁 File Structure

```
network-slow-diagnosis/
├── SKILL.md                     # entry point (routing + layered workflow)
├── manifest.json                # governance metadata
├── Makefile                     # `make test` → regression test
├── references/
│   ├── diagnostic-playbook.md   # layered playbook (commands + criteria + tools + pitfalls)
│   └── dns-root-cause-case.md   # DNS root-cause real case (with before/after evidence)
├── tests/
│   └── test_skill.py            # regression test (structure/hygiene/links/negative cases)
├── LICENSE
├── README.md  /  README.en.md  # bilingual docs (this file is English)
└── .github/                     # Issue/PR templates + CI
```

---

## ▶️ Quick Usage

After triggering, answer its questions and run read-only commands layer by layer. To catch a "slow event" and locate the layer:

```powershell
curl -4 --noproxy '*' -o /dev/null -s -w "nl=%{time_namelookup} ct=%{time_connect} ac=%{time_appconnect} st=%{time_starttransfer} tt=%{time_total}`n" https://www.baidu.com
```

If `nl` (DNS) is close to `tt` and large → 100% stuck at DNS; if `ac - ct` is large → stuck at the TLS handshake.

> Any network-setting change (e.g. changing DNS) needs your explicit consent and often admin rights; this skill only diagnoses, it does not modify.

---

## 🤝 Contributing / Feedback

- Report bugs / suggestions: use the repo's Issue templates
- Contribute: see [CONTRIBUTING.md](CONTRIBUTING.md); run `python tests/test_skill.py` (must be RESULT PASS) before any PR
- Security: see [SECURITY.md](SECURITY.md) (private vulnerability reporting, not public issues)

---

## 📜 License

[MIT](LICENSE) © 2026 hyt315

> 🌏 **中文版: [README.md](./README.md)**