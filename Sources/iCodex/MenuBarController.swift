import Cocoa
import iCodexCore

@MainActor
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private let state: CodexState
    private var balanceText: String?

    init(state: CodexState) {
        self.state = state
        super.init()
        setup()
    }

    // MARK: - Setup

    private func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        button.action = #selector(buttonClicked)
        button.target = self
        updateIcon()
    }

    // MARK: - Icon

    private func updateIcon() {
        let name = state.codexEnabled ? "house.fill" : "house"

        if let img = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
            img.size = NSSize(width: 16, height: 16)
            statusItem?.button?.image = img
        }
    }

    // MARK: - 余额查询

    /// 同步查询余额，每次点菜单都实时拉取
    private func fetchBalance() -> String? {
        guard !state.apiKey.isEmpty,
              let url = URL(string: "https://api.deepseek.com/user/balance") else { return nil }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(state.apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 3

        let semaphore = DispatchSemaphore(value: 0)
        var result: String?

        let task = URLSession.shared.dataTask(with: req) { data, _, error in
            defer { semaphore.signal() }
            guard let data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let infos = json["balance_infos"] as? [[String: Any]] else {
                result = "余额查询失败"
                return
            }
            let parts = infos.compactMap { info -> String? in
                guard let currency = info["currency"] as? String,
                      let balance = info["total_balance"] as? String else { return nil }
                let symbol = currency == "CNY" ? "¥" : "$"
                return "\(symbol)\(balance)"
            }
            result = parts.isEmpty ? "余额查询失败" : parts.joined(separator: " / ")
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 3.5)
        return result
    }

    // MARK: - Menu

    @objc private func buttonClicked() {
        balanceText = fetchBalance()
        statusItem?.menu = buildMenu()
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let model = NSMenuItem(title: state.codexEnabled ? "关闭模型" : "开启模型",
                               action: #selector(toggleModel), keyEquivalent: "")
        model.target = self
        menu.addItem(model)

        menu.addItem(.separator())

        let apiKey = NSMenuItem(title: "设置密钥", action: #selector(openConfig), keyEquivalent: "")
        apiKey.target = self
        menu.addItem(apiKey)

        let log = NSMenuItem(title: "打开日志", action: #selector(openLog), keyEquivalent: "")
        log.target = self
        menu.addItem(log)

        menu.addItem(.separator())

        if let balance = balanceText {
            let item = NSMenuItem(title: "余额: \(balance)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        let quit = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    // MARK: - Actions

    @objc private func toggleModel() {
        state.toggleCodex()
        updateIcon()
    }

    @objc private func openConfig() {
        openApiKeyConfig(state: state)
    }

    @objc private func openLog() {
        Log.open()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
