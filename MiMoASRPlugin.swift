import Foundation
import SwiftUI
import TypeWhisperPluginSDK

// MARK: - MIMO ASR Plugin

@objc(MIMOASRPlugin)
final class MIMOASRPlugin: NSObject,
    TranscriptionEnginePlugin,
    DictionaryTermsCapabilityProviding,
    PluginAuthRoleStatusProviding,
    @unchecked Sendable
{
    static let pluginId = "com.typewhisper.mimo-asr"
    static let pluginName = "MIMO ASR"
    
    nonisolated(unsafe) fileprivate var host: HostServices?
    nonisolated(unsafe) fileprivate var _apiKey: String?
    nonisolated(unsafe) fileprivate var _selectedModelId: String?
    
    private static let apiKeyCredentialLabel = "MIMO API Key"
    private static let baseURL = "https://api.xiaomimimo.com/v1"
    private static let defaultSampleRate = 16000
    
    private static let storageKeys = (
        apiKey: "mimo-api-key",
        selectedModel: "mimo-selected-model"
    )
    
    required override init() {
        super.init()
    }
    
    func activate(host: HostServices) {
        self.host = host
        _apiKey = host.loadSecret(key: Self.storageKeys.apiKey)
        _selectedModelId = host.userDefault(forKey: Self.storageKeys.selectedModel) as? String
            ?? transcriptionModels.first?.id
    }
    
    func deactivate() {
        host = nil
    }
    
    // MARK: - PluginAuthRoleStatusProviding
    
    nonisolated func authStatus(for role: PluginAuthRole) -> PluginAuthRoleStatus {
        switch role {
        case .transcription:
            if let key = _apiKey, !key.isEmpty {
                return .available
            }
            return .unavailable(
                reason: "MIMO ASR requires an API key from Xiaomi MIMO.",
                requiredCredentialLabel: Self.apiKeyCredentialLabel
            )
        default:
            return .unavailable(
                reason: "MIMO ASR only supports transcription.",
                requiredCredentialLabel: Self.apiKeyCredentialLabel
            )
        }
    }
    
    // MARK: - TranscriptionEnginePlugin
    
    nonisolated var providerId: String { "mimo-asr" }
    nonisolated var providerDisplayName: String { "MIMO ASR" }
    
    nonisolated var isConfigured: Bool {
        guard let key = _apiKey else { return false }
        return !key.isEmpty
    }
    
    nonisolated var transcriptionModels: [PluginModelInfo] {
        [
            PluginModelInfo(id: "mimo-v2.5-asr", displayName: "MIMO v2.5 ASR"),
        ]
    }
    
    nonisolated var selectedModelId: String? { _selectedModelId }
    
    func selectModel(_ modelId: String) {
        _selectedModelId = modelId
        host?.setUserDefault(modelId, forKey: Self.storageKeys.selectedModel)
    }
    
    nonisolated var supportsTranslation: Bool { false }
    nonisolated var supportsStreaming: Bool { false }
    
    // TypeWhisper 会自动处理字典，将字典术语合并到 prompt 中传递给我们
    nonisolated var dictionaryTermsSupport: DictionaryTermsSupport { .supported }
    
    nonisolated var supportedLanguages: [String] {
        ["auto", "zh", "en", "ja", "ko"]
    }
    
    func transcribe(
        audio: AudioData,
        language: String?,
        translate: Bool,
        prompt: String?
    ) async throws -> PluginTranscriptionResult {
        guard let apiKey = _apiKey, !apiKey.isEmpty else {
            throw PluginTranscriptionError.notConfigured
        }
        guard let modelId = _selectedModelId else {
            throw PluginTranscriptionError.noModelSelected
        }
        
        return try await transcribeWithMIMO(
            samples: audio.samples,
            apiKey: apiKey,
            modelId: modelId,
            language: language,
            prompt: prompt  // TypeWhisper 会自动将字典术语附加到 prompt 中
        )
    }
    
    func transcribe(
        audio: AudioData,
        language: String?,
        translate: Bool,
        prompt: String?,
        onProgress: @Sendable @escaping (String) -> Bool
    ) async throws -> PluginTranscriptionResult {
        // 不支持流式，直接调用非流式方法
        let result = try await transcribe(
            audio: audio,
            language: language,
            translate: translate,
            prompt: prompt
        )
        _ = onProgress(result.text)
        return result
    }
    
    // MARK: - Settings View
    
    var settingsView: AnyView? {
        AnyView(MIMOASRSettingsView(plugin: self))
    }
    
    // MARK: - API Key Management
    
    func setApiKey(_ key: String) {
        _apiKey = key
        if let host {
            do {
                try host.storeSecret(key: Self.storageKeys.apiKey, value: key)
            } catch {
                print("[MIMOASRPlugin] Failed to store API key: \(error)")
            }
            host.notifyCapabilitiesChanged()
        }
    }
    
    func removeApiKey() {
        _apiKey = nil
        if let host {
            do {
                try host.storeSecret(key: Self.storageKeys.apiKey, value: "")
            } catch {
                print("[MIMOASRPlugin] Failed to delete API key: \(error)")
            }
            host.notifyCapabilitiesChanged()
        }
    }
    
    func validateApiKey(_ key: String) async -> Bool {
        do {
            guard let url = URL(string: "\(Self.baseURL)/models") else {
                return false
            }
            
            var request = URLRequest(url: url)
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 10
            
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func transcribeWithMIMO(
        samples: [Float],
        apiKey: String,
        modelId: String,
        language: String?,
        prompt: String?
    ) async throws -> PluginTranscriptionResult {
        let wavData = convertToWAV(samples: samples)
        let base64Audio = wavData.base64EncodedString()
        
        guard let url = URL(string: "\(Self.baseURL)/chat/completions") else {
            throw MIMOASRError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 600
        
        var requestBody: [String: Any] = [
            "model": modelId,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "input_audio",
                            "input_audio": [
                                "data": "data:audio/wav;base64,\(base64Audio)"
                            ]
                        ]
                    ]
                ]
            ],
            "stream": false
        ]
        
        // 构建 ASR 选项
        var asrOptions: [String: Any] = [:]
        
        // 语言设置
        if let lang = language, !lang.isEmpty {
            asrOptions["language"] = lang
        } else {
            asrOptions["language"] = "auto"
        }
        
        // prompt 包含字典术语（由 TypeWhisper 自动添加）
        if let prompt = prompt, !prompt.isEmpty {
            asrOptions["prompt"] = prompt
        }
        
        if !asrOptions.isEmpty {
            requestBody["extra_body"] = [
                "asr_options": asrOptions
            ]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PluginTranscriptionError.networkError("Invalid response")
        }
        
        switch httpResponse.statusCode {
        case 200:
            return try parseResponse(data)
        case 401:
            throw PluginTranscriptionError.invalidApiKey
        case 429:
            throw PluginTranscriptionError.rateLimited
        default:
            throw PluginTranscriptionError.apiError(parseErrorMessage(from: data, statusCode: httpResponse.statusCode))
        }
    }
    
    private func parseResponse(_ data: Data) throws -> PluginTranscriptionResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PluginTranscriptionError.apiError("Failed to parse response")
        }
        
        if let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            
            let trimmedText = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else {
                throw PluginTranscriptionError.apiError("Empty transcription result")
            }
            
            return PluginTranscriptionResult(
                text: trimmedText,
                detectedLanguage: nil
            )
        }
        
        throw PluginTranscriptionError.apiError("No transcription found in response")
    }
    
    private func convertToWAV(samples: [Float]) -> Data {
        let sampleRate = Self.defaultSampleRate
        let doubleSampleRate = Double(sampleRate)
        var data = Data()
        
        let numChannels: UInt32 = 1
        let bitsPerSample: UInt32 = 16
        let byteRate = UInt32(doubleSampleRate) * numChannels * bitsPerSample / 8
        let blockAlign = numChannels * bitsPerSample / 8
        let dataSize = UInt32(samples.count * Int(bitsPerSample / 8))
        
        data.append(contentsOf: "RIFF".utf8)
        data.append(withUnsafeBytes(of: UInt32(36 + dataSize).littleEndian) { Data($0) })
        data.append(contentsOf: "WAVE".utf8)
        
        data.append(contentsOf: "fmt ".utf8)
        data.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: UInt16(numChannels).littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: UInt32(doubleSampleRate).littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: UInt16(blockAlign).littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian) { Data($0) })
        
        data.append(contentsOf: "data".utf8)
        data.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        
        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            var int16 = Int16(clamped * 32767.0).littleEndian
            data.append(withUnsafeBytes(of: &int16) { Data($0) })
        }
        
        return data
    }
    
    private func parseErrorMessage(from data: Data, statusCode: Int) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        if let body = String(data: data, encoding: .utf8), !body.isEmpty {
            return "HTTP \(statusCode): \(body)"
        }
        return "HTTP \(statusCode)"
    }
}

