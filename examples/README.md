# 脱敏样例 / Sanitized Examples

> ⚠️ **这是脱敏样例，不是真实项目数据。**
> 所有参与者名、消息内容、时间戳、路径**全部是虚构的**，只用来展示"一个跑起来的项目长什么样"。
> 真实项目数据不进仓库——`projects/` 已写进 `.gitignore`。

## 怎么浏览

| 文件 | 看什么 |
|---|---|
| [structure-two-ai.md](structure-two-ai.md) | 两个 AI 的最小项目——**第一次用，看这个就够了** |
| [structure-three-role.md](structure-three-role.md) | 总控 + 两个干活的，多项目协作才需要 |
| [messages.md](messages.md) | 一次完整往返：task → result → ack |
| [root-files.md](root-files.md) | STATE / SWITCH / DECISIONS / HEARTBEAT / LEASES / PROGRESS 六个状态文件的骨架 |

## 建议顺序

1. 先看 [structure-two-ai.md](structure-two-ai.md)，对着 `template/` 复制一遍，项目就起来了
2. 再看 [messages.md](messages.md)，知道一条消息长什么样、回执怎么写
3. 跑起来之后回头看 [root-files.md](root-files.md)，知道那六个文件该往里填什么
4. 总控那一套（三角色、跨项目）等你真的有第二个项目再说

## 命名约定

样例里统一用 `ai-a` / `ai-b` 指代参与者。真实项目里换成你自己的名字就行——
**名字只是槽位名，不是模型名**（这条是 [template/IDENTITY.md](../template/IDENTITY.md) 的第一节）。
