import Foundation

/// AEGIS V46 networking — same contract as Windows/Android clients.
class TradeBridge: ObservableObject {
    static let clientVersion = "1.46.0"

    @Published var lastSignal: String = "Waiting…"
    @Published var lastHTTP: Int = 0
    @Published var frames: Int = 0
    @Published var uploadsOK: Int = 0
    @Published var registrySummary: String = "Registry: not loaded"

    func sendFrame(imageData: Data, config: Config) async {
        guard let base = URL(string: config.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              !config.apiKey.isEmpty else {
            await MainActor.run { self.lastSignal = "Missing server URL or API key" }
            return
        }
        let url = base.appendingPathComponent("aegis/analyze")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(config.apiKey, forHTTPHeaderField: "X-API-Key")
        req.setValue(config.apiKey, forHTTPHeaderField: "Authorization")
        req.setValue(config.accountID, forHTTPHeaderField: "X-Account-Id")
        req.setValue("macos", forHTTPHeaderField: "X-Platform")
        req.setValue(Self.clientVersion, forHTTPHeaderField: "X-Client-Version")
        req.setValue("AegisCapture-Mac/\(Self.clientVersion)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 60

        let boundary = "AegisBoundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func append(_ s: String) { body.append(Data(s.utf8)) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"account_id\"\r\n\r\n")
        append("\(config.accountID)\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"platform\"\r\n\r\n")
        append("macos\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"client_version\"\r\n\r\n")
        append("\(Self.clientVersion)\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"captured_at_ms\"\r\n\r\n")
        append("\(Int(Date().timeIntervalSince1970 * 1000))\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"image\"; filename=\"chart.png\"\r\n")
        append("Content-Type: image/png\r\n\r\n")
        body.append(imageData)
        append("\r\n--\(boundary)--\r\n")
        req.httpBody = body

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            var signal = "HOLD"
            var rule = ""
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                signal = (obj["signal"] as? String) ?? (obj["action"] as? String) ?? "HOLD"
                rule = (obj["rule_name"] as? String) ?? (obj["rule"] as? String) ?? ""
            }
            await MainActor.run {
                self.frames += 1
                self.lastHTTP = code
                if code == 200 { self.uploadsOK += 1 }
                self.lastSignal = "\(signal) · HTTP \(code)" + (rule.isEmpty ? "" : " · \(rule)")
            }
            if ["BUY", "SELL", "HOLD"].contains(signal.uppercased()) {
                let path = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/Application Support/MetaQuotes/Terminal/Common/Files/aegis_signal.txt")
                try? FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? signal.uppercased().data(using: .utf8)?.write(to: path)
            }
        } catch {
            await MainActor.run { self.lastSignal = "Error: \(error.localizedDescription)" }
        }
    }

    func loadRegistry(config: Config) async {
        guard let base = URL(string: config.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            await MainActor.run { self.registrySummary = "Registry: bad server URL" }
            return
        }
        var req = URLRequest(url: base.appendingPathComponent("api/registry/pairs"))
        req.setValue(config.apiKey, forHTTPHeaderField: "X-API-Key")
        req.setValue(config.accountID, forHTTPHeaderField: "X-Account-Id")
        req.setValue(Self.clientVersion, forHTTPHeaderField: "X-Client-Version")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            var n = 0
            var ind = false
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let pairs = obj["pairs"] as? [Any] { n = pairs.count }
                ind = (obj["indicators_required"] as? Bool) ?? false
            }
            await MainActor.run {
                self.registrySummary = "Registry HTTP \(code) · tradeable pairs: \(n) · indicators_required=\(ind)"
            }
        } catch {
            await MainActor.run { self.registrySummary = "Registry error: \(error.localizedDescription)" }
        }
    }

    func setRiskPreset(config: Config, preset: String) async {
        guard let base = URL(string: config.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        var req = URLRequest(url: base.appendingPathComponent("api/account/risk_preset"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(config.apiKey, forHTTPHeaderField: "X-API-Key")
        req.setValue(config.accountID, forHTTPHeaderField: "X-Account-Id")
        let payload: [String: String] = ["account_id": config.accountID, "risk_preset": preset]
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            var lot = "?"
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let v = obj["calculated_lot_size"] { lot = "\(v)" }
            }
            await MainActor.run {
                self.lastSignal = "Risk \(preset) · HTTP \(code) · lot \(lot)"
            }
        } catch {
            await MainActor.run { self.lastSignal = "Risk error: \(error.localizedDescription)" }
        }
    }
}
