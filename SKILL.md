---
name: network-slow-diagnosis
description: Diagnose why web pages load slowly or intermittently on Windows (WiFi/Ethernet). Use when a user reports web pages opening slowly, intermittent lag, stalls, or "the network feels slow" without obvious cause. Features dual-mode layered read-only diagnosis (automated scripts/diagnose.ps1 or manual): physical link (WiFi signal/co-channel contention, NDIS 3rd-party filters, gateway latency), NIC power management (Modern Standby D3 throttling), DNS & DoH (suffix search list, forwarder jitter, cold cache), IPv4/IPv6 fallback (Happy Eyeballs timeout, PMTU black hole), TCP connect/TLS timing, TIME_WAIT socket backlog, zombie proxy residuals, hosts static overrides, and background hogs (DoSvc P2P upstream, Bufferbloat). Exclude all proxy/VPN/Clash configuration or tunnel topics — if the user asks to configure proxies or tunnels, do not handle it here; redirect the user elsewhere.
metadata:
  author: hyt315
---

# Windows 网络变慢排查

专治「网页有时很慢 / 间歇性卡顿 / 网络感觉慢」这类本机网络层问题。**适用范围：Windows 本机网络层与 DNS 导致的网页加载慢（直连路径）。**

## Principles

- **只读优先**：诊断阶段只用 `ping` / `Test-NetConnection` / `Resolve-DnsName` / `Get-Net*` / `curl.exe -w` / `resmon` / `pathping` 等只读手段，下结论前不动任何设置。
- **用证据说话**：每一层都要给出「确凿证实 / 确凿排除」的只读测量结果，禁止用「可能」「大概」。
- **分层从底向上**：物理链路与节能 → DNS 与 DoH → 传输层与双栈 → 应用层与代理残余 → 资源占用与后台，逐层证明或排除。
- **纯原生零依赖**：所有辅助脚本基于 Windows 原生 PowerShell 与 Python 标准库，100% 零第三方依赖、纯只读无害。

## When To Use This Skill

- 用户说「网页打开很慢 / 有时卡很久才出来 / 网络感觉慢」。
- 打开某个或某类网站间歇性转圈、首屏慢。
- 想排查是不是 Wi-Fi 7/双频合一漫游颠簸与同频拥塞、NDIS 第三方过滤驱动丢包、网卡休眠节能、DNS 搜索后缀与 DoH 超时、IPv6 假通回退、TIME_WAIT 端口耗尽、死挂系统代理残余、Hosts 静态篡改、后台上行占满与 Bufferbloat 导致变慢。

## Workflow

### 执行模式（两选一）

- **模式 A：一键自动化只读扫描（推荐，首选）**
  直接执行内置的原生无损诊断工具，5~10 秒内全自动完成 L0~L5 全层测绘与事实判定：
  ```powershell
  # 终端彩色表格输出
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/diagnose.ps1 -Domain <目标域名>
  # 或机读 JSON 输出（供 Agent 一次性反序列化）
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/diagnose.ps1 -Domain <目标域名> -Json
  ```
- **模式 B：分步手动排查（后备 / 针对性复测）**
  当环境受限或需要对特定层做深钻取证时，按如下 1~5 步骤逐层排查。

---

### 1. 界定范围（只读）

- 问清/确认：是所有网站都慢，还是个别网站？是一直慢，还是有时慢？
- `Get-NetIPConfiguration` 确认已拿到 IP、网关、DNS。若 IPv4 是 `169.254.x.x`，说明 DHCP 失败——那是「没网」不是「慢」，方向完全不同。

### 2. 物理 / 链路 / 硬件节能层（只读）

- 网关延迟：`ping <网关IP> -n 4`，正常 <5ms；>30ms 或抖动大说明内网/WiFi 问题。
- WiFi 物理状态与同频信道拥塞：`netsh wlan show interfaces` 看 Radio type、Band、Signal 与 Rx/Tx rate；`netsh wlan show networks mode=bssid` 审计同频邻近 AP 数量（>3 个高信号同频 AP 会因 CSMA/CA 空口争用引发跳 ping）。
- 网卡节能休眠（首开卡顿元凶）：`Get-NetAdapter -Physical | Get-NetAdapterPowerManagement` 查看 `AllowComputerToTurnOffDevice` 是否开启；`Get-NetAdapterAdvancedProperty` 审计 `Energy Efficient Ethernet` (EEE) 与漫游主动性 `Roaming Aggressiveness`。
- 第三方 NDIS 过滤驱动审计：`Get-NetAdapterBinding | Where-Object { $_.ComponentID -notmatch '^(ms_|vms_)' -and $_.Enabled -eq $true }`（检查是否有旧版抓包驱动、老旧杀软或虚拟机桥接组件在内核层引起排队迟滞或静默丢包）。
- 网卡速率与状态：`Get-NetAdapter | Select-Object Name, LinkSpeed, Status`。
- 网卡错包/丢包：`netstat -e` 查看累计 Errors 与 Discards；`Get-NetAdapterStatistics -Name <接口名>` 看实时统计。计数持续增长说明网线/端口/双工协商有问题。
- 后台占带宽：`Get-NetTCPConnection | Group-Object State` 看连接数；`resmon` 网络选项卡看 Top 进程吞吐。

