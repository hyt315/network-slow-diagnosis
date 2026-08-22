# Changelog

## [1.0.1] - 2026-08-22

### Changed

- SKILL.md 的 Reference Map 升级为条件触发式读取引导（"需要按层执行诊断时读 playbook / 需要真实案例对照时读 case"），修复 LK005 弱引用（references 按需加载，措辞决定执行 AI 是否真的去读）——skill-doctor v1.2.1 检出。

## [1.0.0] - 2026-08-21

### Added

- 经联网调研的中审优化，补齐分层诊断原遗漏环节：
  - **TLS 握手耗时定位**：`curl -w` 的 `time_appconnect`，把"首字节慢"精确归因到证书链/密钥协商。
  - **网卡错包/丢包计数**：`Get-NetAdapterStatistics` / `netstat -e`，暴露网线/端口/双工问题导致的间歇性重传。
  - **TCP 栈全局参数**：`netsh int tcp show global` + `Get-NetTCPSetting`（Auto-Tuning / ECN / 拥塞控制）。
  - **默认路由/多网卡错走**：`Get-NetRoute` + `Get-NetIPInterface` 的 `InterfaceMetric`。
  - **浏览器 DoH 绕过系统 DNS** 的只读确认（`Get-DnsClientDohServerAddress` 与浏览器安全 DNS 设置）。
  - **HTTP/3（QUIC）** 首包观测说明（`chrome://net-internals/#quic`）。
  - **Windows 11 后台占用坑**：传递优化(DoSvc)、核心隔离/HVCI、驱动回退、计量网络。
  - **AAAA 解析耗时对照**（IPv6 路径异常 / Happy Eyeballs 回退）。
  - **新工具**：pktmon、psping、Test-Connection -Traceroute、netsh trace（均零安装/官方）。
  - 常见根因表由 10 条扩至 16 条；经典误区新增 TLS 误判、错包误判、路由错走误判。
- 社区健康文件（github-oss-prep 流程）：LICENSE(MIT)、双语 README、CONTRIBUTING、CODE_OF_CONDUCT、SECURITY、`.github/` 模板、CI、本文件、agents/openai.yaml。
- 回归测试 `tests/test_skill.py`：含结构/卫生/引用链接/负向用例，并对上述优化点加防回归断言。

### Changed

- 正文移除"作者排除代理"类元注释，仅在顶部保留中性适用范围说明；触发边界由 SKILL.md frontmatter 描述承担。

### Scope

- 适用范围：Windows 本机网络层与 DNS 导致的网页加载慢（直连路径）。
