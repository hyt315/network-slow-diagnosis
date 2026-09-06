# Changelog

All notable changes to `network-slow-diagnosis` will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-09-06

### Added
- **第三方 NDIS 过滤驱动审计（NDIS Filter Drivers）**：新增对网卡绑定的非微软原生过滤驱动与协议组件（如旧版抓包驱动、老旧杀软网络过滤驱动、虚拟机桥接驱动）的只读扫描与风险提示，彻底定位物理协商千兆但吞吐被锁死在几十兆或内核排队丢包的隐蔽元凶。
- **Wi-Fi 同频信道竞争与邻近 AP 拥塞审计**：新增信道拥堵与邻近同频 BSSID 扫描分析，当信道内存在 3 个以上高信号同频邻居 AP 时及时预警，解决 Wi-Fi 信号满格但频繁跳 ping 掉速问题。
- **DNS 搜索后缀列表（SuffixSearchList）与 NRPT 规则排障**：新增对全局 DNS 搜索后缀及名称解析策略表（NRPT）的只读探测，解决加入过企业域或内网环境后公网域名因多轮后缀拼接超时导致解析耗时放大数倍的卡顿。
- **临时端口耗尽与 TIME_WAIT 套接字积压检测**：新增动态临时端口配额与 `TIME_WAIT` 状态连接数快速统计，及时捕捉短连接爆发导致源端口耗尽并抛出 `10055 (WSAENOBUFS)` 异常的瞬间瘫痪状态。
- **Hosts 文件静态条目篡改与失效 IP 映射审计**：新增对系统 Hosts 文件的只读扫描与当前域名匹配，精准排查特定域名被硬编码至失效、下线或异地 IP 导致的单网站打不开或持续超时。
- **Bufferbloat（缓冲区膨胀）满载与空载延迟对比**：新增链路在并发大流量吞吐与空闲状态下的 RTT 膨胀对比排查，定位路由器与驱动深队列造成的交互小包堵塞。
- **常见根因表与排障手册扩充**：`references/diagnostic-playbook.md` 常见根因表由 18 项扩充至 24 项，新增全套官方只读排查命令与安全恢复最小治理指南。
- **现代网络避坑指南扩充**：`references/modern-network-pitfalls.md` 由 8 大陷阱全面扩展至 14 大现代 Windows 网络陷阱，补齐技术根因、官方命令与证据判定标准。
- **自动化诊断扫描器增强 (`scripts/diagnose.ps1`)**：集成以上所有新增排查项，单次运行 5~10 秒内完整输出包含 NDIS 驱动、Wi-Fi 信道争用、DNS 后缀、TIME_WAIT、Hosts 条目等多层维度事实报告卡。
- **回归测试套件升级**：`tests/test_skill.py` 新增对 NDIS 绑定、DNS 后缀、TIME_WAIT、Hosts 等新增排查能力的完整断言覆盖。

## [1.2.0] - 2026-09-06

### Added
- **一键自动化只读诊断扫描器 (`scripts/diagnose.ps1`)**：纯原生、零第三方依赖的 PowerShell 诊断工具，5~10 秒内全自动对 L0~L5 进行立体测绘，支持终端彩色事实卡片与机读 `-Json` 输出。
- **死挂系统代理残余检测（Zombie Proxy Residuals）**：只读审计注册表 `Internet Settings` 中 `ProxyEnable=1` 死端口残余，解决第三方网络软件退出后浏览器全网请求超时痛点。
- **多网卡与虚拟网卡（VMware/WSL/Hyper-V）Metric 冲突与 SMHNR 延迟审计**：排查默认路由被虚拟网卡抢占导致吞吐腰斩，以及多网卡并发 DNS 探测超时问题。
- **Windows CLI 健壮性修复**：全面修复 Windows PowerShell 下 `curl` 别名与 `/dev/null` 语法陷阱，规范为 `curl.exe -o NUL` 与 `--noproxy "*"`。
- **标准化交付模版**：在 `SKILL.md` 中规范了统一的「Windows 网络分层诊断事实卡」输出格式。
- **语法与回归自检增强**：`scripts/selftest.py` 增加对 PowerShell 脚本的 AST 语法树解析检验与 v1.2.0 新指标回归锁。

## [1.1.0] - 2026-09-02

### Added
- **Wi-Fi 7 / MLO & 双频合一漫游颠簸排查**：新增针对 802.11be/ax 无线频段漫游跳变、信道冲突及网卡漫游激进性（`Roaming Aggressiveness`）只读审计命令。
- **网卡 Modern Standby 节能休眠断流诊断**：新增 `Get-NetAdapterPowerManagement` 与 `AllowComputerToTurnOffDevice` 探测，一键排查静置后首个网页必卡 2~3 秒的唤醒迟滞根因。
- **Windows 11 原生 DoH（DNS-over-HTTPS）加密超时检测**：新增 `Get-DnsClientDohServerAddress` 与 `netsh dns show encryption` 审计，精准定位因不可达 DoH 模板导致的握手超时与降级白屏。
- **IPv6 假通与 Path MTU 黑洞深度诊断**：新增 RFC 6724 前缀策略优先级审计（`netsh interface ipv6 show prefixpolicies`）、PPPoE MTU 1492 黑洞排查与双栈并行 TCP 443 延迟对比。
- **传递优化（DoSvc）P2P 上行占满与 Bufferbloat 缓冲区膨胀检测**：新增 `Get-DeliveryOptimizationStatus -PeerInfo`、`Get-DeliveryOptimizationPerfSnap` 与高并发 Established 连接进程排障。
- **全新参考文档**：新增 [`references/modern-network-pitfalls.md`](references/modern-network-pitfalls.md)，详尽解析 6 大现代网络深水区陷阱与官方治理对策。
- **回归自测套件升级**：新增 `scripts/selftest.py` 并强化 `tests/test_skill.py`，全维度覆盖现代诊断命令与安全断言。

## [1.0.1] - 2026-08-22

### Changed
- Added reading-time guidance to SKILL.md Reference Map so AI models pick reference files predictably.
- Documented single-layer reference reading constraint.

## [1.0.0] - 2026-08-21

### Added
- Initial release of layered read-only Windows network slowness diagnosis skill.
