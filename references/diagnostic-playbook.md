# 分层诊断手册（Windows 上网慢 / 间歇性卡顿）

> 适用范围：本机网络层 + DNS。**不包含任何代理/VPN/Clash/系统代理/隧道内容**。所有命令均为只读，诊断阶段不修改任何设置（仅「冷查询对照实验」会用到 `Clear-DnsClientCache`，且须先告知用户）。

## 目录

- [第 0 层：界定范围](#第-0-层界定范围)
- [第 1 层：物理 / 链路层](#第-1-层物理--链路层)
- [第 2 层：DNS 解析层（最常见根因）](#第-2-层dns-解析层最常见根因)
- [第 3 层：传输层（TCP 建连 / IPv6 回退 / MTU）](#第-3-层传输层tcp-建连--ipv6-回退--mtu)
- [第 4 层：应用层 / TTFB](#第-4-层应用层--ttfb)
- [第 5 层：资源占用](#第-5-层资源占用)
- [权威文档（微软官方）](#权威文档微软官方)
- [开源 / 免费诊断工具（均不含代理类）](#开源--免费诊断工具均不含代理类)
- [常见根因表](#常见根因表)
- [经典误区（看起来像 A 其实是 B）](#经典误区看起来像-a-其实是-b)
- [落地的工程纪律](#落地的工程纪律)

## 第 0 层：界定范围

- 问清：所有网站都慢 vs 个别网站？一直慢 vs 有时慢？
- `Get-NetIPConfiguration`：确认已拿到 IP/网关/DNS。若 IPv4 地址是 `169.254.x.x`，说明 DHCP 失败——那是「没网」，不是「慢」，排查方向完全不同。

## 第 1 层：物理 / 链路层

判定：延迟/丢包是否发生在「你 → 网关」这一段。

- 网关延迟（核心）：`ping <网关IP> -n 4`，正常 <5ms；>30ms 或抖动大 → 内网/WiFi 问题。
- WiFi：`netsh wlan show interfaces`（Signal 强度、Rx/Tx rate）；`netsh wlan show all`（同信道 AP 拥塞）。
- 网卡：`Get-NetAdapter | Select Name, LinkSpeed, Status`。
- 链路丢包：`pathping <网关IP>` 观察 Link 列。
- 节能降速嫌疑：`Get-NetAdapterPowerManagement`（看是否开启节能）。
- 网卡错包/丢包：`Get-NetAdapterStatistics -Name <接口名>` 看 `ReceivedErrors`/`ReceivedDiscards`；`netstat -e` 看 RX/TX 错误。计数持续增长说明网线/端口/双工协商问题（间歇性卡顿的物理层元凶）。
- 后台占带宽：`resmon` 网络选项卡看 Top 进程吞吐；`Get-NetTCPConnection | Group-Object State` 看连接数是否异常。

## 第 2 层：DNS 解析层（最常见根因）

判定：是否卡在「把域名变成 IP」这一步。

- 当前 DNS 耗时：`Measure-Command { Resolve-DnsName 域名 -Server <当前DNS> }`，多次采样；出现 >1s 或超时即异常。
- 横向对比公共 DNS（确凿锁定）：`Resolve-DnsName 域名 -Server 223.5.5.5` / `119.29.29.29` / `8.8.8.8`。若公共 DNS 稳定而当前 DNS 抖 → 锁定 DNS 服务器/路由器转发器问题。
- **抓慢事件并定位环节（最强证据）**：
  `curl -4 --noproxy '*' -o /dev/null -s -w "nl=%{time_namelookup} ct=%{time_connect} st=%{time_starttransfer} tt=%{time_total}\n" https://域名`
  若 `nl`（DNS）接近 `tt` 且很大 → 100% 卡在 DNS。
- 冷缓存对照：`Clear-DnsClientCache` 后首次解析明显慢于命中缓存 → 典型冷查询。
- 当前 DNS 配置：`Get-DnsClientServerAddress -AddressFamily IPv4`；静态还是 DHCP（`netsh interface ip show dns "WLAN"`）。
- AAAA（IPv6）解析耗时对照：`Measure-Command { Resolve-DnsName 域名 -Type AAAA }` 相比 `-Type A` 明显更慢/超时 → 运营商 IPv6 路径异常（Happy Eyeballs 回退拖慢首包）。
- **浏览器自带 DoH 会绕过系统 DNS**：Chrome/Edge 的「安全 DNS（DoH）」直接用浏览器内置解析器，改系统 DNS 对浏览器无效。`Get-DnsClientDohServerAddress` 看系统层 DoH；浏览器 `edge://settings/security` / `chrome://settings/security` 看是否开启安全 DNS（只读确认）。若浏览器开了安全 DNS，第 2 层「换系统 DNS」对浏览器无效，应改在浏览器或路由器层处理。

## 第 3 层：传输层（TCP 建连 / IPv6 回退 / MTU）

判定：IP 通了但「建连/首包」慢。

- TCP 建连：`curl -4 -o /dev/null -s -w "ct=%{time_connect} st=%{time_starttransfer}\n" https://域名`；或 `Test-NetConnection 域名 -Port 443`。
- IPv6 回退（首包延迟元凶）：`curl -4` 与 `curl -6` 对比；`-6` 卡死/慢而 `-4` 秒回 → IPv6 回退。`Get-NetIPInterface` 看 IPv6 接口；`netsh interface ipv4 show prefixpolicies` 看前缀策略。参考 RFC 6555 / RFC 8305。
- MTU/分片：`ping -f -l 1472 目标` 失败、`-l 1400` 成功 → 分片异常；先 `netsh interface ipv4 show subinterfaces` 看当前 MTU。
- 路径级抖动/丢包：`pathping 目标`、`tracert 目标`、WinMTR（见工具）。
- **TLS 握手耗时**（HTTPS 最易漏）：`curl -4 -o /dev/null -s -w "ct=%{time_connect} ac=%{time_appconnect} st=%{time_starttransfer} tt=%{time_total}\n" https://域名`，`ac - ct` 即纯 TLS 握手时长（证书链校验 + 密钥协商）。`curl -4 -v` 可看 TLS 版本/证书：`Select-String -Pattern "SSL connection|subject:|expire|issuer:|TLSv1"`；强制 `curl --tlsv1.3` / `--tlsv1.2` 对比可判定版本回退。
- TCP 栈全局参数（隐藏的慢根因）：`netsh int tcp show global`；`Get-NetTCPSetting | Select SettingName, AutoTuningLevelLocal, AutoTuningLevelEffective, CongestionProvider, ECN`。`AutoTuningLevelEffective=disabled`、拥塞控制被改非默认、ECN 异常 → 高延迟链路吞吐受限。
- 默认路由/多网卡错走：`Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Select NextHop, InterfaceIndex, RouteMetric`；`Get-NetIPInterface | Select InterfaceAlias, AddressFamily, InterfaceMetric, ConnectionState | Sort-Object InterfaceMetric`。有线+无线同连时度量小的接口优先，可能「插着网线却走 WiFi」。

## 第 4 层：应用层 / TTFB

判定：本地 DNS/TCP 都健康，但「应用响应」慢。

- TTFB：`curl -o /dev/null -s -w "ttfb=%{time_starttransfer} tt=%{time_total}\n" https://域名`。
- 浏览器逐请求：F12 → Network → 某请求 Timing（Stalled / DNS / Initial connection / TTFB）；`chrome://net-internals/#dns` 看解析耗时，`chrome://net-internals/#quic` 看 QUIC 握手/0-RTT。
- HTTP/3（QUIC）：现代站点走 UDP/443 的 QUIC，`curl` 只测 TCP 看不到 QUIC 握手。各段都正常却首包慢 → 用浏览器 `chrome://net-internals/#quic` 看 QUIC；UDP/443 被限速会让 QUIC 反复回退到 HTTP/2。
- 仅此层偏高 + 本地健康 → 指向远端服务器/内容，非本机网络。

## 第 5 层：资源占用

- `resmon` 网络选项卡看实时吞吐 Top 进程；TCPView 看哪个进程持续收发。某进程在卡顿时段占满链路 → 根因是后台占用，不是网络质量。
- Windows 11 系统性占用（非网络故障却让网页变慢）：`Get-Service DoSvc` 看「传递优化」是否后台 P2P 占带宽；`Get-NetConnectionProfile` 看是否计量网络（限制后台）；`Get-NetAdapter | Get-NetAdapterDriverInfo` 看网卡驱动是否被更新/回退导致吞吐骤降；「核心隔离/HVCI」开启可能拖累旧网卡驱动。

## 权威文档（微软官方）

- Test-NetConnection: https://learn.microsoft.com/en-us/powershell/module/nettcpip/test-netconnection
- Get-NetIPConfiguration: https://learn.microsoft.com/en-us/powershell/module/nettcpip/get-netipconfiguration
- Get-NetAdapter: https://learn.microsoft.com/en-us/powershell/module/netadapter/get-netadapter
- Get-NetTCPConnection: https://learn.microsoft.com/en-us/powershell/module/nettcpip/get-nettcpconnection
- Resolve-DnsName: https://learn.microsoft.com/en-us/powershell/module/dnsclient/resolve-dnsname
- Get-DnsClientServerAddress: https://learn.microsoft.com/en-us/powershell/module/dnsclient/
- netsh: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/netsh
- ping/tracert/pathping/netstat: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/ping 等
- TCPView / PsPing (Sysinternals): https://learn.microsoft.com/en-us/sysinternals/downloads/tcpview

## 开源 / 免费诊断工具（均不含代理类）

- WinMTR（Windows 持续路由追踪 + 逐跳丢包/延迟，适合间歇性卡顿长期采样）: https://sourceforge.net/projects/winmtr/
- mtr（Linux/macOS 同源）: https://github.com/traviscross/mtr
- dnsdiag（dnsping/dnsperf/dnseval/dnsfuzz，DNS 测速与对比）: https://dnsdiag.org/
- namebench（Google 出品，对比各 DNS 对你网络的真实速度）: https://github.com/google/namebench
- GRC DNS Benchmark（图形化对 DNS 做速度/可靠性排名）: https://www.grc.com/dns/benchmark.htm
- speedtest-cli（命令行测带宽，排除真·带宽不足）: https://github.com/sivel/speedtest-cli
- Wireshark（抓包做最细粒度分析）: https://www.wireshark.org/
- 内置即用：ping、tracert、pathping、netstat、resmon、任务管理器性能页。
- pktmon（Win10 2004+ 内置抓包/丢包统计，只读确认本机收发与丢包，零安装）: https://learn.microsoft.com/en-us/windows-server/networking/technologies/pktmon/pktmon
- psping（Sysinternals，ICMP/TCP 延迟与不分片大包探测，比 ping 更强）: https://learn.microsoft.com/en-us/sysinternals/downloads/psping
- Test-Connection -Traceroute（PowerShell 7+ 内置 traceroute，轻量替代 pathping）: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/test-connection
- netsh trace / WPR（系统级网络跟踪与性能记录，深层排障）: https://learn.microsoft.com/en-us/windows-server/networking/technologies/netsh/netsh-trace

## 常见根因表

| # | 根因 | 像一直慢/有时慢 | 确凿测量 |
|---|---|---|---|
| 1 | DNS 解析慢/抽风 | 皆可，常「有时」 | 多次 Resolve-DnsName 到当前 DNS 出现 >1s/超时；换公共 DNS 后稳定 |
| 2 | DNS 缓存冷查询 | 「首次/有时」 | Clear-DnsClientCache 后首次明显慢于命中 |
| 3 | IPv6 回退首包延迟 | 「首开慢、之后正常」 | curl -4 比默认双栈快；解析落到 IPv6 |
| 4 | 路由器 DNS 转发器不稳定 | 「有时」，仅本 WiFi/家庭网 | 直连公共 DNS 稳定，用路由器分配 DNS 时抖 |
| 5 | 网关/ISP 抖动 | 典型「有时」 | 长 ping 网关 / WinMTR 到目标出现周期尖峰或丢包 |
| 6 | 后台进程占带宽 | 「有时」（后台触发时） | resmon 显示某进程占满链路 |
| 7 | 网卡驱动/节能降速 | 一直慢/间歇掉速 | LinkSpeed 远低于签约；关节能后复测提升 |
| 8 | WiFi 信号弱/拥塞 | 「有时」（移动/干扰） | Signal 低、协商速率低、同信道 AP 多 |
| 9 | MTU/分片 | 传大内容时慢 | ping -f -l 1472 失败、1400 成功 |
| 10 | 远端服务器/内容慢 | 个别网站 | 本地 DNS/TCP 健康但 TTFB 仍高；换设备同样慢 |
| 11 | TLS 握手慢 | 首字节慢、但 TCP 已通 | `curl -w` 中 `time_appconnect - time_connect` 很大；证书链长/OCSP 超时/版本回退 |
| 12 | 网卡错包/丢包 | 「有时」（时好时坏） | `Get-NetAdapterStatistics` 的 ReceivedErrors/Discards 持续增长；`netstat -e` RX/TX 错误 |
| 13 | TCP 全局参数异常（Auto-Tuning/ECN/拥塞） | 大文件/多资源整体慢 | `AutoTuningLevelEffective=disabled`、拥塞控制非默认、ECN 异常 |
| 14 | 多网卡默认路由错走 | 连着网线却走 WiFi | `Get-NetRoute 0.0.0.0/0` 指向更慢接口；InterfaceMetric 错排 |
| 15 | 浏览器 DoH 绕过系统 DNS | 改系统 DNS 无效 | 浏览器安全 DNS 开启；系统 DNS 改了但浏览器照旧慢 |
| 16 | Windows 11 后台占用（DoSvc/HVCI/驱动回退） | 非故障型变慢 | DoSvc 占带宽、驱动被回退、HVCI 拖累旧网卡 |

## 经典误区（看起来像 A 其实是 B）

- 把「DNS 慢」误判为「带宽慢」：实测下载满速、只是开网页卡 → 用 DNS 耗时测量区分。
- 把「IPv6 回退首包延迟」误判为「网站/服务器慢」：仅首次连接慢 → 本地协议栈回退，非对方服务器差。
- 把「后台占带宽」误判为「浏览器/网页问题」：关网页没用，瓶颈是别的进程在吃带宽（resmon 一眼识破）。
- 把「网卡节能降速」误判为「宽带缩水」：签约 1000M 实则跑 100M → 驱动/电源策略，非运营商。
- 把「WiFi 信号弱」误判为「运营商问题」：ping 网关就抖，根本没出户；换有线即正常。
- 把「间歇性 DNS 抖动」误判为「ISP 整体抽风」：只有解析环节抽风，换 DNS 即解决，而非投诉运营商。
- 把「TLS 握手慢」误判为「服务器慢/传输层慢」：`time_appconnect - time_connect` 很大时，瓶颈在证书链校验/密钥协商，与对方业务服务器无关，换 CDN/换站无效。
- 把「网卡错包重传」误判为「运营商抽风」：`netstat -e` / `Get-NetAdapterStatistics` 的错包持续增长，换网络供应商也救不了，是网线/端口/双工问题。
- 把「多网卡错走接口」误判为「WiFi 差」：插着网线却因 InterfaceMetric 默认路由指向 WiFi，表现为无线卡顿，实为路由优先级问题。

## 落地的工程纪律

1. 只读优先：诊断只用只读命令；`Clear-DnsClientCache` 等写操作只在「冷查询对照实验」里、明确告知用户后使用。
2. 分层给结论：每层输出「是/否」，不跳跃猜测。
3. 对照实验思维：换 DNS 服务器、强制 IPv4(`-4`)、关节能、换有线——哪一步让「有时慢」消失，哪一层就是根因。
