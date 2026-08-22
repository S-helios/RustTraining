# Async Rust：从 Future 到生产实践（中文版）

这是当前目录中英文原书的完整中文翻译与深入解读版。中文版保持原有章节、示例、练习、图表和交叉引用，并对容易混淆的概念使用统一术语。

## 本地阅读

```bash
cd async-book-zh
mdbook serve --hostname 127.0.0.1 --port 3000
```

浏览器打开 <http://localhost:3000>。

如果系统尚未安装依赖：

```bash
cargo install mdbook mdbook-mermaid
```

## 翻译约定

- Rust 类型、trait、函数、宏、crate 与代码标识符保持英文原名。
- `Future`、`Stream`、`Pin`、`Waker` 等核心抽象保留原名，并在首次出现处解释。
- `poll` 作为 API 名时保持原样，作为动作时译为“轮询”。
- 译者补充内容明确标记为“深入理解”，与原文含义区分。
