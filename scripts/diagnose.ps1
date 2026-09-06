<#
.SYNOPSIS
    Layered read-only Windows network slowness & intermittent lag diagnostic scanner.
.DESCRIPTION
    Non-destructive, zero-dependency diagnostic collector for Windows 10/11.
    Evaluates L0 to L5 network health: APIPA, gateway latency, Wi-Fi link,
    NIC power management, DNS/DoH latency, TCP/TLS handshake, zombie proxy
    residuals, virtual NIC conflicts, and background bandwidth hogs.
.PARAMETER Domain
    Target domain to evaluate for DNS and HTTP/TLS metrics (default: www.qq.com).
.PARAMETER Quick
    Skip extended ping sampling for faster execution.
.PARAMETER Json
    Output machine-readable JSON instead of formatted text card.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\diagnose.ps1
    powershell -ExecutionPolicy Bypass -File scripts\diagnose.ps1 -Domain www.baidu.com -Quick
    powershell -ExecutionPolicy Bypass -File scripts\diagnose.ps1 -Json
#>
[CmdletBinding()]
param (
    [string]$Domain = "www.qq.com",
    [switch]$Quick,
    [switch]$Json
)

Set-StrictMode -Off
$ErrorActionPreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"

$report = [ordered]@{
    Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    TargetDomain = $Domain
    Layers = [ordered]@{}
    Findings = [System.Collections.Generic.List[string]]::new()
    RootCauses = [System.Collections.Generic.List[string]]::new()
    Recommendations = [System.Collections.Generic.List[string]]::new()
}

# Helper to record layer item
function Add-Metric {
    param (
        [string]$Layer,
        [string]$Item,
        [string]$Value,
        [string]$Baseline,
        [string]$Status, # "OK", "WARN", "CRITICAL"
        [string]$Note = ""
    )
    if (-not $report.Layers.Contains($Layer)) {
        $report.Layers[$Layer] = [System.Collections.Generic.List[hashtable]]::new()
    }
    $report.Layers[$Layer].Add(@{
        Item = $Item
        Value = $Value
        Baseline = $Baseline
        Status = $Status
        Note = $Note
    })
}

# --- L0: Scope & Primary Route / IP Configuration ---
$primaryRoute = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1
$ipConfig = $null
if ($primaryRoute) {
    $ipConfig = Get-NetIPConfiguration -InterfaceIndex $primaryRoute.InterfaceIndex -ErrorAction SilentlyContinue
}
if (-not $ipConfig) {
    $ipConfig = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null } | Select-Object -First 1
}
if (-not $ipConfig) {
    $ipConfig = Get-NetIPConfiguration | Where-Object { $_.NetIPv4Interface.InterfaceAlias -notmatch "Loopback" } | Select-Object -First 1
}

$localIPv4 = "Unknown"
$gatewayIPv4 = "None"
$dnsList = @()
$activeAlias = "Unknown"

if ($ipConfig) {
    $activeAlias = $ipConfig.InterfaceAlias
    $addrObj = @($ipConfig.IPv4Address)
    if ($addrObj.Count -gt 0) {
        $localIPv4 = $addrObj[0].IPAddress
    }
    if ($ipConfig.IPv4DefaultGateway) {
        $gwList = @($ipConfig.IPv4DefaultGateway.NextHop)
        if ($gwList.Count -gt 0) {
            $gatewayIPv4 = $gwList[0]
        }
    }
    if ($ipConfig.DNSServer) {
        $dnsList = @($ipConfig.DNSServer.ServerAddresses)
    }
}

if ($localIPv4 -like "169.254.*") {
    Add-Metric -Layer "L0_Scope" -Item "IPv4 Allocation" -Value $localIPv4 -Baseline "DHCP assigned (not 169.254.x.x)" -Status "CRITICAL" -Note "APIPA address: DHCP negotiation failed. No connection."
    $report.RootCauses.Add("DHCP 获取 IP 失败（处于 169.254.x.x APIPA 状态），物理链路未完成分配")
    $report.Recommendations.Add("检查路由器 DHCP 服务，或在网络设置中重新连接")
} else {
    Add-Metric -Layer "L0_Scope" -Item "IPv4 Allocation" -Value "$localIPv4 ($activeAlias)" -Baseline "Valid LAN IP" -Status "OK"
}

