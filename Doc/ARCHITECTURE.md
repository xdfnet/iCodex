# iCodex 架构文档

> 版本 3.0.0 · macOS 菜单栏应用 · Zero external dependencies

---

## 概述

**iCodex** 是一个运行在 macOS 菜单栏的配置与补丁工具。

DeepSeek 官方已原生支持 Responses API（OpenAI 格式兼容），因此 **Codex 直接连接 `https://api.deepseek.com`**，iCodex 不再做本地协议中转。iCodex 核心负责两件事（另提供菜单栏余额查询）：

1. **配置**：向 `~/.codex/config.toml` 写入直连 DeepSeek 的 provider 配置（`base_url` + `wire_api` + `model_catalog_json`）
2. **补丁**：等长替换 Codex 桌面版 `app.asar` 中的模型白名单过滤表达式，让 DeepSeek 模型出现在模型列表中

请求链路：

```text
Codex ──responses API──→ https://api.deepseek.com
                             ↑
       （iCodex 只写配置、打补丁，不参与请求转发）
```

---

## 分层架构

```text
┌──────────────────────────────────────────────┐
│               UI Layer (AppKit)               │
│  MenuBarController  ApiKeyConfigWindow       │
└──────────────────────┬────────────────────────┘
                       │ 持有
                       ▼
┌──────────────────────────────────────────────┐
│             State Layer (CodexState)          │
│  apiKey · model · codexEnabled · 模型列表缓存 │
│  UserDefaults 持久化                          │
└─────────┬────────────────────────────────────┘
          │ owns
          ▼
┌──────────────────────────────────────────────┐
│          CodexConfigManager                   │
│  写入 ~/.codex/config.toml + models.json      │
│  └─ owns ─ CodexAppPatcher                    │
│             等长替换 app.asar 白名单表达式     │
└──────────────────────────────────────────────┘
```

### 模块结构

```text
📦 iCodexCore (library)
├── Models/
│   └── CodexConfig.swift    # ModelInfo 数据模型
└── Services/
    └── Logger.swift          # 异步文件日志

📦 iCodex (executable, depends on iCodexCore)
├── iCodexApp.swift           # @main 入口 + API Key 配置窗口
├── MenuBarController.swift   # NSStatusItem 菜单栏（模型/补丁/配置）
├── Models/
│   └── CodexState.swift      # 全局状态（apiKey/model/codexEnabled）
└── Services/
    ├── CodexConfigManager.swift  # ~/.codex/config.toml 管理
    └── CodexAppPatcher.swift # Codex 桌面 App 白名单补丁
```

---

## 核心流程

### 开启模型

```text
用户点「开启模型」
  └─ toggleCodex() → syncCodexConfig()
      └─ CodexConfigManager.enable(model:, apiKey:)
          ├─ 写入 ~/.codex/config.toml
          │   model_provider = "deepseek"
          │   model = "deepseek-v4-flash"
          │   model_catalog_json = "~/.codex/models.json"
          │   forced_login_method = "api"   # 禁用 ChatGPT 账号登录，强制 API Key 认证
          │
          │   [model_providers.deepseek]
          │   name = "deepseek"
          │   base_url = "https://api.deepseek.com"
          │   wire_api = "responses"
          │   experimental_bearer_token = "<apiKey>"   # Codex 直连时用作 Bearer 认证
          └─ 写入 ~/.codex/models.json（DeepSeek 模型元数据）
```

> `base_url` 不带 `/v1`：DeepSeek 官方 Responses 端点即 `https://api.deepseek.com/responses`；Codex 拼接 `base_url + /responses` 与 `base_url + /models` 均有效。

### 打补丁

```text
用户点「开启补丁」
  └─ patchAppAsar()
      ├─ ensurePermission()   # 检测 App 管理权限，未授权弹窗引导
      ├─ 校验 original 表达式存在
      ├─ 备份 app.asar → app.asar.bak
      └─ 等长替换两处白名单表达式
```

### 关闭模型

```text
用户点「关闭模型」
  └─ disableCodex() → CodexConfigManager.disable()
      ├─ 清 config.toml 中 DeepSeek 配置
      └─ 删 models.json
```

---

## 持久化

| 存储位置 | 内容 | 读写时机 |
|---|---|---|
| `UserDefaults` key `icodex_apiKey` | DeepSeek API Key | 配置窗口保存时 |
| `UserDefaults` key `icodex_model` | 当前模型 ID | 切换模型时 |
| `UserDefaults` key `icodex_codexEnabled` | Codex 集成开关 | 开关模型时 |
| `UserDefaults` key `icodex_models` | 模型列表缓存 | 拉取模型列表后 |
| `~/.codex/config.toml` | Codex 直连配置 | 开模型/切模型时写，关模型时清 |
| `~/.codex/models.json` | 模型目录（DeepSeek） | 同上 |
| `/Applications/ChatGPT.app/.../app.asar` | Codex 桌面 App 前端包 | 打补丁时备份 + 等长替换 |
| `~/.config/icodex/icodex.log` | 运行日志 | 每行日志异步追加 |

---

## 关键设计决策

### 零外部依赖

全部基于 Apple 内置框架（AppKit + Foundation + SwiftUI），无任何第三方库。

### 直连而非中转

v3.0.0 起移除本地 HTTP 中转。原因：DeepSeek 官方原生支持 Responses API，本地 `Responses↔Chat` 协议转换（约 400 行）已无必要；直连减少一层故障点，且官方语义化 SSE 事件直接用。

### 等长补丁

补丁用 `Data.replaceSubrange` 做字节等长替换，不改变 `app.asar` 长度，避免依赖 `npx asar` 重新打包。打补丁前校验：每个 original 恰好出现一次、patched 尚未存在、两者长度相等。

---

## 限制

1. **API Key 明文存储** — UserDefaults + config.toml 的 `experimental_bearer_token`，非钥匙串
2. **DeepSeek Responses 模型受限** — 官方目前仅支持 `deepseek-v4-flash`，`deepseek-v4-pro` 预计 2026 年 8 月初上线
3. **asar 补丁依赖 bundle 字符串** — Codex 更新后表达式可能变化

## 版本历史

### 2026-08-01：v3.0.0 直连改造
- 移除本地中转代理：删除 `HTTPServer` / `RelayHandler` / `ChatClient` / `ProviderConfig` 及全部协议转换（`RelayHandlerTests` 同步删除）
- Codex 直连 DeepSeek 官方 Responses API（`base_url = "https://api.deepseek.com"`，`wire_api = "responses"`）
- 菜单「开启/关闭代理」改为「开启/关闭模型」；删除数据流图标闪烁，图标改为 `house.fill`
- 默认模型过渡为 `deepseek-v4-flash`（官方 pro 上线后恢复）

### v2.2.x：本地中转（历史）
- 本地 HTTPServer (8787) 模拟 Responses 协议，转 Chat Completions 后转发 DeepSeek
