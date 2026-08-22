<div style="background-color: #d9d9d9; padding: 16px; border-radius: 6px; color: #000000;">

**License** This project is dual-licensed under the [MIT License](LICENSE) and [Creative Commons Attribution 4.0 International (CC-BY-4.0)](LICENSE-DOCS).

</div>

<div style="background-color: #d9d9d9; padding: 16px; border-radius: 6px; color: #000000;">

**Trademarks** This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general). Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship. Any use of third-party trademarks or logos are subject to those third-party's policies.

</div>

# Rust Training Books

Eight training courses covering Rust from different programming backgrounds, plus deep-dives on async, advanced patterns, engineering practices, and a categorized technical notes blog.

This material combines original content with ideas and examples inspired by some of the best resources in the Rust ecosystem. The goal is to present an in-depth, technically accurate curriculum that weaves together knowledge scattered across books, blogs, conference talks, and video series into a cohesive, pedagogically structured experience.

> **Disclaimer:** These books are training material, not an authoritative reference. While we strive for accuracy, always verify critical details against the [official Rust documentation](https://doc.rust-lang.org/) and the [Rust Reference](https://doc.rust-lang.org/reference/).

### Inspirations & Acknowledgments

- [**The Rust Programming Language**](https://doc.rust-lang.org/book/) — the foundation everything builds on
- [**Jon Gjengset**](https://www.youtube.com/c/JonGjengset) — deep-dive streams on advanced Rust internals, `Crust of Rust` series
- [**withoutboats**](https://without.boats/blog/) — async design, `Pin`, and the futures model
- [**fasterthanlime (Amos)**](https://fasterthanli.me/) — systems programming from first principles, engaging long-form explorations
- [**Mara Bos**](https://marabos.nl/) — *Rust Atomics and Locks*, concurrency primitives
- [**Aleksey Kladov (matklad)**](https://matklad.github.io/) — Rust analyzer insights, API design, error handling patterns
- [**Niko Matsakis**](https://smallcultfollowing.com/babysteps/) — language design, borrow checker internals, Polonius
- [**Rust by Example**](https://doc.rust-lang.org/rust-by-example/) and [**Rustonomicon**](https://doc.rust-lang.org/nomicon/) — practical patterns and unsafe deep-dives
- [**This Week in Rust**](https://this-week-in-rust.org/) — community discoveries that shaped many examples
- [**Binary Musings - Tag(Rust)**](https://binarymusings.org/posts/category/rust/) — Deep dive into Rust internals 
- …and many others in the **Rust community at large** whose blog posts, conference talks, RFCs, and forum discussions have informed this material — too numerous to list individually, but deeply appreciated

## 📖 Start Reading

Pick the book that matches your background. Books are grouped by complexity so you can chart a learning path:

| Level | Description |
|-------|-------------|
| 🟢 **Bridge** | Learn Rust coming from another language — start here |
| 🔵 **Deep Dive** | Focused exploration of a major Rust subsystem |
| 🟡 **Advanced** | Patterns and techniques for experienced Rustaceans |
| 🟣 **Expert** | Cutting-edge type-level and correctness techniques |
| 🟤 **Practices** | Engineering, tooling, and production readiness |

| Book | Level | Who it's for |
|------|-------|-------------|
| [**Rust for C/C++ Programmers**](https://microsoft.github.io/RustTraining/c-cpp-book/) | 🟢 Bridge | Move semantics, RAII, FFI, embedded, no_std |
| [**Rust for C# Programmers**](https://microsoft.github.io/RustTraining/csharp-book/) | 🟢 Bridge | Swift / C# / Java → ownership & type system |
| [**Rust for Python Programmers**](https://microsoft.github.io/RustTraining/python-book/) | 🟢 Bridge | Dynamic → static typing, GIL-free concurrency |
| [**Async Rust**](https://microsoft.github.io/RustTraining/async-book/) | 🔵 Deep Dive | Tokio, streams, cancellation safety |
| [**Async Rust 中文版**](https://sunp.xyz/async-book-zh/) | 🔵 Deep Dive | Future、Pin、执行器、Tokio、Stream 与生产实践的完整中文翻译和深入解读 |
| [**Xihe 的技术笔记**](https://sunp.xyz/notes-blog/) | 📝 Notes | AI Agent、Pi Harness、Rust 与工程实践的分类双语笔记 |
| [**Rust Patterns**](https://microsoft.github.io/RustTraining/rust-patterns-book/) | 🟡 Advanced | Pin, allocators, lock-free structures, unsafe |
| [**Type-Driven Correctness**](https://microsoft.github.io/RustTraining/type-driven-correctness-book/) | 🟣 Expert | Type-state, phantom types, capability tokens |
| [**Rust Engineering Practices**](https://microsoft.github.io/RustTraining/engineering-book/) | 🟤 Practices | Build scripts, cross-compilation, CI/CD, Miri |

Each book has 15–16 chapters with Mermaid diagrams, editable Rust playgrounds, exercises, and full-text search.

> **Tip:** Browse the rendered books with sidebar navigation and search at the [GitHub Pages site](https://microsoft.github.io/RustTraining/).
>
> **Local preview:** For offline reading or while contributing ([install Rust](https://rustup.rs/) first):
> ```
> git clone https://github.com/microsoft/RustTraining.git
> cd RustTraining
> cargo install mdbook mdbook-mermaid
> cargo xtask serve    # http://localhost:3000
> ```

---

## 🔧 For Maintainers

<details>
<summary>Building, serving, and editing the books locally</summary>

### Prerequisites

Install [Rust via **rustup**](https://rustup.rs/) if you haven't already, then:

```bash
cargo install mdbook@0.4.52 mdbook-mermaid@0.14.0
```

### Clone the repo

```bash
git clone https://github.com/microsoft/RustTraining.git
cd RustTraining
```

### Build & serve

```bash
cargo xtask build               # Build all books into site/ (local preview)
cargo xtask serve               # Build and serve at http://localhost:3000
cargo xtask deploy              # Build all books into docs/ (for GitHub Pages)
cargo xtask clean               # Remove site/ and docs/
```

To build or serve a single book:

```bash
cd c-cpp-book && mdbook serve --open    # http://localhost:3000
```

### Deployment

The site auto-deploys to GitHub Pages on push to `main` via `.github/workflows/pages.yml`. No manual steps needed.

</details>
