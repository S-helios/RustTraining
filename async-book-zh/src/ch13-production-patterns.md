# 第 13 章：生产实践模式 🔴

> **你将学到什么：**
> - 使用 `watch` 通道与 `select!` 实现优雅关闭
> - 背压：有界通道如何防止内存耗尽
> - 使用 `JoinSet` 与 `TaskTracker` 管理任务组生命周期
> - 超时、重试和指数退避
> - 错误处理：`thiserror`、`anyhow` 与双 `?` 模式
> - Tower：Axum、Tonic、Hyper 使用的中间件模式

## 优雅关闭

生产服务器必须干净地关闭：完成进行中的请求、刷新缓冲区并关闭连接。

```rust
use tokio::signal;
use tokio::sync::watch;

async fn main_server() {
    // Create a shutdown signal channel
    let (shutdown_tx, shutdown_rx) = watch::channel(false);

    // Spawn the server
    let mut server_handle = tokio::spawn(run_server(shutdown_rx.clone()));

    // Wait for Ctrl+C
    signal::ctrl_c().await.expect("Failed to listen for Ctrl+C");
    println!("Shutdown signal received, finishing in-flight requests...");

    // Notify all tasks to shut down
    // NOTE: .unwrap() is used for brevity. Production code should handle
    // the case where all receivers have been dropped.
    shutdown_tx.send(true).unwrap();

    // Wait for server to finish (with timeout)
    match tokio::time::timeout(
        std::time::Duration::from_secs(30),
        &mut server_handle,
    ).await {
        Ok(Ok(())) => println!("Server shut down gracefully"),
        Ok(Err(e)) => eprintln!("Server error: {e}"),
        Err(_) => {
            eprintln!("Server shutdown timed out — aborting remaining tasks");
            server_handle.abort();
            let _ = server_handle.await;
        }
    }
}

async fn run_server(mut shutdown: watch::Receiver<bool>) {
    let mut connections = tokio::task::JoinSet::new();

    loop {
        tokio::select! {
            // 这里有意采用固定优先级：一旦能够观察到关闭状态，
            // 就不要抢先接收另一个已经就绪的新连接。
            biased;

            changed = shutdown.changed() => {
                if changed.is_err() || *shutdown.borrow() {
                    println!("Stopping accepting new connections");
                    break;
                }
            }
            // 正常运行期间及时回收已完成任务，避免其输出一直积累到关闭阶段。
            Some(result) = connections.join_next(), if !connections.is_empty() => {
                if let Err(e) = result {
                    eprintln!("Connection task failed: {e}");
                }
            }
            // Accept new connections
            conn = accept_connection() => {
                let shutdown = shutdown.clone();
                connections.spawn(handle_connection(conn, shutdown));
            }
        }
    }

    // 所有连接都观察同一个关闭状态。由于 JoinHandle 仍保存在 JoinSet 中，
    // run_server 返回时可以保证连接任务确实全部结束，而不是变成失联的后台任务。
    while let Some(result) = connections.join_next().await {
        if let Err(e) = result {
            eprintln!("Connection task failed during shutdown: {e}");
        }
    }
}

async fn handle_connection(conn: Connection, mut shutdown: watch::Receiver<bool>) {
    loop {
        tokio::select! {
            request = conn.next_request() => {
                // Process the request fully — don't abandon mid-request
                process_request(request).await;
            }
            changed = shutdown.changed() => {
                if changed.is_err() || *shutdown.borrow() {
                    // Finish current request, then exit
                    break;
                }
            }
        }
    }
}
```

```mermaid
sequenceDiagram
    participant OS as 操作系统信号
    participant Main as 主任务
    participant WCH as watch 通道
    participant W1 as 工作任务 1
    participant W2 as 工作任务 2

    OS->>Main: SIGINT (Ctrl+C)
    Main->>WCH: send(true)
    WCH-->>W1: changed()
    WCH-->>W2: changed()

    Note over W1: 完成当前请求
    Note over W2: 完成当前请求

    W1-->>Main: 任务完成
    W2-->>Main: 任务完成
    Main->>Main: 所有工作任务结束 → 退出
```

### 使用有界通道实现背压

如果生产者快于消费者，无界通道可能最终耗尽内存。生产环境应优先使用有界通道：

