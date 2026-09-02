<div align="center">

# 🌐 Windows 网络变慢分层排查技能 (`network-slow-diagnosis`)

**专治 Windows「网页有时很慢 / 间歇性卡顿 / 网络感觉慢 / 首屏转圈」等复杂疑难网络层问题。**  
**纯只读探测 · 毫秒级证据说话 · 深度覆盖 Windows 11 (24H2) / Wi-Fi 7 / DoH / IPv6 假通 · 零外部依赖。**

**简体中文 · [English](./README.en.md)**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/hyt315/network-slow-diagnosis?sort=semver)](https://github.com/hyt315/network-slow-diagnosis/releases)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-compatible-1f6feb)](SKILL.md)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%2024H2-lightgrey)](SKILL.md)
[![Dependencies](https://img.shields.io/badge/Dependencies-Zero%20(Pure%20PowerShell%20%2B%20Python)-brightgreen)](SKILL.md)
[![Stars](https://img.shields.io/github/stars/hyt315/network-slow-diagnosis?style=social)](https://github.com/hyt315/network-slow-diagnosis/stargazers)

</div>

---

## 📖 这是什么？

很多 Windows 用户经常遇到这类让人抓狂的网络问题：
- “路由器就在旁边，ping 网关只要 1ms，但每次在浏览器点开新网页**前 3 秒必定卡死转圈**”；
- “微信打字聊天秒发，但打开大型网页要卡几十秒甚至报错连接超时”；
- “家里只要有人开电脑，所有设备游戏延迟瞬间从 10ms 飙升至 1500ms”。

**`network-slow-diagnosis`** 是一个专为 AI Agent（以及系统工程师）打造的专业级 Windows 本机网络诊断技能。它摒弃了“大概是 DNS 抽风”、“重启路由器试试”等模糊猜测，遵循 **「自底向上逐层排查、纯只读测量、用毫秒级数据说话」** 的硬核原则，直击 Windows 11 24H2 / Wi-Fi 7 / 节能调度 / DoH 超时 / IPv6 假通 / 传递优化 Bufferbloat 等现代网络深水区。

---

## ✨ 核心特性大盘

| 诊断层级 | 覆盖场景 | 核心只读命令 / 工具 | 确凿判定依据 |
|---|---|---|---|
| **物理与无线链路** | Wi-Fi 7/6/5 信号强度、双频合一漫游颠簸、信道拥塞、网线丢包错包 | `netsh wlan show interfaces`<br>`netsh wlan show networks mode=bssid`<br>`Get-NetAdapterStatistics` | 信号 `<60%` 或相同 SSID 多 BSSID 频繁重关联；错包计数持续递增 |
| **硬件能耗调度** | Modern Standby (S0ix) D3 挂起、静置后首开网页迟滞、EEE 节能 | `Get-NetAdapterPowerManagement`<br>`Get-NetAdapterAdvancedProperty` | `AllowComputerToTurnOffDevice = Enabled`，硬件拉起时钟延迟 |
| **域名解析 (DNS/DoH)** | Win11 原生 DoH 握手超时回退、冷查询慢、路由器转发器抽风 | `Get-DnsClientDohServerAddress`<br>`netsh dns show encryption`<br>`Resolve-DnsName -Server` | 系统启用了海外/不可达 DoH 模板导致 TLS 超时后才降级 UDP 53；`nl` 耗时接近 `tt` |
| **传输层与双栈** | IPv6 假通 (Happy Eyeballs 21s 超时)、PPPoE MTU 1492 黑洞、TCP 窗口自适应 | `netsh interface ipv6 show prefixpolicies`<br>`netsh interface ipv6 show subinterfaces`<br>`Test-NetConnection -Port 443` | IPv4 秒连 (<30ms) 而 IPv6 握手失败/丢包；`AutoTuningLevelEffective = Disabled` |
| **系统隐蔽后台** | Windows 传递优化 (DoSvc) P2P 上行吃满、Bufferbloat 缓冲区膨胀 | `Get-DeliveryOptimizationStatus -PeerInfo`<br>`Get-DeliveryOptimizationPerfSnap`<br>`Get-NetTCPConnection` | `TotalBytesUploadedToInternet` 巨大，上行被吃满导致下行 ACK 队列堆积延迟雪崩 |
| **应用与 TLS 握手** | TLS 证书链协商延迟、HTTP/3 QUIC 握手回退、远端服务器 TTFB | `curl -w "ct=%{time_connect} ac=%{time_appconnect}..."`<br>`chrome://net-internals/#quic` | `ac - ct` 极大（TLS 握手受阻）；本地健康但 `ttfb` 极大（远端服务器瓶颈） |

---

## 📊 分层排查架构

```
[用户反馈: 网页有时很慢 / 间歇性卡顿]
                     │
         [第 0 层: 界定范围与 IP 状态]
         Get-NetIPConfiguration (排除 169.254.x.x DHCP 失败)
                     │
         [第 1 层: 物理链路与无线频段]
         ping 网关 (<5ms?) ──(异常)──> WiFi 弱 / 频段漫游颠簸 / 网线错包
                     │ (正常)
         [第 2 层: 硬件节能与电源调度]
         Get-NetAdapterPowerManagement ──(开启)──> Modern Standby D3 唤醒迟滞
                     │ (排除)
         [第 3 层: DNS 与 Win11 DoH 加密]
         curl time_namelookup / DoH 审计 ──(慢)──> DoH 握手超时降级 / 路由器 DNS 抽风
                     │ (正常)
         [第 4 层: 传输层握手与 IPv6 双栈]
         IPv4 vs IPv6 测速 / MTU ──(卡死)──> IPv6 假通 / PMTU 黑洞 / TCP 窗口锁死
                     │ (正常)
         [第 5 层: 后台占用与缓冲区膨胀]
         Get-DeliveryOptimizationStatus ──(占满)──> DoSvc P2P 上行吃满 (Bufferbloat)
                     │ (正常)
         [第 6 层: 应用层 TLS / 远端 TTFB]
         time_appconnect vs TTFB ──> 定位为远端服务器 / CDN 响应瓶颈
```

---

## 🚀 快速开始

### 1. AI Agent 一句话自动安装（推荐）

把下面这句话直接复制发送给你的 AI 助手（Claude Code / Cursor / Codex / Antigravity 等）：

> **“请安装 network-slow-diagnosis 技能：把 https://github.com/hyt315/network-slow-diagnosis.git 克隆到你的 skills 目录（如 `~/.claude/skills/network-slow-diagnosis` 或 `~/.agents/skills/network-slow-diagnosis`），并确认安装成功。”**

### 2. 多平台手动安装

| 平台 | 推荐安装命令 |
|---|---|
| **Claude Code** | `git clone https://github.com/hyt315/network-slow-diagnosis.git ~/.claude/skills/network-slow-diagnosis` |
| **Cursor / Codex** | `git clone https://github.com/hyt315/network-slow-diagnosis.git ~/.cursor/skills/network-slow-diagnosis` |
| **Antigravity / 本地环境** | `git clone https://github.com/hyt315/network-slow-diagnosis.git D:\skills
etwork-slow-diagnosis` |

### 3. 一键运行回归自检

```powershell
python scripts/selftest.py
```

---

## 🎯 现代网络 6 大疑难杂症实战速查

| 典型现象 | 根因分类 | 核心排查命令 | 官方治理方案 |
|---|---|---|---|
| 🛜 **每隔几分钟突发卡顿 3 秒** | Wi-Fi 7 / 双频合一漫游颠簸 | `netsh wlan show networks mode=bssid`<br>`Get-NetAdapterAdvancedProperty -Name "*"` | 路由器将 2.4G 与 5G/6G 分开命名；网卡漫游激进性调为 `1. Lowest` |
| 🔋 **静置一会儿后首次开网页必卡** | 网卡 Modern Standby D3 挂起 | `Get-NetAdapter -Physical \| Get-NetAdapterPowerManagement` | 网卡属性电源管理中取消勾选“允许计算机关闭此设备以节约电源” |
| 🔒 **局域网极快，但开新网页白屏 2 秒** | Windows 11 原生 DoH 超时降级 | `Get-DnsClientDohServerAddress`<br>`netsh dns show encryption` | 换用国内高速 DoH（阿里/腾讯）或将 DNS 加密切换为“仅未加密” |
| 🌐 **即时通讯正常，部分网页转圈超时** | IPv6 假通 (Happy Eyeballs 21s 超时) | `netsh interface ipv6 show prefixpolicies`<br>`Test-NetConnection <IPv6> -Port 443` | 禁用故障 IPv6 或配置注册表 `DisabledComponents=0x20` 设置 IPv4 优先 |
| 🚀 **全家网络暴卡，ping 网关飙到 1500ms** | 传递优化 DoSvc P2P 上行占满 | `Get-DeliveryOptimizationStatus -PeerInfo`<br>`Get-DeliveryOptimizationPerfSnap` | Windows 更新 -> 高级选项 -> 传递优化 -> 关闭“允许从其他电脑下载” |
| 🐢 **千兆宽带下载被锁死几百 KB/s** | TCP 接收窗口自适应被意外关闭 | `Get-NetTCPSetting \| Select AutoTuningLevelEffective` | 执行 `netsh int tcp set global autotuninglevel=normal` 恢复默认 |

---

## 🛡️ 铁律原则与安全规范

1. **绝对只读优先（Zero Mutation）**：所有诊断步骤均基于 PowerShell / CMD 原生只读查询，绝不擅自修改注册表、静默重置网络栈或修改 DNS。
2. **用确凿数据说话**：下结论必须带有毫秒级延迟、握手状态或丢包计数的证据链，禁止使用“大概”、“可能”。
3. **完全零外部依赖**：纯 Windows 原生命令 + Python 3 标准库，无需 `npm install` 或 `pip install` 任何第三方包。
4. **范围明确**：**严格排除** 任何代理 / VPN / 隧道相关话题，专注解决 Windows 直连网络层瓶颈。

---

## 📖 深度技术参考文档

| 参考文档 | 核心内容 | 推荐阅读时机 |
|---|---|---|
| 📑 [**分层诊断手册 (`diagnostic-playbook.md`)**](references/diagnostic-playbook.md) | 第 0~5 层全量排查命令、判定基准、开源工具链与经典误区 | 需要按步骤执行完整排查或查询标准判定值时 |
| 💡 [**现代网络深水区指南 (`modern-network-pitfalls.md`)**](references/modern-network-pitfalls.md) | 深入剖析 Wi-Fi 7、Modern Standby、DoH、IPv6 假通、Bufferbloat 根因与治理 | 遇到疑难断流、握手超时或后台占满等深度问题时 |
| 🔍 [**DNS 根因实战案例 (`dns-root-cause-case.md`)**](references/dns-root-cause-case.md) | 一次真实「间歇性 11 秒卡顿」的完整证据链与排障全记录 | 向用户展示“证据说话”排障范式或复盘时 |

---

## 📄 开源协议

本项目采用 [MIT 许可证](LICENSE) 开源。
