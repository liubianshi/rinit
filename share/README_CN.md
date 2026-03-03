# __PROJECT_NAME__

## 项目简介

在此描述你的研究目标。

## 复现指南

本项目遵循可复现研究工作流。

1. **打开项目**：在编辑器中打开项目目录（VS Code、RStudio 等）。
2. **恢复环境**：运行 `renv::restore()` 安装依赖包（如使用 renv）。
3. **准备数据**：
   - 如使用 DVC：运行 `dvc pull`
   - 否则，确保原始数据已放置在 `/data` 目录下。
4. **运行分析**：
   - 直接执行主脚本：
     `source("R/main.R")`
   - 或使用任务系统：
     `task < 任务名 >` （详见下方 [任务系统](#任务系统)）

## 目录结构

- `/R/`：R 源代码（build、analysis、check、utils）
- `/data/`：原始数据（只读，请勿手动修改）
- `/out/`：生成的输出文件（已加入.gitignore）
- `/cache/`：缓存数据（已加入.gitignore）
- `/doc/`：文档与手稿
- `/log/`：执行日志
- `/template/`：文档模板（CSL、DOCX）
- `/tasks/`：go-task 任务定义（自动生成，请勿手动编辑）

## 任务系统

本项目使用 [go-task](https://taskfile.dev) 进行任务自动化。
任务在 `config.yml` 或 `config.R` 中定义，并自动编译为 `tasks/r_tasks.yml`。

### 安装

```bash
# macOS / Linux（通过官方安装脚本）
sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin

# Arch Linux
pacman -S go-task

# macOS（Homebrew）
brew install go-task
```

### 工作原理

任务在 `config.yml`（或 `config.R`）中以层级结构定义，
包含 `mod` 和 `func` 字段的叶节点即为一个可执行任务：

```yaml
# config.yml
cache:
  data:
    my_dataset: # → 任务名：cache:data:my_dataset
      mod: R/build/Data # box 模块路径（对应 R/build/Data.R）
      func: load_data # 模块中导出的函数名
      update: null # 缓存策略（null = 缓存存在时跳过执行）
      args: null # 传递给函数的参数
```

任务名按配置树的层级以冒号拼接（如 `cache:data:my_dataset`）。

### 定义新任务

任务可在 `config.yml`（静态）或 `config.R`（动态）中定义，两者**不会合并**，
同时存在时 `config.R` 优先（需返回非 `NULL` 值）。

**方式 A：`config.yml`** — 适合简单、静态的任务定义：

```yaml
cache:
  analysis:
    regression:
      mod: R/analysis/Model # box 模块路径（R/analysis/Model.R）
      func: run_regression # 要调用的导出函数
      update: null # 缓存策略（null = 缓存存在时跳过）
      args:
        method: lm
        controls: [age, income]
```

**方式 B：`config.R`** — 适合动态任务定义（如批量循环生成任务）。
文件的**最后一个表达式**作为返回值：

```r
# config.R
datasets <- c("survey", "panel", "census")

cache_tasks <- setNames(
  lapply(datasets, function(d) {
    list(
      mod = paste0("R/build/", d),
      func = "load_data",
      update = NULL,
      args = list(year = 2023)
    )
  }),
  datasets
)

# 最后一个表达式即为返回值
list(
  cache = list(
    data = cache_tasks
  )
)
```

以上配置会生成任务 `cache:data:survey`、`cache:data:panel`、`cache:data:census`。

定义任务后，需重新生成任务文件：

```bash
task build_r_tasks
```

该命令执行 `Rscript -e 'box::use(R/utils/Task); Task$write_taskfile()'`，
更新 `tasks/r_tasks.yml`。

### 执行任务

```bash
# 列出所有可用任务
task --list

# 执行指定任务（冒号分隔层级）
task cache:data:my_dataset

# 执行所有任务（默认）
task

# 强制重新执行任务（忽略缓存）
task --force cache:analysis:regression

# 监视文件变化并自动重建
task --watch build_r_tasks
```

### 任务缓存

任务通过 `cache_result()` 函数实现基于文件的缓存，输出以 `.qs` 格式存储在 `cache/` 目录下，
路径与任务名层级对应：

- `cache:data:my_dataset` → `cache/data/my_dataset/default.qs`

go-task 会追踪 `sources`（输入的 R 模块文件）和 `generates`（输出的缓存文件）。
若源文件自上次运行后未发生变化，任务将被跳过。

### 内置任务

| 任务 | 说明 |
|------|------|
| `build_r_tasks` | 从 `config.yml` / `config.R` 重新生成 `tasks/r_tasks.yml` |
