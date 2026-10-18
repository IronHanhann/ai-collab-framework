# 样例二：总控 + 两个干活的（三角色）

> 虚构样例。**第一次用不需要这个**——直接看 [structure-two-ai.md](structure-two-ai.md)。
> 这个配置用于：你已经有一个跑顺的项目，想再开一个，又想让某个 AI 统一管规则。

## 为什么需要总控

两个项目各跑各的，会出三件事：

1. **规则漂移**——A 项目改了协议，B 项目不知道，最后两套规则
2. **跨项目私聊**——A 的 AI 直接给 B 的 AI 发消息，绕过了边界，两边都说不清谁该负责
3. **抢编号**——两个项目同时用了 `0042`，合并时撞车

总控就是用来收口这三件事的。**总控是职位不是身份**——`CONTROLLER.md` 里一行就能换人。

## 目录长这样

框架根只有一个总开关，两个项目并列挂在 `projects\` 下：

```
{协作根目录}\
├── SWITCH.md              # 框架级总开关：全停则什么都不干
├── CONTROLLER.md          # 总控是谁（有总控时；见协议第十八节）
├── FRAMEWORK.md           # 协议本体（框架根副本 = 规范源）
├── USER-GUIDE.md          # 给人看的操作手册
└── projects\
    ├── my-project\            # 业务项目（干活的）
    │   ├── SWITCH.md          # 项目级开关：停了只跳过 my-project
    │   ├── ROLE.md            # 写明"我不是总控，我只守 my-project"
    │   ├── STATE.md
    │   ├── PARTICIPANTS.md
    │   ├── IDENTITY.md
    │   ├── inbox-ai-a\
    │   ├── inbox-ai-b\
    │   └── archive\
    │
    └── controller-project\    # 总控项目（管规则的）
        ├── CONTROLLER.md      # 当前总控是谁
        ├── SWITCH.md
        ├── ROLE.md            # 写明"我是总控"
        ├── STATE.md
        ├── inbox-controller\  # 固定收件箱，所有项目的问题都投这
        ├── inbox-ai-a\
        └── archive\
```

> `STATE.md` / `DECISIONS.md` / `HEARTBEAT.md` / `LEASES.md` / `PROGRESS.md` / `SWITCH.md`
> 这六个是**项目级**文件，只在 `projects\<项目名>\` 下；框架根除了一个总开关，
> 只剩协议规定的 `CONTROLLER.md`（有总控时）+ `FRAMEWORK.md` + `USER-GUIDE.md`。
> 各自的骨架见 [root-files.md](root-files.md)。

两个项目的 AI **各自只读自己的 `ROLE.md`**，不跨项目翻文件。

## 跨项目必须走总控中转

```
my-project 的 ai-a 想找 controller-project 的 ai-b
  ↓ 不许直接发
发到 controller-project\inbox-controller\
  ↓ 总控收到
总控转发到 controller-project\inbox-ai-b\
```

**为什么不让"知道对方存在就直接发"**：跨项目完全隔离是原则。一旦允许私聊，
边界就烂了——最后没人说得清某条消息该归哪个项目负责。

## 总控该干什么

| 事 | 谁干 |
|---|---|
| 改全局规则（`FRAMEWORK.md` / 根 `SWITCH.md` / 根 `template\`） | 只有总控 |
| 紧急 bug 修复 | 任何方都能改 |
| 协议变更广播 | 总控往每个**活跃项目**的各参与者收件箱各发一条 |
| 接收问题报告 | 总控收件箱，收到要回 ack |
| 分消息号段 | 总控 |

## 总控失联了怎么办

1. **不自动接管**——没有竞价、没有选举，避免两个总控打架
2. 业务项目照常跑，只是规则暂时不改
3. 紧急 bug 自己修完，广播出去
4. 新总控由**用户**指定，不是 AI 内部晋升

> 判定失联看 `.alive` 的 mtime（30 分钟没动），**不是** `HEARTBEAT.md`——
> 那是共享文件，任何人写一笔都会刷新它的 mtime。
