# Windows 网络变慢排查技能 (`network-slow-diagnosis`)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/hyt315/network-slow-diagnosis)](https://github.com/hyt315/network-slow-diagnosis/releases)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%2024H2-lightgrey)](SKILL.md)

专治 Windows 用户「网页有时很慢 / 间歇性卡顿 / 网络感觉慢」这类本机网络层问题的 AI Agent Skill。

---

## 🌟 核心特性 (v1.1.0 现代化升级)

| 诊断层级 | 覆盖场景 | 核心只读命令 |
|---|---|---|
| **物理与无线层** | Wi-Fi 7/6/5 信号、双频合一漫游颠簸、网线错包/丢包 | `netsh wlan show interfaces`, `netsh wlan show networks mode=bssid`, `Get-NetAdapterStatistics` |
| **硬件节能层** | Modern Standby D3 挂起、首开网页卡顿、EEE 节能 | `Get-NetAdapterPowerManagement`, `Get-NetAdapterAdvancedProperty` |
| **DNS 与 DoH 层** | Win11 原生 DoH 超时降级、冷缓存慢、递归耗时 | `Get-DnsClientDohServerAddress`, `netsh dns show encryption`, `Resolve-DnsName` |
| **传输与 IPv6 双栈** | IPv6 假通回退 (Happy Eyeballs 21s 超时)、PMTU 黑洞 | `netsh interface ipv6 show prefixpolicies`, `Test-NetConnection -Port 443` |
| **后台占用与延迟** | 传递优化 (DoSvc) P2P 上行吃满、Bufferbloat 缓冲区膨胀 | `Get-DeliveryOptimizationStatus -PeerInfo`, `Get-DeliveryOptimizationPerfSnap` |

---

## 🛡️ 铁律原则

1. **只读优先**：所有诊断命令均为 PowerShell / CMD 原生只读探测，下结论前绝不擅自破坏性修改网络配置。
2. **用证据说话**：每一层均输出毫秒级延迟与状态证据，确凿证实或排除根因。
3. **零外部依赖**：无需安装任何第三方 npm/pip 包，直接在任意 Windows 机器上即开即用。

---

## 📖 参考文档

- [分层诊断手册 (`references/diagnostic-playbook.md`)](references/diagnostic-playbook.md)
- [现代网络深水区避坑指南 (`references/modern-network-pitfalls.md`)](references/modern-network-pitfalls.md)
- [DNS 根因实战案例 (`references/dns-root-cause-case.md`)](references/dns-root-cause-case.md)

## 📄 开源协议

本项目采用 [MIT 许可证](LICENSE)。
