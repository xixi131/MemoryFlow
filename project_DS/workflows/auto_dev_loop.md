---
description: 父子 Agent 协作模式：读取 feature_list.json 状态机，循环执行开发、验证、日志更新与提交，直到达到目标任务数或无待办项。
---

# 自动开发工作流

## 人类如何使用

1. 如果是新需求，先用 `$task-init` 把需求拆成 `feature_list.json` 任务队列。
2. 再维护 `codex-progress.md`，保留最近的重要上下文。
3. 在仓库里用 `$auto_dev 完成 1 个任务` 或 `$auto_dev 完成 2 个任务` 触发父代理。
4. 父代理会读取状态机，派发子代理处理第一个 `passes: false` 的任务。
5. 子代理完成后会更新状态、写日志、提交 commit。
6. 如果失败超过阈值，系统会停止并请求人工介入。
