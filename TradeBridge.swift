import Foundation

class TradeBridge: ObservableObject {
    @Published var lastSignal: String? = "Waiting..."
    
    func sendPing() async {
        // Placeholder until we wire real capture
        await MainActor.run { self.lastSignal = "Capturing..." }
    }
    
    func sendFrame(imageData: Data, config: Config) async {
        guard !config.serverURL.isEmpty else { return }
        var req = URLRequest(url: URL(string: "\(config.serverURL)/aegis/analyze")!)
        req.httpMethod = "POST"
        req.setValue(config.apiKey, forHTTPHeaderField: "X-API-Key")
        req.setValue(config.accountID, forHTTPHeaderField: "X-Account-ID")
        req.httpBody = imageData
        
        do {
            let (_, _) = try await URLSession.shared.data(for: req)
            await MainActor.run { self.lastSignal = "Sent" }
        } catch {
            await MainActor.run { self.lastSignal = "Error: \(error.localizedDescription)" }
        }
    }
}
