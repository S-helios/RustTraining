# 总结与速查卡

## 快速参考

### 异步心智模型

```text
┌─────────────────────────────────────────────────────┐
│  async fn → 状态机（enum）→ impl Future             │
│  .await   → poll() 内层 Future                      │
│  执行器    → loop { poll(); 休眠直到被唤醒; }          │
│  Waker    → “执行器，请再次 poll 我”                  │
│  Pin      → “保证我不会在内存中移动”                  │
└─────────────────────────────────────────────────────┘
```

### 常见模式速查

| 目标 | 使用 |
|------|-----|
| 并发运行两个 Future | `tokio::join!(a, b)` |
| 让两个 Future 竞速 | `tokio::select! { ... }` |
| 派生后台任务 | `tokio::spawn(async { ... })` |
| 在异步中运行阻塞代码 | `tokio::task::spawn_blocking(\|\| { ... })` |
| 限制并发量 | `Semaphore::new(N)` |
| 收集多个任务结果 | `JoinSet` |
| 跨任务共享状态 | `Arc<Mutex<T>>` 或通道 |
| 优雅关闭 | `watch::channel` + `select!` |
| Stream 每次并发处理 N 项 | `.buffer_unordered(N)` |
| 给 Future 设置超时 | `tokio::time::timeout(dur, fut)` |
| 退避重试 | 自定义组合器（见第 13 章） |

### 固定（Pinning）速查

| 场景 | 使用 |
|-----------|-----|
| 在堆上固定 Future | `Box::pin(fut)` |
| 在栈上固定 Future | `tokio::pin!(fut)` |
| 固定 `Unpin` 类型 | `Pin::new(&mut val)`——安全、无额外成本 |
| 返回已固定的 trait 对象 | `-> Pin<Box<dyn Future<Output = T> + Send>>` |

### 通道选择指南

| 通道 | 生产者 | 消费者 | 值 | 使用场景 |
|---------|-----------|-----------|--------|----------|
| `mpsc` | N | 1 | 连续消息 | 工作队列、事件总线 |
| `oneshot` | 1 | 1 | 单值 | 请求/响应、完成通知 |
| `broadcast` | N | N | 每人收到全部 | 扇出通知、关闭信号 |
| `watch` | 1 | N | 只保留最新值 | 配置更新、健康状态 |

### Mutex 选择指南

| Mutex | 使用场景 |
|-------|----------|
| `std::sync::Mutex` | 短时间持锁，绝不跨 `.await` |
| `tokio::sync::Mutex` | 必须跨 `.await` 持锁 |
| `parking_lot::Mutex` | 竞争较高、无 `.await`、注重性能 |
| `tokio::sync::RwLock` | 读多写少，并且锁会跨 `.await` |

### 决策速查

```text
需要并发？
├── I/O 密集 → async/await
├── CPU 密集 → Rayon / std::thread
└── 混合 → CPU 部分使用 spawn_blocking

选择运行时？
├── 服务器应用 → Tokio
├── 库 → 与运行时无关（futures crate）
├── 嵌入式 → Embassy
└── 极简 → smol

需要并发 Future？
├── 满足 'static + Send → tokio::spawn
├── 满足 'static 但 !Send → LocalSet
├── 无法满足 'static → FuturesUnordered
└── 需要跟踪/中止 → JoinSet
```

### 常见错误与修复

| 错误 | 原因 | 修复 |
|-------|-------|-----|
| `future is not Send` | 跨 `.await` 保存了 `!Send` 类型 | 让该值在 `.await` 前析构，或使用 `current_thread` |
| spawn 中借用值存活不够久 | `tokio::spawn` 要求 `'static` | 使用 `Arc`、`clone()` 或 `FuturesUnordered` |
| `Future is not implemented for ()` | 缺少 `.await` | 为异步调用添加 `.await` |
| poll 中无法可变借用 | 自引用借用问题 | 正确使用 `Pin<&mut Self>`（见第 4 章） |
| 程序静默挂起 | 忘记调用 `waker.wake()` | 每条 `Pending` 路径都必须登记并最终触发 Waker |

### 延伸阅读

| 资源 | 推荐理由 |
|----------|-----|
| [Tokio Tutorial](https://tokio.rs/tokio/tutorial) | 官方动手指南，适合第一个项目 |
| [Async Book（官方）](https://rust-lang.github.io/async-book/) | 从语言层讲解 `Future`、`Pin`、`Stream` |
| [Jon Gjengset — Crust of Rust: async/await](https://www.youtube.com/watch?v=ThjvMReOXYM) | 两小时现场编码，深入内部机制 |
| [Alice Ryhl — Actors with Tokio](https://ryhl.io/blog/actors-with-tokio/) | 有状态服务的生产架构模式 |
| [Without Boats — Pin, Unpin, and why Rust needs them](https://without.boats/blog/pin/) | 语言设计者对 Pin 动机的原始说明 |
| [Tokio mini-Redis](https://github.com/tokio-rs/mini-redis) | 完整且适合研读的异步 Rust 项目 |
| [Tower 文档](https://docs.rs/tower) | Axum、Tonic、Hyper 使用的中间件架构 |

***

*Async Rust 培训指南正文完*
