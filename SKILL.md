---
name: campus-network-troubleshoot
description: >
  校园网/企业网故障远程排查技能。当用户提到交换机故障、端口不通、不能上网、
  网络诊断、交换机排查、华为/H3C/华三交换机管理、VLAN排查、
  网线故障、链路抖动、端口协商、私接DHCP、IP冲突、设备无法上网等场景时自动触发。
  支持 Telnet 远程连接华为/H3C 交换机执行批量诊断命令并输出分析报告。
---

# 校园网/企业网故障排查技能

远程连接华为/H3C 交换机，自动执行诊断命令，分析根因并给出修复建议。

## 前置条件

向用户确认或从上下文推断：
- **交换机 IP** — 若用户未提供则主动询问
- **管理密码** — 默认 Telnet 端口 23
- **故障定位信息** — 端口号 / 房间名 / 设备 MAC / IP 地址

## 连接方式

使用 `scripts/telnet_diag.ps1` 脚本（无需安装 Telnet 客户端）：

```powershell
powershell -File scripts/telnet_diag.ps1 -Ip <ip> -Password <pw> -Cmd "命令;命令"
```

**连接前检查**：先 `ping` + `Test-NetConnection -Port 23` 确认可达。

---

## 诊断场景

### 场景 A：房间不能上网（物理层排查）

触发条件：用户反馈某房间断网、网速慢、时断时续。

**步骤**：
1. `display interface GigabitEthernet X/X/X` — 关注：
   - **current state**：UP 还是 DOWN？
   - **Speed**：100M 还是 1000M？100M = 网线可能只有 4 芯通
   - **CRC / Total Error**：>0 则物理层有问题
   - **Last 300 seconds input/output rate**：流量是否为零
2. `display logbuffer | include X/X/X` — 检查是否有 UP/DOWN 日志
3. 如果用户提供正常工作的对照端口，执行对比诊断（见场景 D）

**判断依据**：

| 症状 | 诊断 | 处理 |
|------|------|------|
| 频繁 UP/DOWN + 100M | 网线物理损伤（4 芯通） | 更换网线或重新打水晶头 |
| 频繁 UP/DOWN + 1000M + CRC>0 | 网线接触不良 | 重新插拔或更换 |
| 端口 DOWN 且无历史 UP 记录 | 对端关机或线缆断开 | 检查房间设备 |
| 端口 UP 但流量为 0 | 设备未获取 IP 或未开机 | 检查设备网络配置 |

**参考案例**：
- GE0/0/5（106 房间）：100M 速率 + 频繁 UP/DOWN → 网线损伤
- GE0/0/21（107 希沃）：1000M 但 CRC=99 + 频繁 UP/DOWN → 线缆接触不良
- GE0/0/13（101 希沃）：1000M + CRC=0 + 流量正常 → 物理层完好，问题在 DHCP

### 场景 B：设备获取到错误 IP（DHCP 冲突排查）

触发条件：用户反馈设备拿到 192.168.x.x 而非预期的 10.x.x.x。

**诊断逻辑**：
当设备获取的 IP 网段与校园网规划不一致（如 192.168.10.x 而非 10.10.x.x），说明 VLAN 内存在**私接 DHCP 服务器**（通常来自家用路由器 LAN 口反插）。

**排查步骤**：
1. 确认故障设备所在的 VLAN：
   ```
   display port vlan GigabitEthernet X/X/X
   ```
2. 查看该 VLAN 所有 MAC 地址，排查非学校设备（按端口统计设备数）：
   ```
   display mac-address vlan <VID>
   ```
3. 通过排除法缩小范围：逐个 shutdown 可疑端口，观察故障设备是否恢复正常
4. 若无法物理定位，直接启用 DHCP Snooping 封堵（见场景 E）

**关键认知**：DHCP Discover 是广播帧，私接路由器的 DHCP 应答会泛洪到整个 VLAN，影响同 VLAN 下所有房间——不是只影响私接设备所在的房间。

**参考案例**：VLAN 1210 内某设备 DHCP 分发 192.168.10.x → 101 希沃拿到 192.168.10.4 → 无法上网。排除 106 房间和 19 房间后，最终通过 DHCP Snooping 全局封堵。

### 场景 C：通过 IP/MAC 定位设备物理位置

触发条件：用户知道设备 IP 或 MAC 后缀，需要找到它在哪个端口。

