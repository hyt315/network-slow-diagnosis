# 分层诊断手册（Windows 上网慢 / 间歇性卡顿）

> 适用范围：本机网络层 + DNS。**不包含任何代理/VPN/Clash/系统代理/隧道配置内容**。所有命令均为只读，诊断阶段不修改任何设置（仅「冷查询对照实验」会用到 `Clear-DnsClientCache`，且须先告知用户）。

## 目录

- [一键自动化只读诊断工具（推荐）](#一键自动化只读诊断工具推荐)
- [第 0 层：界定范围](#第-0-层界定范围)
- [第 1 层：物理 / 链路层](#第-1-层物理--链路层)
- [第 2 层：DNS 解析层（最常见根因）](#第-2-层dns-解析层最常见根因)
- [第 3 层：传输层（TCP 建连 / IPv6 回退 / MTU）](#第-3-层传输层tcp-建连--ipv6-回退--mtu)
- [第 4 层：应用层 / TTFB / 死挂代理残余](#第-4-层应用层--ttfb--死挂代理残余)
- [第 5 层：资源占用](#第-5-层资源占用)
- [权威文档（微软官方）](#权威文档微软官方)
- [开源 / 免费诊断工具（均不含代理类）](#开源--免费诊断工具均不含代理类)
- [常见根因表](#常见根因表)
- [经典误区（看起来像 A 其实是 B）](#经典误区看起来像-a-其实是-b)
- [安全恢复与最小治理指南（须用户明确授权）](#安全恢复与最小治理指南须用户明确授权)
- [落地的工程纪律](#落地的工程纪律)

---

## 一键自动化只读诊断工具（推荐）

为了避免在终端中手动敲入 20+ 个命令导致效率低下与语法错误，本技能提供了纯原生、零依赖的一键自动化只读诊断工具：

```powershell
# 1. 默认快速诊断（目标域名 www.qq.com）
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/diagnose.ps1

# 2. 指定排查域名并执行快速采样
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/diagnose.ps1 -Domain www.baidu.com -Quick

# 3. 输出机读 JSON 结构（供 Agent 程序化解析与多轮比对）
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/diagnose.ps1 -Domain www.qq.com -Json
```

该工具在 5~10 秒内自动采集 L0~L5 数据，生成带正常基线比对与状态标签（🟢 OK / 🟡 WARN / 🔴 CRITICAL）的完整事实报告卡。

---

## 第 0 层：界定范围

- 问清：所有网站都慢 vs 个别网站？一直慢 vs 有时慢？
- `Get-NetIPConfiguration`：确认已拿到 IP/网关/DNS。若 IPv4 地址是 `169.254.x.x`，说明 DHCP 失败——那是「没网」，不是「慢」，排查方向完全不同。

## 第 1 层：物理 / 链路层

判定：延迟/丢包是否发生在「你 → 网关」这一段。

- 网关延迟（核心）：`ping <网关IP> -n 4`，正常 <5ms；>30ms 或抖动大 → 内网/WiFi 问题。
- WiFi 物理参数：`netsh wlan show interfaces`（Signal 强度、频段 Band、Rx/Tx rate）。
- Wi-Fi 同频信道竞争审计：`netsh wlan show networks mode=bssid` 统计同一信道周围高信号邻居 AP 数量；>3 个高信号同频 AP 会因 CSMA/CA 空口竞争引发间歇性跳 ping。
- 网卡速率与状态：`Get-NetAdapter | Select-Object Name, LinkSpeed, Status`。
- 链路丢包：`pathping <网关IP>` 观察 Link 列。
- 节能降速嫌疑：`Get-NetAdapterPowerManagement`（看是否开启节能休眠）。
- 第三方 NDIS 过滤驱动审计：`Get-NetAdapterBinding | Where-Object { $_.ComponentID -notmatch '^(ms_|vms_)' -and $_.Enabled -eq $true }`；检查是否有已废弃的抓包驱动、老旧杀软网络过滤组件或虚拟机桥接协议在内核层静默丢包或注入微秒级延迟。
- 网卡错包/丢包：`netstat -e` 查看累计 Errors 与 Discards；`Get-NetAdapterStatistics -Name <接口名>` 看硬件实时统计。计数持续增长说明网线/端口/双工协商问题（间歇性卡顿的物理层元凶）。
- 后台占带宽：`resmon` 网络选项卡看 Top 进程吞吐；`Get-NetTCPConnection | Group-Object State` 看连接数是否异常。

## 第 2 层：DNS 解析层（最常见根因）

判定：是否卡在「把域名变成 IP」这一步。

- 当前 DNS 耗时：`Measure-Command { Resolve-DnsName 域名 -Server <当前DNS> }`，多次采样；出现 >1s 或超时即异常。
- 横向对比公共 DNS（确凿锁定）：`Resolve-DnsName 域名 -Server 223.5.5.5` / `119.29.29.29` / `8.8.8.8`。若公共 DNS 稳定而当前 DNS 抖 → 锁定 DNS 服务器/路由器转发器问题。
- **抓慢事件并定位环节（最强证据，Windows 下强制 curl.exe -o NUL）**：
  `curl.exe -4 --noproxy '*' -o NUL -s -w "nl=%{time_namelookup} ct=%{time_connect} st=%{time_starttransfer} tt=%{time_total}\n" https://域名`
  若 `nl`（DNS）接近 `tt` 且很大 → 100% 卡在 DNS。
- 冷缓存对照：`Clear-DnsClientCache` 后首次解析明显慢于命中缓存 → 典型冷查询。
- 当前 DNS 配置：`Get-DnsClientServerAddress -AddressFamily IPv4`；静态还是 DHCP（`netsh interface ip show dns "WLAN"`）。
- DNS 全局搜索后缀列表（SuffixSearchList）与 NRPT 规则审计：
  `Get-DnsClientGlobalSetting | Select-Object SuffixSearchList, UseDevolution`；`Get-DnsClientNrptRule`。若列表中残留有企业内网域名后缀，每次公网解析都会触发级联拼接查询，导致耗时放大 2~4 倍并产生超时等待。
- AAAA（IPv6）解析耗时对照：`Measure-Command { Resolve-DnsName 域名 -Type AAAA }` 相比 `-Type A` 明显更慢/超时 → 运营商 IPv6 路径异常（Happy Eyeballs 回退拖慢首包）。
- **浏览器自带 DoH 会绕过系统 DNS**：Chrome/Edge 的「安全 DNS（DoH）」直接用浏览器内置解析器，改系统 DNS 对浏览器无效。`Get-DnsClientDohServerAddress` 看系统层 DoH；浏览器 `edge://settings/security` / `chrome://settings/security` 看是否开启安全 DNS（只读确认）。若浏览器开了安全 DNS，第 2 层「换系统 DNS」对浏览器无效，应改在浏览器或路由器层处理。

## 第 3 层：传输层（TCP 建连 / IPv6 回退 / MTU / 端口积压）

判定：IP 通了但「建连/首包」慢。

- TCP 建连：`curl.exe -4 --noproxy '*' -o NUL -s -w "ct=%{time_connect} st=%{time_starttransfer}\n" https://域名`；或 `Test-NetConnection 域名 -Port 443`。
- 临时端口耗尽与 TIME_WAIT 积压：`netsh int ipv4 show dynamicport tcp` 查看动态端口配额；`(Get-NetTCPConnection -State TimeWait).Count` 检查积压数量。若积压达数千，新发请求将因端口耗尽直接抛出 10055 异常。
- Bufferbloat（缓冲区膨胀）满载对比：在并发大流量吞吐时运行 `ping 223.5.5.5 -n 10`，若 RTT 相比空载时膨胀数倍至数十倍，说明路由器或驱动排队队列过深阻塞了交互型数据包。
- IPv6 回退（首包延迟元凶）：`curl.exe -4` 与 `curl.exe -6` 对比；`-6` 卡死/慢而 `-4` 秒回 → IPv6 回退。`Get-NetIPInterface` 看 IPv6 接口；`netsh interface ipv4 show prefixpolicies` 看前缀策略。参考 RFC 6555 / RFC 8305。
- MTU/分片：`ping -f -l 1472 目标` 失败、`-l 1400` 成功 → 分片异常；先 `netsh interface ipv4 show subinterfaces` 看当前 MTU。
- 路径级抖动/丢包：`pathping 目标`、`tracert 目标`、WinMTR（见工具）。
- **TLS 握手耗时**（HTTPS 最易漏）：`curl.exe -4 --noproxy '*' -o NUL -s -w "ct=%{time_connect} ac=%{time_appconnect} st=%{time_starttransfer} tt=%{time_total}\n" https://域名`，`ac - ct` 即纯 TLS 握手时长（证书链校验 + 密钥协商）。`curl.exe -4 -v` 可看 TLS 版本/证书；强制 `curl.exe --tlsv1.3` / `--tlsv1.2` 对比可判定版本回退。
- TCP 栈全局参数（隐藏的慢根因）：`netsh int tcp show global`；`Get-NetTCPSetting | Select-Object SettingName, AutoTuningLevelLocal, AutoTuningLevelEffective, CongestionProvider, ECN`。`AutoTuningLevelEffective=disabled`、拥塞控制被改非默认、ECN 异常 → 高延迟链路吞吐受限。
- 默认路由/多网卡错走与虚拟网卡冲突：`Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Sort-Object RouteMetric`；`Get-NetIPInterface | Select-Object InterfaceAlias, AddressFamily, InterfaceMetric, ConnectionState`。有线+无线同连时度量小的接口优先，可能「插着网线却走 WiFi」；或安装了虚拟机（VMware/WSL）导致默认路由被虚拟接口劫持。

## 第 4 层：应用层 / TTFB / 死挂代理残余 / Hosts 劫持

判定：本地 DNS/TCP 都健康，但「应用响应」慢；或全局请求陷入死挂超时。

- TTFB：`curl.exe -o NUL -s -w "ttfb=%{time_starttransfer} tt=%{time_total}\n" https://域名`。
- 浏览器逐请求：F12 → Network → 某请求 Timing（Stalled / DNS / Initial connection / TTFB）；`chrome://net-internals/#dns` 看解析耗时，`chrome://net-internals/#quic` 看 QUIC 握手/0-RTT。
- HTTP/3（QUIC）：现代站点走 UDP/443 的 QUIC，用浏览器 `chrome://net-internals/#quic` 看 QUIC；UDP/443 被限速会让 QUIC 反复回退到 HTTP/2。
- **死挂系统代理残余只读检测**：
  `Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" | Select-Object ProxyEnable, ProxyServer`
  若 `ProxyEnable = 1`，但对应本地端口（如 7890/10808）无监听进程，所有 HTTP 请求都会尝试连接死端口直到超时才报错。提示用户在 Windows「设置 -> 网络和 Internet -> 代理」中关闭系统代理。
- **Hosts 文件静态映射审计**：
  `Get-Content -Path "$env:windir\System32\drivers\etc\hosts" -ErrorAction SilentlyContinue | Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*#' }`
  检查是否存在硬编码映射至过期、失效或异地 IP 的静态规则，防止特定域名陷入无法建连的循环。

## 第 5 层：资源占用

- `resmon` 网络选项卡看实时吞吐 Top 进程；TCPView 看哪个进程持续收发。某进程在卡顿时段占满链路 → 根因是后台占用，不是网络质量。
- Windows 11 系统性占用（非网络故障却让网页变慢）：`Get-Service DoSvc` 看「传递优化」是否后台 P2P 占带宽；`Get-DeliveryOptimizationPerfSnap` 看累计上传量；`Get-NetConnectionProfile` 看是否计量网络（限制后台）；`Get-NetAdapter | Get-NetAdapterDriverInfo` 看网卡驱动是否被更新/回退导致吞吐骤降；「核心隔离/HVCI」开启可能拖累旧网卡驱动。

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
- Wireshark（抓包做最细粒度分析）: https://www.wireshark.org/
- 内置即用：ping、tracert、pathping、netstat、resmon、任务管理器性能页。
- pktmon（Win10 2004+ 内置抓包/丢包统计，只读确认本机收发与丢包，零安装）: https://learn.microsoft.com/en-us/windows-server/networking/technologies/pktmon/pktmon
- psping（Sysinternals，ICMP/TCP 延迟与不分片大包探测，比 ping 更强）: https://learn.microsoft.com/en-us/sysinternals/downloads/psping

## 常见根因表

| # | 根因 | 像一直慢/有时慢 | 确凿测量 |
|---|---|---|---|
| 1 | DNS 解析慢/抽风 | 皆可，常「有时」 | 多次 Resolve-DnsName 到当前 DNS 出现 >1s/超时；换公共 DNS 后稳定 |
| 2 | DNS 缓存冷查询 | 「首次/有时」 | Clear-DnsClientCache 后首次明显慢于命中 |
| 3 | IPv6 回退首包延迟 | 「首开慢、之后正常」 | curl.exe -4 比默认双栈快；解析落到 IPv6 |
| 4 | 路由器 DNS 转发器不稳定 | 「有时」，仅本 WiFi/家庭网 | 直连公共 DNS 稳定，用路由器分配 DNS 时抖 |
| 5 | 网关/ISP 抖动 | 典型「有时」 | 长 ping 网关 / WinMTR 到目标出现周期尖峰或丢包 |
| 6 | 后台进程占带宽 | 「有时」（后台触发时） | resmon 显示某进程占满链路 |
| 7 | 网卡驱动/节能降速 | 一直慢/间歇掉速 | LinkSpeed 远低于签约；关节能后复测提升 |
| 8 | WiFi 信号弱/拥塞 | 「有时」（移动/干扰） | Signal 低、协商速率低、同信道 AP 多 |
| 9 | MTU/分片 | 传大内容时慢 | ping -f -l 1472 失败、1400 成功 |
| 10 | 远端服务器/内容慢 | 个别网站 | 本地 DNS/TCP 健康但 TTFB 仍高；换设备同样慢 |
| 11 | TLS 握手慢 | 首字节慢、但 TCP 已通 | `curl.exe -w` 中 `time_appconnect - time_connect` 很大；证书链长/OCSP 超时/版本回退 |
| 12 | 网卡错包/丢包 | 「有时」（时好时坏） | `netstat -e` RX/TX 错误持续增长；`Get-NetAdapterStatistics` 错包统计 |
| 13 | TCP 全局参数异常（Auto-Tuning/ECN/拥塞） | 大文件/多资源整体慢 | `AutoTuningLevelEffective=disabled`、拥塞控制非默认、ECN 异常 |
| 14 | 多网卡默认路由错走 | 连着网线却走 WiFi | `Get-NetRoute 0.0.0.0/0` 指向更慢接口；InterfaceMetric 错排 |
| 15 | 浏览器 DoH 绕过系统 DNS | 改系统 DNS 无效 | 浏览器安全 DNS 开启；系统 DNS 改了但浏览器照旧慢 |
| 16 | Windows 11 后台占用（DoSvc/HVCI/驱动回退） | 非故障型变慢 | DoSvc 占带宽、驱动被回退、HVCI 拖累旧网卡 |
| 17 | 死挂系统代理残余 | 全网或大部分网页打不开/卡死 | 注册表 `ProxyEnable=1` 但对应端口已死，无法建连导致持续超时 |
| 18 | 虚拟网卡 Metric 劫持与 SMHNR 延迟 | 偶尔卡死几秒 | VMware/WSL 网卡跃点数低于物理网卡；多网卡并发查询超时 |
| 19 | DNS 搜索后缀列表过多 / NRPT 策略规则 | 域名冷解析普遍需要 2~5 秒以上 | `SuffixSearchList` 有多个已失效后缀；`Resolve-DnsName` 触发多轮超时拼接 |
| 20 | 短连接泛滥与 TIME_WAIT 临时端口耗尽 | 高并发/刷新时突发全网卡死，报 10055 | `(Get-NetTCPConnection -State TimeWait).Count` 突破 3000~5000，可用动态端口耗尽 |
| 21 | 第三方 NDIS 轻量级过滤驱动静默丢包 | 物理千兆协商正常，但吞吐极低或抖动 | `Get-NetAdapterBinding` 存在非微软原生第三方过滤驱动（Npcap/杀软/旧桥接驱动）且已启用 |
| 22 | Wi-Fi 同频信道干扰与邻近 AP 严重拥塞 | 信号满格但网络频繁跳 ping 掉速 | `netsh wlan show networks mode=bssid` 当前信道存在 3 个以上高信号同频邻居 AP |
| 23 | Bufferbloat 缓冲区膨胀与队列积压 | 平时正常，一旦下载/上传大流量即卡死 | 大流量吞吐时 Ping 网关/公网延迟从 10ms 暴增至 500ms+ 伴随丢包 |
| 24 | Hosts 文件静态条目篡改或失效 IP 固化 | 唯独某特定域名极慢或连不上 | `hosts` 包含该域名的硬编码映射且映射至失效或不可达 IP |

## 经典误区（看起来像 A 其实是 B）

- 把「DNS 慢」误判为「带宽慢」：实测下载满速、只是开网页卡 → 用 DNS 耗时测量区分。
- 把「IPv6 回退首包延迟」误判为「网站/服务器慢」：仅首次连接慢 → 本地协议栈回退，非对方服务器差。
- 把「后台占带宽」误判为「浏览器/网页问题」：关网页没用，瓶颈是别的进程在吃带宽（resmon 一眼识破）。
- 把「网卡节能降速」误判为「宽带缩水」：签约 1000M 实则跑 100M → 驱动/电源策略，非运营商。
- 把「WiFi 信号弱」误判为「运营商问题」：ping 网关就抖，根本没出户；换有线即正常。
- 把「间歇性 DNS 抖动」误判为「ISP 整体抽风」：只有解析环节抽风，换 DNS 即解决，而非投诉运营商。
- 把「TLS 握手慢」误判为「服务器慢/传输层慢」：`time_appconnect - time_connect` 很大时，瓶颈在证书链校验/密钥协商。
- 把「死挂代理残余」误判为「路由器断网」：系统代理未随软件关闭而还原，直连流量全部撞墙超时，关闭系统代理即秒解。
- 把「多网卡错走接口」误判为「WiFi 差」：插着网线却因 InterfaceMetric 默认路由指向 WiFi 或虚拟机虚拟网卡。
- 把「NDIS 第三方过滤驱动丢包」误判为「网线或宽带问题」：物理协商千兆但吞吐极慢，排查网卡过滤协议即可定位。
- 把「Wi-Fi 同频拥塞」误判为「Wi-Fi 信号不好」：信号 100% 但跳 ping，根因是同信道多个邻居 AP 争用空口。
- 把「DNS 搜索后缀过多」误判为「公网 DNS 慢」：每个公网域名都拼上内网后缀查询超时，根因在本地后缀列表。
- 把「Hosts 文件写死旧 IP」误判为「目标网站服务器挂了」：换手机同网络能开，电脑打不开，根因在本地 Hosts 劫持。

## 安全恢复与最小治理指南（须用户明确授权）

> [!IMPORTANT]
> 诊断阶段坚决保持 100% 只读。以下治理操作通常需要管理员权限，且**必须在确凿证据锁定根因、向用户清晰告知风险与效果并获得明确同意后**，由用户手动或授权执行：

1. **死挂系统代理恢复直连**：
   - 打开 Windows「设置」->「网络和 Internet」->「代理」，关闭「使用代理服务器」；
   - 或只读验证清理：`Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 0`。
2. **关闭网卡节能休眠（解决空闲后首次点击 2~3 秒顿挫）**：
   - 设备管理器 -> 展开「网络适配器」-> 双击物理网卡 ->「电源管理」-> 取消勾选「允许计算机关闭此设备以节约电源」。
3. **更换干净公共 DNS（解决本地 DNS 抽风/路由器转发器抖动）**：
   - `Set-DnsClientServerAddress -InterfaceAlias "以太网" -ServerAddresses ("223.5.5.5","119.29.29.29")`。
4. **清理失效的 DNS 搜索后缀（解决域名级联查询放大）**：
   - 网络适配器属性 -> TCP/IPv4 -> 高级 -> DNS -> 恢复默认选择「附加主 DNS 后缀和连接特定的 DNS 后缀」，删除列表中失效的企业域名。
5. **禁用冲突的第三方 NDIS 过滤组件（解决千兆掉速与内核排队）**：
   - 网络适配器属性 -> 组件列表中取消勾选失效的第三方抓包/杀软过滤协议；
   - 或使用 PowerShell：`Disable-NetAdapterBinding -Name "以太网" -ComponentID "<目标组件ID>"`。
6. **重置 Hosts 文件中的过期条目（解决特定网站打不开）**：
   - 以管理员身份打开 `%SystemRoot%\System32\drivers\etc\hosts`，将硬编码指定失效 IP 的行加上 `#` 注释或直接删除。
7. **调整虚拟网卡 Metric 优先级（解决流量误走虚拟交换机）**：
   - `Set-NetIPInterface -InterfaceAlias "vEthernet*" -InterfaceMetric 50`，保证物理有线/无线网卡拥有更小（更高优先级）的跃点数。

## 落地的工程纪律

1. 只读优先：诊断只用只读命令；`Clear-DnsClientCache` 等写操作只在「冷查询对照实验」里、明确告知用户后使用。
2. 分层给结论：每层输出「是/否」，不跳跃猜测。
3. 对照实验思维：换 DNS 服务器、强制 IPv4(`-4`)、关节能、换有线——哪一步让「有时慢」消失，哪一层就是根因。
