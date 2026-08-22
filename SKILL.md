---
name: network-slow-diagnosis
description: Diagnose why web pages load slowly or intermittently on Windows (WiFi/Ethernet). Use when a user reports web pages opening slowly, intermittent lag, stalls while a site loads, or "the network feels slow" without an obvious cause. Covers layered read-only diagnosis — physical/link (WiFi signal, gateway latency), DNS resolution speed and flakiness (router DNS forwarder, cold-cache misses), IPv4 vs IPv6 fallback, TCP connect/TTFB, and background bandwidth hogs. Exclude all proxy/VPN/Clash/system-proxy/tunnel topics — if the complaint is about proxy settings, 翻墙, or routing through a proxy, do not handle it here; redirect the user elsewhere.
metadata:
  author: hyt315
---

# Windows 网络变慢排查

专治「网页有时很慢 / 间歇性卡顿 / 网络感觉慢」这类本机网络层问题。**适用范围：Windows 本机网络层与 DNS 导致的网页加载慢（直连路径）。**

## Principles

- **只读优先**：诊断阶段只用 `ping` / `Test-NetConnection` / `Resolve-DnsName` / `Get-Net*` / `curl -w` / `resmon` / `pathping` 等只读手段，下结论前不动任何设置。
- **用证据说话**：每一层都要给出「确凿证实 / 确凿排除」的只读测量结果，禁止用「可能」「大概」。
- **分层从底向上**：物理链路 → DNS → 传输层 → 应用层 → 资源占用，逐层证明或排除。

## When To Use This Skill

- 用户说「网页打开很慢 / 有时卡很久才出来 / 网络感觉慢」。
- 打开某个或某类网站间歇性转圈、首屏慢。
- 想排查是不是 DNS、WiFi、网关、IPv6 回退、后台占用导致变慢。

## Workflow

### 1. 界定范围（只读）

- 问清/确认：是所有网站都慢，还是个别网站？是一直慢，还是有时慢？
- `Get-NetIPConfiguration` 确认已拿到 IP、网关、DNS。若 IPv4 是 `169.254.x.x`，说明 DHCP 失败——那是「没网」不是「慢」，方向完全不同。

### 2. 物理 / 链路层（只读）

- 网关延迟：`ping <网关IP> -n 4`，正常 <5ms；>30ms 或抖动大说明内网/WiFi 问题。
- WiFi：`netsh wlan show interfaces` 看 Signal、Rx/Tx rate。
- 网卡速率：`Get-NetAdapter | Select Name, LinkSpeed, Status`。
- 网卡错包/丢包：`Get-NetAdapterStatistics -Name <接口名>` 看 `ReceivedErrors`/`ReceivedDiscards`；`netstat -e` 看 RX/TX 错误。计数持续增长说明网线/端口/双工协商有问题（间歇性卡顿的常见物理层元凶）。
- 后台占带宽：`Get-NetTCPConnection | Group-Object State` 看连接数；`resmon` 网络选项卡看 Top 进程吞吐。

### 3. DNS 层（最关键，只读）

- 测当前 DNS 解析耗时：`Measure-Command { Resolve-DnsName 域名 -Server <当前DNS> }`，多次采样看是否出现 >1s 或超时。
- 横向对比公共 DNS：`Resolve-DnsName 域名 -Server 223.5.5.5` / `119.29.29.29` / `8.8.8.8`，看是否稳定快很多 → 锁定是 DNS 服务器/路由器转发器问题。
- **抓「慢事件」并定位环节**（最强证据）：
  `curl -4 --noproxy '*' -o /dev/null -s -w "nl=%{time_namelookup} ct=%{time_connect} st=%{time_starttransfer} tt=%{time_total}\n" https://域名`
  若 `nl`（DNS）接近 `tt` 且很大 → 100% 卡在 DNS。