### 3. DNS 与 DoH 加密层（最关键，只读）

- 测当前 DNS 解析耗时：`Measure-Command { Resolve-DnsName 域名 -Server <当前DNS> }`，多次采样看是否出现 >1s 或超时。
- 横向对比公共 DNS：`Resolve-DnsName 域名 -Server 223.5.5.5` / `119.29.29.29` / `8.8.8.8`，看是否稳定快很多 → 锁定是本地 DNS 服务器/路由器转发器问题。
- **抓「慢事件」并定位环节**（最强证据，Windows 下强制 `curl.exe -o NUL`）：
  `curl.exe -4 --noproxy '*' -o NUL -s -w "nl=%{time_namelookup} ct=%{time_connect} st=%{time_starttransfer} tt=%{time_total}\n" https://域名`
  若 `nl`（DNS）接近 `tt` 且很大 → 100% 卡在 DNS。
- 冷缓存对照：`Clear-DnsClientCache` 后首次解析明显慢于命中缓存 → 典型冷查询现象。
- DNS 全局搜索后缀与 NRPT 审计：`Get-DnsClientGlobalSetting | Select-Object SuffixSearchList, UseDevolution`；`Get-DnsClientNrptRule`（多余的失效内网后缀会导致单次解析级联超时，延迟放大数倍）。
- AAAA（IPv6）解析耗时对照：`Measure-Command { Resolve-DnsName 域名 -Type AAAA }` 相比 `-Type A` 明显更慢/超时 → 运营商 IPv6 路径异常。
- **Windows 11 系统级 DoH 与浏览器安全 DNS**：
  - 系统层：`Get-DnsClientDohServerAddress` 与 `netsh dns show encryption` 审计是否启用了不可达的 DoH 模板（导致 TLS 超时后才慢速回退 UDP 53）；
  - 浏览器层：Chrome/Edge 的「安全 DNS（DoH）」直接用浏览器内置解析器，`edge://settings/security` / `chrome://settings/security` 若开启会绕过系统 DNS。

### 4. 传输层与 IPv6 双栈（只读）

- **TLS 握手耗时**（HTTPS 最易漏的环节）：
  `curl.exe -4 --noproxy '*' -o NUL -s -w "ct=%{time_connect} ac=%{time_appconnect} st=%{time_starttransfer} tt=%{time_total}\n" https://域名`
  `ac - ct` 即纯 TLS 握手时长（证书链校验 + 密钥协商）；若它很大 → 卡在 TLS，而非 TCP 或服务器。
- TCP 建连：`curl.exe -4 --noproxy '*' -o NUL -s -w "ct=%{time_connect} st=%{time_starttransfer}\n" https://域名`；或 `Test-NetConnection 域名 -Port 443`。
- 临时端口耗尽与 TIME_WAIT 积压：`netsh int ipv4 show dynamicport tcp` 查看动态端口配额；`(Get-NetTCPConnection -State TimeWait).Count` 检查积压套接字数量（积压过高会导致新建连接报 10055 异常）。
- Bufferbloat 满载对比：并发大流量时 `ping 223.5.5.5 -n 10`，若 RTT 较空闲时膨胀数倍甚至数十倍，说明排队缓冲区过深。
- IPv6 假通与双栈超时（Happy Eyeballs 21s 超时元凶）：
  - `netsh interface ipv6 show prefixpolicies`（查看是否 IPv6 优先）；
  - `netsh interface ipv6 show subinterfaces`（检查 IPv6 MTU / PPPoE 1492 黑洞）；
  - 双栈分别测速：`Test-NetConnection -ComputerName <IPv4_IP> -Port 443` 与 `Test-NetConnection -ComputerName <IPv6_IP> -Port 443`。若 IPv4 秒通而 IPv6 卡死 → IPv6 假通阻塞。
- MTU/分片：`ping -f -l 1472 目标` 失败、`-l 1400` 成功 → 分片异常。
- TCP 栈全局参数：`netsh int tcp show global` + `Get-NetTCPSetting | Select-Object AutoTuningLevelEffective, CongestionProvider, ECN`。
- 双栈与 MTU 深入核验：👉 动作：读取 `references/network-slow-diagnosis-pitfalls.md#三-底层协议-rfc-与权威参数基线`，核对 RFC 8305 Happy Eyeballs 超时、Path MTU 分片与 TCP 接收窗口参数。
- 默认路由/多网卡错走与虚拟网卡冲突：
  `Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Sort-Object RouteMetric` 与 `Get-NetIPInterface | Select-Object InterfaceAlias, InterfaceMetric`；若默认路由指向虚拟网卡（VMware/WSL/TAP）或插着网线却优先走 WiFi，会导致速度骤降。

