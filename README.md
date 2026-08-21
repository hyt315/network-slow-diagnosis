<div align="center">

# 🐢 Windows 网络变慢排查 / Network Slow Diagnosis

**只读、分层、用证据说话：把"网页加载慢/间歇性卡顿"精确归因到物理链路、DNS、传输层、应用层或后台占用。**

**简体中文 · [English](./README.en.md)**

[![License: MIT](https://img.shields.io/github/license/hyt315/network-slow-diagnosis)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-compatible-1f6feb)](SKILL.md)
[![Platform](https://img.shields.io/badge/Platform-Windows-blue)](SKILL.md)
[![Tests](https://github.com/hyt315/network-slow-diagnosis/actions/workflows/ci.yml/badge.svg)](https://github.com/hyt315/network-slow-diagnosis/actions)

</div>

> **适用范围**：Windows 本机网络层与 DNS 导致的网页加载慢（直连路径）。

---

## 这是什么

打开网页有时很慢、转圈很久、间歇性卡顿，但不知道卡在哪？**Windows 网络变慢排查** 是一个 AI Agent Skill：它用**只读命令**（`ping` / `Test-NetConnection` / `Resolve-DnsName` / `curl -w` / `resmon` …）按"物理链路 → DNS → 传输层 → 应用层 → 资源占用"逐层取证，每层给出"确凿证实 / 确凿排除"，不靠"可能""大概"，更**不擅自改动任何设置**（改动需你明确同意）。

### 核心特性

| 特性 | 说明 |
|------|------|
| 🔍 **分层只读诊断** | 从 WiFi 信号、网关延迟一路查到 TLS 握手、TTFB、后台占带宽，逐层定位 |
| 🧭 **DNS 根因专长** | 用 `curl -w` 的 `time_namelookup` 把"慢"精确锁到 DNS；横向对比公共 DNS 确凿验证 |
| 🔐 **TLS 握手定位** | `time_appconnect - time_connect` 单独暴露证书链/密钥协商耗时，不再误判成服务器慢 |
| 🛰️ **多协议覆盖** | IPv4/IPv6 回退、MTU 分片、TCP 全局参数（Auto-Tuning/ECN）、默认路由错走 |
| 🧰 **权威工具清单** | WinMTR / dnsdiag / namebench / pktmon / psping 等只读诊断工具 |
| 📋 **16 条根因表 + 误区** | 把"看起来像 A 其实是 B"的常见误判一网打尽 |
| 🛡️ **只读优先** | 诊断阶段零改动；唯一写操作（`Clear-DnsClientCache`）仅在对照实验、明确告知后使用 |
| 🌐 **中英双语** | README 双语，案例与手册均中文 |

---

## 分层诊断流程（摘要）

1. **界定范围**：是所有网站都慢，还是个别？一直慢还是有时慢？`Get-NetIPConfiguration` 确认拿到 IP/网关/DNS（`169.254.x.x` = 没网，不是慢）。
2. **物理/链路层**：网关 `ping` 延迟、WiFi 信号、`Get-NetAdapterStatistics` 错包计数。
3. **DNS 层（最常见）**：`Measure-Command { Resolve-DnsName }` 多次采样；`curl -w` 抓 `time_namelookup` 慢事件；冷缓存对照。
4. **传输层**：TLS 握手（`time_appconnect`）、TCP 建连、`curl -4/-6` 看 IPv6 回退、`Get-NetTCPSetting`、`Get-NetRoute` 看多网卡错走。
5. **应用层/TTFB**：`time_starttransfer`；QUIC（`chrome://net-internals/#quic`）。
6. **资源占用**：`resmon` / TCPView / Windows 11 后台占用（DoSvc、HVCI、驱动回退）。

完整命令、判定标准、工具清单与真实案例见 `references/`：

- [分层诊断手册](references/diagnostic-playbook.md)
- [DNS 根因实战案例](references/dns-root-cause-case.md)（一次真实"间歇性 11 秒卡顿"的完整排查）

---

## 📁 文件结构

```
network-slow-diagnosis/
├── SKILL.md                     # 技能入口（路由 + 分层 Workflow）
├── manifest.json                # 治理元数据
├── Makefile                     # `make test` → 回归测试
├── references/
│   ├── diagnostic-playbook.md   # 分层诊断手册（精确命令 + 判定标准 + 工具 + 误区）
│   └── dns-root-cause-case.md   # DNS 根因实战案例
├── tests/
│   └── test_skill.py            # 回归测试（结构/卫生/引用链接/负向用例）
├── LICENSE
├── README.md  /  README.en.md  # 双语说明（本文件为中文）
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
├── SECURITY.md
├── CHANGELOG.md
├── .github/                     # Issue/PR 模板 + CI
└── agents/openai.yaml           # OpenAI 兼容 Agent 描述
```

---

## 📥 下载 / 安装

支持主流 Agent 平台，把技能目录放到对应 skills 文件夹即可：

| 平台 | 安装路径 |
|------|----------|
| Claude Code | `~/.claude/skills/network-slow-diagnosis/` |
| Cursor | `~/.cursor/skills/network-slow-diagnosis/` |
| Codex / ChatGPT | 项目内 `.agent/skills/network-slow-diagnosis/`（配合 `agents/openai.yaml`） |
| 通用 | 任意 Agent 的 skills 目录 |

下载方式（5 选 1）：

```bash
# HTTPS
git clone https://github.com/hyt315/network-slow-diagnosis.git

# SSH
git clone git@github.com:hyt315/network-slow-diagnosis.git

# GitHub CLI
gh repo clone hyt315/network-slow-diagnosis

# ZIP
# https://github.com/hyt315/network-slow-diagnosis/archive/refs/heads/main.zip

# 单文件（仅 SKILL.md）
curl -O https://raw.githubusercontent.com/hyt315/network-slow-diagnosis/main/SKILL.md
```

---

## ▶️ 使用

触发后，按 SKILL.md 的 Workflow 逐层回答它的问题、跑只读命令。例如抓"慢事件"并定位环节：

```powershell
curl -4 --noproxy '*' -o /dev/null -s -w "nl=%{time_namelookup} ct=%{time_connect} ac=%{time_appconnect} st=%{time_starttransfer} tt=%{time_total}`n" https://www.baidu.com
```

若 `nl`（DNS）接近 `tt` 且很大 → 100% 卡在 DNS；若 `ac - ct` 很大 → 卡在 TLS 握手。

> 任何改动网络设置（如改 DNS）都需要你明确同意，且常需管理员权限；本技能只诊断，不擅自修改。

---

## 🤝 贡献 / 反馈

- 报 Bug / 提建议：用仓库的 Issue 模板。
- 参与贡献：见 [CONTRIBUTING.md](CONTRIBUTING.md)，改动前请跑 `python tests/test_skill.py`（须 RESULT PASS）。
- 漏洞报告：见 [SECURITY.md](SECURITY.md)（私有漏洞报告，勿走公开 Issue）。

---

## 📜 License

[MIT](LICENSE) © 2026 hyt315

> 🌏 **English version: [README.en.md](./README.en.md)**
