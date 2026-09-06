# 《network-slow-diagnosis》深水区多源对标与避坑指南 (Domain Grounding & Pitfalls)

> - **领域归属**: `Windows 网络卡慢与延迟分层根因排查 (Windows Network Latency Diagnosis)`
> - **形态架构**: `[HYBRID]` 复合型（脚本工具 + 知识库复合体）
> - **对标成果**: GitHub 同类 Agent 技能标杆 + 顶级开源工具实现 + RFC 官方规范 + 生产故障事故

---

## 一、GitHub 同类 Agent 技能标杆对标 (Peer Agent Skills Benchmark)

对标 `alibabacloud-ecs-windows-troubleshooting`、`wireshark-analysis` 与 `performance-engineer` 核心交互经验：

1. **分层路由与自下而上击穿 (Bottom-Up Layered Routing)**：
   - 同类优秀技能均避免在用户报“网慢”时直接测速（测速只会掩盖 DNS 慢或网关抖动）。
   - 必须按工业标准分层：
     - **L1 物理/链路层**：WiFi RSSI 信号强度（目标 >= -65 dBm）、协商链路速率（802.11ac/ax 协商率）；
     - **L2 网关与局域网层**：本地默认网关往返延迟（正常基线 < 2ms，WiFi < 5ms）；
     - **L3 DNS 解析服务层**：主副 DNS 解析时延（正常基线 < 50ms，超时切换阀值 200ms）；
     - **L4 公网骨干路由跳点**：首跳至 ISP 骨干路由器 RTT 与抖动（Jitter < 10ms）；
     - **L5 传输层与代理/MTU**：TCP 接收窗口自动调节状态、IPv6 Happy Eyeballs 与 MTU 分片。

2. **零外部依赖与优雅探测**：
   - 标杆技能严禁依赖第三方安装包，100% 依赖 Windows 原生 `PowerShell`、`Get-NetAdapter`、`Test-NetConnection` 与 Python 原生 `socket` 实现。

---

## 二、GitHub 顶级开源网络诊断工程经验 (Top Domain OSS Insights)

对标 `bp2008/pingtracer`、`diqezit/Ping` 与 `HarmanPreet-Singh-XYT/PingRoute`：

1. **抖动（Jitter）与偶发丢包识别**：
   - 网页“偶发卡死”的根因往往不是高延迟，而是高抖动（Jitter > 30ms）或 1%~2% 的偶发丢包。单一平均 Ping 无法反映，需要至少连续 10~20 次快速采样。
2. **ICMP 阻断时的 TCP 探针回退机制**：
   - 生产环境中部分企业防火墙与云节点禁 Ping（ICMP Echo 被丢弃）。
   - 探测工具必须具备 TCP 握手探针（如向目标 443/80 端口发起 TCP 握手计时），杜绝因禁 Ping 误报“网络中断”。

---

## 三、底层协议 RFC 与权威参数基线 (RFC & Official Standards)

1. **RFC 8305 - Happy Eyeballs Version 2: Dual-Stack Algorithm**：
   - **痛点**：若系统启用了 IPv6 但局域网或运营商 IPv6 路由不通，系统会在尝试 IPv6 超时（默认约 250ms~3s）后才回退到 IPv4，造成网页打开明显卡顿。
   - **诊断基线**：探测 `Get-NetIPAddress` 是否存在有效全局公网 IPv6 地址；对比 IPv4 与 IPv6 到相同域名的 TCP 建立耗时。

2. **RFC 1191 / RFC 4821 - Path MTU Discovery (PMTUD)**：
   - **痛点**：VPN、PPPoE 或网络代理虚拟网卡常将 MTU 限制在 1492 或更小；若中间路由丢弃 ICMP "Fragmentation Needed" 包，会导致大包（如上传、视频流）直接黑洞挂死，表现为小文本能开、大网页打不开。
   - **基线**：默认以太网 MTU = 1500，PPPoE = 1492。

3. **Windows TCP Window Auto-Tuning (RFC 1323)**：
   - **痛点**：部分优化软件误将 `autotuninglevel` 设为 `disabled`，导致千兆宽带下载被锁死在几百 KB/s。
   - **基线**：`netsh interface tcp show global` 中 `Receive Window Auto-Tuning Level` 必须为 `normal`。

---

## 四、生产级隐蔽踩坑与杀手故障库 (Killer Failure Modes)

1. **DNS 多网卡污染与虚拟网卡优先级争抢**：
   - 现象：安装了 WSL、VMware、Docker 或企业 VPN 后，网络卡死。
   - 根因：虚拟网卡接口跃点数（Interface Metric）被设得比物理网卡还低，或残留了失效的 DNS 服务器 IP（如 192.168.100.1 无响应）。
   - 排查对策：`Get-NetIPInterface | Sort-Object InterfaceMetric`，排查活跃默认路由。

2. **WiFi 频段与信道拥塞死锁**：
   - 现象：笔记本连 WiFi 2.4GHz，蓝牙耳机或微波炉工作时网络瞬间丢包 50%。
   - 根因：2.4GHz 频宽受限且同频干扰严重。
   - 排查对策：检查 WiFi 连接频段（RadioType 是否为 802.11ax/ac 5GHz）。

3. **代理软件 Loopback 静默断流**：
   - 现象：浏览器提示 ERR_PROXY_CONNECTION_FAILED 或加载极慢。
   - 根因：系统代理开启了 127.0.0.1:7890 但本地代理进程已意外退出，导致全部流量在本地黑洞。
   - 排查对策：检查注册表 `Internet Settings` 中 `ProxyEnable` 与 `ProxyServer` 存活状态。

---

## 五、代码片段可执行探针准则 (Sanity Probes)

所有引入该技能的诊断代码必须满足：
1. **纯标准库与静态编译**：Python 脚本必须通过 `ast.parse` 静态语法解析，不依赖外部三方库；
2. **命令参数有效性**：PowerShell 命令限定使用 Windows 10/11 原生 cmdlet（如 `Get-NetAdapter`、`Test-NetConnection`），禁止使用过时 `ipconfig /all` 纯文本正则匹配（避免英文/中文语言包输出不兼容）；
3. **只读安全性**：100% 遵循 Zero-Mutation，任何重置 DNS、重启网卡建议必须由用户授权手动执行。
