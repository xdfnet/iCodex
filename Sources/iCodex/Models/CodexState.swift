import Foundation
import Combine
import iCodexCore

@MainActor
final class CodexState: ObservableObject {
    @Published var model: String = "deepseek-v4-flash" {
        didSet { UserDefaults.standard.set(model, forKey: Self.modelKey) }
    }
    @Published var availableModels: [ModelInfo] = CodexState.loadModels()
    @Published var apiKey: String = "" {
        didSet { UserDefaults.standard.set(apiKey, forKey: Self.keychainKey) }
    }
    @Published var codexEnabled: Bool {
        didSet { UserDefaults.standard.set(codexEnabled, forKey: Self.codexKey) }
    }
    /// Codex 直连的 DeepSeek 上游地址
    let upstream = "https://api.deepseek.com"

    private static let keychainKey = "icodex_apiKey"
    static let modelKey = "icodex_model"
    private static let codexKey = "icodex_codexEnabled"
    private static func saveModels(_ models: [ModelInfo]) {
        guard let data = try? JSONEncoder().encode(models) else { return }
        UserDefaults.standard.set(data, forKey: "icodex_models")
    }

    nonisolated static func loadModels() -> [ModelInfo] {
        guard let data = UserDefaults.standard.data(forKey: "icodex_models"),
              let models = try? JSONDecoder().decode([ModelInfo].self, from: data),
              !models.isEmpty
        else {
            return [
                ModelInfo(id: "deepseek-v4-flash", description: "DeepSeek V4 Flash"),
                ModelInfo(id: "deepseek-v4-pro", description: "DeepSeek V4 Pro"),
            ]
        }
        return models
    }

    let codexConfigManager = CodexConfigManager()
    static let version = "3.0.0"

    /// 一次性迁移旧版 iRelay 的 UserDefaults key → iCodex
    private static func migrateLegacyKeys() {
        let pairs: [(String, String)] = [
            ("irelay_apiKey", "icodex_apiKey"),
            ("irelay_model", "icodex_model"),
            ("irelay_codexEnabled", "icodex_codexEnabled"),
            ("irelay_models", "icodex_models"),
        ]
        let d = UserDefaults.standard
        for (old, new) in pairs {
            if let v = d.object(forKey: old), d.object(forKey: new) == nil {
                d.set(v, forKey: new)
                d.removeObject(forKey: old)
            }
        }
    }

    /// 实时读文件判断补丁状态
    var isCodexPatched: Bool { codexConfigManager.isPatched }

    init() {
        Self.migrateLegacyKeys()
        apiKey = UserDefaults.standard.string(forKey: Self.keychainKey) ?? ""
        model = UserDefaults.standard.string(forKey: Self.modelKey) ?? "deepseek-v4-flash"
        codexEnabled = UserDefaults.standard.object(forKey: Self.codexKey) as? Bool ?? true

        // 升级迁移：此前已开启且配置了 Key 时，把 config.toml 同步为直连 DeepSeek
        if codexEnabled, !apiKey.isEmpty {
            syncCodexConfig()
        }
    }

    func selectModel(_ id: String) {
        model = id
        if apiKey.isEmpty {
            codexEnabled = false
            Log.error("codex_config_skip", "reason", "empty_api_key", "model", id)
        } else {
            codexEnabled = true
            syncCodexConfig()
        }
        Log.info("model_switched", "model", id)
    }

    func disableCodex() {
        codexEnableSkippedForMissingKey = false
        codexEnabled = false
        codexConfigManager.disable()
        Log.info("codex_config_disabled")
    }

    func toggleCodex() {
        if codexEnabled {
            disableCodex()
        } else if !apiKey.isEmpty {
            model = "deepseek-v4-flash"
            codexEnabled = true
            syncCodexConfig()
        }
    }

    /// 切换补丁状态：已打→还原，未打→打补丁
    func toggleCodexAsar() {
        if codexConfigManager.isPatched {
            guard codexConfigManager.restoreAppAsar() else {
                Log.error("codex_asar_restore_failed")
                return
            }
            Log.info("codex_asar_restored")
        } else {
            guard codexConfigManager.patchAppAsar() else {
                Log.error("codex_asar_patch_failed")
                return
            }
            Log.info("codex_asar_patched")
        }
        objectWillChange.send()
    }

    func saveApiKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        apiKey = trimmed
        if codexEnabled {
            syncCodexConfig()
        }
        Log.info("api_key_updated")
        return true
    }

    func fetchModels() async {
        guard !apiKey.isEmpty else { return }
        guard let url = URL(string: upstream + "/v1/models") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataList = json["data"] as? [[String: Any]]
        else { return }
        let models = dataList.compactMap { item -> ModelInfo? in
            guard let id = item["id"] as? String else { return nil }
            let desc = item["description"] as? String ?? ""
            return ModelInfo(id: id, description: desc)
        }
        guard !models.isEmpty else { return }
        availableModels = models
        Self.saveModels(models)
    }

    private var codexEnableSkippedForMissingKey = false

    private func syncCodexConfig() {
        guard codexEnabled else {
            codexConfigManager.disable()
            return
        }
        guard !apiKey.isEmpty else {
            Log.error("codex_config_skip", "reason", "empty_api_key")
            codexEnableSkippedForMissingKey = true
            codexEnabled = false
            return
        }
        if codexConfigManager.enable(model: model, apiKey: apiKey) {
            codexEnableSkippedForMissingKey = false
            Log.info("codex_config_enabled", "model", model)
        }
    }
}
