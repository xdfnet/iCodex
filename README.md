# iRelay

[![Build](https://github.com/xdfnet/iRelay/actions/workflows/build.yml/badge.svg)](https://github.com/xdfnet/iRelay/actions/workflows/build.yml)
![macOS](https://img.shields.io/badge/macOS-14.0+-brightgreen)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> 纯原生 macOS 菜单栏 App — Codex 直连 DeepSeek 配置 + 白名单补丁工具。
>
> 纯 Swift 实现，**零外部依赖**。菜单栏常驻，即开即用。

## 功能

| 功能 | 说明 |
|------|------|
| 模型开关 | 配置 Codex 直连 DeepSeek 官方 API，默认使用 DeepSeek V4 Flash |
| 补丁开关 | 独立修补 Codex 桌面版模型白名单过滤，与模型配置解耦 |
| 权限检查 | 操作前检测 App 管理权限，未授权弹窗引导 |
| 余额查询 | 菜单中实时显示 DeepSeek 账户可用余额 |
| API Key | 窗口配置 DeepSeek API Key |
| 模型元数据 | 自动为 Codex 提供完整模型信息，消除 fallback 警告 |

> DeepSeek 官方已原生支持 Responses API，Codex 直接连接 `https://api.deepseek.com`，iRelay 不再做本地协议中转。

## 要求

- macOS 14+
- Xcode 15+ 或 Swift 5.9+

## 安装

### 从 GitHub Releases 下载（推荐）

```bash
curl -sL https://github.com/xdfnet/iRelay/releases/latest/download/iRelay.zip -o /tmp/iRelay.zip
unzip -qo /tmp/iRelay.zip -d /Applications
open /Applications/iRelay.app
```

或一条命令：

```bash
bash <(curl -sL https://raw.githubusercontent.com/xdfnet/iRelay/main/install.sh)
```

> ⚠️ 首次运行需右键 `iRelay.app` → **打开**（未签名应用 Gatekeeper 拦截）

### 从源码构建

```bash
# 需要 Xcode 15+ 或 Swift 5.9+
git clone https://github.com/xdfnet/iRelay.git
cd iRelay
swift run                    # 开发调试
./build.sh                   # 构建正式包
open iRelay.app               # 启动
```

## 使用

1. 启动 iRelay，点击菜单栏图标 → **设置密钥** → 输入 DeepSeek API Key
2. 点击 **开启补丁** → 授权 App 管理权限 → 修补 Codex 模型白名单
3. 点击 **开启模型** → 配置 Codex 直连 DeepSeek
4. 开关模型、打补丁等均在菜单栏操作

首次使用后重启 Codex，它会自动从官方 API 获取模型列表。

## 架构

```
NSStatusItem (AppKit)
  ├─ 开启/关闭模型 / 开启/关闭补丁 / 配置 / 退出
  ├─ RelayState     — 全局状态（apiKey / model / codexEnabled）
  │   └─ UserDefaults 持久化 + 模型列表缓存
  └─ CodexConfigManager — ~/.codex/config.toml
      ├─ 写入 model_provider = "deepseek" + base_url，指向官方 API
      ├─ 写入 model_catalog_json，让 Codex 正确识别 DeepSeek 模型
      └─ CodexAppPatcher — 修补桌面 App 模型白名单过滤
```

- **请求链路**：Codex 直连 `https://api.deepseek.com`（官方 Responses API），iRelay 不参与请求转发
- **CodexConfigManager**: 配 Key/切模型时写入 `model_provider = "DeepSeek"`、当前模型、`model_catalog_json`；关模型时清理
- **CodexAppPatcher**: 等长替换 `app.asar` 中白名单过滤表达式，去除模型过滤

## 目录结构

```
Sources/iRelay/
├── iRelayApp.swift              # @main 入口，API Key 配置窗口
├── MenuBarController.swift      # NSStatusItem 菜单栏（模型/补丁/配置）
├── Models/
│   └── RelayState.swift         # @Observable 全局状态
└── Services/
    ├── CodexConfigManager.swift # ~/.codex/config.toml 和模型 catalog 管理
    └── CodexAppPatcher.swift    # Codex 桌面 App 模型菜单补丁
```

## Codex 兼容性

| 组件 | 支持版本 | 说明 |
|------|---------|------|
| Codex CLI | ≥ 0.142.0 | 通过 `~/.codex/config.toml` 配置直连 |
| Codex 桌面 App | 26.727.51351 | 修补 `app.asar` 两处模型白名单过滤（主 UI + list-models-for-host，已实测兼容含 amazonBedrock 分支的新版） |

> ⚠️ **补丁机制依赖 asar 中 minified JS 的变量名**，每次 Codex 桌面版升级后变量名可能变化（如 `s→l→u→i/e/r`）或新增过滤点，导致补丁失效。届时需更新 iRelay 重新适配。

## Codex 桌面 App 适配

Codex 桌面 App 前端会读取远端 Statsig 模型白名单。某些版本中白名单只包含 `gpt-*` 模型，并启用了 `use_hidden_models`，导致 DeepSeek 模型被过滤，模型菜单显示为空。即使 Codex 直连 DeepSeek 官方 API，只要模型不在桌面版白名单中，仍需补丁才能出现在模型选择器中。

iRelay 提供独立的「开启补丁/关闭补丁」菜单项，修补 Codex 桌面版前会先检测 `App 管理`权限，未授权则弹窗引导。

补丁方式是等长替换前端过滤表达式，避免依赖 `npx asar` 或其他外部工具。每次修补前会重新备份（删旧→建新），保证备份始终对应当前 Codex 版本。

补丁与模型配置完全解耦：关闭模型配置不会还原补丁，关闭补丁也不会影响直连配置。

## 许可证

MIT
