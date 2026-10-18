# 定时器 Prompt 模板

> 所有项目、所有 AI 的轮询定时器必须用此模板创建。
> 原则：逻辑全在 poll.ps1 里，定时器 prompt 只负责"触发执行"，不重复脚本已做的判断。

## 能跑 PowerShell 的 AI 侧

### 模板

```
[项目名]轮询（X分）。执行：
powershell -ExecutionPolicy Bypass -File "<框架根目录>\projects\[项目名]\poll.ps1"
开关OFF就结束；有新消息按FRAMEWORK.md处理写inbox-ai-a。
```

### 变量替换

| 占位符 | 说明 | 示例 |
|---|---|---|
| `[项目名]` | 项目目录名 | main / project-a |
| `X分` | 触发分钟 | 0 / 15 / 30 / 45 |

### 示例（main，0分）

```
main轮询（0分）。执行：
powershell -ExecutionPolicy Bypass -File "<框架根目录>\projects\main\poll.ps1"
开关OFF就结束；有新消息按FRAMEWORK.md处理写inbox-ai-a。
```

## 不能跑 PowerShell、需手动执行的 AI 侧

### 模板

```
[项目名]轮询（X分）。
1. 读根SWITCH.md yaml块，enabled=false就结束
2. 读projects/[项目名]/SWITCH.md yaml块，enabled=false或mode=stopped就结束
3. 写inbox-ai-a/.alive=当前时间
4. 列inbox-ai-a/新消息（跳过.alive/.tmp），有则处理写inbox-ai-b
```

### 示例（main，15分）

```
main轮询（15分）。
1. 读根SWITCH.md yaml块，enabled=false就结束
2. 读projects/main/SWITCH.md yaml块，enabled=false或mode=stopped就结束
3. 写inbox-ai-a/.alive=当前时间
4. 列inbox-ai-a/新消息（跳过.alive/.tmp），有则处理写inbox-ai-b
```

## 运行时行为规则（v1.10.2 新增）

### 项目开关 OFF 的三级降级

项目开关读到 `enabled: false` 或 `mode: stopped` 时，**不要立即删定时器**：

| 连续OFF轮数 | 行为 | 说明 |
|---|---|---|
| 第1轮 | 只暂停本轮，写日志标"疑似暂停" | 可能是误关，给一次修正机会 |
| 连续2轮（约 2 个轮询周期） | 把间隔临时拉长到约 4 倍 | 省token但不丢定时器 |
| 连续4轮（~2h） | 才删定时器 | 删前必须先扫一次收件箱，有query/notice先处理 |

状态记录在 STATE.md 的"定时器状态"区块，每轮更新。

### 空转降频（间隔可按需调整，以下为默认节奏）

连续若干轮无新消息时，自动按倍数拉长轮询间隔；一旦有新消息，立即恢复默认间隔：

- 正常：默认 15 分钟（可按需调整）
- 连续空转累积：间隔按倍数拉长（例如拉到 2 倍、4 倍）
- 有新消息：立即恢复默认间隔，不延迟

> 不要写死具体分钟数——不同项目节奏不同，倍数拉长 + 新消息立即恢复即可。

### 定时器合并

轮询 + 租约续期**建议**合并成一条定时器（默认 15 分钟，可按需调整）——本框架默认这么做。但各 AI 平台限制不同：有的平台最小间隔就是 1 小时、有的平台一开始就建了多个错开的定时器；**按你自己的平台限制和原有结构自行决定**是否合并。租约检查只是多读一个文件，合并通常更省事，但这不是硬规定。

## 禁止事项

- 禁止在定时器 prompt 里写详细操作步骤（读ROLE.md、读STATE.md、扫墓碑、算编号等）——这些是 poll.ps1 或 FRAMEWORK.md 的事
- 禁止在定时器 prompt 里写项目特定的业务逻辑——定时器只负责触发，不负责决策
- 定时器 prompt 总长度不超过 200 字（能跑 PowerShell 的 AI 侧）/ 300 字（需手动执行的 AI 侧）
- 创建定时器时必须用本模板，不得自由发挥

## 为什么要这样

1. **省 token**：定时器 prompt 是每轮触发时的输入，越长每轮越费
2. **一致性**：所有项目、所有 AI 用同一格式，新会话/新项目一看就懂
3. **可维护**：逻辑改了只改 poll.ps1 / FRAMEWORK.md，不用逐个改定时器 prompt
4. **防漂移**：早期定时器 prompt 写了详细步骤，后来脚本完善了但 prompt 没跟着精简，导致重复劳动
