# xihe dev

独立的分类博客，使用 mdBook 构建。目前首先收录 Pi Agent Harness v2 设计文档的完整中英文对照翻译。

## 本地构建

```bash
mdbook build
mdbook serve
```

若从 RustTraining 根目录使用聚合命令：

```bash
cargo xtask build
cargo xtask serve  # 仅在确实需要预览时启动 localhost:3000
```
