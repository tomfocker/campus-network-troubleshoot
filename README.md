# 🏫 Campus Network Troubleshoot Skill

> 基于 ZCode AI Agent 的校园网/企业网交换机故障远程排查技能

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey)]()

## 📖 简介

这是一个为 ZCode AI 编程助手设计的技能模块，用于远程连接华为/H3C 系列交换机，自动执行网络故障诊断命令，分析根因并输出结构化诊断报告。

### 为什么需要这个技能？

传统网络故障排查流程：
1. 网管人员到现场或远程登录交换机
2. 逐条执行诊断命令（`display interface`、`display logbuffer`...）
3. 人工对比分析数据
4. 凭经验判断根因

**使用本技能后**：
- 🤖 一句话描述故障现象，AI 自动连接交换机执行诊断
- ⚡ 自动执行全部诊断命令组合，数秒完成
- 📊 自动对比故障端口 vs 正常端口，差异一目了然
- 🎯 内置根因判断引擎，给出修复建议

## 🚀 快速开始

### 安装

1. 将本仓库克隆到 ZCode 项目或用户的 skills 目录：

```bash
# 项目级安装（仅当前项目可用）
mkdir -p .agents/skills/
git clone https://github.com/tomfocker/campus-network-troubleshoot.git .agents/skills/campus-network-troubleshoot/

# 或用户级安装（所有项目可用）
mkdir -p ~/.agents/skills/
git clone https://github.com/tomfocker/campus-network-troubleshoot.git ~/.agents/skills/campus-network-troubleshoot/
```

2. 确保 ZCode 能访问网络设备（需与交换机在同一网络或通过 VPN）

### 使用示例

安装后，在 ZCode 对话中直接描述故障即可自动触发：

```
# 断网排查
"172.16.20.217 交换机 GE0/0/5 口下面的 106 房间不能上网，帮我排查"

# 端口抖动分析
"幼教楼交换机端口 21 一直在 UP/DOWN 抖动，查一下日志"

# 对比诊断
"5 口和 19 口对比一下，看看 5 口有什么问题"

# 批量巡检
"172.16.20.217 交换机所有 access 口状态巡检"
```

## 📋 诊断能力

### 自动执行的诊断命令

| 阶段 | 命令 | 检查内容 |
|------|------|----------|
| 基础信息 | `display version`, `display device` | 设备型号/版本/运行时间 |
| 端口深度 | `display interface X/X/X` | 速率/双工/流量/CRC错误 |
| VLAN 归属 | `display vlan`, `display port vlan` | VLAN 配置是否正确 |
| MAC 学习 | `display mac-address X/X/X` | 下挂设备是否正常学习 |
| STP 状态 | `display stp interface X/X/X` | 是否 Forwarding/拓扑变更 |
| 日志分析 | `display logbuffer` | UP/DOWN 事件/安全告警 |
| 安全策略 | `display acl`, `display dhcp snooping` | 是否有误拦截 |

### 根因判断速查

| 症状 | 诊断结论 |
|------|----------|
| 频繁 UP/DOWN + 100M 速率 | 🔌 网线物理损伤（4芯通），更换线缆 |
| UP 但出流量≈0 + ARP 为空 | 📡 设备未获取 IP（DHCP 失败） |
| CRC/错误计数高 | 🔧 线缆质量差/电磁干扰/光模块故障 |
| STP 非 Forwarding | 🔄 网络环路/STP 收敛中 |
| MAC 漂移 | ↩️ 下游存在二层环路 |
| 端口 error-down | 🛡️ 安全策略触发 |

## 📁 项目结构

```
campus-network-troubleshoot/
├── SKILL.md                    # 技能定义（ZCode 入口）
├── README.md                   # 本文档
├── LICENSE                     # MIT 许可
├── scripts/
│   └── telnet_diag.ps1         # PowerShell Telnet 脚本
│                                # 无需安装 Telnet 客户端
│                                # 直连交换机 TCP 23 端口
└── references/
    └── huawei_commands.md      # 华为/H3C VRP 命令速查表
```

## 🔧 支持设备

| 厂商 | 系列 | 状态 |
|------|------|------|
| 华为 | Quidway S5700 / S3700 / S2700 | ✅ 已测试 |
| 华为 | CloudEngine 系列 | 🧪 理论兼容 |
| 华三(H3C) | Comware 系列 | ✅ 已测试 |
| 锐捷 | RGOS 系列 | 📋 计划中 |
| 思科 | IOS/IOS-XE | 📋 计划中 |

## ⚠️ 安全提醒

- **Telnet 是明文协议** — 密码以明文在网络传输，生产环境建议启用 SSH
- 本脚本仅执行**只读诊断命令**，不会修改交换机配置
- 所有凭据仅在当次会话内存中使用，不落盘存储

## 🤝 贡献

欢迎提交 Issue 和 PR！

### 计划路线图

- [ ] SSH 连接支持
- [ ] 批量端口巡检报告
- [ ] 锐捷/思科设备适配
- [ ] 自动生成拓扑图
- [ ] Web 可视化面板

## 📄 许可

MIT License - 详见 [LICENSE](LICENSE)
