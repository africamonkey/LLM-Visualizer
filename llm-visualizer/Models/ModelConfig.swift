//
//  ModelConfig.swift
//

import Foundation
import MLXLMCommon

enum ModelConfig {
    nonisolated static let directory: URL = {
        Bundle.main.bundleURL.appending(path: "Qwen3-0.6B-4bit-DWQ-053125")
    }()

    nonisolated static let id = "mlx-community/Qwen3-0.6B-4bit-DWQ-053125"

    nonisolated static let configuration = ModelConfiguration(directory: directory)

    nonisolated static let parameters = GenerateParameters(temperature: 0.6, topP: 0.95, topK: 20)
}
