## 第 15 章：练习

### 练习 1：异步回显服务器

构建一个能并发处理多个客户端的 TCP 回显服务器。

**要求：**
- 监听 `127.0.0.1:8080`
- 接受连接并逐行回显
- 妥善处理客户端断开
- 客户端连接、断开时打印日志

<details>
<summary>🔑 答案</summary>

```rust
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::TcpListener;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let listener = TcpListener::bind("127.0.0.1:8080").await?;
    println!("Echo server listening on :8080");

    loop {
        let (socket, addr) = listener.accept().await?;
        println!("[{addr}] Connected");

        tokio::spawn(async move {
            let (reader, mut writer) = socket.into_split();
            let mut reader = BufReader::new(reader);
            let mut line = String::new();

            loop {
                line.clear();
                match reader.read_line(&mut line).await {
                    Ok(0) => {
                        println!("[{addr}] Disconnected");
                        break;
                    }
                    Ok(_) => {
                        print!("[{addr}] Echo: {line}");
                        if writer.write_all(line.as_bytes()).await.is_err() {
                            println!("[{addr}] Write error, disconnecting");
                            break;
                        }
                    }
                    Err(e) => {
                        eprintln!("[{addr}] Read error: {e}");
                        break;
                    }
                }
            }
        });
    }
}
```

</details>

---

### 练习 2：带限流的并发 URL 获取器

并发获取一组 URL，同时最多允许 5 个请求在途。

<details>
<summary>🔑 答案</summary>

```rust
use futures::stream::{self, StreamExt};
use tokio::time::{sleep, Duration};

async fn fetch_urls(urls: Vec<String>) -> Vec<Result<String, String>> {
    // buffer_unordered(5) ensures at most 5 futures are polled
    // concurrently — no separate Semaphore needed here.
    let results: Vec<_> = stream::iter(urls)
        .map(|url| {
            async move {
                println!("Fetching: {url}");

                match reqwest::get(&url).await {
                    Ok(resp) => match resp.text().await {
                        Ok(body) => Ok(body),
                        Err(e) => Err(format!("{url}: {e}")),
                    },
                    Err(e) => Err(format!("{url}: {e}")),
                }
            }
        })
        .buffer_unordered(5) // ← This alone limits concurrency to 5
        .collect()
        .await;

    results
}

// NOTE: Use Semaphore when you need to limit concurrency across
// independently spawned tasks (tokio::spawn). Use buffer_unordered
// when processing a stream. Don't combine both for the same limit.
```

</details>

---

### 练习 3：工作池优雅关闭

构建一个任务处理器，其中包含：
- 基于通道的工作队列
- 从队列消费的 N 个工作任务
- Ctrl+C 时优雅关闭：停止接收新工作，完成在途工作

<details>
<summary>🔑 答案</summary>

```rust
use tokio::sync::{mpsc, watch};
use tokio::time::{sleep, Duration};

struct WorkItem {
    id: u64,
    payload: String,
}

#[tokio::main]
async fn main() {
    let (work_tx, work_rx) = mpsc::channel::<WorkItem>(100);
    let (shutdown_tx, shutdown_rx) = watch::channel(false);

    // Spawn 4 workers
    let mut worker_handles = Vec::new();
    let work_rx = std::sync::Arc::new(tokio::sync::Mutex::new(work_rx));

    for id in 0..4 {
        let rx = work_rx.clone();
        let mut shutdown = shutdown_rx.clone();
        let handle = tokio::spawn(async move {
            loop {
                let item = {
                    let mut rx = rx.lock().await;
                    tokio::select! {
                        item = rx.recv() => item,
                        _ = shutdown.changed() => {
                            if *shutdown.borrow() { None } else { continue }
                        }
                    }
                };

                match item {
                    Some(work) => {
                        println!("Worker {id}: processing item {}", work.id);
                        sleep(Duration::from_millis(200)).await; // Simulate work
                        println!("Worker {id}: done with item {}", work.id);
                    }
                    None => {
                        println!("Worker {id}: channel closed, exiting");
                        break;
                    }
                }
            }
        });
        worker_handles.push(handle);
    }

    // Producer: submit some work
    let producer = tokio::spawn(async move {
        for i in 0..20 {
            let _ = work_tx.send(WorkItem {
                id: i,
                payload: format!("task-{i}"),
            }).await;
            sleep(Duration::from_millis(50)).await;
        }
    });

    // Wait for Ctrl+C
    tokio::signal::ctrl_c().await.unwrap();
    println!("\nShutdown signal received!");
    shutdown_tx.send(true).unwrap();
    producer.abort(); // Cancel the producer task

    // Wait for workers to finish
    for handle in worker_handles {
        let _ = handle.await;
    }
    println!("All workers shut down. Goodbye!");
}
```

</details>

---

### 练习 4：从零构建简单异步 Mutex

不使用 `tokio::sync::Mutex`，实现一个异步感知的互斥锁。

*提示*：使用只有 1 个许可的 `tokio::sync::Semaphore` 串行化访问。

<details>
<summary>🔑 答案</summary>