### 5. 应用层 / 隐蔽系统后台与死挂代理残余（只读）

- TTFB：`curl.exe -o NUL -s -w "ttfb=%{time_starttransfer} tt=%{time_total}\n" https://域名`；本地 DNS/TCP 都健康但 TTFB 仍高 → 指向远端服务器/内容。
- HTTP/3（QUIC）：现代站点走 UDP/443 的 QUIC，用浏览器 `chrome://net-internals/#quic` 看 QUIC 握手与回退。
- **死挂系统代理残余检测（非代理设置指导，仅排查历史残留死端口）**：
  `Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" | Select-Object ProxyEnable, ProxyServer`
  若 `ProxyEnable = 1` 且目标端口无法建连，说明历史软件退出未清理注册表，导致所有直连流量持续等待死端口超时。提示用户在系统设置中关闭。
- **Hosts 文件静态条目审计**：
  `Get-Content -Path "$env:windir\System32\drivers\etc\hosts" -ErrorAction SilentlyContinue | Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*#' }`
  检查是否硬编码了失效、下线或异地的旧 IP 导致特定站点卡死。
- Windows 11 传递优化（DoSvc）与后台上行占用：
  - `Get-DeliveryOptimizationStatus -PeerInfo` 与 `Get-DeliveryOptimizationPerfSnap`（检测后台 P2P 上行是否吃满宽带）；
  - `Get-NetTCPConnection -State Established | Group-Object OwningProcess` 找出建立大量活跃连接的后台进程；
  - `Get-NetConnectionProfile` 看是否为计量网络。

### 6. 标准交付成果：Windows 网络分层诊断事实卡

排查完毕后，Agent 必须以标准 Markdown 表格卡片向用户汇总证据，并明确区分「确凿根因」与「可选优化」：

```markdown
### 📊 Windows 网络分层诊断事实卡
| 层级 | 检查项 | 测量实值 | 正常基线 | 判定结果 |
|---|---|---|---|:---:|
| L0 范围界定 | 本机 IP / 网关 | 192.168.1.2 (以太网) | 非 169.254.x.x | 🟢 正常 |
| L1 物理链路 | 网关延迟 / WiFi 信号 | 1.8ms / 95% (2.4GHz) | < 5ms / > 65% | 🟢 正常 |
| L1 物理链路 | NDIS 过滤驱动 | Clean (MS Native) | Clean | 🟢 正常 |
| L2 DNS 解析 | 当前 DNS vs 公共 DNS | 1250ms vs 15ms | < 50ms | 🔴 严重异常 (根因) |
| L2 DNS 解析 | DNS 搜索后缀列表 | None | 0-1 Suffix | 🟢 正常 |
| L3 传输层 | TCP 443 / TLS 握手 | 18ms / 25ms | < 100ms | 🟢 正常 |
| L3 传输层 | TIME_WAIT 积压 | 45 sockets | < 500 sockets | 🟢 正常 |
| L4 应用与代理 | 死挂系统代理残余 | Clean (Disabled) | Disabled | 🟢 正常 |
| L4 应用与代理 | Hosts 静态映射 | Clean (Default) | Clean | 🟢 正常 |
| L5 后台占用 | 传递优化 P2P 上行 | 0 MB (Idle) | < 100MB | 🟢 正常 |

【确凿定位根因】...
【针对性治理建议（须用户明确同意后手动执行）】...
```

强调：**任何改动设置都需要用户明确同意，且常需管理员权限；本技能只诊断，不擅自修改。**

## Reference Map

- 需要按层执行完整诊断流程、查 24 类常见根因与判定标准或工具清单时，先读 [分层诊断手册](references/diagnostic-playbook.md)：每层精确命令、确凿判定标准、权威文档与开源工具清单、经典误区与安全恢复指南。
- 需要深入排查 Wi-Fi 7、网卡节能休眠、DoH 降级超时、IPv6 假通、NDIS 过滤驱动丢包、TIME_WAIT 端口耗尽、死挂代理残余、Bufferbloat 等现代深水区问题时，先读 [现代 Windows 网络深水区避坑与官方排障指南](references/modern-network-pitfalls.md)：14 大现代网络陷阱技术根因、只读审计命令与针对性治理对策。
- 需要对标 GitHub 同类排查技能、开源工具经验、RFC 协议标准（如 Happy Eyeballs / MTU 黑洞）与生产级踩坑时，先读 [深水区多源对标与避坑指南](references/network-slow-diagnosis-pitfalls.md)：涵盖分层路由最佳实践、TCP 探针禁 Ping 回退与深水故障排查。
- 需要用真实案例对照方法论、或向用户证明"证据说话"时，先读 [DNS 根因实战案例](references/dns-root-cause-case.md)：一次真实「间歇性 11 秒卡顿」的完整排查与修复记录（含前后证据）。
