import Foundation
import AppKit
import iCodexCore

/// 管理 Codex 桌面版 app.asar 补丁
final class CodexAppPatcher {
    private let asar = URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources/app.asar")
    private let backup = URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources/app.asar.bak")
    /// 注意：Codex 每次升级可能改变 minifier 变量名（s→l→u→i/e/r 等）并新增过滤点，失效时需同步更新。
    /// 26.727 起为两处过滤，均为「useHiddenModels 时查白名单，否则仅看 hidden」的三元式，等长替换掉白名单分支。
    /// 过滤点 1：主 UI 模型列表（K$r）  ?n.has(r.model):!r.hidden
    /// 过滤点 2：list-models-for-host（kVu）  ?i.availableModels.has(e.model):!e.hidden
    private let patches: [(original: Data, patched: Data)] = [
        (Data("?n.has(r.model):!r.hidden".utf8),
         Data("?!r.hidden     :!r.hidden".utf8)),
        (Data("?i.availableModels.has(e.model):!e.hidden".utf8),
         Data("?!e.hidden                     :!e.hidden".utf8)),
    ]

    /// 检测是否已打补丁（不修改文件）
    var isPatched: Bool {
        guard let data = try? Data(contentsOf: asar) else { return false }
        return patches.allSatisfy { data.range(of: $0.patched) != nil }
    }

    /// 检测 App 管理权限（试探写入临时文件）
    private var hasAppManagementPermission: Bool {
        let testFile = asar.deletingLastPathComponent().appendingPathComponent(".icodex_perm_test")
        do {
            try Data("test".utf8).write(to: testFile, options: .atomic)
            try FileManager.default.removeItem(at: testFile)
            return true
        } catch {
            return false
        }
    }

    /// 检查权限，无权限则弹窗引导，返回是否已就绪
    @discardableResult
    func ensurePermission() -> Bool {
        guard !hasAppManagementPermission else { return true }
        showPermissionAlert()
        return false
    }

    /// 备份 → 打补丁，调用前需 ensurePermission
    @discardableResult
    func ensurePatched() -> Bool {
        guard let data = try? Data(contentsOf: asar) else { return false }
        if isPatched { return true }
        guard patches.allSatisfy({ data.range(of: $0.original) != nil }) else { return false }

        do {
            if FileManager.default.fileExists(atPath: backup.path) {
                try FileManager.default.removeItem(at: backup)
            }
            try FileManager.default.copyItem(at: asar, to: backup)
            return applyPatch(data)
        } catch {
            Log.error("codex_app_patch_failed", "error", error.localizedDescription)
            return false
        }
    }

    /// 从备份还原 asar，调用前需 ensurePermission
    @discardableResult
    func restoreFromBackup() -> Bool {
        guard FileManager.default.fileExists(atPath: backup.path) else { return true }
        do {
            if FileManager.default.fileExists(atPath: asar.path) {
                try FileManager.default.removeItem(at: asar)
            }
            try FileManager.default.copyItem(at: backup, to: asar)
            try FileManager.default.removeItem(at: backup)
            return true
        } catch {
            Log.error("codex_app_restore_failed", "error", error.localizedDescription)
            return false
        }
    }

    private func applyPatch(_ data: Data) -> Bool {
        var d = data
        for patch in patches {
            guard let r = d.range(of: patch.original) else { return false }
            d.replaceSubrange(r, with: patch.patched)
        }
        try? d.write(to: asar, options: .atomic)
        return true
    }

    private func showPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "需要「App 管理」权限"
            alert.informativeText = "iCodex 需要修改 Codex 桌面版才能显示 DeepSeek 模型。\n\n请前往：系统设置 → 隐私与安全性 → App 管理 → 开启 iCodex"
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "取消")
            alert.alertStyle = .warning
            if alert.runModal() == .alertFirstButtonReturn,
               let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AppBundles") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
