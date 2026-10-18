# SCRIPT-SPEC — poll / check 脚本契约

> **这份文件是"思路"版**。如果你能跑 PowerShell（Windows），直接复制 `template/poll.ps1` 和 `template/check.ps1` 即可，不用看这份。
> 如果你的环境跑不了 PowerShell（macOS / Linux / 别的 shell），或者你想用自己的语言重写，**照这份契约让 AI 生成脚本**，生成后逐条对照本文件自检。

---

## 0. 通用约定

| 项 | 约定 |
|---|---|
| 运行方式 | 由定时器每轮触发一次，无参数 |
| 输出 | 打印到 stdout 的纯文本报告；不给机器解析用 |
| 退出码 | `0` = 正常（含告警）；`1` = 依赖缺失等致命错误 |
| 时间 | **必须取系统真实时间**，禁止估算、禁止写死 |
| 幂等 | 同一轮重复执行不应产生破坏性副作用 |

---

## 1. poll 脚本（轮询）

### 1.1 什么时候做（判定顺序，**顺序不能变**）

1. **读根开关** `{框架根}/SWITCH.md` 的 ```yaml 代码块
   - `enabled: false` → 打印 `>> OFF`，**直接结束**（不写任何文件）
   - 解析失败 → 打印错误，退出码 `1`
2. **读项目开关** `{项目}/SWITCH.md` 的 ```yaml 代码块
   - `enabled: false` 或 `mode: stopped` → 打印 `>> OFF`，往 `cron-log.md` 记一行，**结束**
   - **`mode: readonly` → 只读模式**：只更新自己的 `.alive`，往 `cron-log.md` 记一行 `readonly`，**结束**。**不得**扫收件箱、**不得**跑 check、**不得**写任何消息文件
3. 只有 `enabled: true` 且 `mode: normal` 才继续

> ⚠️ `readonly` 是最容易漏的一条。漏了它，"只读模式"就是假的——脚本会在只读下照样写日志、跑检查。

### 1.2 正常模式要做什么

| 步骤 | 动作 | 说明 |
|---|---|---|
| a | 写自己的 `.alive` | `{项目}/inbox-{me}/.alive` = 当前时间；写后**回读校验**，不一致则告警 |
| b | （可选）写总控 `.alive` | 仅当自己是总控（`$isController` 等价开关）才写 `inbox-controller/.alive`。**属主制**：不要替别人写 |
| c | 扫所有活跃项目 | 遍历 `{框架根}/projects/*/SWITCH.md`，`enabled: true` 且 `mode` 不是 `stopped`/`readonly` 的算活跃；每个只列 `inbox-*/` 里最新 1 条消息的**文件名 + 时间**，不读内容 |
| d | 查租约 | 读 `{项目}/LEASES.md` 的「活跃租约」表；有未过期租约就打印出来（续租由 AI 决策，脚本不自动续） |
| e | 列自己的收件箱 | `{项目}/inbox-{me}/` 下非 `.alive`、非 `*.tmp` 的消息，按时间倒序；目录不存在要静默处理并打印空态，**不要抛异常** |
| f | 算最大编号 | 扫 `inbox-*` + `archive/`，取 4 位数字前缀的最大值，打印 `Max msg id: N` |
| g | 追加日志 | 往 `{项目}/cron-log.md` 追加一行：`{时间} | poll | idle, msgs: {条数}` |
| h | 调用 check | 最后执行 check 脚本（若存在），其告警**不阻塞** poll |

### 1.3 必须遵守的不变量

- **只读模式绝不写消息文件**、绝不跑 check
- **属主制**：只写自己的 `.alive`
- 任何单步失败都不应让整轮崩溃；用 try/catch 包住并打印原因（含异常消息文本）
- 目录缺失 / 文件缺失一律按"空"处理，不抛红字
- 不修改任何消息文件的内容，不删除任何文件

---

## 2. check 脚本（一致性检查）

### 2.1 必需依赖（缺 = 退出码 1）

- `{框架根}/FRAMEWORK.md`
- `{项目}/SWITCH.md`
- `{项目}/STATE.md`

### 2.2 检查项

| 编号 | 检查 | 级别 |
|---|---|---|
| A | 必需依赖存在 | FAIL（退出码 1） |
| A2 | `FRAMEWORK.md` 里有版本标记 `- vX.Y.Z ——`；取**数值最大**的版本（不要取最后一行，版本表可能乱序） | FAIL |
| B1 | `STATE.md` 声明的「当前版本：框架 vX.Y.Z」与 A2 的最大版本一致 | WARN |
| G1/G2 | `STATE.md` 的「必读索引」里对总开关/项目开关状态的描述，与实际 `SWITCH.md` 一致 | WARN |
| F1 | 同一发送者 + 同一消息类型 在同一编号出现 ≥2 次 | WARN |
| F2 | 已墓碑的收件箱（有 `EXITED.md`）在墓碑之后又收到文件 | WARN |
| F3 | 同一编号同时存在于活跃收件箱与 `archive/`，且收件箱那份比归档新 >1 天（=关闭后被复用） | WARN |
| H1 | 每个 `inbox-*/` 都有自己的 `.alive`（含 `.gitkeep` 的占位目录跳过） | WARN |

> 说明：编号撞号判定要区分「同一 ID 不同发送者」——**请求 + 回复共用同一 ID 是设计内行为**，不算撞号。

### 2.3 输出契约

```
=== Check ===
Framework version: vX.Y.Z
CHECK: OK ({N} versions, no drift)          # 无告警
CHECK: WARN {一行一个问题}                    # 有告警
CHECK: WARN {n} issue(s) found
CHECK: SKIP {跳过的检查项}                    # 可选
CHECK: FAIL {原因}                            # 致命，退出码 1
```

---

## 3. 让 AI 生成脚本时，必须逐条自检

生成完成后，让 AI 自己回答这 8 条，任何一条答不上就等于没做完：

1. 项目开关 `mode: readonly` 时会怎样？会不会误写消息或跑 check？
2. 项目开关 `enabled: false` 时会怎样？有没有在结束前写了不该写的文件？
3. 根开关 `enabled: false` 时会怎样？
4. 自己的收件箱目录不存在时会怎样？会不会红字/崩溃？
5. `.alive` 写入失败时，日志里能不能看到**原因**？
6. 会不会替别人写 `.alive`（违反属主制）？
7. 活跃项目扫描里，`readonly` 的项目会不会被当成"待处理"？
8. `check` 的版本号取的是"数值最大"还是"最后一行"？（版本表可能乱序，取最后一行是错的）
9. **项目开关是 `enabled: true` 时，有没有一个真的在跑的定时器？**（`poll` 脚本只在"被唤醒"时才有机会工作——定时器不存在，开关开着也等于停摆。脚本管不了定时器的注册，这条只能由 AI 在搭建/启用时自觉确认，并在项目 `STATE.md` 记下定时器 id 与最近一次触发时间）

---

## 4. 与现成脚本的对应关系

| 契约条目 | `template/poll.ps1` 位置 | `template/check.ps1` 位置 |
|---|---|---|
| readonly 分支 | `if ($projMode -eq "readonly")` | — |
| 属主制 `.alive` | `inbox-$me/.alive` + `if ($isController)` | — |
| 活跃项目扫描 | `Active Projects Overview` 段 | — |
| 编号最大值 | `foreach ($dir in @(...))` + `Measure-Object -Maximum` | F1/F3 |
| 版本取最大 | — | `$maxVer` 循环 |
