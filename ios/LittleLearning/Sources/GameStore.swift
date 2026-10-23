import SwiftUI
import AVFoundation
#if canImport(LearningCore)
import LearningCore
#endif

enum DrawerCategory: String, CaseIterable {
    case learning, play
    var title: String { self == .learning ? "学习" : "游玩" }
    var symbol: String { self == .learning ? "book.closed.fill" : "gamecontroller.fill" }
}

@MainActor
final class GameStore: ObservableObject {
    @Published private(set) var game: NumberLineGame
    @Published var selectedGame: LearningGame?
    @Published var selectedFunGame: FunGame?
    @Published var showsRewards = false
    @Published var drawerCategory: DrawerCategory = .learning
    @Published var topicPickerGame: LearningGame?
    private let collection: CollectionStore
    var isPlaying: Bool { selectedGame != nil }
    @Published var duckSelected = false
    @Published var dragOffset = CGSize.zero
    @Published var isDragging = false
    var padFrames: [Int: CGRect] = [:]
    private let defaults: UserDefaults
    private let speech = AVSpeechSynthesizer()
    private static let saveKey = "numberLine.v1"

    init(collection: CollectionStore,defaults: UserDefaults = .standard) {
        self.collection=collection
        self.defaults = defaults
        game = collection.progress.numberLine ?? defaults.data(forKey: Self.saveKey).flatMap(NumberLineGame.restore) ?? .fresh()
        #if os(iOS)
        // Playback is user-initiated and respects the silent switch.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        #endif
        #if DEBUG
        let args=ProcessInfo.processInfo.arguments
        if let index=args.firstIndex(of:"--check-offline-game"),args.indices.contains(index+1),let game=FunGame(rawValue:args[index+1]),game.isWebGame { selectedFunGame=game }
        #endif
    }

    var hasProgress: Bool { game.phase != .complete && (game.index > 0 || game.position != game.question.start || game.phase == .correct) }

    func openFun(_ selected: FunGame) {
        collection.pauseFun();stopSpeech();save();selectedGame=nil;selectedFunGame=selected
    }
    func closeFun() { collection.pauseFun();save();selectedFunGame=nil }
    func open() { open(.numberLine) }
    func open(_ game: LearningGame) {
        stopSpeech();collection.clearRewardNotice()
        if game != .printing && collection.group(game) == nil { topicPickerGame=game;return }
        collection.prepareGroup(game)
        enter(game)
    }
    private func enter(_ selected: LearningGame) {
        duckSelected=false;dragOffset = .zero;isDragging=false
        if selected == .numberLine { game=collection.progress.numberLine ?? .fresh() }
        selectedGame=selected
    }
    func chooseGroup(_ group: StudyGroup,review: Bool = false) {
        stopSpeech();collection.selectGroup(group,review:review)
        topicPickerGame=nil;enter(group.game)
    }
    func reviewGroup(_ game: LearningGame) { if let group=collection.group(game) { chooseGroup(group,review:true) } }
    func close() { collection.clearRewardNotice(); stopSpeech(); save(); selectedGame = nil }
    func jump(_ direction: Int) { stopSpeech(); game.jump(direction); save() }
    func move(to number: Int) { stopSpeech(); game.move(to: number); save() }
    func check() { stopSpeech(); game.check(); save() }
    func next() { collection.clearRewardNotice(); stopSpeech(); game.next(); save(); if game.phase == .complete { collection.finishMathIfNeeded() } }
    func restart() {
        collection.clearRewardNotice();stopSpeech()
        if let group=collection.group(.numberLine) { chooseGroup(group,review:collection.isReviewing(.numberLine)) }
        else { game = .fresh();save() }
    }
    func resetPosition() { stopSpeech(); game.resetPosition(); save() }
    func save() {
        if collection.progress.numberLine != game { collection.progress.numberLine=game }
        collection.save()
    }
    func stopSpeech() { speech.stopSpeaking(at: .immediate) }
    func readQuestion() {
        stopSpeech()
        let text: String
        switch game.phase {
        case .complete: text = "这一轮跳完了！加法往右跳，减法往左跳。"
        case .correct: text = "跳对了！\(game.question.equation.replacingOccurrences(of: "+", with: "加").replacingOccurrences(of: "−", with: "减")) 等于 \(game.question.answer)。"
        case .playing: text = game.hint ?? game.question.spokenQuestion
        }
        speak(text)
    }
    func speak(_ text: String, language: String = "zh-CN") {
        stopSpeech()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = 0.42
        speech.speak(utterance)
    }
}