// MARK: - MIMO ASR Error

enum MIMOASRError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid MIMO API URL"
        case .invalidResponse:
            return "Invalid MIMO API response"
        case .apiError(let message):
            return "MIMO API error: \(message)"
        }
    }
}

// MARK: - Settings View

private struct MIMOASRSettingsView: View {
    let plugin: MIMOASRPlugin
    @State private var apiKeyInput = ""
    @State private var isValidating = false
    @State private var validationResult: Bool?
    @State private var showApiKey = false
    @State private var selectedModel: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("MIMO API Key")
                    .font(.headline)
                
                HStack(spacing: 8) {
                    if showApiKey {
                        TextField("API Key", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField("API Key", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Button {
                        showApiKey.toggle()
                    } label: {
                        Image(systemName: showApiKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    
                    if plugin.isConfigured {
                        Button("Remove") {
                            apiKeyInput = ""
                            validationResult = nil
                            plugin.removeApiKey()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundStyle(.red)
                    } else {
                        Button("Save") {
                            saveApiKey()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                
                if isValidating {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.small)
                        Text("Validating...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let result = validationResult {
                    HStack(spacing: 4) {
                        Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result ? .green : .red)
                        Text(result ? "Valid API Key" : "Invalid API Key")
                            .font(.caption)
                            .foregroundStyle(result ? .green : .red)
                    }
                }
                
                Text("Get your API key from the Xiaomi MIMO platform")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if plugin.isConfigured {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("ASR Model")
                        .font(.headline)
                    
                    Picker("ASR Model", selection: $selectedModel) {
                        ForEach(plugin.transcriptionModels, id: \.id) { model in
                            Text(model.displayName).tag(model.id)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: selectedModel) { _, newValue in
                        plugin.selectModel(newValue)
                    }
                }
                
                Text("MIMO ASR supports Chinese, English, Japanese, Korean and auto-detection")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("Dictionary terms are automatically applied via TypeWhisper")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .onAppear {
            if let key = plugin._apiKey, !key.isEmpty {
                apiKeyInput = key
            }
            selectedModel = plugin.selectedModelId ?? plugin.transcriptionModels.first?.id ?? ""
        }
    }
    
    private func saveApiKey() {
        let trimmedKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }
        
        plugin.setApiKey(trimmedKey)
        
        isValidating = true
        validationResult = nil
        Task {
            let isValid = await plugin.validateApiKey(trimmedKey)
            await MainActor.run {
                isValidating = false
                validationResult = isValid
            }
        }
    }
}
