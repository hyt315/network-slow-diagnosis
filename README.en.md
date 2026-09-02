<div align="center">

# 🌐 Windows Network Slowness Diagnosis Skill (`network-slow-diagnosis`)

**Diagnose why web pages load slowly, intermittently lag, or stall on Windows.**  
**Read-only queries · Millisecond-level evidence · Deep coverage for Windows 11 (24H2) / Wi-Fi 7 / DoH / IPv6 · Zero external dependencies.**

**[简体中文](./README.md) · English**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/hyt315/network-slow-diagnosis?sort=semver)](https://github.com/hyt315/network-slow-diagnosis/releases)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-compatible-1f6feb)](SKILL.md)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%2024H2-lightgrey)](SKILL.md)
[![Dependencies](https://img.shields.io/badge/Dependencies-Zero%20(Pure%20PowerShell%20%2B%20Python)-brightgreen)](SKILL.md)
[![Stars](https://img.shields.io/github/stars/hyt315/network-slow-diagnosis?style=social)](https://github.com/hyt315/network-slow-diagnosis/stargazers)

</div>

---

## 📖 What is this?

Windows users frequently encounter frustrating, elusive network bottlenecks:
- "The router is right beside me and pinging the gateway takes 1ms, yet every time I click a new page in my browser, **the first 3 seconds always freeze and spin**."
- "Chat apps work instantly, but opening heavy web pages stalls for dozens of seconds or errors out with connection timeout."
- "Whenever a PC starts up in the house, gaming latency for all devices skyrockets from 10ms to 1500ms."

**`network-slow-diagnosis`** is a professional-grade Windows network diagnostic skill built for AI Agents and system engineers. It replaces vague guesses with **layered, bottom-up, read-only measurements and hard millisecond-level evidence**, directly pinpointing modern network pain points in Windows 11 24H2, Wi-Fi 7, Modern Standby power saving, DoH timeout fallback, IPv6 stalls, and Delivery Optimization Bufferbloat.

---

## ✨ Core Features Matrix

| Diagnostic Layer | Scenarios Covered | Core Read-Only Cmdlets / Tools | Definitive Criteria |
|---|---|---|---|
| **Physical & Wireless** | Wi-Fi 7/6/5 signal, Band Steering roaming jitter, channel congestion, packet errors | `netsh wlan show interfaces`<br>`netsh wlan show networks mode=bssid`<br>`Get-NetAdapterStatistics` | Signal `<60%` or frequent re-associations across BSSIDs under same SSID; incrementing error counters |
| **Hardware Power & PPM** | Modern Standby (S0ix) D3 throttling, cold-start latency, EEE energy saving | `Get-NetAdapterPowerManagement`<br>`Get-NetAdapterAdvancedProperty` | `AllowComputerToTurnOffDevice = Enabled`, hardware clock recovery latency |
| **Domain Resolution (DNS/DoH)** | Windows 11 native DoH handshake timeout fallback, cold cache misses, router DNS flakiness | `Get-DnsClientDohServerAddress`<br>`netsh dns show encryption`<br>`Resolve-DnsName -Server` | System configured unreachable DoH template causing TLS timeout before falling back to UDP 53; `nl` near `tt` |
| **Transport & Dual Stack** | IPv6 fallback stall (Happy Eyeballs 21s timeout), PPPoE MTU 1492 black hole, TCP window autotuning | `netsh interface ipv6 show prefixpolicies`<br>`netsh interface ipv6 show subinterfaces`<br>`Test-NetConnection -Port 443` | IPv4 connects in `<30ms` while IPv6 fails/drops packets; `AutoTuningLevelEffective = Disabled` |
| **System Background Hogs** | Windows Delivery Optimization (DoSvc) P2P upstream saturation, Bufferbloat | `Get-DeliveryOptimizationStatus -PeerInfo`<br>`Get-DeliveryOptimizationPerfSnap`<br>`Get-NetTCPConnection` | High `TotalBytesUploadedToInternet`, upstream bandwidth saturated delaying downstream ACK packets |
| **Application & TLS Handshake** | TLS certificate chain negotiation delay, HTTP/3 QUIC fallback, remote server TTFB | `curl -w "ct=%{time_connect} ac=%{time_appconnect}..."`<br>`chrome://net-internals/#quic` | High `ac - ct` (TLS handshake bottleneck); local health verified but high `ttfb` (remote bottleneck) |

---

## 📊 Layered Diagnostic Architecture

```
[User reports: Web pages intermittently slow / lagging]
                          │
         [Layer 0: Scope & IP Configuration]
         Get-NetIPConfiguration (Rule out 169.254.x.x DHCP failure)
                          │
         [Layer 1: Physical Link & Wireless Band]
         ping gateway (<5ms?) ──(Abnormal)──> Weak WiFi / Band Steering Jitter / Bad Cable
                          │ (Normal)
         [Layer 2: Hardware Power & PPM Throttling]
         Get-NetAdapterPowerManagement ──(Enabled)──> Modern Standby D3 Wake Delay
                          │ (Ruled Out)
         [Layer 3: DNS & Windows 11 DoH Encryption]
         curl time_namelookup / DoH Audit ──(Slow)──> DoH Handshake Timeout Fallback
                          │ (Normal)
         [Layer 4: Transport Handshake & IPv6 Dual Stack]
         IPv4 vs IPv6 Latency / MTU ──(Stalled)──> IPv6 Fake-Pass / PMTU Black Hole
                          │ (Normal)
         [Layer 5: Background Bandwidth & Bufferbloat]
         Get-DeliveryOptimizationStatus ──(Saturated)──> DoSvc P2P Upstream Hog (Bufferbloat)
                          │ (Normal)
         [Layer 6: Application TLS & Remote TTFB]
         time_appconnect vs TTFB ──> Isolated to Remote Server / CDN Latency
```

---

## 🚀 Quick Start

### 1. One-Sentence Auto-Install for AI Agents (Recommended)

Copy and send this prompt to your AI Assistant (Claude Code / Cursor / Codex / Antigravity):

> **"Please install the network-slow-diagnosis skill: Clone https://github.com/hyt315/network-slow-diagnosis.git into your skills directory (e.g., `~/.claude/skills/network-slow-diagnosis` or `~/.agents/skills/network-slow-diagnosis`) and confirm installation."**

### 2. Multi-Platform Manual Installation

| Platform | Recommended Command |
|---|---|
| **Claude Code** | `git clone https://github.com/hyt315/network-slow-diagnosis.git ~/.claude/skills/network-slow-diagnosis` |
| **Cursor / Codex** | `git clone https://github.com/hyt315/network-slow-diagnosis.git ~/.cursor/skills/network-slow-diagnosis` |
| **Antigravity / Local** | `git clone https://github.com/hyt315/network-slow-diagnosis.git D:\skills
etwork-slow-diagnosis` |

### 3. Run Self-Test Suite

```powershell
python scripts/selftest.py
```

---

## 🎯 Modern Network Top 6 Pitfalls Quick Reference

| Typical Symptom | Root Cause Category | Key Diagnostic Cmdlet | Official Remediation |
|---|---|---|---|
| 🛜 **Stalls for 3s every few minutes** | Wi-Fi 7 / Band Steering Jitter | `netsh wlan show networks mode=bssid`<br>`Get-NetAdapterAdvancedProperty -Name "*"` | Separate 2.4GHz and 5GHz/6GHz SSIDs; set Roaming Aggressiveness to `1. Lowest` |
| 🔋 **First page stalls after idle** | NIC Modern Standby D3 Throttling | `Get-NetAdapter -Physical \| Get-NetAdapterPowerManagement` | Uncheck "Allow the computer to turn off this device to save power" in Device Manager |
| 🔒 **LAN fast, new sites freeze 2s** | Windows 11 Native DoH Timeout Fallback | `Get-DnsClientDohServerAddress`<br>`netsh dns show encryption` | Switch to reliable local DoH provider or set DNS encryption to "Unencrypted only" |
| 🌐 **Chat works, heavy sites timeout** | IPv6 Stall (Happy Eyeballs 21s Timeout) | `netsh interface ipv6 show prefixpolicies`<br>`Test-NetConnection <IPv6> -Port 443` | Disable faulty IPv6 or set registry `DisabledComponents=0x20` for IPv4 preference |
| 🚀 **Global lag, gateway ping 1500ms** | Delivery Optimization DoSvc P2P Upstream | `Get-DeliveryOptimizationStatus -PeerInfo`<br>`Get-DeliveryOptimizationPerfSnap` | Windows Update -> Advanced -> Delivery Optimization -> Turn off P2P downloads |
| 🐢 **Gigabit download stuck at KB/s** | TCP Window Auto-Tuning Disabled | `Get-NetTCPSetting \| Select AutoTuningLevelEffective` | Run `netsh int tcp set global autotuninglevel=normal` to restore defaults |

---

## 🛡️ Core Safety Principles

1. **Read-Only First (Zero Mutation)**: All diagnostics use native PowerShell/CMD read-only queries. Never alters registry or silently resets network without permission.
2. **Evidence-Based**: Quantitative latency and packet drop measurements for every conclusion.
3. **Zero Dependencies**: Pure native Windows commands + Python 3 standard library.
4. **Strict Scope**: **Explicitly excludes** all proxy/VPN/tunnel topics to focus entirely on direct Windows network stack health.

---

## 📖 In-Depth Technical References

| Reference Guide | Core Focus | When to Read |
|---|---|---|
| 📑 [**Diagnostic Playbook (`diagnostic-playbook.md`)**](references/diagnostic-playbook.md) | Layer 0~5 step-by-step commands, criteria, tools, and myths | When running end-to-end diagnosis or verifying threshold values |
| 💡 [**Modern Network Pitfalls (`modern-network-pitfalls.md`)**](references/modern-network-pitfalls.md) | Deep analysis of Wi-Fi 7, Modern Standby, DoH, IPv6, and Bufferbloat | When encountering elusive roaming stalls or handshake timeouts |
| 🔍 [**DNS Root Cause Real Case (`dns-root-cause-case.md`)**](references/dns-root-cause-case.md) | Full evidence chain of a real-world 11-second DNS stall investigation | When reviewing evidence-based diagnostic methodology |

---

## 📄 License

Licensed under the [MIT License](LICENSE).
