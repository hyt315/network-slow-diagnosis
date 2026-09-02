# Windows Network Slowness Diagnosis Skill (`network-slow-diagnosis`)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/hyt315/network-slow-diagnosis)](https://github.com/hyt315/network-slow-diagnosis/releases)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%2024H2-lightgrey)](SKILL.md)

An AI Agent Skill designed to diagnose why web pages load slowly or intermittently on Windows (WiFi/Ethernet) through layered, read-only evidence gathering.

---

## 🌟 Key Features (v1.1.0 Modernization)

| Diagnostic Layer | Scenarios Covered | Key Read-Only Cmdlets |
|---|---|---|
| **Physical & Wireless** | Wi-Fi 7/6/5 signals, Band Steering roaming jitter, NIC packet discards | `netsh wlan show interfaces`, `netsh wlan show networks mode=bssid`, `Get-NetAdapterStatistics` |
| **Power Management** | Modern Standby D3 throttling, cold-start latency, EEE energy saving | `Get-NetAdapterPowerManagement`, `Get-NetAdapterAdvancedProperty` |
| **DNS & DoH** | Windows 11 DNS-over-HTTPS fallback stalls, cold cache misses | `Get-DnsClientDohServerAddress`, `netsh dns show encryption`, `Resolve-DnsName` |
| **Transport & Dual Stack** | IPv6 fallback stalls (Happy Eyeballs timeout), PMTU black holes | `netsh interface ipv6 show prefixpolicies`, `Test-NetConnection -Port 443` |
| **Background & Bufferbloat**| Delivery Optimization (DoSvc) P2P upstream saturation, Bufferbloat | `Get-DeliveryOptimizationStatus -PeerInfo`, `Get-DeliveryOptimizationPerfSnap` |

---

## 🛡️ Core Principles

1. **Read-Only First**: All diagnostic commands are native PowerShell / CMD read-only queries. Zero destructive mutations.
2. **Evidence-Based**: Precise latency measurements and status counters for every layer.
3. **Zero Dependencies**: Pure standard library and OS built-in commands.

---

## 📖 Documentation

- [Layered Diagnostic Playbook (`references/diagnostic-playbook.md`)](references/diagnostic-playbook.md)
- [Modern Network Pitfalls Guide (`references/modern-network-pitfalls.md`)](references/modern-network-pitfalls.md)
- [DNS Root Cause Real Case (`references/dns-root-cause-case.md`)](references/dns-root-cause-case.md)

## 📄 License

Licensed under the [MIT License](LICENSE).
