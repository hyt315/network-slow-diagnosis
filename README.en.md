# 🌐 Windows Network Slowness Diagnosis / network-slow-diagnosis

<div align="center">

**Layered, read-only Windows network slowness diagnosis — pinpoint root cause from physical link to DNS to app with hard evidence.**

**分层只读排查 Windows 网页加载慢、间歇性卡顿与首屏转圈，用确凿毫秒级证据说话。**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/hyt315/network-slow-diagnosis?sort=semver)](CHANGELOG.md)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-compatible-1f6feb)](SKILL.md)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%2024H2-lightgrey)](SKILL.md)
[![GitHub Stars](https://img.shields.io/github/stars/hyt315/network-slow-diagnosis?style=social)](https://github.com/hyt315/network-slow-diagnosis/stargazers)

[English](./README.en.md) | [中文](./README.md)

</div>

---

## 📖 What is this?

Windows users frequently encounter frustrating, elusive network bottlenecks:
- "The router is right beside me and pinging the gateway takes 1ms, yet every time I click a new page in my browser, **the first 3 seconds always freeze and spin**."
- "Chat apps work instantly, but opening heavy web pages stalls for dozens of seconds or errors out with connection timeout."
- "Whenever a PC starts up or updates in the house, gaming latency for all devices skyrockets from 10ms to 1500ms."

**`network-slow-diagnosis`** is a professional-grade Windows network diagnostic skill built for AI Agents and system engineers. It replaces vague guesses with **layered, bottom-up, read-only measurements and hard millisecond-level evidence**, directly pinpointing modern network pain points in Windows 11 24H2, Wi-Fi 7, Band Steering roaming jitter, Modern Standby power saving, DoH timeout fallback, IPv6 stalls, and Delivery Optimization Bufferbloat.

---

## ✨ Key Features

| Diagnostic Layer | Scenarios Covered | Core Read-Only Cmdlets / Tools | Definitive Criteria |
|---|---|---|---|
| **Layer 1: Physical & Wireless** | Wi-Fi 7/6/5 signal, Band Steering roaming jitter, channel congestion, packet errors | `netsh wlan show interfaces`<br>`netsh wlan show networks mode=bssid`<br>`Get-NetAdapterStatistics` | Signal `<60%` or frequent re-associations across BSSIDs under same SSID; incrementing error counters |
| **Layer 2: Hardware Power Management** | Modern Standby (S0ix) D3 throttling, cold-start latency, EEE energy saving | `Get-NetAdapterPowerManagement`<br>`Get-NetAdapterAdvancedProperty` | `AllowComputerToTurnOffDevice = Enabled`, hardware clock recovery latency |
| **Layer 3: Domain Resolution (DNS/DoH)** | Windows 11 native DoH handshake timeout fallback, cold cache misses, router DNS flakiness | `Get-DnsClientDohServerAddress`<br>`netsh dns show encryption`<br>`Resolve-DnsName -Server` | System configured unreachable DoH template causing TLS timeout before falling back to UDP 53; `nl` (DNS lookup time) near total time |
| **Layer 4: Transport & Dual Stack** | IPv6 fallback stall (Happy Eyeballs 21s timeout), PPPoE MTU 1492 black hole, TCP window autotuning | `netsh interface ipv6 show prefixpolicies`<br>`netsh interface ipv6 show subinterfaces`<br>`Test-NetConnection -Port 443` | IPv4 connects in `<30ms` while IPv6 fails/drops packets; `AutoTuningLevelEffective = Disabled` |
| **Layer 5: System Background Hogs** | Windows Delivery Optimization (DoSvc) P2P upstream saturation, Bufferbloat | `Get-DeliveryOptimizationStatus -PeerInfo`<br>`Get-DeliveryOptimizationPerfSnap`<br>`Get-NetTCPConnection` | High `TotalBytesUploadedToInternet`, upstream bandwidth saturated delaying downstream ACK packets |
| **Layer 6: Application & TLS Handshake** | TLS certificate chain negotiation delay, HTTP/3 QUIC fallback, remote server TTFB | `curl -w "ct=%{time_connect} ac=%{time_appconnect}..."`<br>`chrome://net-internals/#quic` | High `ac - ct` (TLS handshake bottleneck); local health verified but high `ttfb` (remote bottleneck) |

---

## 🚀 Quick Start

This is an AI Agent Skill — install it into your AI assistant and you're ready.

### Option A: Paste one sentence into any Agent (recommended, most universal)

Send this to your AI assistant and it will detect the platform and clone to the right skills directory:

> Please install the network-slow-diagnosis skill: clone `https://github.com/hyt315/network-slow-diagnosis` into your skills directory (e.g. `~/.claude/skills/network-slow-diagnosis` or `~/.agents/skills/network-slow-diagnosis`) and confirm it works.

> 💡 **Works with smaller models too**: once installed, just say "diagnose why my network is slow" or "why are web pages loading slowly" to trigger the layered diagnostic workflow.

### Option B: GitHub CLI 2.90+ (one command)

```bash
gh skill install hyt315/network-slow-diagnosis network-slow-diagnosis --agent claude-code --scope user
# swap claude-code for codex / cursor / github-copilot, etc.
```

### Option C: Manual per-platform install

| Platform | Command |
|---|---|
| **Claude Code** | `git clone https://github.com/hyt315/network-slow-diagnosis.git ~/.claude/skills/network-slow-diagnosis` |
| **Codex** | `git clone https://github.com/hyt315/network-slow-diagnosis.git ~/.codex/skills/network-slow-diagnosis` |
| **Cursor** | `git clone https://github.com/hyt315/network-slow-diagnosis.git ~/.cursor/skills/network-slow-diagnosis` |
| **General Agents Directory** | `git clone https://github.com/hyt315/network-slow-diagnosis.git ~/.agents/skills/network-slow-diagnosis` |

### Option D: Run local regression selftest

```powershell
python scripts/selftest.py
```

---

## 🔒 Safety & Privacy Principles

- **Read-Only First (Zero Mutation)**: All diagnostics use native PowerShell/CMD read-only queries. Never alters registry or silently resets network without permission.
- **Evidence-Based**: Quantitative latency and packet drop measurements for every conclusion.
- **Zero Dependencies**: Pure native Windows commands + Python 3 standard library.
- **Strict Scope**: **Explicitly excludes** all proxy/VPN/tunnel topics to focus entirely on direct Windows network stack health.

---

## 📥 Download

| Method | Command / Link |
|---|---|
| **HTTPS** | `git clone https://github.com/hyt315/network-slow-diagnosis.git` |
| **SSH** | `git clone git@github.com:hyt315/network-slow-diagnosis.git` |
| **GitHub CLI** | `gh repo clone hyt315/network-slow-diagnosis` |
| **ZIP** | [Download ZIP](https://github.com/hyt315/network-slow-diagnosis/archive/refs/heads/main.zip) |
| **Tarball** | [Download Tar](https://github.com/hyt315/network-slow-diagnosis/archive/refs/heads/main.tar.gz) |
| **Single file (SKILL.md)** | `curl -O https://raw.githubusercontent.com/hyt315/network-slow-diagnosis/main/SKILL.md` |

---

## 💡 Core Philosophy

- **Bottom-Up**: Physical link → Hardware power → DNS/DoH → Transport dual stack → Application response → System background.
- **Slow Event Capture**: Use `curl -w` and `Measure-Command` to capture cold query latencies and handshake timings.
- **Distinguish Disconnected vs. Slow**: If IPv4 is `169.254.x.x`, it's a DHCP failure, not a slow network.
- **Approval-Gated Remediation**: Diagnoses and provides recommendations, but requires explicit user approval before applying changes.

---

## 📁 File Structure

```
network-slow-diagnosis/
├── SKILL.md                          # Core skill definition and layered workflow
├── README.md                         # Chinese documentation
├── README.en.md                      # English documentation
├── CHANGELOG.md                      # Version history
├── LICENSE                           # MIT License
├── .gitignore                        # Git ignore rules
├── CONTRIBUTING.md                   # Contribution guide
├── CODE_OF_CONDUCT.md                # Code of conduct
├── SECURITY.md                       # Security policy
├── Makefile                          # Test target
├── manifest.json                     # Skill manifest
├── agents/                           # Agent platform metadata
├── scripts/
│   └── selftest.py                   # Skill regression test runner
├── tests/
│   └── test_skill.py                 # Structure and assertion test suite
└── references/                       # In-depth technical guides
    ├── diagnostic-playbook.md        # Layered playbook and criteria
    ├── modern-network-pitfalls.md    # Modern Windows network pitfalls guide
    └── dns-root-cause-case.md        # Real-world 11-second DNS stall case study
```

---

## 📚 Real-World Quick Reference

| Typical Symptom | Root Cause Category | Key Diagnostic Cmdlet | Official Remediation |
|---|---|---|---|
| 🛜 **Stalls for 3s every few minutes** | Wi-Fi 7 / Band Steering Jitter | `netsh wlan show networks mode=bssid`<br>`Get-NetAdapterAdvancedProperty -Name "*"` | Separate 2.4GHz and 5GHz/6GHz SSIDs; set Roaming Aggressiveness to `1. Lowest` |
| 🔋 **First page stalls after idle** | NIC Modern Standby D3 Throttling | `Get-NetAdapter -Physical \| Get-NetAdapterPowerManagement` | Uncheck "Allow the computer to turn off this device to save power" in Device Manager |
| 🔒 **LAN fast, new sites freeze 2s** | Windows 11 Native DoH Timeout Fallback | `Get-DnsClientDohServerAddress`<br>`netsh dns show encryption` | Switch to reliable local DoH provider or set DNS encryption to "Unencrypted only" |
| 🌐 **Chat works, heavy sites timeout** | IPv6 Stall (Happy Eyeballs 21s Timeout) | `netsh interface ipv6 show prefixpolicies`<br>`Test-NetConnection <IPv6> -Port 443` | Disable faulty IPv6 or set registry `DisabledComponents=0x20` for IPv4 preference |
| 🚀 **Global lag, gateway ping 1500ms** | Delivery Optimization DoSvc P2P Upstream | `Get-DeliveryOptimizationStatus -PeerInfo`<br>`Get-DeliveryOptimizationPerfSnap` | Windows Update -> Advanced -> Delivery Optimization -> Turn off P2P downloads |
| 🐢 **Gigabit download stuck at KB/s** | TCP Window Auto-Tuning Disabled | `Get-NetTCPSetting \| Select AutoTuningLevelEffective` | Run `netsh int tcp set global autotuninglevel=normal` to restore defaults |

---

## ❓ FAQ

- **Q: Can I run this without Administrator privileges?**  
  A: Yes. All diagnostic commands are read-only queries. `ping`, `curl`, `Resolve-DnsName`, `Get-Net*`, and `netsh` query commands work directly under standard user accounts.
- **Q: Why are proxy and VPN topics excluded?**  
  A: Proxies and VPN tunnels alter the native routing topology. This skill specifically focuses on Windows native network stack and direct link bottlenecks.
- **Q: Will the diagnosis interrupt my active connections?**  
  A: Absolutely not. The skill adheres strictly to the Zero-Mutation principle, never resetting adapters, flushing DNS, or modifying network configs without consent.

---

## 🤝 Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md). If this skill helped you, please give it a [Star ⭐](https://github.com/hyt315/network-slow-diagnosis/stargazers)!

---

## 📄 License

Licensed under the [MIT License](LICENSE).

See [CHANGELOG.md](CHANGELOG.md) for version history.

---

> 🌏 **中文版: [README.md](./README.md)**
