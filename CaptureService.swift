import SwiftUI
import ScreenCaptureKit
import Combine

class CaptureService: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var isSelectingRegion = false
    @Published var screenshotCount = 0
    @Published var lastSignal = "HOLD"
    
    private var timer: Timer?
    private var region: CGRect = .zero
    private var config: Config
    private var apiClient: APIClient?
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        self.config = Config()
        super.init()
        self.apiClient = APIClient(config: config)
    }
    
    func startCapture(config: Config, region: CGRect) {
        self.config = config
        self.region = region
        self.isRunning = true
        self.screenshotCount = 0
        
        // Check for screen recording permission
        requestScreenRecordingPermission()
        
        // Start the timer
        timer = Timer.scheduledTimer(withTimeInterval: config.intervalSec, repeats: true) { [weak self] _ in
            self?.captureScreenshot()
        }
    }
    
    func stopCapture() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    private func requestScreenRecordingPermission() {
        // This will trigger the system permission dialog
        if #available(macOS 14.0, *) {
            SCShareableContent.getCurrentProcessContent { content, error in
                if let error = error {
                    print("Permission error: \(error)")
                } else {
                    print("Screen recording permission granted")
                }
            }
        } else {
            // Fallback for older macOS
            let shareContent = SCShareableContent()
            _ = shareContent
        }
    }
    
    private func captureScreenshot() {
        guard isRunning else { return }
        
        // Create the capture configuration
        let config = SCContentFilter()
        // We want to capture the entire screen and then crop
        let display = SCShareableContent.getCurrentDisplay()
        
        // Use ScreenCaptureKit for modern macOS
        if #available(macOS 14.0, *) {
            captureWithScreenCaptureKit()
        } else {
            // Fallback for older macOS versions
            captureWithDeprecatedMethod()
        }
    }
    
    @available(macOS 14.0, *)
    private func captureWithScreenCaptureKit() {
        // Configure the capture
        let contentFilter = SCContentFilter()
        
        // Create a stream configuration for the region
        let streamConfig = SCStreamConfiguration()
        streamConfig.width = Int(region.width)
        streamConfig.height = Int(region.height)
        streamConfig.capturesAudio = false
        streamConfig.showsCursor = false
        
        // Get the actual screen scale for proper capture
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        streamConfig.scalesToFit = true
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 2) // 30fps
        
        // Create stream output handler
        let streamOutput = SCStreamOutput()
        
        // Start the stream
        Task {
            do {
                // Get the display content
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                
                // Find the display
                guard let display = content.displays.first else {
                    print("No display found")
                    return
                }
                
                // Create a filter for the display
                let filter = SCContentFilter(display: display, excludingWindows: [])
                
                // Create the stream
                let stream = SCStream(filter: filter, configuration: streamConfig, delegate: nil)
                
                // Add output
                try stream.addStreamOutput(streamOutput, type: .screen, sampleHandlerQueue: .main)
                
                // Start the stream
                try await stream.startCapture()
                
                // For now, we'll capture a single frame since we only need periodic screenshots
                // In a real implementation, you'd use the stream output handler
                if let image = await captureFrame(stream: stream, config: streamConfig) {
                    processCapturedImage(image)
                }
                
                // Stop after one frame
                try await stream.stopCapture()
                
            } catch {
                print("ScreenCaptureKit error: \(error)")
                // Fallback to deprecated method if ScreenCaptureKit fails
                captureWithDeprecatedMethod()
            }
        }
    }
    
    @available(macOS 14.0, *)
    private func captureFrame(stream: SCStream, config: SCStreamConfiguration) async -> NSImage? {
        // This is a simplified approach - for a full implementation you'd use the stream output
        // to get the actual frame data
        
        // Since getting a single frame from SCStream is complex, 
        // we'll use the deprecated method as fallback for now
        return nil
    }
    
    private func captureWithDeprecatedMethod() {
        // Use the deprecated method as fallback
        // This will still work in current macOS versions but may be removed in future
        #if !targetEnvironment(simulator)
        let screenRect = region
        let windowID = CGWindowID(0) // Use 0 to capture desktop
        
        // For deprecated method, we need to handle the warning
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        guard let cgImage = CGWindowListCreateImage(
            screenRect,
            .optionOnScreenBelowWindow,
            windowID,
            .bestResolution
        ) else {
            print("Failed to capture screenshot")
            return
        }
        #pragma clang diagnostic pop
        
        let image = NSImage(cgImage: cgImage, size: screenRect.size)
        processCapturedImage(image)
        #endif
    }
    
    private func processCapturedImage(_ image: NSImage) {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            print("Failed to convert image")
            return
        }
        
        guard let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            print("Failed to convert to PNG")
            return
        }
        
        // Send to API
        sendToAPI(pngData)
        
        screenshotCount += 1
    }
    
    private func sendToAPI(_ imageData: Data) {
        // Convert to Base64 for sending
        let base64String = imageData.base64EncodedString()
        
        // Send to API
        apiClient?.analyzeScreenshot(imageBase64: base64String) { [weak self] result in
            switch result {
            case .success(let signal):
                DispatchQueue.main.async {
                    self?.lastSignal = signal
                }
            case .failure(let error):
                print("API error: \(error)")
            }
        }
    }
    
    func selectRegion() {
        isSelectingRegion = true
        // This would trigger a region selection UI
        // You can implement a custom region selector here
        isSelectingRegion = false
    }
}

// Helper class for API communication
class APIClient {
    private let config: Config
    private let session = URLSession.shared
    
    init(config: Config) {
        self.config = config
    }
    
    func analyzeScreenshot(imageBase64: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(config.serverURL)/aegis/analyze") else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "image": imageBase64,
            "account_id": config.accountID,
            "api_key": config.apiKey,
            "device_id": config.deviceID
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: -1)))
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let signal = json?["signal"] as? String ?? "HOLD"
                completion(.success(signal))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
}

// MARK: - SCShareableContent Extension for backward compatibility
@available(macOS 13.0, *)
extension SCShareableContent {
    static func getCurrentProcessContent(completion: @escaping (SCShareableContent?, Error?) -> Void) {
        Task {
            do {
                let content = try await SCShareableContent.current()
                completion(content, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
    
    static func getCurrentDisplay() -> SCDisplay? {
        Task {
            do {
                let content = try await SCShareableContent.current()
                return content.displays.first
            } catch {
                return nil
            }
        }
        return nil
    }
}

// MARK: - SCContentFilter Extension
@available(macOS 13.0, *)
extension SCContentFilter {
    convenience init() {
        // Default initializer
        self.init(display: SCDisplay(), excludingWindows: [])!
    }
    
    convenience init(display: SCDisplay, excludingWindows windows: [SCWindow]) {
        self.init(display: display, excludingWindows: windows)!
    }
}

// MARK: - SCStreamOutput
class SCStreamOutput: NSObject, SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // Handle sample buffer here
        // This gets called for each frame
        // Convert sampleBuffer to image and process
    }
}

// MARK: - SCStream Configuration
extension SCStreamConfiguration {
    convenience init() {
        self.init()
        // Default configuration
    }
}

// MARK: - Memory Warning Handling
extension CaptureService {
    func handleMemoryWarning() {
        // Clear any cached images or data
        print("Memory warning received - cleaning up")
    }
}
