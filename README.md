<div align="center">

# 🐢 Windows 网络变慢排查 / Network Slow Diagnosis

**只读、分层、用证据说话：把"网页加载慢/间歇性卡顿"精确归因到物理链路、DNS、传输层、应用层或后台占用。**

**简体中文 · [English](./README.en.md)**

[![License: MIT](https://img.shields.io/github/license/hyt315/network-slow-diagnosis)](LICENSE)
[![Release](https://img.shields.io/github/v/release/hyt315/network-slow-diagnosis?sort=semver)](https://github.com/hyt315/network-slow-diagnosis/releases)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-compatible-1f6feb)](SKILL.md)
[![Platform](https://img.shields.io/badge/Platform-Windows-blue)](SKILL.md)
[![Tests](https://github.com/hyt315/network-slow-diagnosis/actions/workflows/ci.yml/badge.svg)](https://github.com/hyt315/network-slow-diagnosis/actions)
[![Stars](https://img.shields.io/github/stars/hyt315/network-slow-diagnosis?style=social)](https://github.com/hyt315/network-slow-diagnosis/stargazers)

</div>

> **适用范围**：Windows 本机网络层与 DNS 导致的网页加载慢（直连路径）。

---

## 📖 这是什么？

打开网页有时很慢、转圈很久、间歇性卡顿，但不知道卡在哪？**Windows 网络变慢排查** 是一个 AI Agent Skill：它用**只读命令**（`ping` / `Test-NetConnection` / `Resolve-DnsName` / `curl -w` / `resmon` …）按"物理链路 → DNS → 传输层 → 应用层 → 资源占用"逐层取证，每层给出"确凿证实 / 确凿排除"，不靠"可能""大概"，更**不擅自改动任何设置**（改动需你明确同意）。

### ✨ 核心特性

| 特性 | 说明 |
|------|------|
| 🔍 **分层只读诊断** | 从 WiFi 信号、网关延迟一路查到 TLS 握手、TTFB、后台占带宽，逐层定位 |
| 🧭 **DNS 根因专长** | 用 `curl -w` 的 `time_namelookup` 把"慢"精确锁到 DNS；横向对比公共 DNS 确凿验证 |
| 🔐 **TLS 握手定位** | `time_appconnect - time_connect` 单独暴露证书链/密钥协商耗时，不再误判成服务器慢 |
| 🛰️ **多协议覆盖** | IPv4/IPv6 回退、MTU 分片、TCP 全局参数（Auto-Tuning/ECN）、默认路由错走 |
| 🧰 **权威工具清单** | WinMTR / dnsdiag / namebench / pktmon / psping 等只读诊断工具 |
| 📋 **16 条根因表 + 误区** | 把"看起来像 A 其实是 B"的常见误判一网打尽 |
| 🛡️ **只读优先** | 诊断阶段零改动；唯一写操作（`Clear-DnsClientCache`）仅在对照实验、明确告知后使用 |

---

## 📚 示例：一次真实的「11 秒卡顿」定位

实战案例（完整记录见 [dns-root-cause-case.md](references/dns-root-cause-case.md)）：用户反映"网页有时要等很久"，抓一个慢事件：

```text
curl -4 --noproxy '*' -w "nl=%{time_namelookup} ct=%{time_connect} st=%{time_starttransfer} tt=%{time_total}"
baidu #1  nl=11.086766  ct=11.118662  st=11.184887  tt=11.185000
```

`nl`（DNS）≈ `tt`（总耗时）= 11 秒，建连与首字节都在 DNS 返回后瞬间完成 → **100% 卡在 DNS**。再横向对比公共 DNS（223.5.5.5 稳定 25–31ms vs 路由器转发器冷查询 800ms–11s）→ 根因确凿锁定。改 DNS 后所有站点 `nl` 降到 7–29ms，卡顿消失。

这就是本技能的方法论：**每一层都给"确凿证实 / 确凿排除"，禁止"可能大概"。**

---

## 🚀 快速开始

> ✨ **一句话装进 AI Agent**：把下面这段话直接发给你的 AI 助手，它会自动完成安装——
>
> ```text
> 请安装 network-slow-diagnosis Skill：把 https://github.com/hyt315/network-slow-diagnosis 克隆到你的 skills 目录（Claude Code：~/.claude/skills/network-slow-diagnosis/；Cursor：~/.cursor/skills/；Codex/ChatGPT：项目内 .agent/skills/），并确认 SKILL.md、references/、tests/ 都在。以后我报告「网页打开很慢 / 间歇性卡顿 / 网络感觉慢」时，按 SKILL.md 的 Workflow 用只读命令分层诊断。
> ```

| 平台 | 安装命令 |
|------|----------|
| **Claude Code** | `git clone https://github.com/hyt315/network-slow-diagnosis.git ~/.claude/skills/network-slow-diagnosis` |
| **Cursor** | `git clone https://github.com/hyt315/network-slow-diagnosis.git ~/.cursor/skills/network-slow-diagnosis` |
| **Codex / ChatGPT** | 项目内 `.agent/skills/network-slow-diagnosis/` |
| **通用** | 任意 Agent 的 skills 目录 |

---

## 💬 触发方式

对 AI 说以下任意一类话，即会触发本技能：

- 「网页打开很慢」「有时卡很久才出来」「间歇性转圈」
- 「网络感觉慢」「不知道是不是 DNS 的问题」
- 「想排查是不是 WiFi / 网关 / IPv6 回退 / 后台占用导致变慢」

## ⚙️ 前置条件

- **Windows 10 / 11**（PowerShell 与 curl 系统自带，零额外安装）
- 诊断阶段**无需管理员权限**（全部只读）；仅修复阶段改设置才需要管理员 + 你的明确同意
- 无第三方依赖；可选工具（WinMTR / dnsdiag 等）仅在需要深挖时建议安装

## 📦 输出交付物

```text
📋 分层诊断结论   —— 物理链路/DNS/传输层/应用层/资源占用，每层"确凿证实 或 确凿排除"
🎯 根因一句话     —— 已查实、非推测（如"WLAN 的 DNS 是路由器 192.168.1.1，冷查询要 11 秒"）
🛠️ 修复建议       —— 需你明确同意后才执行，且常需管理员权限；本技能只诊断，不擅自修改
```

---

## 📥 下载 / 安装

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

## 📁 文件结构

```
network-slow-diagnosis/
├── SKILL.md                     # 技能入口（路由 + 分层 Workflow）
├── manifest.json                # 治理元数据
├── Makefile                     # `make test` → 回归测试
├── references/
│   ├── diagnostic-playbook.md   # 分层诊断手册（精确命令 + 判定标准 + 工具 + 误区）
│   └── dns-root-cause-case.md   # DNS 根因实战案例（含前后证据）
├── tests/
│   └── test_skill.py            # 回归测试（结构/卫生/引用链接/负向用例）
├── LICENSE
├── README.md  /  README.en.md  # 双语说明（本文件为中文）
└── .github/                     # Issue/PR 模板 + CI
```

---

## ▶️ 快速使用

触发后，按 SKILL.md 的 Workflow 逐层回答它的问题、跑只读命令。例如抓"慢事件"并定位环节：

```powershell
curl -4 --noproxy '*' -o /dev/null -s -w "nl=%{time_namelookup} ct=%{time_connect} ac=%{time_appconnect} st=%{time_starttransfer} tt=%{time_total}`n" https://www.baidu.com
```

若 `nl`（DNS）接近 `tt` 且很大 → 100% 卡在 DNS；若 `ac - ct` 很大 → 卡在 TLS 握手。

> 任何改动网络设置（如改 DNS）都需要你明确同意，且常需管理员权限；本技能只诊断，不擅自修改。

---

## 🤝 贡献 / 反馈

- 报 Bug / 提建议：用仓库的 Issue 模板
- 参与贡献：见 [CONTRIBUTING.md](CONTRIBUTING.md)，改动前请跑 `python tests/test_skill.py`（须 RESULT PASS）
- 漏洞报告：见 [SECURITY.md](SECURITY.md)（私有漏洞报告，勿走公开 Issue）

---

## 📜 License

[MIT](LICENSE) © 2026 hyt315

> 🌏 **English version: [README.en.md](./README.en.md)**