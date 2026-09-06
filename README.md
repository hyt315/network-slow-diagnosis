# 🌐 Windows 网络变慢排查 / Network Slow Diagnosis

<div align="center">

**分层只读排查 Windows 网页加载慢、间歇性卡顿与首屏转圈，用确凿毫秒级证据说话。**

**Layered, read-only Windows network slowness diagnosis — pinpoint root cause from physical link to DNS to app with hard evidence.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/hyt315/network-slow-diagnosis?sort=semver)](CHANGELOG.md)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-compatible-1f6feb)](SKILL.md)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%2024H2-lightgrey)](SKILL.md)
[![GitHub Stars](https://img.shields.io/github/stars/hyt315/network-slow-diagnosis?style=social)](https://github.com/hyt315/network-slow-diagnosis/stargazers)

[English](./README.en.md) | [中文](./README.md)

</div>

---

## 📖 这是什么？

很多 Windows 用户经常遇到这类让人抓狂的网络现象：
- “路由器就在旁边，ping 网关只有 1ms，但每次在浏览器点开新网页**前 3 秒必定卡死转圈**”；
- “微信打字聊天秒发，但打开部分大型网页要卡几十秒甚至报错连接超时”；
- “家里只要有人开机或更新系统，所有设备游戏延迟瞬间从 10ms 飙升至 1500ms”。

**`network-slow-diagnosis`** 是一个专为 AI Agent（以及系统工程师）打造的专业级 Windows 本机网络诊断技能。它摒弃了“大概是 DNS 抽风”、“重启路由器试试”等模糊猜测，遵循 **「自底向上逐层排查、纯只读测量、用毫秒级数据说话」** 的原则，深度覆盖 Windows 11 24H2、Wi-Fi 7 / 双频合一漫游颠簸、网卡 Modern Standby 节能调度、DoH 超时降级、IPv6 假通与传递优化 Bufferbloat 等现代网络深水区。

---

## ✨ 核心特性

| 诊断层级 | 覆盖场景 | 核心只读命令 / 工具 | 确凿判定依据 |
|---|---|---|---|
| **一键诊断扫描器** | L0~L5 全层自动化毫秒级测绘，输出标准事实卡片 | `powershell -File scripts/diagnose.ps1` | 5~10 秒全自动出具各层指标、基线比对与确凿归因 |
| **第 1 层：物理与无线链路** | Wi-Fi 7/6/5 信号强度、双频合一漫游颠簸、同频 AP 拥塞、NDIS 第三方过滤驱动、硬件错包丢包 | `netsh wlan show interfaces`<br>`netsh wlan show networks mode=bssid`<br>`Get-NetAdapterBinding`<br>`netstat -e` | 信号 `<60%` 或同信道 >3 个高信号 AP；网卡绑定非微软第三方过滤驱动；错包计数递增 |
| **第 2 层：硬件节能调度** | Modern Standby (S0ix) D3 挂起、静置后首开网页迟滞、EEE 节能 | `Get-NetAdapterPowerManagement`<br>`Get-NetAdapterAdvancedProperty` | `AllowComputerToTurnOffDevice = Enabled`，硬件时钟唤醒延迟 |
| **第 3 层：DNS 与 DoH 解析** | Win11 原生 DoH 握手超时回退、DNS 搜索后缀列表级联超时、NRPT 规则失效、冷查询慢 | `Get-DnsClientGlobalSetting`<br>`Get-DnsClientDohServerAddress`<br>`Resolve-DnsName -Server` | `SuffixSearchList` 包含多个失效后缀；不可达 DoH 模板导致 TLS 超时回退；`nl` 接近总耗时 |
| **第 4 层：传输层与双栈** | 临时端口耗尽与 TIME_WAIT 积压、IPv6 假通超时、PPPoE MTU 1492 黑洞、TCP 窗口自适应 | `(Get-NetTCPConnection -State TimeWait).Count`<br>`netsh interface ipv6 show prefixpolicies`<br>`Test-NetConnection -Port 443` | `TimeWait` 超过 3000~5000 导致 10055 异常；IPv4 秒通而 IPv6 卡死；`AutoTuningLevelEffective = Disabled` |
| **第 5 层：死挂代理与 Hosts** | 注册表死挂代理残余检测、Hosts 文件硬编码失效旧 IP、虚拟网卡 (VMware/WSL) 优先级冲突 | `Get-ItemProperty ... "Internet Settings"`<br>`Get-Content ...\hosts`<br>`Get-NetRoute -DestinationPrefix "0.0.0.0/0"` | 注册表 `ProxyEnable=1` 但对应端口无响应；Hosts 静态绑定失效 IP；默认路由指向虚拟网卡 |
| **第 6 层：后台占用与膨胀** | Windows 传递优化 (DoSvc) P2P 上行吃满、Bufferbloat 缓冲区膨胀 | `Get-DeliveryOptimizationStatus -PeerInfo`<br>`Get-DeliveryOptimizationPerfSnap`<br>`Get-NetTCPConnection` | `TotalBytesUploadedToInternet` 巨大；并发大吞吐时 Ping 延迟由 10ms 暴涨至 500ms+ |
| **第 7 层：应用与 TLS 握手** | TLS 证书链协商延迟、HTTP/3 QUIC 握手回退、远端服务器 TTFB | `curl.exe -w "ct=%{time_connect} ac=%{time_appconnect}..."`<br>`chrome://net-internals/#quic` | `ac - ct` 极大（TLS 握手受阻）；本地健康但 `ttfb` 极大（远端服务器响应慢） |

---

## 🚀 快速开始

这是一个标准的 AI Agent Skill —— 安装到你的 AI 助手后即可直接使用。

### 方式 A：把一句话发给任意 Agent（最推荐、最通用）

把下面这句话直接复制发送给你的 AI 助手，它会自动识别环境并克隆到正确的技能目录：

> 请安装 network-slow-diagnosis 技能：克隆 `https://github.com/hyt315/network-slow-diagnosis` 到你的 skills 目录（如 `~/.claude/skills/network-slow-diagnosis` 或 `~/.agents/skills/network-slow-diagnosis`），并确认安装成功。

> 💡 **小模型同样适配**：安装完成后，只需对 AI 说“帮我排查网络为什么变慢”或“为什么网页打开很卡”，即可自动触发分层诊断。

### 方式 B：GitHub CLI 2.90+（一行命令）

```bash
gh skill install hyt315/network-slow-diagnosis network-slow-diagnosis --agent claude-code --scope user
# 也可将 claude-code 替换为 codex / cursor / github-copilot 等
```

### 方式 C：多平台手动安装

| 平台 | 安装命令 |
|---|---|
| **Claude Code** | `git clone https://github.com/hyt315/network-slow-diagnosis.git ~/.claude/skills/network-slow-diagnosis` |
| **Codex** | `git clone https://github.com/hyt315/network-slow-diagnosis.git ~/.codex/skills/network-slow-diagnosis` |
| **Cursor** | `git clone https://github.com/hyt315/network-slow-diagnosis.git ~/.cursor/skills/network-slow-diagnosis` |
| **通用 Agents 目录** | `git clone https://github.com/hyt315/network-slow-diagnosis.git ~/.agents/skills/network-slow-diagnosis` |

### 方式 D：本地运行回归自测

```powershell
python scripts/selftest.py
```

---

## 🔒 安全与隐私原则

- **纯只读排查（Zero Mutation）**：所有诊断命令均为 PowerShell / CMD 原生只读查询，绝不擅自修改注册表、静默重置网络栈或修改 DNS。
- **用确凿数据说话**：下结论必须带有毫秒级延迟、握手状态或丢包计数的证据链，禁止使用“大概”、“可能”。
- **完全零外部依赖**：纯 Windows 原生命令 + Python 3 标准库，无需 `npm install` 或 `pip install` 任何第三方包。
- **严格排除代理话题**：**严格排除** 任何代理 / VPN / Clash / 隧道相关话题，专注解决 Windows 直连网络层瓶颈。

---

## 📥 下载与获取

| 方式 | 命令 / 链接 |
|---|---|
| **HTTPS** | `git clone https://github.com/hyt315/network-slow-diagnosis.git` |
| **SSH** | `git clone git@github.com:hyt315/network-slow-diagnosis.git` |
| **GitHub CLI** | `gh repo clone hyt315/network-slow-diagnosis` |
| **ZIP 压缩包** | [下载 ZIP](https://github.com/hyt315/network-slow-diagnosis/archive/refs/heads/main.zip) |
| **Tar 归档** | [下载 Tar](https://github.com/hyt315/network-slow-diagnosis/archive/refs/heads/main.tar.gz) |
| **单文件 (SKILL.md)** | `curl -O https://raw.githubusercontent.com/hyt315/network-slow-diagnosis/main/SKILL.md` |

---

## 💡 核心排查哲学

- **自底向上**：物理链路 → 硬件节能 → DNS/DoH → 传输层双栈 → 应用响应 → 系统后台，逐层确凿证实或排除。
- **慢事件捕获**：使用 `curl -w` 与 `Measure-Command` 实测冷查询与首次握手耗时，抓取偶发卡顿瞬间。
- **区分断网与慢速**：若 IP 为 `169.254.x.x` 说明是 DHCP 故障断网，不作为变慢排查，快速重定向。
- **建议需获授权**：排查后给出明确根因和治理建议，但任何修改操作均需用户明确授权。

---

## 📁 文件结构

```
network-slow-diagnosis/
├── SKILL.md                          # 核心技能定义与分层工作流
├── README.md                         # 中文说明文档
├── README.en.md                      # 英文说明文档
├── CHANGELOG.md                      # 版本发布记录
├── LICENSE                           # MIT 开源许可证
├── .gitignore                        # Git 忽略规则
├── CONTRIBUTING.md                   # 社区贡献指南
├── CODE_OF_CONDUCT.md                # 行为准则
├── SECURITY.md                       # 安全策略
├── Makefile                          # 自动化测试指令
├── manifest.json                     # 技能元数据清单
├── agents/                           # 多 Agent 平台元数据
├── scripts/
│   ├── diagnose.ps1                  # 一键自动化只读网络诊断工具 (PowerShell)
│   └── selftest.py                   # 技能回归自测脚本 (Python)
├── tests/
│   └── test_skill.py                 # 规范性与断言测试套件
└── references/                       # 深度参考文档
    ├── diagnostic-playbook.md        # 分层诊断手册与判定标准
    ├── modern-network-pitfalls.md    # 现代 Windows 网络深水区排障指南
    └── dns-root-cause-case.md        # 真实 11 秒卡顿根因案例复盘
```

---

## 📚 实战速查案例

| 典型现象 | 根因分类 | 核心排查命令 | 官方治理方案 |
|---|---|---|---|
| 🛜 **每隔几分钟突发卡顿 3 秒** | Wi-Fi 7 / 双频合一漫游颠簸 | `netsh wlan show networks mode=bssid`<br>`Get-NetAdapterAdvancedProperty -Name "*"` | 路由器将 2.4G 与 5G/6G 分开命名；网卡漫游激进性调为 `1. Lowest` |
| 🔋 **静置一会儿后首次开网页必卡** | 网卡 Modern Standby D3 挂起 | `Get-NetAdapter -Physical \| Get-NetAdapterPowerManagement` | 设备管理器网卡属性电源管理中取消勾选“允许计算机关闭此设备以节约电源” |
| 🔒 **局域网极快，但开新网页白屏 2 秒** | Windows 11 原生 DoH 超时降级 | `Get-DnsClientDohServerAddress`<br>`netsh dns show encryption` | 换用国内高速 DoH（阿里/腾讯）或将 DNS 加密切换为“仅未加密” |
| 🌐 **即时通讯正常，部分网页转圈超时** | IPv6 假通 (Happy Eyeballs 21s 超时) | `netsh interface ipv6 show prefixpolicies`<br>`Test-NetConnection <IPv6> -Port 443` | 禁用故障 IPv6 或配置注册表 `DisabledComponents=0x20` 设置 IPv4 优先 |
| 🧩 **千兆网卡协商正常，实际跑不满且微丢包** | 第三方 NDIS 过滤驱动内核排队 | `Get-NetAdapterBinding \| Where-Object { $_.ComponentID -notmatch '^(ms_\|vms_)' }` | 在网卡属性中取消勾选已卸载残留或过期的第三方抓包/杀软过滤驱动组件 |
| ⚠️ **高并发下载或刷新突然全网卡死 10055** | 短连接泛滥与 TIME_WAIT 端口耗尽 | `(Get-NetTCPConnection -State TimeWait).Count`<br>`netsh int ipv4 show dynamicport tcp` | 关闭恶意刷短连接的后台进程；评估优化 `TcpTimedWaitDelay` 超时时间 |
| 📝 **唯独某个特定网站打不开或死等超时** | Hosts 文件静态映射至失效旧 IP | `Get-Content "$env:windir\System32\drivers\etc\hosts"` | 管理员身份编辑 Hosts 文件，删除或注释掉失效的静态 IP 条目 |
| 🚀 **全家网络暴卡，ping 网关飙到 1500ms** | 传递优化 DoSvc P2P 上行占满 / Bufferbloat | `Get-DeliveryOptimizationStatus -PeerInfo`<br>`Get-DeliveryOptimizationPerfSnap` | Windows 更新 -> 高级选项 -> 传递优化 -> 关闭“允许从其他电脑下载”；路由器开 SQM |
| 🐢 **千兆宽带下载被锁死几百 KB/s** | TCP 接收窗口自适应被意外关闭 | `Get-NetTCPSetting \| Select AutoTuningLevelEffective` | 执行 `netsh int tcp set global autotuninglevel=normal` 恢复默认 |

---

## ❓ 常见问题 (FAQ)

- **Q: 不需要管理员权限也能排查吗？**  
  A: 是的。所有诊断命令均为只读查询，绝大部分 `ping`、`curl`、`Resolve-DnsName`、`Get-Net*` 和 `netsh` 查询命令在普通用户权限下均可直接运行。
- **Q: 为什么排查排除了代理/VPN？**  
  A: 代理工具（如 TUN 虚拟网卡、系统代理转发）会改变原本的直连路由拓扑。本技能专注于诊断 Windows 本机网络层与直接链路瓶颈。
- **Q: 诊断过程中会中断我的网络连接吗？**  
  A: 绝对不会。本技能坚持 Zero-Mutation 原则，不执行网卡重启、DNS 修改或连接重置。

---

## 🤝 参与贡献

欢迎提交 Issue 与 Pull Request！详见 [CONTRIBUTING.md](CONTRIBUTING.md)。如果这个技能对你有帮助，欢迎在 GitHub 上点个 [Star ⭐](https://github.com/hyt315/network-slow-diagnosis/stargazers)！

---

## 📄 开源协议

本项目采用 [MIT 许可证](LICENSE) 开源。

详见 [CHANGELOG.md](CHANGELOG.md) 了解版本演进历史。

---

> 🌏 **English: [README.en.md](./README.en.md)**
