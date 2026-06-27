//
//  AppShellViewModelTests.swift
//

import Foundation
import Testing
@testable import llm_visualizer

@Suite(.serialized)
@MainActor
struct AppShellViewModelTests {

    private func freshStore() -> ProgressStore {
        let defaults = UserDefaults(suiteName: "llmviz.test.\(UUID().uuidString)")!
        return ProgressStore(defaults: defaults)
    }

    @Test func initialStateIsLoading() {
        let appVM = AppShellViewModel(
            service: MockLLMService(),
            progressStore: freshStore(),
            onboardingPrompt: "test"
        )
        #expect(appVM.state == .loading)
        #expect(appVM.example == nil)
    }

    @Test func bootstrapHappyPathWhenOnboardingNotSeen() async {
        let store = freshStore()
        let mock = MockLLMService()
        mock.stubbedPredictTopK = [
            TokenCandidate(id: 1, text: "好", probability: 0.7),
            TokenCandidate(id: 2, text: "不错", probability: 0.2),
        ]
        let appVM = AppShellViewModel(service: mock, progressStore: store, onboardingPrompt: "今天天气真")
        await appVM.bootstrap()
        #expect(appVM.state == .ready(hasSeenOnboarding: false))
        #expect(appVM.example?.prompt == "今天天气真")
        #expect(appVM.example?.candidates.count == 2)
    }

    @Test func bootstrapHappyPathWhenOnboardingAlreadySeen() async {
        let store = freshStore()
        store.hasSeenOnboarding = true
        let mock = MockLLMService()
        mock.stubbedPredictTopK = [
            TokenCandidate(id: 1, text: "好", probability: 0.5)
        ]
        let appVM = AppShellViewModel(service: mock, progressStore: store, onboardingPrompt: "test")
        await appVM.bootstrap()
        #expect(appVM.state == .ready(hasSeenOnboarding: true))
    }

    @Test func bootstrapFailsWhenLoadModelThrows() async {
        let mock = MockLLMService()
        mock.loadModelError = NSError(
            domain: "test", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "model not found"]
        )
        let appVM = AppShellViewModel(
            service: mock,
            progressStore: freshStore(),
            onboardingPrompt: "test"
        )
        await appVM.bootstrap()
        #expect(appVM.state == .failed("model not found"))
        #expect(appVM.example == nil)
    }

    @Test func bootstrapFailsWhenPredictNextTokensThrows() async {
        let mock = MockLLMService()
        mock.predictNextTokensError = NSError(
            domain: "test", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "forward pass crashed"]
        )
        let appVM = AppShellViewModel(
            service: mock,
            progressStore: freshStore(),
            onboardingPrompt: "test"
        )
        await appVM.bootstrap()
        #expect(appVM.state == .failed("forward pass crashed"))
    }

    @Test func retryFromFailedReachesReady() async {
        let mock = MockLLMService()
        mock.loadModelError = NSError(
            domain: "test", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "first call fails"]
        )
        let appVM = AppShellViewModel(
            service: mock,
            progressStore: freshStore(),
            onboardingPrompt: "test"
        )
        await appVM.bootstrap()
        #expect(appVM.state == .failed("first call fails"))

        mock.loadModelError = nil
        mock.stubbedPredictTopK = [
            TokenCandidate(id: 1, text: "好", probability: 0.5)
        ]
        await appVM.retry()
        #expect(appVM.state == .ready(hasSeenOnboarding: false))
        #expect(appVM.example != nil)
    }

    @Test func retryFromReadyIsNoOp() async {
        let mock = MockLLMService()
        mock.stubbedPredictTopK = [
            TokenCandidate(id: 1, text: "好", probability: 0.5)
        ]
        let appVM = AppShellViewModel(
            service: mock,
            progressStore: freshStore(),
            onboardingPrompt: "test"
        )
        await appVM.bootstrap()
        #expect(appVM.state == .ready(hasSeenOnboarding: false))
        await appVM.retry()
        #expect(appVM.state == .ready(hasSeenOnboarding: false))
    }

    @Test func markOnboardingCompleteFlipsReadyFalseToReadyTrue() async {
        let mock = MockLLMService()
        mock.stubbedPredictTopK = [
            TokenCandidate(id: 1, text: "好", probability: 0.5)
        ]
        let appVM = AppShellViewModel(
            service: mock,
            progressStore: freshStore(),
            onboardingPrompt: "test"
        )
        await appVM.bootstrap()
        #expect(appVM.state == .ready(hasSeenOnboarding: false))
        appVM.markOnboardingComplete()
        #expect(appVM.state == .ready(hasSeenOnboarding: true))
    }

    @Test func markOnboardingCompleteFromLoadingIsNoOp() {
        let appVM = AppShellViewModel(
            service: MockLLMService(),
            progressStore: freshStore(),
            onboardingPrompt: "test"
        )
        #expect(appVM.state == .loading)
        appVM.markOnboardingComplete()
        #expect(appVM.state == .loading)
    }
}