if ($gatewayIPv4 -eq "None") {
    Add-Metric -Layer "L0_Scope" -Item "Default Gateway" -Value "None" -Baseline "Valid Gateway IP" -Status "CRITICAL" -Note "No default gateway found."
} else {
    Add-Metric -Layer "L0_Scope" -Item "Default Gateway" -Value $gatewayIPv4 -Baseline "Present" -Status "OK"
}

# --- L1: Physical / Link / Energy ---
if ($gatewayIPv4 -ne "None") {
    $pingCount = if ($Quick) { 2 } else { 4 }
    $pingTimes = @()
    $lostPackets = 0
    
    1..$pingCount | ForEach-Object {
        $p = Test-Connection -ComputerName $gatewayIPv4 -Count 1 -ErrorAction SilentlyContinue
        if ($p -and $p.ResponseTime -ne $null) {
            $pingTimes += $p.ResponseTime
        } else {
            $lostPackets++
        }
    }
    
    if ($pingTimes.Count -gt 0) {
        $avgPing = [math]::Round(($pingTimes | Measure-Object -Average).Average, 1)
        $maxPing = ($pingTimes | Measure-Object -Maximum).Maximum
        $valStr = "${avgPing}ms (Max: ${maxPing}ms, Loss: $lostPackets/$pingCount)"
        if ($lostPackets -gt 0 -or $avgPing -ge 30) {
            Add-Metric -Layer "L1_PhysicalLink" -Item "Gateway Latency" -Value $valStr -Baseline "< 5ms (LAN/WiFi)" -Status "WARN" -Note "High gateway latency or packet loss."
            $report.Findings.Add("局域网网关通信延迟偏高 (${valStr})，可能是本地 WiFi 信号差或局域网信道拥堵")
        } else {
            Add-Metric -Layer "L1_PhysicalLink" -Item "Gateway Latency" -Value $valStr -Baseline "< 5ms (LAN/WiFi)" -Status "OK"
        }
    } else {
        Add-Metric -Layer "L1_PhysicalLink" -Item "Gateway Latency" -Value "ICMP Dropped (Gateway blocks Ping)" -Baseline "< 5ms" -Status "OK" -Note "Gateway ping disabled or isolated."
    }
}

# Wi-Fi check
$wlanRaw = (netsh wlan show interfaces 2>&1 | Out-String)
if ($wlanRaw -match "State\s*:\s*connected" -and $wlanRaw -match "SSID\s*:\s*(.+)") {
    $ssid = ($matches[1] -split "\r?\n")[0].Trim()
    $signal = 0
    $radio = "Unknown"
    $band = ""
    $rxRate = "Unknown"
    
    if ($wlanRaw -match "Signal\s*:\s*(\d+)%") { $signal = [int]$matches[1] }
    if ($wlanRaw -match "Radio type\s*:\s*(.+)") { $radio = ($matches[1] -split "\r?\n")[0].Trim() }
    if ($wlanRaw -match "Band\s*:\s*(.+)") { $band = ($matches[1] -split "\r?\n")[0].Trim() }
    if ($wlanRaw -match "Receive rate \(Mbps\)\s*:\s*(.+)") { $rxRate = ($matches[1] -split "\r?\n")[0].Trim() }
    
    $bandInfo = if ($band) { "$band, " } else { "" }
    $wlanVal = "$ssid ($radio, ${bandInfo}Signal: $signal%, Rx: $rxRate Mbps)"
    if ($signal -lt 55) {
        Add-Metric -Layer "L1_PhysicalLink" -Item "Wi-Fi Interface" -Value $wlanVal -Baseline "Signal > 65%" -Status "WARN" -Note "Weak Wi-Fi signal causes retransmissions."
        $report.Findings.Add("WiFi 信号偏弱 (${signal}%)，容易引起重传与握手抖动")
    } else {
        Add-Metric -Layer "L1_PhysicalLink" -Item "Wi-Fi Interface" -Value $wlanVal -Baseline "Signal > 65%" -Status "OK"
    }
} elseif ($activeAlias -notmatch "WLAN|Wi-Fi") {
    Add-Metric -Layer "L1_PhysicalLink" -Item "Active Interface" -Value "$activeAlias (Wired Ethernet)" -Baseline "Physical Link Up" -Status "OK"
}

