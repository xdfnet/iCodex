# iCodex

[![Build](https://github.com/xdfnet/iCodex/actions/workflows/build.yml/badge.svg)](https://github.com/xdfnet/iCodex/actions/workflows/build.yml)
![macOS](https://img.shields.io/badge/macOS-14.0+-brightgreen)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> 纯原生 macOS 菜单栏 App — Codex 直连 DeepSeek 配置工具。
>
> 纯 Swift 实现，**零外部依赖**。菜单栏常驻，即开即用。

## 功能

| 功能 | 说明 |
|------|------|
| 模型开关 | 配置 Codex 直连 DeepSeek 官方 API，默认使用 DeepSeek V4 Flash |
| 余额查询 | 菜单中实时显示 DeepSeek 账户可用余额 |
| API Key | 窗口配置 DeepSeek API Key |
| 模型元数据 | 自动为 Codex 提供完整模型信息，消除 fallback 警告 |

> DeepSeek 官方已原生支持 Responses API，Codex 直接连接 `https://api.deepseek.com`，iCodex 不再做本地协议中转。

## 要求

- macOS 14+
- Xcode 15+ 或 Swift 5.9+

## 安装

### 从 GitHub Releases 下载（推荐）

```bash
curl -sL https://github.com/xdfnet/iCodex/releases/latest/download/iCodex.zip -o /tmp/iCodex.zip
unzip -qo /tmp/iCodex.zip -d /Applications
open /Applications/iCodex.app
```

或一条命令：

```bash
bash <(curl -sL https://raw.githubusercontent.com/xdfnet/iCodex/main/install.sh)
```

> ⚠️ 首次运行需右键 `iCodex.app` → **打开**（未签名应用 Gatekeeper 拦截）

### 从源码构建

```bash
# 需要 Xcode 15+ 或 Swift 5.9+
git clone https://github.com/xdfnet/iCodex.git
cd iCodex
swift run                    # 开发调试
./build.sh                   # 构建正式包
open iCodex.app               # 启动
```

## 使用

1. 启动 iCodex，点击菜单栏图标 → **设置密钥** → 输入 DeepSeek API Key
2. 点击 **开启模型** → 配置 Codex 直连 DeepSeek
3. 开关模型等操作均在菜单栏完成

首次使用后重启 Codex，它会自动从官方 API 获取模型列表。

## 架构

```
NSStatusItem (AppKit)
  ├─ 开启/关闭模型 / 配置 / 退出
  ├─ CodexState     — 全局状态（apiKey / model / codexEnabled）
  │   └─ UserDefaults 持久化 + 模型列表缓存
  └─ CodexConfigManager — ~/.codex/config.toml
      ├─ 写入 model_provider = "deepseek" + base_url，指向官方 API
      └─ 写入 model_catalog_json，让 Codex 正确识别 DeepSeek 模型
```

- **请求链路**：Codex 直连 `https://api.deepseek.com`（官方 Responses API），iCodex 不参与请求转发
- **CodexConfigManager**: 配 Key/切模型时写入 `model_provider = "DeepSeek"`、当前模型、`model_catalog_json`；关模型时清理

## 目录结构

```
Sources/iCodex/
├── iCodexApp.swift              # @main 入口，API Key 配置窗口
├── MenuBarController.swift      # NSStatusItem 菜单栏（模型/配置）
├── Models/
│   └── CodexState.swift         # @Observable 全局状态
└── Services/
    └── CodexConfigManager.swift # ~/.codex/config.toml 和模型 catalog 管理
```

## Codex 兼容性

| 组件 | 支持版本 | 说明 |
|------|---------|------|
| Codex CLI | ≥ 0.142.0 | 通过 `~/.codex/config.toml` 配置直连 |
| Codex 桌面 App | ≥ 26.810 | 通过官方 `model_catalog_json` 识别 DeepSeek 模型，无需补丁 |

## 模型识别

Codex 桌面版通过 `model_catalog_json`（官方扩展机制）读取第三方模型。iCodex 开启模型时写入 `~/.codex/models.json`，其中完整定义 DeepSeek 模型元数据（slug / 上下文窗口 / reasoning levels 等），Codex 会将其直接加入可用模型列表，无需修改 `app.asar`。因此升级 Codex 桌面版不会导致 DeepSeek 模型失效。

## 许可证

MIT
