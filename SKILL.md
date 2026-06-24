---
name: campus-network-troubleshoot
description: >
  校园网/企业网故障远程排查技能。当用户提到交换机故障、端口不通、不能上网、
  网络诊断、交换机排查、华为/H3C/华三交换机管理、VLAN排查、
  网线故障、链路抖动、端口协商等场景时自动触发。
  也适用于用户说"帮我看看XX楼XX房间为什么不能上网"之类的请求。
  支持 Telnet 远程连接华为/H3C 交换机执行批量诊断命令并输出分析报告。
---

# 校园网故障排查技能

远程连接华为/H3C 交换机，自动执行诊断命令，分析根因并给出修复建议。

## 前置条件

用户需要提供（或在对话中询问获取）：
- **交换机 IP 地址**
- **管理密码**（Telnet 端口默认 23）
- **故障端口号** 或 **房间名称/编号**
- 可选：一个正常工作的对照端口（用于对比诊断）

## 连接方式

默认使用 Telnet（端口 23），如用户明确要求可用 SSH。

**首次连接前检查**：
1. 先 `ping` 目标 IP 确认可达性
2. 用 PowerShell `Test-NetConnection` 确认端口开放
3. 如 Telnet 客户端未安装，使用 `scripts/telnet_diag.ps1` 脚本

## 诊断流程

### 第一步：基础信息收集

连接交换机后执行以下命令，了解全局状态：

```
display version                        # 设备型号、软件版本、运行时间
display device                         # 板卡状态
display ip interface brief             # 三层接口概览
display interface brief                # 端口状态概览
```

### 第二步：故障端口深度诊断

对目标端口执行：

```
display interface GigabitEthernet X/X/X    # 端口详情：速率、双工、流量、错误
display port vlan GigabitEthernet X/X/X    # VLAN 归属
display mac-address GigabitEthernet X/X/X  # 下挂设备 MAC
display stp interface GigabitEthernet X/X/X # STP 状态
display arp interface GigabitEthernet X/X/X # ARP 记录（仅三层接口有效）
```

**进入系统视图查看端口完整配置**：
```
system-view
interface GigabitEthernet X/X/X
display this
quit
```

### 第三步：对比诊断（用户提供对照端口时）

对正常工作的对照端口执行相同命令，重点对比：

| 指标 | 说明 |
|------|------|
| 协商速率 | 100M vs 1000M，速率异常通常意味着线缆问题 |
| 流量差异 | 故障端口出流量极低 → 设备未获取 IP 或无有效通信 |
| 错误计数 | CRC、Giants 是否异常 |
| MAC 数量 | 下挂设备是否正常学习到 |
| STP 状态 | 是否为 Forwarding，有无频繁拓扑变更 |
| 端口配置 | 是否有多余的 ACL/安全策略限制 |

### 第四步：日志分析

```
display logbuffer | include X/X/X          # 过滤端口相关日志
display logbuffer                          # 最近 512 条日志（查找 UP/DOWN 事件）
display mac-address flapping record        # MAC 漂移记录
```

### 第五步：DHCP 与安全策略检查

```
display dhcp snooping                      # DHCP 监听状态
display acl all                            # ACL 配置
display traffic-policy applied-record      # 流策略
```

## 根因判断速查表

| 症状 | 可能根因 |
|------|----------|
| 端口频繁 UP/DOWN + 100M 速率 | **网线物理损伤**（4芯通），需更换线缆或重打水晶头 |
| 端口 UP 但出流量为 0、ARP 为空 | 设备未获取 IP（DHCP 失败），或设备网络配置错误 |
| 端口 DOWN 状态 | 网线断开、对端设备关机、端口 shutdown |
| CRC/错误计数高 | 网线质量差、电磁干扰、光模块故障 |
| STP 非 Forwarding | 网络环路、STP 收敛中 |
| MAC 漂移 | 下游存在环路 |
| 端口 error-down | 安全策略触发（BPDU保护、风暴控制等） |

## 输出格式

诊断完成后，输出结构化的分析报告：

```
## 🔍 故障诊断报告

### 设备信息
- 型号 / 版本 / 运行时间

### 端口状态对比

| 指标 | 故障端口 (GE0/0/X) | 对照端口 (GE0/0/Y) |
|------|---------------------|---------------------|
| ... | ... | ... |

### 日志关键事件
- [时间] 事件描述

### 🎯 根因分析
(简要结论)

### 🛠️ 修复建议
1. (具体操作步骤)
2. ...
```

## 注意事项

- **Telnet 为明文协议**，完成后需提醒用户改用 SSH
- 华为 VRP 系统分页会显示 `---- More ----`，脚本需处理分页
- 部分命令在不同 VRP 版本中语法有差异，如遇 `Error: Unrecognized command` 需尝试替代命令
- `display arp interface` 仅对三层接口有效，纯二层交换机上该命令返回空是正常现象
- 修改配置前务必提醒用户，先 `display this` 备份当前配置

## 脚本资源

- `scripts/telnet_diag.ps1` — PowerShell 脚本，通过 TCP 直连交换机执行 Telnet 命令，无需安装 Telnet 客户端
- `references/huawei_commands.md` — 华为/H3C VRP 常用诊断命令参考
