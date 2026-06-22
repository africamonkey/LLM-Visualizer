//
//  llm_visualizerApp.swift
//  llm-visualizer
//

import SwiftUI

@main
struct llm_visualizerApp: App {
    @State private var viewModel = ChatViewModel(service: LLMService())

    var body: some Scene {
        WindowGroup {
            ChatView(viewModel: viewModel)
        }
    }
}