```rust
use tokio::sync::mpsc;

async fn backpressure_example() {
    // Bounded channel: max 100 items buffered
    let (tx, mut rx) = mpsc::channel::<WorkItem>(100);

    // Producer: slows down naturally when buffer is full
    let producer = tokio::spawn(async move {
        for i in 0..1_000_000 {
            // send() is async — waits if buffer is full
            // This creates natural backpressure!
            tx.send(WorkItem { id: i }).await.unwrap();
        }
    });

    // Consumer: processes items at its own pace
    let consumer = tokio::spawn(async move {
        while let Some(item) = rx.recv().await {
            process(item).await; // Slow processing is OK — producer waits
        }
    });

    let _ = tokio::join!(producer, consumer);
}

// Compare with unbounded — DANGEROUS:
// let (tx, rx) = mpsc::unbounded_channel(); // No backpressure!
// Producer can fill memory indefinitely
```

### 任务组：JoinSet 与 TaskTracker

`JoinSet` 把相关任务组织成一组，使所有者能够收集每个结果并避免任务失联。它有助于建立结构化的任务生命周期，但自身并不提供完整的结构化并发保证：取消策略、错误传播以及丢弃任务组的含义，仍必须由应用明确设计。

```rust
use tokio::task::JoinSet;
use tokio::time::{sleep, Duration};

async fn structured_concurrency() {
    let mut set = JoinSet::new();

    // Spawn a batch of tasks
    for url in get_urls() {
        set.spawn(async move {
            fetch_and_process(url).await
        });
    }

    // Collect all results (order not guaranteed)
    let mut results = Vec::new();
    while let Some(result) = set.join_next().await {
        match result {
            Ok(Ok(data)) => results.push(data),
            Ok(Err(e)) => eprintln!("Task error: {e}"),
            Err(e) => eprintln!("Task panicked: {e}"),
        }
    }

    // ALL tasks are done here — no dangling background work
    println!("Processed {} items", results.len());
}

// TaskTracker (tokio-util 0.7.9+) — wait for all spawned tasks
use tokio_util::task::TaskTracker;

async fn with_tracker() {
    let tracker = TaskTracker::new();

    for i in 0..10 {
        tracker.spawn(async move {
            sleep(Duration::from_millis(100 * i)).await;
            println!("Task {i} done");
        });
    }

    // close() 把跟踪器标记为已关闭，使 wait() 能在集合为空时完成。
    // 它既不会取消任务，也不会禁止之后继续 spawn。
    // 应用还必须通过所有权或协议单独阻止生产者继续添加工作。
    tracker.close();
    tracker.wait().await; // 等待当前跟踪的全部任务结束
    println!("All tasks finished");
}
```

### 超时与重试

```rust
use tokio::time::{timeout, sleep, Duration};

// Simple timeout
async fn with_timeout() -> Result<Response, Error> {
    match timeout(Duration::from_secs(5), fetch_data()).await {
        Ok(Ok(response)) => Ok(response),
        Ok(Err(e)) => Err(Error::Fetch(e)),
        Err(_) => Err(Error::Timeout),
    }
}

// timeout() 在期限到达时通过丢弃内部 Future 来取消操作。
// 只有当操作具有取消安全性时才应直接这样使用；否则应把操作放入可跟踪任务，
// 并明确规定它是否可以在后台继续完成。网络服务通常应维护一个端到端 deadline
// 预算，再从中派生更短的连接、读取、写入与空闲期限，而不是每一层都重新获得完整超时。

// Exponential backoff retry
async fn retry_with_backoff<F, Fut, T, E>(
    max_attempts: u32,
    base_delay_ms: u64,
    operation: F,
) -> Result<T, E>
where
    F: Fn() -> Fut,
    Fut: std::future::Future<Output = Result<T, E>>,
    E: std::fmt::Display,
{
    let mut delay = Duration::from_millis(base_delay_ms);

    for attempt in 1..=max_attempts {
        match operation().await {
            Ok(result) => return Ok(result),
            Err(e) => {
                if attempt == max_attempts {
                    eprintln!("Final attempt {attempt} failed: {e}");
                    return Err(e);
                }
                eprintln!("Attempt {attempt} failed: {e}, retrying in {delay:?}");
                sleep(delay).await;
                delay *= 2; // Exponential backoff
            }
        }
    }
    unreachable!()
}

// Usage:
// let result = retry_with_backoff(3, 100, || async {
//     reqwest::get("https://api.example.com/data").await
// }).await?;
```

