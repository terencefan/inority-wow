# Develop Guide

这个文件只放开发和检查相关内容。产品说明、架构、模块职责和 UI 结构仍留在 [README.md](../../README.md)。

## Git Hooks

> 这一段说明提交前检查如何通过 Git hook 自动执行。

- 仓库内的 pre-commit hook 入口在 [.githooks/pre-commit](../../.githooks/pre-commit)。
- 它在 WSL / Linux 下统一调用 [tools/check.sh](../../tools/check.sh)，并保留 [tools/check.ps1](../../tools/check.ps1) 作为 Windows PowerShell 手动入口，把现有静态检查和 Lua tests 串成一次提交前检查。
- 安装脚本默认用 [tools/install_git_hooks.sh](../../tools/install_git_hooks.sh)，并保留 [tools/install_git_hooks.ps1](../../tools/install_git_hooks.ps1) 作为 Windows PowerShell 入口。

安装：

```bash
bash ./tools/install_git_hooks.sh
```

或：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\install_git_hooks.ps1
```

安装后，`git commit` 会自动执行：
- `luac -p`
- `luacheck`
- `LuaLS`
- `stylua --check`
- Lua tests / validators

## LuaCheck

> 这一段说明 Lua 语法和静态问题检查的入口与运行方式。

- 项目已接入根目录配置文件：[.luacheckrc](../../.luacheckrc)
- 运行脚本：WSL / Linux 用 [tools/run_luacheck.sh](../../tools/run_luacheck.sh)，Windows PowerShell 用 [tools/run_luacheck.ps1](../../tools/run_luacheck.ps1)
- 默认检查范围：
  - `src/`
  - `tests/`
  - `tools/`
- WoW AddOn 常用全局已在 `.luacheckrc` 里做了白名单，避免把 Blizzard API 误报成未定义全局。

本机如果还没有 `luacheck`，先安装：

```powershell
luarocks install luacheck
```

然后运行：

```bash
bash ./tools/run_luacheck.sh
```

如果要把 warning 也视为失败：

```bash
bash ./tools/run_luacheck.sh --fail-on-warnings
```

说明：
- `luacheck` 依赖 `luafilesystem`
- 在 Windows 上如果 LuaRocks 只能拿到源码包，还需要本地 C 编译器才能完成安装

## StyLua

> 这一段说明 Lua 格式检查和写回格式的入口。

- 项目已接入格式配置：[.stylua.toml](../../.stylua.toml)
- 运行脚本：WSL / Linux 用 [tools/run_stylua.sh](../../tools/run_stylua.sh)，Windows PowerShell 用 [tools/run_stylua.ps1](../../tools/run_stylua.ps1)
- 当前仓库已接入格式入口；脚本会在 `stylua` 缺失时直接报错提醒安装

检查格式：

```bash
bash ./tools/run_stylua.sh --check
```

写回格式：

```bash
bash ./tools/run_stylua.sh
```

## LuaLS

> 这一段说明 Lua Language Server 的检查入口和工作区配置。

- 项目已接入工作区配置：[.luarc.json](../../.luarc.json)
- LuaLS 本地 stub 库：[types/wow-globals.lua](../../types/wow-globals.lua)
- 命令行检查脚本：WSL / Linux 用 [tools/run_luals_check.sh](../../tools/run_luals_check.sh)，Windows PowerShell 用 [tools/run_luals_check.ps1](../../tools/run_luals_check.ps1)
- 目标运行时固定为 `Lua 5.1`
- 常用 Blizzard / SavedVariables 全局和动态 WoW table 字段已预先声明，减少编辑器误报
- 需要本机自行安装 `lua-language-server` 或 `lua_ls`
- 如果刚装完 LuaLS 而当前终端还认不到命令，重开一个 shell 再试

默认运行：

```bash
bash ./tools/run_luals_check.sh
```

如果要把 LuaLS warning 也视为失败：

```bash
bash ./tools/run_luals_check.sh --fail-on-warnings
```

说明：
- 默认模式下，LuaLS 只把真实 `Error` 级诊断当作失败
- WoW AddOn 项目里低信号的动态环境诊断已在 `.luarc.json` 里降噪
- `types/` 目录被加入了 LuaLS workspace library，编辑器跳转和补全会直接读取这些 stub

## JSCPD（可选）

> 这一段说明重复代码检查的入口和范围。

- 项目已接入重复代码检查配置：[.jscpd.json](../../.jscpd.json)
- 命令行检查脚本：[tools/run_jscpd.ps1](../../tools/run_jscpd.ps1)
- 默认检查范围：
  - `src/`
  - `Locale/`
  - `tests/`
  - `tools/`

运行：

```powershell
npm install -g jscpd
powershell -ExecutionPolicy Bypass -File .\tools\run_jscpd.ps1
```

如果要把重复块也视为失败：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_jscpd.ps1 -FailOnClones
```

说明：
- 推荐使用 `npm install -g jscpd`
- 只要 `jscpd` 在 `PATH` 上，脚本也可以配合其他全局工具管理方式使用
- `dist/` 已排除，不参与重复代码统计
- 默认 unified check / pre-commit 不再包含重复代码扫描；只有显式运行 `run_jscpd.ps1` 时才会执行

## VS Code Tasks

> 这一段说明仓库内预设的 VS Code 任务入口。

- 已接入任务入口：[.vscode/tasks.json](../../.vscode/tasks.json)
- 可直接运行：
  - `MogTracker: check`
  - `MogTracker: check (skip format)`
  - `MogTracker: luacheck`
  - `MogTracker: LuaLS`
  - `MogTracker: jscpd`
  - `MogTracker: tests`

## Unified Check

> 这一段说明统一检查脚本如何串起所有开发检查步骤。

- 统一检查入口：WSL / Linux 用 [tools/check.sh](../../tools/check.sh)，Windows PowerShell 用 [tools/check.ps1](../../tools/check.ps1)
- Lua 测试与 mock 校验入口：WSL / Linux 用 [tools/run_lua_tests.sh](../../tools/run_lua_tests.sh)，Windows PowerShell 用 [tools/run_lua_tests.ps1](../../tools/run_lua_tests.ps1)

默认顺序：
- `luac -p`
- `luacheck`
- `LuaLS`
- `stylua --check`
- Lua tests / validators