# NIC Hardware Errors & Discards (netstat -e fallback)
$netstatRaw = (netstat -e 2>&1 | Out-String)
$errs = 0
$discards = 0
if ($netstatRaw -match "Errors\s+(\d+)\s+(\d+)") {
    $errs = [int]$matches[1] + [int]$matches[2]
}
if ($netstatRaw -match "Discards\s+(\d+)\s+(\d+)") {
    $discards = [int]$matches[1] + [int]$matches[2]
}

$statStr = "Errors: $errs, Discards: $discards"
if ($errs -gt 100 -or $discards -gt 500) {
    Add-Metric -Layer "L1_PhysicalLink" -Item "NIC Errors/Discards" -Value $statStr -Baseline "Low Errors/Discards" -Status "WARN" -Note "Hardware drops detected."
    $report.Findings.Add("网卡统计中累计错包较高 ($statStr)，网线端口或物理协商可能存在异常")
} else {
    Add-Metric -Layer "L1_PhysicalLink" -Item "NIC Errors/Discards" -Value $statStr -Baseline "Low Errors/Discards" -Status "OK"
}

# NIC Power Management
$pm = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Get-NetAdapterPowerManagement -ErrorAction SilentlyContinue
$pmSleeping = $false
foreach ($adapterPm in $pm) {
    if ($adapterPm.AllowComputerToTurnOffDevice -eq "Enabled") {
        $pmSleeping = $true
        break
    }
}
if ($pmSleeping) {
    Add-Metric -Layer "L1_PhysicalLink" -Item "NIC Power Management" -Value "AllowTurnOffDevice = Enabled" -Baseline "Disabled" -Status "WARN" -Note "May cause 2-3s cold wake-up stall."
    $report.Findings.Add("网卡启用了休眠节电（AllowComputerToTurnOffDevice=Enabled），空闲后首次点击网页常有 2~3 秒唤醒迟滞")
    $report.Recommendations.Add("在设备管理器网卡属性的「电源管理」中取消勾选「允许计算机关闭此设备以节约电源」")
} else {
    Add-Metric -Layer "L1_PhysicalLink" -Item "NIC Power Management" -Value "Power saving disabled" -Baseline "Disabled" -Status "OK"
}

# --- L2: DNS & DoH ---
$primaryDns = if ($dnsList.Count -gt 0) { $dnsList[0] } else { "223.5.5.5" }
$dnsResolveMs = -1

# Measure current DNS resolution time
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$res = Resolve-DnsName -Name $Domain -Server $primaryDns -Type A -DnsOnly -ErrorAction SilentlyContinue
$sw.Stop()
$dnsResolveMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)

$dnsStatus = if ($dnsResolveMs -gt 1000) { "CRITICAL" } elseif ($dnsResolveMs -gt 200) { "WARN" } else { "OK" }
Add-Metric -Layer "L2_DNS" -Item "Current DNS Latency" -Value "${dnsResolveMs}ms ($primaryDns)" -Baseline "< 50ms" -Status $dnsStatus

# Compare with Public DNS (223.5.5.5 AliDNS)
$swPublic = [System.Diagnostics.Stopwatch]::StartNew()
$resPublic = Resolve-DnsName -Name $Domain -Server "223.5.5.5" -Type A -DnsOnly -ErrorAction SilentlyContinue
$swPublic.Stop()
$publicDnsMs = [math]::Round($swPublic.Elapsed.TotalMilliseconds, 1)

