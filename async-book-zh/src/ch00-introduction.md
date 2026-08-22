# Async Rust：从 Future 到生产实践

## 讲者介绍

- 微软 SCHIE（Silicon and Cloud Hardware Infrastructure Engineering，硅与云硬件基础设施工程）团队首席固件架构师
- 资深业界从业者，专长涵盖安全、系统编程（固件、操作系统、虚拟机监控器）、CPU 与平台架构，以及 C++ 系统开发
- 2017 年在 AWS EC2 开始使用 Rust 编程，此后一直深爱这门语言

---

这是一本深入讲解 Rust 异步编程的指南。多数异步教程从 `tokio::main` 开始，对内部机制一带而过；本书则从第一性原理建立理解——先学习 `Future` trait、轮询与状态机，再逐步进入现实开发模式、运行时选型和生产环境中的常见陷阱。

## 本书适合谁

- 能够编写同步 Rust，却仍对异步感到困惑的 Rust 开发者
- 来自 C#、Go、Python 或 JavaScript，了解 `async/await`，但不了解 Rust 异步模型的开发者
- 曾经被 `Future is not Send`、`Pin<Box<dyn Future>>`，或者“为什么我的程序卡住了？”折磨过的任何人

## 前置知识

你应当熟悉：

- 所有权、借用和生命周期
- trait 与泛型（包括 `impl Trait`）
- 使用 `Result<T, E>` 和 `?` 运算符
- 基础多线程编程（`std::thread::spawn`、`Arc`、`Mutex`）

不要求具备 Rust 异步编程经验。

## 如何使用本书

**第一次请按顺序阅读。** 第一至第三部分层层递进。每一章都包含：

| 符号 | 含义 |
|------|------|
| 🟢 | 初级——基础概念 |
| 🟡 | 中级——需要先理解前面的章节 |
| 🔴 | 高级——深入内部机制或生产实践模式 |

每章包括：

- 章首的 **“你将学到什么”** 提示块
- 面向视觉型学习者的 **Mermaid 图表**
- 带折叠答案的**随堂练习**
- 汇总核心思想的**要点回顾**
- 指向相关章节的**交叉引用**

## 学习进度建议

| 章节 | 主题 | 建议用时 | 阶段目标 |
|------|------|----------|----------|
| 1–5 | 异步机制如何运作 | 6–8 小时 | 能解释 `Future`、`Poll`、`Pin`，以及 Rust 为什么没有内置运行时 |
| 6–10 | 异步生态系统 | 6–8 小时 | 能手工构建 Future、选择运行时并使用 Tokio API |
| 11–13 | 生产级异步编程 | 6–8 小时 | 能用流、正确的错误处理和优雅关闭编写生产级异步代码 |
| 综合项目 | 聊天服务器 | 4–6 小时 | 构建一个融合所有概念的真实异步应用 |

**预计总用时：22–30 小时**

## 完成练习的方式

每个内容章节都有随堂练习。综合项目（第 17 章）会把所有知识整合到一个项目中。为了获得最佳学习效果：

1. **先尝试练习，再展开答案**——真正的学习往往发生在你苦苦思考的时候
2. **亲手输入代码，不要复制粘贴**——形成 Rust 语法的肌肉记忆很重要
3. **运行每个示例**——执行 `cargo new async-exercises`，边学习边测试

## 目录概览

### 第一部分：异步机制如何运作

- [第 1 章：为什么 Rust 的异步与众不同](ch01-why-async-is-different-in-rust.md) 🟢——根本差异：Rust 没有内置运行时
- [第 2 章：Future Trait](ch02-the-future-trait.md) 🟡——`poll()`、`Waker`，以及让整个机制得以运转的契约
- [第 3 章：poll 如何工作](ch03-how-poll-works.md) 🟡——轮询状态机与最小执行器
- [第 4 章：Pin 与 Unpin](ch04-pin-and-unpin.md) 🔴——自引用结构为什么需要固定（pinning）
- [第 5 章：揭开状态机的面纱](ch05-the-state-machine-reveal.md) 🟢——编译器究竟会根据 `async fn` 生成什么

### 第二部分：异步生态系统

- [第 6 章：手工构建 Future](ch06-building-futures-by-hand.md) 🟡——从零实现 TimerFuture、Join 和 Select
- [第 7 章：执行器与运行时](ch07-executors-and-runtimes.md) 🟡——Tokio、smol、async-std、Embassy：如何选择
- [第 8 章：深入 Tokio](ch08-tokio-deep-dive.md) 🟡——运行时类型、spawn、通道和同步原语
- [第 9 章：Tokio 并非最佳选择的场景](ch09-when-tokio-isnt-the-right-fit.md) 🟡——LocalSet、FuturesUnordered 与运行时无关设计
- [第 10 章：异步 Trait](ch10-async-traits.md) 🟡——RPITIT、动态分派、trait_variant 与异步闭包

### 第三部分：生产级异步 Rust

- [第 11 章：Stream 与 AsyncIterator](ch11-streams-and-asynciterator.md) 🟡——异步迭代、AsyncRead/Write 与流组合器
- [第 12 章：常见陷阱](ch12-common-pitfalls.md) 🔴——9 类生产缺陷及其规避方法
- [第 13 章：生产实践模式](ch13-production-patterns.md) 🔴——优雅关闭、背压与 Tower 中间件
- [第 14 章：异步是一种优化，而非架构](ch14-async-is-an-optimization-not-an-architecture.md) 🔴——同步核心/异步外壳与函数“染色”成本

### 附录

- [总结与速查卡](ch16-summary-and-reference-card.md)——快速查询表和决策树
- [综合项目：异步聊天服务器](ch17-capstone-project.md)——构建一个完整的异步应用

> **深入理解：本书的学习主线**
>
> Rust 的 `async/await` 不是一套脱离语言其他部分的“魔法并发系统”。它把异步计算编译成普通 Rust 类型，再由库提供的执行器持续调用 `Future::poll`。因此，所有权、借用、生命周期、`Send`、`Sync` 和 trait 约束都会原封不动地进入异步世界。本书先讲状态机和轮询，再讲 Tokio，正是为了让你理解 Tokio 在替你完成什么，而不只是记住 API。

***
