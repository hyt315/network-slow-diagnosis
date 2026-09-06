# Changelog

All notable changes to `network-slow-diagnosis` will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