Add-Metric -Layer "L2_DNS" -Item "Public DNS (223.5.5.5)" -Value "${publicDnsMs}ms" -Baseline "< 50ms" -Status "OK"

if ($dnsResolveMs -gt 500 -and $publicDnsMs -lt 100) {
    $report.RootCauses.Add("当前 DNS (${primaryDns}) 解析耗时达 ${dnsResolveMs}ms，而公共 DNS 仅 ${publicDnsMs}ms，确凿卡在本地 DNS/路由器转发器")
    $report.Recommendations.Add("将本机或路由器 DNS 改为公共 DNS（首选 223.5.5.5，备用 119.29.29.29）")
}

# IPv6 AAAA latency comparison
$swAAAA = [System.Diagnostics.Stopwatch]::StartNew()
$resAAAA = Resolve-DnsName -Name $Domain -Type AAAA -DnsOnly -ErrorAction SilentlyContinue
$swAAAA.Stop()
$aaaaMs = [math]::Round($swAAAA.Elapsed.TotalMilliseconds, 1)

if ($aaaaMs -gt 1500 -and $dnsResolveMs -lt 200) {
    Add-Metric -Layer "L2_DNS" -Item "AAAA (IPv6) Resolution" -Value "${aaaaMs}ms" -Baseline "< 100ms" -Status "WARN" -Note "IPv6 resolution stall."
    $report.Findings.Add("IPv6 (AAAA) 解析耗时异常偏长 (${aaaaMs}ms)，可能导致双栈客户端回退超时")
} else {
    Add-Metric -Layer "L2_DNS" -Item "AAAA (IPv6) Resolution" -Value "${aaaaMs}ms" -Baseline "< 100ms" -Status "OK"
}

# System DoH check
$dohConfigs = Get-DnsClientDohServerAddress -ErrorAction SilentlyContinue
$dohEnabled = ($dohConfigs -and $dohConfigs.Count -gt 0)
Add-Metric -Layer "L2_DNS" -Item "System DoH (DNS-over-HTTPS)" -Value (if ($dohEnabled) { "Configured" } else { "Not active" }) -Baseline "Informational" -Status "OK"

# --- L3: Transport & Dual Stack ---
# TCP 443 Test
$tcpSw = [System.Diagnostics.Stopwatch]::StartNew()
$tcpTest = Test-NetConnection -ComputerName $Domain -Port 443 -WarningAction SilentlyContinue
$tcpSw.Stop()
$tcpMs = [math]::Round($tcpSw.Elapsed.TotalMilliseconds, 1)

if ($tcpTest.TcpTestSucceeded) {
    Add-Metric -Layer "L3_Transport" -Item "TCP 443 Connect" -Value "Succeeded (~${tcpMs}ms)" -Baseline "Succeeded" -Status "OK"
} else {
    Add-Metric -Layer "L3_Transport" -Item "TCP 443 Connect" -Value "Failed" -Baseline "Succeeded" -Status "CRITICAL"
    $report.RootCauses.Add("目标域名 $Domain 的 443 端口无法建立 TCP 连接")
}

# Precision TLS timing with curl.exe
$curlExe = Get-Command "curl.exe" -ErrorAction SilentlyContinue
if ($curlExe) {
    $timingRaw = & $curlExe.Source -4 --noproxy "*" -o NUL -s -w "nl=%{time_namelookup} ct=%{time_connect} ac=%{time_appconnect} st=%{time_starttransfer} tt=%{time_total}" "https://$Domain" 2>&1
    if ($timingRaw -match "nl=([\d\.]+)\s+ct=([\d\.]+)\s+ac=([\d\.]+)\s+st=([\d\.]+)\s+tt=([\d\.]+)") {
        $nl = [math]::Round([double]$matches[1] * 1000, 1)
        $ct = [math]::Round([double]$matches[2] * 1000, 1)
        $ac = [math]::Round([double]$matches[3] * 1000, 1)
        $st = [math]::Round([double]$matches[4] * 1000, 1)
        $tt = [math]::Round([double]$matches[5] * 1000, 1)
        
        $tlsHandshake = [math]::Round($ac - $ct, 1)
        $tcpConnect = [math]::Round($ct - $nl, 1)
        $ttfb = [math]::Round($st - $ac, 1)
        
        Add-Metric -Layer "L3_Transport" -Item "TLS Handshake" -Value "${tlsHandshake}ms" -Baseline "< 100ms" -Status (if ($tlsHandshake -gt 500) { "WARN" } else { "OK" })
        Add-Metric -Layer "L4_Application" -Item "Server TTFB" -Value "${ttfb}ms" -Baseline "< 300ms" -Status (if ($ttfb -gt 1000) { "WARN" } else { "OK" })
        Add-Metric -Layer "L4_Application" -Item "Total Page Timing" -Value "${tt}ms" -Baseline "< 1500ms" -Status "OK"
    }
}

