//
//  ModelConfig.swift
//

import Foundation
import MLXLMCommon

enum ModelConfig {
    static let directory: URL = {
        Bundle.main.bundleURL.appending(path: "Qwen3-0.6B-4bit-DWQ-053125")
    }()

    static let id = "mlx-community/Qwen3-0.6B-4bit-DWQ-053125"

    static let configuration = ModelConfiguration(directory: directory)

    static let parameters = GenerateParameters(temperature: 0.6, topP: 0.95, topK: 20)
}
