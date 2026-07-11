#!/usr/bin/env swift
//
// probe-tokenizer.swift
//
// One-shot CLI: loads Qwen3-0.6B (full model load, ~5s), then prints
// the tokenize behavior of a bank of common Chinese words and English
// words. Use the printed table to calibrate Level2Constants star
// thresholds and the hint2ExampleText.
//
// Usage:
//     swift scripts/probe-tokenizer.swift
//
// Output format (whitespace-aligned):
//
//     word          tokens  chars
//     ────────────  ──────  ─────
//     我            1       1
//     中华人民共和国  1       7
//     unbelievable  3       12
//     ...
//
// After running, eyeball the `tokens` column at various `chars` ranges
// and pick star thresholds accordingly.

import Foundation
import MLX
import MLXLMCommon
import Tokenizers

@main
struct ProbeTokenizer {
    static func main() async throws {
        Memory.cacheLimit = 20 * 1024 * 1024
        let container = try await LLMModelFactory.shared.loadContainer(
            configuration: ModelConfig.configuration
        )
        try container.perform { context in
            let words = [
                "我", "你", "他", "我们", "中国", "美国", "北京", "上海",
                "今天天气真", "中华人民共和国", "五星红旗", "中华民族",
                "unbelievable", "tokyo", "hello world",
                "asdfqwerty", "我爱你中国"
            ]
            print(String(
                format: "%-22s %6s %6s",
                "word".cString(using: .utf8)!,
                "tokens".cString(using: .utf8)!,
                "chars".cString(using: .utf8)!
            ))
            print(String(repeating: "─", count: 40))
            for word in words {
                let ids = try context.tokenizer.encode(text: word)
                let chars = word.count
                print(String(
                    format: "%-22s %6d %6d",
                    word.cString(using: .utf8)!,
                    ids.count,
                    chars
                ))
            }
        }
    }
}
