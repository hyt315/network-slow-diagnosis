# 现代 Windows 网络深水区避坑与官方排障指南

> 适用系统：Windows 10 / Windows 11（深度覆盖 22H2 / 23H2 / 24H2）。
> 核心原则：**只读排查、用证据说话、绝不擅自破坏性修改**。

---

## 目录

1. [坑 1：Wi-Fi 7 / MLO 与双频合一漫游颠簸（Band Steering Jitter）](#坑-1wi-fi-7--mlo-与双频合一漫游颠簸band-steering-jitter)
2. [坑 2：网卡 Modern Standby 节能休眠与唤醒迟滞（D3 Throttling）](#坑-2网卡-modern-standby-节能休眠与唤醒迟滞d3-throttling)
3. [坑 3：Windows 11 原生 DoH（DNS-over-HTTPS）加密解析超时与降级白屏](#坑-3windows-11-原生-dohdns-over-https加密解析超时与降级白屏)
4. [坑 4：IPv6 假通与 Path MTU 黑洞（Happy Eyeballs 21 秒重传超时）](#坑-4ipv6-假通与-path-mtu-黑洞happy-eyeballs-21-秒重传超时)
5. [坑 5：Windows 传递优化（DoSvc）P2P 上行占满与 Bufferbloat 缓冲区膨胀](#坑-5windows-传递优化dosvc-p2p-上行占满与-bufferbloat-缓冲区膨胀)
6. [坑 6：TCP 窗口自适应关闭与网卡高级节能属性（EEE / RSS / LSO）](#坑-6tcp-窗口自适应关闭与网卡高级节能属性eee--rss--lso)

---

## 坑 1：Wi-Fi 7 / MLO 与双频合一漫游颠簸（Band Steering Jitter）

### 现象表现
- 笔记本在家中特定位置，每隔几分钟游戏突发丢包 3~5 秒，或打开网页时偶尔卡死几秒后恢复。
- 路由器开启了“双频合一 / 三频合一（Smart Connect）”功能。

### 技术根因
在 2.4GHz、5GHz 和 6GHz 覆盖边缘，无线网卡驱动与 AP 会尝试进行频段导航（Band Steering）或 802.11k/v/r 漫游。若网卡驱动漫游主动性（Roaming Aggressiveness）较高，驱动会在临界 RSSI（如 -72dBm）频繁触发重关联（Re-association），每次漫游切换会导致物理链路瞬时断流 500ms~3000ms。

### 官方只读排查命令
```powershell
# 1. 检查当前无线接口物理标准 (802.11ax/be)、频段、信道及协商收发速率
netsh wlan show interfaces

# 2. 扫描所有可见 BSSID 与对应信号强度
netsh wlan show networks mode=bssid

# 3. 检查网卡漫游激进性配置
Get-NetAdapterAdvancedProperty -Name "*" | Where-Object { 
    $_.DisplayName -match "Roaming|Preferred Band|Wireless Mode" 
} | Select-Object InterfaceDescription, DisplayName, DisplayValue
```

### 证据判定与处置
- **证据**：相同 SSID 下存在多个 BSSID，当前信号 `Signal < 65%` 且频繁在 5GHz 与 2.4GHz 之间切换。
- **治理建议**：
  1. 路由器关闭双频合一，将 2.4GHz 与 5GHz/6GHz 分开命名；
  2. 设备管理器中将 `Roaming Aggressiveness`（漫游主动性）调至 `1. Lowest`（最低）或 `2. Medium-Low`。

---

## 坑 2：网卡 Modern Standby 节能休眠与唤醒迟滞（D3 Throttling）

### 现象表现
- 笔记本离开几分钟后重新亮屏，或者在浏览器静置一段时间后点开第一个网页，**前 2~3 秒必定白屏转圈**，之后打开其他网页恢复极速。

### 技术根因
Windows 11 现代待机（Modern Standby / S0ix）和电源管理策略允许系统在无数据传输时将网卡置于 D3 低功耗状态（PCIe Active State Power Management - ASPM）。点击新链接时，物理网卡与主板芯片组需要经历硬件时钟拉起与链路训练（Link Retraining），造成可感知的冷启动延迟。

### 官方只读排查命令
```powershell
# 1. 查看物理网卡的电源管理配置
Get-NetAdapter -Physical | Get-NetAdapterPowerManagement | Select-Object InterfaceDescription, AllowComputerToTurnOffDevice, SelectiveSuspend, DeviceSleepOnDisconnect

# 2. 检查绿色以太网 / 节能属性
Get-NetAdapterAdvancedProperty -Name "*" | Where-Object { 
    $_.DisplayName -match "Energy|Green|Power Saving|MIMO Power" 
} | Select-Object InterfaceDescription, DisplayName, DisplayValue
```

### 证据判定与处置
- **证据**：`AllowComputerToTurnOffDevice = 'Enabled'`，且节能属性处于开启状态。
- **治理建议**：
  - 在设备管理器 -> 网卡属性 -> **电源管理** -> 取消勾选“允许计算机关闭此设备以节约电源”；
  - 属性高级页中关闭 `Energy Efficient Ethernet`（节能以太网）。

---

## 坑 3：Windows 11 原生 DoH（DNS-over-HTTPS）加密解析超时与降级白屏

### 现象表现
- 局域网 Ping 网关延迟极低（<2ms），但浏览器解析域名时首次访问极其迟钝，随后域名命中缓存变快。

### 技术根因
Windows 11 支持系统级 DNS-over-HTTPS。若网络适配器配置了海外或不可达的 DoH 模板（例如 `https://cloudflare-dns.com/dns-query` 被运营商阻断），Windows DNS 客户端会优先尝试通过 443 端口发起 TLS 握手。**在 TLS 握手超时失败后，系统才会回退（Fallback）到普通的 UDP 53 端口**，导致每次未命中的域名查询增加 2000ms~5000ms 的无谓等待。

### 官方只读排查命令
```powershell
# 1. 审计系统级 DoH 模板库
Get-DnsClientDohServerAddress

# 2. 审计适配器 DNS 是否启用了加密
netsh dns show encryption

# 3. 测量纯 UDP DNS 与系统默认 DNS 的耗时差异
$currentDns = (Get-DnsClientServerAddress -AddressFamily IPv4 -InterfaceAlias (Get-NetConnectionProfile.InterfaceAlias)).ServerAddresses[0]
Measure-Command { Resolve-DnsName -Name "www.bing.com" -Server $currentDns -DnsOnly -Type A }
```

### 证据判定与处置
- **证据**：`netsh dns show encryption` 显示启用了 DoH，但 `Resolve-DnsName` 耗时 > 1.5 秒。
- **治理建议**：
  - 进入 Windows 设置 -> 网络和 Internet -> 硬件属性 -> DNS 分配，将“DNS 加密”改为“仅未加密”，或换用国内可靠的 DoH 服务器（如阿里 DNS `https://dns.alidns.com/dns-query`、腾讯 DNSPod `https://doh.pub/dns-query`）。

---

## 坑 4：IPv6 假通与 Path MTU 黑洞（Happy Eyeballs 21 秒重传超时）

### 现象表现
- 微信/QQ 等即时通讯正常，但访问部分大型网站首屏转圈几十秒，甚至直接报错 `ERR_CONNECTION_TIMED_OUT`。

### 技术根因
很多家庭光猫开启了 IPv6（分配了 240e/2408/2409 公网前缀），Windows 默认根据 RFC 6724 将 IPv6 优先级置于 IPv4 之上（`::/0` 优先级 50 vs IPv4 35）。若上游运营商 IPv6 路由不可达，或 PPPoE MTU（1492）未开启 MSS Clamping 导致大于 1280 字节的 IPv6 包被静默丢弃（PMTU 黑洞），系统发起 TCP SYN 时会经历长时间等待才回退到 IPv4。

### 官方只读排查命令
```powershell
# 1. 检查 IPv6 前缀策略优先级
netsh interface ipv6 show prefixpolicies

# 2. 检查 IPv6 子接口 MTU
netsh interface ipv6 show subinterfaces

# 3. 双栈并行测速与握手对比
$domain = "www.qq.com"
$v4 = (Resolve-DnsName $domain -Type A -EA SilentlyContinue).IPAddress | Select -First 1
$v6 = (Resolve-DnsName $domain -Type AAAA -EA SilentlyContinue).IPAddress | Select -First 1

if ($v4) { Test-NetConnection -ComputerName $v4 -Port 443 | Select-Object RemoteAddress, TcpTestSucceeded, PingReplyDetails }
if ($v6) { Test-NetConnection -ComputerName $v6 -Port 443 | Select-Object RemoteAddress, TcpTestSucceeded, PingReplyDetails }
```

### 证据判定与处置
- **证据**：$v4 握手瞬间成功（<30ms），但 $v6 握手失败或耗时极大。
- **治理建议**：
  - 若不需要 IPv6，可在适配器属性中取消勾选“Internet 协议版本 6 (TCP/IPv6)”；
  - 或通过注册表配置 `DisabledComponents=0x20`（IPv4 优先于 IPv6）。

---

## 坑 5：Windows 传递优化（DoSvc）P2P 上行占满与 Bufferbloat 缓冲区膨胀

### 现象表现
- 只要开机或系统更新时，家里所有电脑/手机延迟极高（ping 路由器从 2ms 变成 1500ms），测速下载跑不满，上传却一直在跑。

### 技术根因
Windows Update 传递优化（`DoSvc`）默认开启 P2P 上传，向本地局域网和 Internet 上的其他设备分发更新包。家庭宽带上行通常仅 30M~50M，一旦上传带宽被占满，路由器上行缓冲区爆满（Bufferbloat），下行请求的 TCP ACK 确认包被严重排队推迟，造成下行吞吐暴跌与全局丢包。

### 官方只读排查命令
```powershell
# 1. 查看传递优化当前的 P2P 活跃上传/下载状态
Get-DeliveryOptimizationStatus -PeerInfo -EA SilentlyContinue | Select-Object FileId, Status, BytesFromPeers, BytesToPeers, PercentPeerCaching

# 2. 检查累计上传与下载数据量
Get-DeliveryOptimizationPerfSnap | Select-Object TotalBytesDownloaded, TotalBytesUploadedFromPeers, TotalBytesUploadedToInternet

# 3. 探测占用最多 TCP 活跃连接的前 5 个系统进程
Get-NetTCPConnection -State Established | Group-Object OwningProcess | Sort-Object Count -Descending | Select-Object -First 5 Count, Name | ForEach-Object {
    [PSCustomObject]@{
        PID = $_.Name
        ProcessName = (Get-Process -Id $_.Name -EA SilentlyContinue).ProcessName
        ActiveConnections = $_.Count
    }
}
```

### 证据判定与处置
- **证据**：`TotalBytesUploadedToInternet` 巨大且持续攀升，或 `DoSvc` 进程建立大量对外连接。
- **治理建议**：
  - 进入 Windows 设置 -> Windows 更新 -> 高级选项 -> 传递优化 -> 关闭“允许从其他电脑下载”；
  - 或在“高级选项”中将“后台上传带宽”限制为固定绝对值（如 0.5 Mbps）。

---

## 坑 6：TCP 窗口自适应关闭与网卡高级节能属性（EEE / RSS / LSO）

### 现象表现
- 百兆/千兆宽带下载大文件或大网页时，速度被死死限制在几百 KB/s，CPU 占用却极低。

### 技术根因
某些老旧优化脚本曾错误地执行 `netsh int tcp set global autotuninglevel=disabled`，关闭了 TCP 接收窗口自动调优（Window Auto-Tuning）。在现代高延迟-高带宽（BDP 较大）的公网连接中，固定 64KB 接收窗口会导致 TCP 吞吐公式受阻，无法充分利用带宽。同时，网卡的接收端缩放（RSS）如果被禁用，所有网络中断将被绑定在 CPU Core 0 上造成单核打满瓶颈。

### 官方只读排查命令
```powershell
# 1. 检查全局 TCP 窗口调优状态
Get-NetTCPSetting | Select-Object SettingName, AutoTuningLevelLocal, AutoTuningLevelEffective, CongestionProvider, ECN

# 2. 检查网卡硬件卸载与 RSS 状态
Get-NetAdapterRss
Get-NetAdapterLso
Get-NetAdapterChecksumOffload
```

### 证据判定与处置
- **证据**：`AutoTuningLevelEffective = 'Disabled'`。
- **治理建议**：
  - 恢复系统官方默认自适应调优：`netsh int tcp set global autotuninglevel=normal`。