**步骤**：
1. 若用户只知 IP，先让用户在能正常上网的电脑上 `arp -a` 查对应的 MAC
2. 在交换机上按 MAC 查找：
   ```
   display mac-address | include <MAC后4位>
   ```
   或按 VLAN 缩小范围：
   ```
   display mac-address vlan <VID>
   ```
3. 找到 Learned-From 字段即为物理端口

**注意**：纯二层交换机无法通过 `display arp` 查到接入设备的 IP（只有交换机自己有 IP 的 VLAN 才有 ARP 表），必须通过 MAC 表定位。

**参考案例**：用户提供 MAC 后缀 55F7 → `display mac-address vlan 1210` → 找到 `7424-ca1e-55f7` on GE0/0/13（101 希沃）。

### 场景 D：故障端口 vs 正常端口对比诊断

触发条件：用户提供一个能正常上网的对照端口。

**操作**：对两个端口依次执行：

```
display interface GigabitEthernet X/X/X
display port vlan GigabitEthernet X/X/X
display mac-address GigabitEthernet X/X/X
display stp interface GigabitEthernet X/X/X
```

**对比关键指标**：

| 指标 | 故障暗示 |
|------|----------|
| Speed 不同 | 线缆问题（故障口降速） |
| CRC 差异大 | 物理层劣化 |
| 出流量极低 vs 正常 | DHCP 失败或设备配置错误 |
| MAC 数量 | 下挂设备是否正常 |
| STP 状态 | Forwarding vs 其他 |
| 历史峰值流量 | 端口是否曾被正常使用 |

### 场景 E：安全配置（DHCP Snooping / 端口隔离）

**启用 DHCP Snooping（防私接 DHCP）**：

```
system-view
dhcp enable
dhcp snooping enable
vlan <VID>
 dhcp snooping enable
 quit
interface GigabitEthernet X/X/X   ← 上行口（Trusted，放行校园网 DHCP）
 dhcp snooping trusted
 quit
# 对所有上行口重复
```

**临时端口隔离（切 VLAN）**：

使用 `scripts/switch.ps1`：
```powershell
.\switch.ps1 -Port 21 -Action off   # 切到隔离 VLAN 444
.\switch.ps1 -Port 21 -Action on    # 恢复到正常 VLAN 1210
```

底层原理：将端口 PVID 从业务 VLAN 切换到无网关的隔离 VLAN，物理链路保持 UP 但三层不通。

### 场景 F：交换机安全审计

检查项：
```
display ssh server status          # SSH 是否开启
display local-user                 # 本地用户列表（注意未知账户如 huawei）
display acl all                    # VTY 访问控制
display users                      # 当前在线用户
display logbuffer | include LOGIN  # 登录审计
```

**注意**：Telnet 明文传输密码，若 SSH 可用应立即切换。

---

## 根因速查表

| 症状 | 根因 | 处理 |
|------|------|------|
| UP/DOWN 抖动 + 100M | 网线 4 芯通 | 换线 |
| UP/DOWN 抖动 + CRC>0 | 线缆接触不良 | 重新插拔或换线 |
| 获取 192.168.x.x | 私接 DHCP | DHCP Snooping 封堵 |
| 端口 UP 但流量≈0 | 设备未获取 IP | 检查 DHCP / 设备配置 |
| DOWN 无抖动历史 | 对端关机或断线 | 查房间 |
| CRC 高 + 碎片多 | 电磁干扰或线缆老化 | 换线 |
| MAC 漂移 | 下游环路 | 查房间交换机接线 |

---

## 脚本工具

| 脚本 | 用途 | 用法 |
|------|------|------|
| `scripts/telnet_diag.ps1` | Telnet 命令执行器 | `-Ip ... -Password ... -Cmd "命令;命令"` |
| `scripts/switch.ps1` | 端口快捷开关 | `-Port 21 -Action off/on` |
| `scripts/dashboard.py` | SNMP 实时监控面板 | Python 启动，浏览器访问 |
| `references/huawei_commands.md` | VRP 命令速查 | 按需查阅 |

## 注意事项

- **Telnet 明文** — 提醒用户改用 SSH
- **分页 `---- More ----`** — 脚本自动处理，会发送空格翻页
- **VRP 版本差异** — `display cpu-usage` `display logbuffer | include` 等命令可能在部分版本报错，需换写法
- **二层交换机无 ARP** — `display arp interface` 返回空是正常的
- **改配置先备份** — `display this` 确认当前配置
- **改完要保存** — `save` + `y`，否则重启丢失
