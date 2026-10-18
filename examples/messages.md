# 样例三：一条完整往返

> 虚构样例。消息内容**全部是编的**，只为展示格式与流程。
> 真实项目里的对话一条都没往这放。

---

## 1. ai-b 派活（task）

`projects\my-project\inbox-ai-a\0042-ai-b-task.md`

```markdown
# TASK-0042

## META
- msg_id: 0042
- from: ai-b
- to: ai-a
- type: task
- time: 2026-10-20T09:15:00+08:00

## BODY

帮我把下面这段翻成中文，保持术语一致：

> Zero-dependency means no SDK to install and no API key to configure.

## CONSTRAINTS

- 术语表见项目根 `notes\glossary.md`
- 只翻译，不要改格式

## EXPECTED

回执写到我的收件箱，命名 0043-ai-a-result.md
```

---

## 2. ai-a 交活（result）

`projects\my-project\inbox-ai-b\0043-ai-a-result.md`

```markdown
# RESULT-0043

## META
- msg_id: 0043
- from: ai-a
- to: ai-b
- type: result
- time: 2026-10-20T09:31:00+08:00
- reply_to: 0042

## BODY

译稿：

> 零依赖意味着不需要安装 SDK，也不需要配置 API key。

术语核对：`zero-dependency` 用「零依赖」（与 glossary 第 3 条一致）。

## NOTES

- glossary 里 `API key` 没有既定译法，保留英文，你定
```

---

## 3. ai-b 确认收到（ack）

`projects\my-project\inbox-ai-a\0044-ai-b-ack.md`

```markdown
# ACK-0044

## META
- msg_id: 0044
- from: ai-b
- to: ai-a
- type: ack
- time: 2026-10-20T09:40:00+08:00
- reply_to: 0043

## BODY

收到，译稿可用。`API key` 保留英文，记进 glossary。

0042 这条我归档了（archive\0042\），你那边不用再动。
```

---

## 4. 归档后的样子

```
archive\
├── 0042\
│   ├── 0042-ai-b-task.md      # 任务原文
│   └── 0043-ai-a-result.md    # 结果
└── 0043\
    └── 0044-ai-b-ack.md       # 确认
```

> **先回 result 再归档**（v1.9 归档纪律）。没回执就归档 = 对方永远不知道你看到了。
> 一条往返闭环（task + result + ack 齐了）才搬进 `archive\<号>\`。

---

## 其他消息类型

| 类型 | 什么时候用 |
|---|---|
| `task` | 派活，带 DELIVERABLE / CONSTRAINTS |
| `result` | 交活，带 NOTES 说不确定的 |
| `ack` | 只确认"我看到了"，不干活 |
| `query` | 提问，等对方答 |
| `notice` | 通知，不要求回应（如"新项目开了"） |
| `broadcast` | 规则变更，投给所有活跃项目的所有参与者 |

**所有类型共用同一个编号池**——`notice` 也占号。发之前先扫已用编号：
两个收件箱 + `archive\` 根 + 各 `EXITED.md` 墓碑。
