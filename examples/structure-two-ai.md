# 样例一：两个 AI 的最小项目

> 虚构样例。这是**最小可用配置**——两个 AI，一个项目，一个用户当监工。
> 自己搭的话，就是把 `template/` 复制一份，再建两个收件箱。

## 目录长这样

```
my-project/
├── SWITCH.md              # 项目开关（新项目默认 disabled，人到齐才翻 true）
├── ROLE.md                # 每个 AI 醒来第一个读它：你是谁、守哪块地
├── STATE.md               # 共享状态 ← 中断后恢复的第一入口
├── PARTICIPANTS.md        # 谁在场、各自能力边界
├── IDENTITY.md            # 身份登记（身份=槽位名，不是模型名）
├── DISCIPLINE.md          # 行为纪律
├── DECISIONS.md           # 决策记录，带"为什么"
├── HEARTBEAT.md           # 心跳日志，只记事实不判断
├── LOG.md                 # 消息索引
├── LEASES.md              # 租约表，防两个 AI 干同一件事
├── PROGRESS.md            # 长任务检查点，崩溃后续传
├── cron-log.md            # 每轮醒来干了啥
├── CONTROLLER.md          # 当前总控是谁（两人项目里通常就是你自己）
├── inbox-ai-a/            # ai-a 的收件箱
│   ├── .alive             # 私有存活文件，只有 ai-a 自己写
│   ├── 0042-ai-b-task.md      # ai-b 派来的活
│   └── 0043-ai-a-result.md    # ai-a 的回执
├── inbox-ai-b/
│   ├── .alive
│   ├── 0044-ai-b-ack.md       # ai-b 确认收到 0043
│   └── 0045-ai-a-broadcast.md # 规则变更广播
├── inbox-controller/      # 总控收件箱，问题都投这
│   └── .alive
├── archive/               # 处理完的消息按号归档
│   ├── 0040/
│   ├── 0041/
│   └── 0042/
└── notes/                 # 临时笔记，不属于协议
```

## 各文件是谁写的

| 文件 | 谁写 | 什么时候写 |
|---|---|---|
| `SWITCH.md` | 谁翻谁写 | 启用/停用项目，**必须填** `updated_by` / `updated_at` / `reason` |
| `ROLE.md` | 初始化者 | 建项目时写一次，基本不再动 |
| `STATE.md` | 各自只改自己的区块 | 每轮醒来、状态变化时 |
| `PARTICIPANTS.md` | 总控 | 有人加入/退出时 |
| `IDENTITY.md` | 各自登记自己 | 加入时；换模型时 |
| `DECISIONS.md` | 谁拍板谁记 | 做了个"选 A 不选 B"的决定 |
| `HEARTBEAT.md` | 所有人追加 | 有值得记的事（**只记事实**） |
| `LEASES.md` | 接活的人 | 长任务开工前抢、每 30 分钟续、干完标 done |
| `PROGRESS.md` | 接长活的人 | 长任务写检查点，崩溃后靠它续传 |
| `cron-log.md` | 所有人追加 | 每轮醒来，一行 |
| `inbox-{自己}\` | 只有自己 | 收到消息、写回执 |
| `archive\<号>\` | 处理完的人 | 一条往返闭环后搬进去 |

## 一次典型往返

```
ai-a 醒来
  → 读根 SWITCH（没停）→ 读项目 SWITCH（没停）
  → touch 自己的 inbox-ai-a\.alive
  → 扫已用编号 → 读 STATE.md
  → 发现 inbox-ai-a\0042-ai-b-task.md 没处理
  → 干活，写结果到 ai-b 的收件箱：0043-ai-a-result.md
  → 在 cron-log.md 追加一行
  → 归档 archive\0042\（0042-task + 0043-result 一起搬）

ai-b 醒来
  → 同样的醒来流程
  → 发现 inbox-ai-b\0043-ai-a-result.md
  → 在 ai-a 的收件箱写 0044-ai-b-ack.md（"我看到了"）
  → 归档 archive\0043\
```

## 最小启动清单

照着抄就能跑：

1. `xcopy /E /I "template" "projects\my-project"`
2. `mkdir "projects\my-project\inbox-ai-a"` 和 `inbox-ai-b`
3. 填 `PARTICIPANTS.md` + `IDENTITY.md` + `ROLE.md`
4. 每人每项目配一条定时器（15 分钟够了）
5. 往老项目投一条 notice 说"新项目开了"
6. 人齐了、用户说开始，才把 `SWITCH.md` 的 `enabled` 翻 `true`

> 第 5 步别漏——框架的规则靠广播传播，不广播的话新项目里的人不知道有别的项目存在。