- 冷缓存对照：`Clear-DnsClientCache` 后首次解析明显慢于命中缓存 → 典型冷查询现象。
- AAAA（IPv6）解析耗时对照：`Measure-Command { Resolve-DnsName 域名 -Type AAAA }` 相比 `-Type A` 明显更慢/超时 → 运营商 IPv6 路径异常（Happy Eyeballs 回退会拖慢首包）。
- **浏览器自带 DoH 会绕过系统 DNS**：Chrome/Edge 的「安全 DNS（DoH）」直接用浏览器内置解析器，改系统 DNS 对浏览器无效。排查前先查 `Get-DnsClientDohServerAddress`，以及浏览器 `edge://settings/security` / `chrome://settings/security` 是否开启安全 DNS（只读确认）。

### 4. 传输层（只读）

- **TLS 握手耗时**（HTTPS 最易漏的环节）：`curl -4 -o /dev/null -s -w "ct=%{time_connect} ac=%{time_appconnect} st=%{time_starttransfer} tt=%{time_total}\n" https://域名`。`ac - ct` 即纯 TLS 握手时长（证书链校验 + 密钥协商）；若它很大 → 卡在 TLS，而非 TCP 或服务器。
- TCP 建连：`curl -4 -o /dev/null -s -w "ct=%{time_connect} st=%{time_starttransfer}\n" https://域名`；或 `Test-NetConnection 域名 -Port 443`。
- IPv4 vs IPv6 回退：`curl -4` 与 `curl -6` 对比；若 `-6` 卡死/-6 慢而 `-4` 秒回 → IPv6 回退导致首包延迟。
- MTU/分片：`ping -f -l 1472 目标` 失败、`-l 1400` 成功 → 分片异常。
- TCP 栈全局参数：`netsh int tcp show global` + `Get-NetTCPSetting | Select AutoTuningLevelEffective, CongestionProvider, ECN`。`AutoTuningLevelEffective=disabled`、拥塞控制被改非默认、ECN 异常 → 高延迟链路吞吐受限（隐藏的慢根因）。
- 默认路由/多网卡错走：`Get-NetRoute -DestinationPrefix "0.0.0.0/0"` 与 `Get-NetIPInterface | Select InterfaceAlias, InterfaceMetric`；有线+无线同连时，度量小的接口优先，可能「插着网线却走 WiFi」而变慢。

### 5. 应用层 / 资源（只读）

- TTFB：`curl -o /dev/null -s -w "ttfb=%{time_starttransfer} tt=%{time_total}\n" https://域名`；本地 DNS/TCP 都健康但 TTFB 仍高 → 指向远端服务器/内容。
- HTTP/3（QUIC）：现代站点走 UDP/443 的 QUIC，`curl` 只测 TCP 看不到 QUIC 握手。各段都正常却首包慢时，用浏览器 `chrome://net-internals/#quic` 看 QUIC 握手/0-RTT；UDP/443 被限速也会让 QUIC 反复回退到 HTTP/2。
- 浏览器逐请求：F12 → Network → 某请求 Timing（Stalled / DNS / Initial connection / TTFB）。
- 后台占用：`resmon` 网络选项卡看实时吞吐 Top 进程；TCPView 看哪个进程持续收发。
- Windows 11 系统性占用：`Get-Service DoSvc`（传递优化后台 P2P 占带宽）；`Get-NetConnectionProfile` 看是否计量网络；`Get-NetAdapter | Get-NetAdapterDriverInfo` 看网卡驱动是否被更新/回退导致吞吐骤降；「核心隔离/HVCI」开启可能拖累旧网卡驱动。这些不是网络故障，却会让网页变慢。

### 6. 下结论与建议（需用户同意才动手）

- 用一句话给出「已查实」的根因（如：WLAN 的 DNS 是路由器 192.168.1.1，冷查询/抽风时解析要 11 秒）。
- 给出修复建议（如：把网卡 DNS 改为 `223.5.5.5` / `119.29.29.29`），但强调：**任何改动设置都需要用户明确同意，且常需管理员权限；本技能只诊断，不擅自修改。**

## Reference Map

- 需要按层执行诊断、查判定标准或工具清单时，读 [分层诊断手册](references/diagnostic-playbook.md)：每层精确命令、确凿判定标准、权威文档与开源工具清单、常见误区。
- 需要用真实案例对照方法论、或向用户证明"证据说话"时，读 [DNS 根因实战案例](references/dns-root-cause-case.md)：一次真实「间歇性 11 秒卡顿」的完整排查与修复记录（含前后证据）。