```rust
use std::cell::UnsafeCell;
use std::sync::Arc;
use tokio::sync::{OwnedSemaphorePermit, Semaphore};

pub struct SimpleAsyncMutex<T> {
    data: Arc<UnsafeCell<T>>,
    semaphore: Arc<Semaphore>,
}

// SAFETY: Access to T is serialized by the semaphore (max 1 permit).
unsafe impl<T: Send> Send for SimpleAsyncMutex<T> {}
unsafe impl<T: Send> Sync for SimpleAsyncMutex<T> {}

pub struct SimpleGuard<T> {
    data: Arc<UnsafeCell<T>>,
    _permit: OwnedSemaphorePermit, // Dropped on guard drop → releases lock
}

impl<T> SimpleAsyncMutex<T> {
    pub fn new(value: T) -> Self {
        SimpleAsyncMutex {
            data: Arc::new(UnsafeCell::new(value)),
            semaphore: Arc::new(Semaphore::new(1)),
        }
    }

    pub async fn lock(&self) -> SimpleGuard<T> {
        let permit = self.semaphore.clone().acquire_owned().await.unwrap();
        SimpleGuard {
            data: self.data.clone(),
            _permit: permit,
        }
    }
}

impl<T> std::ops::Deref for SimpleGuard<T> {
    type Target = T;
    fn deref(&self) -> &T {
        // SAFETY: We hold the only semaphore permit, so no other
        // SimpleGuard exists → exclusive access is guaranteed.
        unsafe { &*self.data.get() }
    }
}

impl<T> std::ops::DerefMut for SimpleGuard<T> {
    fn deref_mut(&mut self) -> &mut T {
        // SAFETY: Same reasoning — single permit guarantees exclusivity.
        unsafe { &mut *self.data.get() }
    }
}

// When SimpleGuard is dropped, _permit is dropped,
// which releases the semaphore permit — another lock() can proceed.

// Usage:
// let mutex = SimpleAsyncMutex::new(vec![1, 2, 3]);
// {
//     let mut guard = mutex.lock().await;
//     guard.push(4);
// } // permit released here
```

**关键点**：异步 Mutex 通常建立在 Semaphore 之上。Semaphore 提供异步等待机制：锁被占用时，`acquire()` 暂停任务，直到许可释放。`tokio::sync::Mutex` 内部也是这一类思路。

> **为什么使用 `UnsafeCell`，而不是 `std::sync::Mutex`？** 如果在 `Deref`/`DerefMut` 中对 `Arc<Mutex<T>>` 调用 `.lock().unwrap()`，返回的 `&T` 会借用一个马上被丢弃的临时 `MutexGuard`，因此无法编译。`UnsafeCell` 避开中间 Guard，而 Semaphore 的串行化保证这段 `unsafe` 的有效性。

</details>

---

### 练习 5：Stream 流水线

使用 Stream 构建数据处理流水线：
1. 生成数字 1..=100
2. 过滤出偶数
3. 映射为平方
4. 每次并发处理 10 项（用 sleep 模拟）
5. 收集结果

<details>
<summary>🔑 答案</summary>

```rust
use futures::stream::{self, StreamExt};
use tokio::time::{sleep, Duration};

#[tokio::main]
async fn main() {
    let results: Vec<u64> = stream::iter(1u64..=100)
        // Step 2: Filter evens
        .filter(|x| futures::future::ready(x % 2 == 0))
        // Step 3: Square each
        .map(|x| x * x)
        // Step 4: Process concurrently (simulate async work)
        .map(|x| async move {
            sleep(Duration::from_millis(50)).await;
            println!("Processed: {x}");
            x
        })
        .buffer_unordered(10) // 10 concurrent
        // Step 5: Collect
        .collect()
        .await;

    println!("Got {} results", results.len());
    println!("Sum: {}", results.iter().sum::<u64>());
}
```

</details>

---

### 练习 6：实现带超时的 Select

不使用 `tokio::select!` 或 `tokio::time::timeout`，实现一个让 Future 与截止时间竞速的函数：Future 先完成时返回 `Either::Left(result)`，超时时返回 `Either::Right(())`。

*提示*：以第 6 章的 `Select` 组合器和 `TimerFuture` 为基础。

<details>
<summary>🔑 答案</summary>

```rust,ignore
use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll};
use std::time::Duration;

pub enum Either<A, B> {
    Left(A),
    Right(B),
}

pub struct Timeout<F> {
    future: F,
    timer: TimerFuture, // From Chapter 6
}

impl<F: Future + Unpin> Timeout<F> {
    pub fn new(future: F, duration: Duration) -> Self {
        Timeout {
            future,
            timer: TimerFuture::new(duration),
        }
    }
}

impl<F: Future + Unpin> Future for Timeout<F> {
    type Output = Either<F::Output, ()>;

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        // Check if the main future is done
        if let Poll::Ready(val) = Pin::new(&mut self.future).poll(cx) {
            return Poll::Ready(Either::Left(val));
        }

        // Check if the timer expired
        if let Poll::Ready(()) = Pin::new(&mut self.timer).poll(cx) {
            return Poll::Ready(Either::Right(()));
        }

        Poll::Pending
    }
}

// Usage:
// match Timeout::new(fetch_data(), Duration::from_secs(5)).await {
//     Either::Left(data) => println!("Got data: {data}"),
//     Either::Right(()) => println!("Timed out!"),
// }
```

**关键点**：`select`/`timeout` 本质上只是轮询两个 Future，观察谁先完成。整个异步生态都建立在这个简单原语上：poll、Pending/Ready、Waker。

</details>

***