# --- L4: Zombie Proxy & Virtual Adapter Conflicts ---
# Zombie Proxy Residual Check
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
$proxyEnable = (Get-ItemProperty -Path $regPath -Name "ProxyEnable" -ErrorAction SilentlyContinue).ProxyEnable
$proxyServer = (Get-ItemProperty -Path $regPath -Name "ProxyServer" -ErrorAction SilentlyContinue).ProxyServer

if ($proxyEnable -eq 1 -and $proxyServer) {
    # Check if proxy port is listening
    $proxyHost = "127.0.0.1"
    $proxyPort = 7890
    if ($proxyServer -match "([^:]+):(\d+)") {
        $proxyHost = $matches[1]
        $proxyPort = [int]$matches[2]
    }
    
    $proxyTest = Test-NetConnection -ComputerName $proxyHost -Port $proxyPort -WarningAction SilentlyContinue
    if (-not $proxyTest.TcpTestSucceeded) {
        Add-Metric -Layer "L4_Application" -Item "System Proxy Residual" -Value "Dead ($proxyServer)" -Baseline "Disabled or Active" -Status "CRITICAL" -Note "Zombie proxy detected."
        $report.RootCauses.Add("检测到死挂系统代理（注册表开启了 ProxyEnable=1 指向 $proxyServer，但该端口未开放），导致网页请求持续挂起等待超时")
        $report.Recommendations.Add("进入 Windows「设置 -> 网络和 Internet -> 代理」，关闭系统代理开关")
    } else {
        Add-Metric -Layer "L4_Application" -Item "System Proxy Residual" -Value "Active ($proxyServer)" -Baseline "Clean" -Status "WARN" -Note "System proxy is active."
    }
} else {
    Add-Metric -Layer "L4_Application" -Item "System Proxy Residual" -Value "Clean (Disabled)" -Baseline "Disabled" -Status "OK"
}

# Virtual NIC Metric / Conflict Check
if ($primaryRoute) {
    $topInterface = Get-NetIPInterface -InterfaceIndex $primaryRoute.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($topInterface.InterfaceAlias -match "vEthernet|VMware|Virtual|TAP|WSL") {
        Add-Metric -Layer "L4_Application" -Item "Default Route Target" -Value "$($topInterface.InterfaceAlias) (Metric $($primaryRoute.RouteMetric))" -Baseline "Physical Adapter" -Status "WARN" -Note "Virtual NIC has lower metric."
        $report.Findings.Add("默认路由优先走虚拟网卡 ($($topInterface.InterfaceAlias))，可能导致流量被误导入虚拟链路")
    } else {
        Add-Metric -Layer "L4_Application" -Item "Default Route Target" -Value "$($topInterface.InterfaceAlias) (Metric $($primaryRoute.RouteMetric))" -Baseline "Physical Adapter" -Status "OK"
    }
}