> **生产提示——加入抖动**：上面的函数使用纯指数退避。如果许多客户端同时失败，它们会在相同时间点重试，形成“惊群”。应加入随机*抖动（jitter）*，例如 `sleep(delay + rand_jitter)`，其中 `rand_jitter` 取 `0..delay/4`，把重试分散到不同时间。

### 异步代码中的错误处理

异步带来了独特的错误传播问题：派生任务形成错误边界，超时会包装内层错误，而 Future 跨任务边界时 `?` 的层次也会发生变化。

**`thiserror` 与 `anyhow`**——选择合适工具：

```rust
// thiserror: Define typed errors for libraries and public APIs
// Every variant is explicit — callers can match on specific errors
use thiserror::Error;

#[derive(Error, Debug)]
enum DiagError {
    #[error("IPMI command failed: {0}")]
    Ipmi(#[from] IpmiError),

    #[error("Sensor {sensor} out of range: {value}°C (max {max}°C)")]
    OverTemp { sensor: String, value: f64, max: f64 },

    #[error("Operation timed out after {0:?}")]
    Timeout(std::time::Duration),

    #[error("Task panicked: {0}")]
    TaskPanic(#[from] tokio::task::JoinError),
}

// anyhow: Quick error handling for applications and prototypes
// Wraps any error — no need to define types for every case
use anyhow::{Context, Result};

async fn run_diagnostics() -> Result<()> {
    let config = load_config()
        .await
        .context("Failed to load diagnostic config")?;  // Adds context

    let result = run_gpu_test(&config)
        .await
        .context("GPU diagnostic failed")?;              // Chains context

    Ok(())
}
// anyhow prints: "GPU diagnostic failed: IPMI command failed: timeout"
```

| Crate | 使用场景 | 错误类型 | 匹配方式 |
|-------|----------|-----------|----------|
| `thiserror` | 库代码、公开 API | `enum MyError { ... }` | `match err { MyError::Timeout => ... }` |
| `anyhow` | 应用、CLI、脚本 | 擦除类型的 `anyhow::Error` | `err.downcast_ref::<MyError>()` |
| 组合使用 | 库暴露 `thiserror`，应用用 `anyhow` 包装 | 兼得两者优势 | 库保持类型信息，应用简化传播 |

`tokio::spawn` 的**双 `?` 模式**：

```rust
use thiserror::Error;
use tokio::task::JoinError;

#[derive(Error, Debug)]
enum AppError {
    #[error("HTTP error: {0}")]
    Http(#[from] reqwest::Error),

    #[error("Task panicked: {0}")]
    TaskPanic(#[from] JoinError),
}

async fn spawn_with_errors() -> Result<String, AppError> {
    let handle = tokio::spawn(async {
        let resp = reqwest::get("https://example.com").await?;
        Ok::<_, reqwest::Error>(resp.text().await?)
    });

    // Double ?: First ? unwraps JoinError (task panic), second ? unwraps inner Result
    let result = handle.await??;
    Ok(result)
}
```

**错误边界问题**——`tokio::spawn` 容易丢失上下文：

```rust
// ❌ Error context is lost across spawn boundaries:
async fn bad_error_handling() -> Result<()> {
    let handle = tokio::spawn(async {
        some_fallible_work().await  // Returns Result<T, SomeError>
    });

    // handle.await returns Result<Result<T, SomeError>, JoinError>
    // The inner error has no context about what task failed
    let result = handle.await??;
    Ok(())
}

// ✅ Add context at the spawn boundary:
async fn good_error_handling() -> Result<()> {
    let handle = tokio::spawn(async {
        some_fallible_work()
            .await
            .context("worker task failed")  // Context before crossing boundary
    });

    let result = handle.await
        .context("worker task panicked")??;  // Context for JoinError too
    Ok(())
}
```

**超时错误**——包装还是替换：

```rust
use tokio::time::{timeout, Duration};

async fn with_timeout_context() -> Result<String, DiagError> {
    let dur = Duration::from_secs(30);
    match timeout(dur, fetch_sensor_data()).await {
        Ok(Ok(data)) => Ok(data),
        Ok(Err(e)) => Err(e),                      // Inner error preserved
        Err(_) => Err(DiagError::Timeout(dur)),     // Timeout → typed error
    }
}
```

