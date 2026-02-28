//
//  MultimodalImageGeneratorClient.swift
//  WordsLearner
//

import ComposableArchitecture
import Foundation
import ImageIO

@DependencyClient
struct MultimodalImageGeneratorClient: Sendable {
    var generateImage: @Sendable (_ prompt: String, _ referenceImages: [Data]) async throws -> Data
}

extension MultimodalImageGeneratorClient: DependencyKey {
    static var liveValue: Self {
        @Dependency(\.apiKeyManager) var apiKeyManager
        return Self(
            generateImage: { prompt, referenceImages in
                let apiKey = await MainActor.run {
                    apiKeyManager.getAPIKey()
                }
                guard !apiKey.isEmpty else {
                    throw AIError.authenticationError
                }
                guard let url = URL(string: "https://zenmux.ai/api/vertex-ai/v1/publishers/google/models/gemini-3.1-flash-image-preview:generateContent") else {
                    throw AIError.invalidURL
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                let hasReferences = !referenceImages.isEmpty
                var lastImageData: Data?
                for attempt in 1...4 {
                    let strictAspectLine = attempt > 1 ? "- CRITICAL: Return a landscape 16:9 frame." : ""
                    let strictSceneLine = attempt > 1 ? "- CRITICAL: Match the described story moment exactly. Do not invent unrelated scenes." : ""
                    let strictContinuityLine = (attempt > 1 && hasReferences) ? "- CRITICAL: Keep the same characters and environment continuity from the attached reference image(s)." : ""
                    let continuitySection = hasReferences ? """

                    Continuity requirements:
                    - Use attached reference image(s) from earlier frames as visual canon.
                    - Keep character identity, outfit, proportions, and color palette consistent.
                    - Keep environment continuity unless narration explicitly changes location.
                    - Keep style and camera language consistent with the reference image(s).
                    """ : ""
                    let refinedPrompt = """
                    \(prompt)

                    Scene fidelity requirements:
                    - Treat the provided story/frame details as ground truth.
                    - Depict the exact described action, people, and setting.
                    - Prefer concrete narrative details over generic symbolism.
                    \(continuitySection)

                    Visual constraints:
                    - Cinematic storyboard frame
                    - Landscape 16:9 composition (video-like)
                    - Single clear moment, vivid and concrete
                    - No text, no subtitles, no letters, no watermark
                    \(strictAspectLine)
                    \(strictSceneLine)
                    \(strictContinuityLine)
                    """

                    let parts = buildPromptParts(prompt: refinedPrompt, referenceImages: referenceImages)
                    let payloadWithAspect: [String: Any] = [
                        "contents": [
                            [
                                "role": "user",
                                "parts": parts,
                            ]
                        ],
                        "generationConfig": [
                            "responseModalities": ["TEXT", "IMAGE"]
                        ],
                        "imageConfig": [
                            "aspectRatio": "16:9"
                        ]
                    ]
                    let payloadFallback: [String: Any] = [
                        "contents": [
                            [
                                "role": "user",
                                "parts": parts,
                            ]
                        ],
                        "generationConfig": [
                            "responseModalities": ["TEXT", "IMAGE"]
                        ]
                    ]

                    let imageData: Data
                    do {
                        imageData = try await requestImageData(request: request, payload: payloadWithAspect)
                    } catch AIError.apiError(let statusCode) where statusCode == 400 {
                        imageData = try await requestImageData(request: request, payload: payloadFallback)
                    }

                    lastImageData = imageData
                    if isLandscape16x9(imageData) {
                        return imageData
                    }
                }

                guard let lastImageData else {
                    throw AIError.parsingError
                }
                return lastImageData
            }
        )
    }

    static var previewValue: Self {
        Self(
            generateImage: { _, _ in
                Data()
            }
        )
    }

    static var testValue: Self {
        previewValue
    }
}

private func requestImageData(
    request: URLRequest,
    payload: [String: Any]
) async throws -> Data {
    var mutableRequest = request
    mutableRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
    let (data, response) = try await URLSession.shared.data(for: mutableRequest)
    guard let httpResponse = response as? HTTPURLResponse else {
        throw AIError.networkError
    }
    guard httpResponse.statusCode == 200 else {
        switch httpResponse.statusCode {
        case 401, 403:
            throw AIError.authenticationError
        case 429:
            throw AIError.rateLimitError
        default:
            throw AIError.apiError(statusCode: httpResponse.statusCode)
        }
    }
    guard
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
        let candidates = json["candidates"] as? [[String: Any]]
    else {
        throw AIError.parsingError
    }

    for candidate in candidates {
        guard let content = candidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]]
        else {
            continue
        }
        for part in parts {
            guard
                let inlineData = part["inlineData"] as? [String: Any],
                let base64 = inlineData["data"] as? String,
                let imageData = Data(base64Encoded: base64)
            else {
                continue
            }
            return imageData
        }
    }

    throw AIError.parsingError
}

private func buildPromptParts(prompt: String, referenceImages: [Data]) -> [[String: Any]] {
    var parts: [[String: Any]] = [
        [
            "text": prompt
        ]
    ]

    for imageData in referenceImages {
        parts.append(
            [
                "inlineData": [
                    "mimeType": imageMimeType(for: imageData),
                    "data": imageData.base64EncodedString()
                ]
            ]
        )
    }

    return parts
}

private func imageMimeType(for data: Data) -> String {
    let bytes = [UInt8](data.prefix(12))
    if bytes.count >= 8,
       bytes[0] == 0x89,
       bytes[1] == 0x50,
       bytes[2] == 0x4E,
       bytes[3] == 0x47 {
        return "image/png"
    }
    if bytes.count >= 3,
       bytes[0] == 0xFF,
       bytes[1] == 0xD8,
       bytes[2] == 0xFF {
        return "image/jpeg"
    }
    if bytes.count >= 12,
       bytes[0] == 0x52, // R
       bytes[1] == 0x49, // I
       bytes[2] == 0x46, // F
       bytes[3] == 0x46, // F
       bytes[8] == 0x57, // W
       bytes[9] == 0x45, // E
       bytes[10] == 0x42, // B
       bytes[11] == 0x50 { // P
        return "image/webp"
    }
    if bytes.count >= 4,
       bytes[0] == 0x47, // G
       bytes[1] == 0x49, // I
       bytes[2] == 0x46, // F
       bytes[3] == 0x38 { // 8
        return "image/gif"
    }
    return "image/png"
}

private func isLandscape16x9(_ imageData: Data) -> Bool {
    guard
        let source = CGImageSourceCreateWithData(imageData as CFData, nil),
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
        let width = properties[kCGImagePropertyPixelWidth] as? Double,
        let height = properties[kCGImagePropertyPixelHeight] as? Double,
        height > 0
    else {
        return false
    }

    let ratio = width / height
    let target = 16.0 / 9.0
    return abs(ratio - target) <= 0.02
}

extension DependencyValues {
    var multimodalImageGenerator: MultimodalImageGeneratorClient {
        get { self[MultimodalImageGeneratorClient.self] }
        set { self[MultimodalImageGeneratorClient.self] = newValue }
    }
}