# --- L5: Delivery Optimization & Bandwidth Hogs ---
# Delivery Optimization (DoSvc)
$dosvcPerf = Get-DeliveryOptimizationPerfSnap -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
if ($dosvcPerf -and $dosvcPerf.TotalBytesUploadedToInternet -gt 500MB) {
    $upMb = [math]::Round($dosvcPerf.TotalBytesUploadedToInternet / 1MB, 1)
    Add-Metric -Layer "L5_ResourceHogs" -Item "Delivery Optimization (DoSvc)" -Value "Uploaded ${upMb}MB" -Baseline "< 100MB" -Status "WARN" -Note "High P2P background upload."
    $report.Findings.Add("Windows 传递优化累计对外 P2P 上传达 ${upMb}MB，可能占满家庭上行宽带触发 Bufferbloat")
    $report.Recommendations.Add("在 Windows 设置 -> Windows 更新 -> 高级选项 -> 传递优化 中关闭「允许从其他电脑下载」")
} else {
    Add-Metric -Layer "L5_ResourceHogs" -Item "Delivery Optimization (DoSvc)" -Value "Normal / Idle" -Baseline "< 100MB" -Status "OK"
}

# Top Established Connection Hogs
$topProcs = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue | 
    Group-Object OwningProcess | 
    Sort-Object Count -Descending | 
    Select-Object -First 3

$procSummary = @()
foreach ($g in $topProcs) {
    $procName = "Unknown"
    $p = Get-Process -Id $g.Name -ErrorAction SilentlyContinue
    if ($p) { $procName = $p.ProcessName }
    $procSummary += "${procName}(PID:$($g.Name)): $($g.Count) conns"
}
Add-Metric -Layer "L5_ResourceHogs" -Item "Top Active TCP Hogs" -Value ($procSummary -join "; ") -Baseline "< 50 conns/proc" -Status "OK"

# --- Output Presentation ---
if ($Json) {
    $report | ConvertTo-Json -Depth 6
    exit 0
}

# Formatted Console Output
Write-Host ""
Write-Host "=========================================================================" -ForegroundColor Cyan
Write-Host "        Windows 分层网络只读诊断事实报告 (Windows Network Diagnostic)     " -ForegroundColor Cyan
Write-Host "=========================================================================" -ForegroundColor Cyan
Write-Host "时间: $($report.Timestamp)   目标测试域名: $Domain"
Write-Host ""

Write-Host ("{0,-18} | {1,-28} | {2,-30} | {3,-12} | {4}" -f "层级", "检查项", "测量实值", "正常基线", "状态")
Write-Host ("-" * 105)

foreach ($layerKey in $report.Layers.Keys) {
    foreach ($m in $report.Layers[$layerKey]) {
        $statusIcon = switch ($m.Status) {
            "OK"       { "[OK]    " }
            "WARN"     { "[WARN]  " }
            "CRITICAL" { "[CRIT]  " }
            Default    { "[INFO]  " }
        }
        $color = switch ($m.Status) {
            "OK"       { "Green" }
            "WARN"     { "Yellow" }
            "CRITICAL" { "Red" }
            Default    { "Gray" }
        }
        
        $line = "{0,-18} | {1,-28} | {2,-30} | {3,-12} | " -f $layerKey, $m.Item, $m.Value, $m.Baseline
        Write-Host -NoNewline $line
        Write-Host $statusIcon -ForegroundColor $color
    }
}
Write-Host ("-" * 105)

if ($report.RootCauses.Count -gt 0) {
    Write-Host ""
    Write-Host "【确凿定位根因】" -ForegroundColor Red
    foreach ($rc in $report.RootCauses) {
        Write-Host "  * $rc" -ForegroundColor Red
    }
}

if ($report.Findings.Count -gt 0) {
    Write-Host ""
    Write-Host "【次要发现与潜在风险】" -ForegroundColor Yellow
    foreach ($f in $report.Findings) {
        Write-Host "  * $f" -ForegroundColor Yellow
    }
}

if ($report.Recommendations.Count -gt 0) {
    Write-Host ""
    Write-Host "【针对性最小治理建议（须用户确认同意后手动/授权执行）】" -ForegroundColor Green
    foreach ($rec in $report.Recommendations) {
        Write-Host "  * $rec" -ForegroundColor Green
    }
}
Write-Host ""