### Tower：中间件模式

[Tower](https://docs.rs/tower) 定义了可组合的 `Service` trait，是 Rust 异步中间件的骨架，`axum`、`tonic`、`hyper` 都使用它：

```rust
// Tower's core trait (simplified):
pub trait Service<Request> {
    type Response;
    type Error;
    type Future: Future<Output = Result<Self::Response, Self::Error>>;

    fn poll_ready(&mut self, cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>>;
    fn call(&mut self, req: Request) -> Self::Future;
}
```

中间件包装 `Service`，无需修改内部逻辑即可添加日志、超时、限流等横切能力：

```rust
use tower::{ServiceBuilder, timeout::TimeoutLayer, limit::RateLimitLayer};
use std::time::Duration;

let service = ServiceBuilder::new()
    .layer(TimeoutLayer::new(Duration::from_secs(10)))       // Outermost: timeout
    .layer(RateLimitLayer::new(100, Duration::from_secs(1))) // Then: rate limit
    .service(my_handler);                                     // Innermost: your code
```

**为什么重要**：若你用过 ASP.NET 或 Express.js 中间件，Tower 就是 Rust 中的对应物。生产级 Rust 服务借此添加横切能力，而不复制业务代码。

### 练习：工作池的优雅关闭

<details>
<summary>🏋️ 练习（点击展开）</summary>

**挑战**：构建一个任务处理器，包含基于通道的工作队列、N 个工作任务，并能在 Ctrl+C 时优雅关闭。先停止接收新工作，再排空已接收的排队工作并完成在途工作，然后退出。

<details>
<summary>🔑 答案</summary>

```rust
use tokio::sync::mpsc;
use tokio::time::{sleep, Duration};

struct WorkItem { id: u64, payload: String }

#[tokio::main]
async fn main() {
    let (work_tx, work_rx) = mpsc::channel::<WorkItem>(100);
    let work_rx = std::sync::Arc::new(tokio::sync::Mutex::new(work_rx));

    let mut handles = Vec::new();
    for id in 0..4 {
        let rx = work_rx.clone();
        handles.push(tokio::spawn(async move {
            loop {
                let item = {
                    let mut rx = rx.lock().await;
                    rx.recv().await
                };
                match item {
                    Some(work) => {
                        println!("Worker {id}: processing {}", work.id);
                        sleep(Duration::from_millis(200)).await;
                    }
                    None => break,
                }
            }
        }));
    }

    // 生产者独占唯一的 Sender。生产者停止后，通道会在所有已接收工作
    // 排空后关闭。
    let producer = tokio::spawn(async move {
        for i in 0..20 {
            if work_tx
                .send(WorkItem { id: i, payload: format!("task-{i}") })
                .await
                .is_err()
            {
                break;
            }
            sleep(Duration::from_millis(50)).await;
        }
    });

    // On Ctrl+C: signal shutdown, wait for workers
    // NOTE: .unwrap() is used for brevity — handle errors in production.
    tokio::signal::ctrl_c().await.unwrap();
    // 停止准入。中止生产者会丢弃最后一个 Sender；Worker 仍可接收
    // 所有已经进入队列的工作。
    producer.abort();
    let _ = producer.await;

    // 已关闭的通道排空后，recv() 才会返回 None。
    for h in handles { let _ = h.await; }
    println!("Shut down cleanly.");
}
```

</details>
</details>

> **要点回顾——生产实践模式**
> - 使用 `watch` 通道与 `select!` 协调优雅关闭
> - 有界通道 `mpsc::channel(N)` 提供**背压**：缓冲区满时，发送者异步等待
> - `JoinSet` 与 `TaskTracker` 有助于跟踪和等待任务组；应用仍需定义如何停止接收新工作、如何取消以及如何传播错误
> - 为网络工作设置明确的端到端 deadline 预算和分阶段期限，并确认超时后丢弃 Future 具有取消安全性
> - Tower 的 `Service` trait 是生产级 Rust 服务的标准中间件模式

> **另请参阅：** [第 8 章——深入 Tokio](ch08-tokio-deep-dive.md) 的通道与同步原语；[第 12 章——常见陷阱](ch12-common-pitfalls.md) 的关闭过程取消风险。

***
