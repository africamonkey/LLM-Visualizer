//
//  ThinkingParserTests.swift
//

import Testing
@testable import llm_visualizer

private let thinkEnd = "<" + "/" + "think>"

struct ThinkingParserTests {

    @Test func completeThinkBlock() {
        let result = ThinkingParser.parse("<think>思考内容\n\n" + thinkEnd + "答案内容")
        #expect(result.thinking == "思考内容")
        #expect(result.answer == "答案内容")
    }

    @Test func incompleteStream() {
        let result = ThinkingParser.parse("<think>正在思考")
        #expect(result.thinking == "正在思考")
        #expect(result.answer.isEmpty)
    }

    @Test func noThinkTag() {
        let result = ThinkingParser.parse("直接是答案")
        #expect(result.thinking == nil)
        #expect(result.answer == "直接是答案")
    }

    @Test func emptyThinking() {
        let result = ThinkingParser.parse("<think>\n\n" + thinkEnd + "只有答案")
        #expect(result.thinking == nil)
        #expect(result.answer == "只有答案")
    }

    @Test func whitespaceTrimmed() {
        let result = ThinkingParser.parse("<think>  \n  思考  \n\n" + thinkEnd + "  答案  ")
        #expect(result.thinking == "思考")
        #expect(result.answer == "答案")
    }

    @Test func multilineThinking() {
        let result = ThinkingParser.parse(
            "<think>第一行\n第二行\n\n" + thinkEnd + "answer here"
        )
        #expect(result.thinking == "第一行\n第二行")
        #expect(result.answer == "answer here")
    }
}