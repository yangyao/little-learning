import SwiftUI
#if canImport(LearningCore)
import LearningCore
#endif

struct CollectionGameView: View {
    let game: LearningGame
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var library: CollectionStore
    var body: some View {
        VStack(spacing:0) {
            HStack(spacing:Wood.Spacing.sm) {
                WoodIconButton(symbol:"arrow.left",label:"回游戏抽屉") { library.save(); store.close() }.accessibilityIdentifier("library.back")
                Spacer(minLength:0)
                StudyHeaderTitle(game:game)
                Spacer(minLength:0)
                if hasSpeech {
                    WoodIconButton(symbol:"speaker.wave.2.fill",label:game == .bakery ? "听英文单词" : "朗读提示",yellow:true) { read() }.accessibilityIdentifier("library.read")
                } else {
                    Color.clear.frame(width:Wood.Size.touchMinimum,height:Wood.Size.touchMinimum).accessibilityHidden(true)
                }
            }.padding(.horizontal,Wood.Size.phoneMargin).padding(.vertical,Wood.Spacing.sm)
            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing:Wood.Spacing.lg) {
                    if library.isGroupFinished(game) { StudyFinishedView(game:game) }
                    else {
                    switch game {
                    case .sharing: SharingGameView()
                    case .pinyin,.characters,.idioms,.bakery: WorkshopGameView(game:game)
                    case .clock: ClockGameView()
                    case .matches: MatchGameView()
                    case .sorting: FruitGameView()
                    case .printing: PrintingGameView()
                    case .tangram:TangramGameView()
                    case .delivery:DeliveryGameView()
                    case .beads:BeadsGameView()
                    case .ruler:RulerGameView()
                    case .numberLine: EmptyView()
                    }
                    }
                }.id("lesson.top").frame(maxWidth:760).padding(.horizontal,Wood.Size.phoneMargin).padding(.top,Wood.Spacing.md).padding(.bottom,Wood.Spacing.md).frame(maxWidth:.infinity)
            }
            .onChange(of: navigationStep) { _, _ in proxy.scrollTo("lesson.top",anchor:.top) }
            .onChange(of: library.deliveryPlaying) { _, playing in if game == .delivery && playing { proxy.scrollTo("lesson.top",anchor:.top) } }
            }
            GameActionDock { CollectionGameActions(game:game) }
        }.onDisappear { library.stopDelivery();library.save(); store.stopSpeech() }
    }
    private var navigationStep: String {
        "\(library.group(game)?.id ?? "")-\(library.isGroupFinished(game))-\(questionStep)"
    }
    private var questionStep: String {
        if game.isWorkshop { let s=library.session(game); return "\(s.index)-\(s.phase.rawValue)" }
        switch game {
        case .sharing: return "\(library.progress.sharing.index)"
        case .clock: return "\(library.progress.clock.index)"
        case .matches: return "\(library.progress.matches.index)"
        case .sorting: return "\(library.progress.fruits.level)"
        case .tangram:return "\(library.progress.tangram.index)"
        case .delivery:return "\(library.progress.delivery.index)"
        case .beads:return "\(library.progress.beads.index)"
        case .ruler:return "\(library.progress.ruler.index)"
        default: return ""
        }
    }
    private var hasSpeech: Bool {
        game.isWorkshop && !library.isGroupFinished(game) && library.session(game).phase != .complete
    }
    private func read() {
        guard hasSpeech else { return }
        let session=library.session(game),question=WorkshopContent.questions(for:game)[session.index]
        store.speak(game == .bakery ? question.reading : (session.phase == .playing ? question.clue : question.word),
                    language:game == .bakery ? "en-US" : "zh-CN")
    }
}

struct ChallengeHeading: View {
    let subtitle: String, title: String
    var body: some View {
        Tray {
            VStack(spacing:Wood.Spacing.sm) {
                Text(subtitle).woodText(Wood.Typography.support).foregroundStyle(Wood.Palette.textSecondary)
                Text(title).woodText(Wood.Typography.heading).multilineTextAlignment(.center)
            }.frame(maxWidth:.infinity)
        }
    }
}

struct LibraryFeedback: View {
    let text: String
    var correct = false
    var body: some View {
        Label(text,systemImage:correct ? "checkmark.circle.fill" : "lightbulb.fill")
            .woodText(Wood.Typography.body).foregroundStyle(correct ? Wood.Palette.successText : Wood.Palette.hintText)
            .padding(Wood.Spacing.md).frame(maxWidth:.infinity,alignment:.leading)
            .background(correct ? Wood.Palette.successBackground : Wood.Palette.hintBackground,in:RoundedRectangle(cornerRadius:Wood.Radius.control))
            .accessibilityElement(children:.combine)
    }
}

struct GameCompletion: View {
    let game: LearningGame
    let message: String
    let restart: () -> Void
    @EnvironmentObject private var store: GameStore
    var body: some View {
        Tray {
            VStack(spacing:Wood.Spacing.lg) {
                GameArtwork(game:game).frame(height:150)
                Text("这一轮完成了！").woodText(Wood.Typography.title).multilineTextAlignment(.center)
                Text(message).woodText(Wood.Typography.body).multilineTextAlignment(.center)
            }
        }
    }
}

struct PieceButton: View {
    let text: String
    var selected = false
    var empty = false
    var action: () -> Void
    var body: some View {
        Button(action:action) {
            Text(text.isEmpty ? "　" : text).woodText(Wood.Typography.heading)
                .foregroundStyle(empty ? Wood.Palette.textSecondary : Wood.Palette.onObject)
                .frame(minWidth:Wood.Size.touchMinimum,minHeight:Wood.Size.touchMinimum).frame(maxWidth:.infinity)
                .background(empty ? Wood.Palette.recess : Wood.Palette.object,in:RoundedRectangle(cornerRadius:Wood.Radius.control))
                .overlay {
                    RoundedRectangle(cornerRadius:Wood.Radius.control).strokeBorder(selected ? Wood.Palette.slotStroke : Wood.Palette.objectSide,style:StrokeStyle(lineWidth:selected ? 3 : 1,dash:empty ? [4,4] : []))
                }
        }.buttonStyle(IllustrationButtonStyle())
    }
}
