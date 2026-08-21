<div align="center">

# 🐢 Windows 网络变慢排查 / Network Slow Diagnosis

**Read-only, layered, evidence-based: pinpoint exactly where "web pages load slowly / intermittently stall" — physical link, DNS, transport, app layer, or background hogs.**

**English · [简体中文](./README.md)**

[![License: MIT](https://img.shields.io/github/license/hyt315/network-slow-diagnosis)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-compatible-1f6feb)](SKILL.md)
[![Platform](https://img.shields.io/badge/Platform-Windows-blue)](SKILL.md)
[![Tests](https://github.com/hyt315/network-slow-diagnosis/actions/workflows/ci.yml/badge.svg)](https://github.com/hyt315/network-slow-diagnosis/actions)

</div>

> **Scope**: slow web browsing on Windows caused by the local network layer or DNS (direct path).

---

## What is this

Web pages sometimes load slowly, spin for ages, or stall intermittently — but you don't know where it's stuck? **Windows 网络变慢排查 (Network Slow Diagnosis)** is an AI Agent Skill that uses **read-only commands** (`ping` / `Test-NetConnection` / `Resolve-DnsName` / `curl -w` / `resmon` …) to gather evidence layer by layer — physical link → DNS → transport → app → resource usage — proving or ruling out each layer with "confirmed / ruled out", never "maybe". It **never changes any setting** (changes need your explicit consent).

### Core features

| Feature | Description |
|---------|-------------|
| 🔍 **Layered read-only diagnosis** | From WiFi signal & gateway latency all the way to TLS handshake, TTFB, and background bandwidth hogs |
| 🧭 **DNS root-cause specialty** | Use `curl -w`'s `time_namelookup` to pin "slow" to DNS; cross-check public DNS for confirmation |
| 🔐 **TLS handshake pinpoint** | `time_appconnect - time_connect` exposes cert-chain / key-exchange time instead of blaming the server |
| 🛰️ **Multi-protocol** | IPv4/IPv6 fallback, MTU fragmentation, TCP globals (Auto-Tuning/ECN), wrong default-route on multi-NIC |
| 🧰 **Authoritative tools** | WinMTR / dnsdiag / namebench / pktmon / psping and other read-only diagnostics |
| 📋 **16 root causes + pitfalls** | Catches the "looks like A but is actually B" misjudgments |
| 🛡️ **Read-only first** | Zero changes during diagnosis; the only write (`Clear-DnsClientCache`) only in a controlled experiment, after telling the user |
| 🌐 **Bilingual** | Bilingual README; case study and playbook in Chinese |

---

## Layered workflow (summary)

1. **Scope**: all sites or just some? always or sometimes? `Get-NetIPConfiguration` to confirm IP/gateway/DNS (`169.254.x.x` = no network, not slow).
2. **Physical/link**: gateway `ping` latency, WiFi signal, `Get-NetAdapterStatistics` error counters.
3. **DNS (most common)**: `Measure-Command { Resolve-DnsName }` sampled repeatedly; `curl -w` to catch the `time_namelookup` slow event; cold-cache comparison.
4. **Transport**: TLS handshake (`time_appconnect`), TCP connect, `curl -4/-6` for IPv6 fallback, `Get-NetTCPSetting`, `Get-NetRoute` for multi-NIC misrouting.
5. **App/TTFB**: `time_starttransfer`; QUIC (`chrome://net-internals/#quic`).
6. **Resource usage**: `resmon` / TCPView / Windows 11 background hogs (DoSvc, HVCI, driver rollback).

Full commands, pass/fail criteria, tools, and a real case are in `references/`:

- [分层诊断手册 (diagnostic playbook)](references/diagnostic-playbook.md)
- [DNS 根因实战案例 (DNS root-cause case)](references/dns-root-cause-case.md) — a real "intermittent 11-second stall" investigation

---

## 📁 File structure

```
network-slow-diagnosis/
├── SKILL.md                     # entry point (routing + layered workflow)
├── manifest.json                # governance metadata
├── Makefile                     # `make test` → regression test
├── references/
│   ├── diagnostic-playbook.md   # layered playbook (commands + criteria + tools + pitfalls)
│   └── dns-root-cause-case.md   # DNS root-cause real case
├── tests/
│   └── test_skill.py            # regression test (structure/hygiene/links/negative cases)
├── LICENSE
├── README.md  /  README.en.md  # bilingual docs (this file is English)
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
├── SECURITY.md
├── CHANGELOG.md
├── .github/                     # Issue/PR templates + CI
└── agents/openai.yaml           # OpenAI-compatible agent descriptor
```

---

## 📥 Download / Install

> ✨ **One-liner install into your AI agent**: paste this to your AI assistant and it will install itself:
>
> ```text
> Please install the network-slow-diagnosis Skill: clone https://github.com/hyt315/network-slow-diagnosis into your skills directory (Claude Code: ~/.claude/skills/network-slow-diagnosis/; Cursor: ~/.cursor/skills/; Codex/ChatGPT: .agent/skills/ in your project), and verify that SKILL.md, references/, and tests/ are all present. Whenever I report "web pages load slowly / intermittent stalling / the network feels slow", follow the SKILL.md Workflow and diagnose layer by layer with read-only commands.
> ```

Drop the skill directory into your agent's skills folder:

| Platform | Path |
|----------|------|
| Claude Code | `~/.claude/skills/network-slow-diagnosis/` |
| Cursor | `~/.cursor/skills/network-slow-diagnosis/` |
| Codex / ChatGPT | project `.agent/skills/network-slow-diagnosis/` (with `agents/openai.yaml`) |
| Generic | any agent's skills directory |

Download (pick one):

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

## ▶️ Usage

After triggering, answer its questions and run read-only commands layer by layer. To catch a "slow event" and locate the layer:

```powershell
curl -4 --noproxy '*' -o /dev/null -s -w "nl=%{time_namelookup} ct=%{time_connect} ac=%{time_appconnect} st=%{time_starttransfer} tt=%{time_total}`n" https://www.baidu.com
```

If `nl` (DNS) is close to `tt` and large → 100% stuck at DNS; if `ac - ct` is large → stuck at the TLS handshake.

> Any network-setting change (e.g. changing DNS) needs your explicit consent and often admin rights; this skill only diagnoses, it does not modify.

---

## 🤝 Contribute / Feedback

- Report bugs / suggestions: use the repo's Issue templates.
- Contribute: see [CONTRIBUTING.md](CONTRIBUTING.md); run `python tests/test_skill.py` (must be RESULT PASS) before any PR.
- Security: see [SECURITY.md](SECURITY.md) (private vulnerability reporting, not public issues).

---

## 📜 License

[MIT](LICENSE) © 2026 hyt315

> 🌏 **中文版: [README.md](./README.md)**
