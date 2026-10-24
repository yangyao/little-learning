import SwiftUI
#if canImport(LearningCore)
import LearningCore
#endif

struct NumberLineView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var library: CollectionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var pondHeight: CGFloat = 196
    private var game: NumberLineGame { store.game }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: Wood.Spacing.lg) {
                    if library.isGroupFinished(.numberLine) { StudyFinishedView(game:.numberLine) }
                    else if game.phase == .complete {
                        completion
                    } else {
                        questionTray
                        pond
                    }
                }
                .id("math.top").frame(maxWidth: 760)
                .padding(.horizontal, Wood.Size.phoneMargin)
                .padding(.top, Wood.Spacing.md)
                .padding(.bottom, Wood.Spacing.xl)
                .frame(maxWidth: .infinity)
            }
            .onChange(of:"\(library.group(.numberLine)?.id ?? "")-\(game.index)-\(game.phase.rawValue)-\(library.isGroupFinished(.numberLine))") { _, _ in proxy.scrollTo("math.top",anchor:.top) }
            }
            GameActionDock {
                if library.isGroupFinished(.numberLine) { StudyFinishedActions(game:.numberLine) }
                else if game.phase == .complete {
                    Button(library.isReviewing(.numberLine) ? "再复习一轮" : "继续新题") { store.restart() }.buttonStyle(WoodenPrimaryButtonStyle()).accessibilityIdentifier("game.restart")
                    Button("换一组") { store.topicPickerGame = .numberLine }.buttonStyle(SecondaryWoodStyle())
                } else { controls }
            }
        }
        .onDisappear { store.stopSpeech() }
    }

    private var header: some View {
        HStack(spacing: Wood.Spacing.sm) {
            WoodIconButton(symbol: "arrow.left", label: "回游戏抽屉") { store.close() }
                .accessibilityIdentifier("game.back")
            Spacer(minLength: 0)
            StudyHeaderTitle(game:.numberLine)
            Spacer(minLength: 0)
            Color.clear.frame(width:Wood.Size.touchMinimum,height:Wood.Size.touchMinimum).accessibilityHidden(true)
        }
        .padding(.horizontal, Wood.Size.phoneMargin).padding(.top, Wood.Spacing.sm).padding(.bottom, Wood.Spacing.sm)
    }

    private var questionTray: some View {
        Tray {
            VStack(spacing: Wood.Spacing.md) {
                HStack {
                    Text(game.progressLabel).woodText(Wood.Typography.support).foregroundStyle(Wood.Palette.textSecondary)
                    Spacer()
                    Text("\(game.completedCount) / \(game.questions.count)")
                        .woodText(Wood.Typography.support).monospacedDigit().foregroundStyle(Wood.Palette.textSecondary)
                        .accessibilityLabel("已完成 \(game.completedCount) 题")
                }
                Text("\(game.question.equation) = \(game.phase == .correct ? String(game.question.answer) : "?")")
                    .woodText(Wood.Typography.display).monospacedDigit()
                    .frame(maxWidth: .infinity).padding(.vertical, Wood.Spacing.xs)
                    .accessibilityLabel(game.phase == .correct ? "\(game.question.spokenQuestion) 答案是 \(game.question.answer)" : game.question.spokenQuestion)
                    .accessibilityIdentifier("game.equation")
                Text(game.question.instruction).woodText(Wood.Typography.body).multilineTextAlignment(.center)
            }
        }
    }

    private var pond: some View {
        VStack(alignment: .leading, spacing: Wood.Spacing.sm) {
            HStack {
                Label("现在在 \(game.position)", systemImage: "location.fill")
                    .woodText(Wood.Typography.support).foregroundStyle(Wood.Palette.successText)
                Spacer()
                Text("← 0 — \(game.limit) →").woodText(Wood.Typography.support).foregroundStyle(Wood.Palette.textSecondary)
            }
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(alignment: .bottom, spacing: Wood.Spacing.md) {
                        ForEach(0...game.limit, id: \.self) { number in
                            pad(number).id(number)
                        }
                    }
                    .padding(.horizontal, Wood.Spacing.lg)
                    .padding(.top, Wood.Spacing.md).padding(.bottom, Wood.Spacing.md)
                }
                .scrollIndicators(.visible)
                .coordinateSpace(name: "pond")
                .onPreferenceChange(PadFramesKey.self) { store.padFrames = $0 }
                .frame(height: pondHeight)
                .background(Wood.Palette.successBackground, in: RoundedRectangle(cornerRadius: Wood.Radius.tray))
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: Wood.Radius.tray)
                        .strokeBorder(Wood.Palette.success.opacity(0.18), lineWidth: Wood.Stroke.hairline)
                        .allowsHitTesting(false)
                }
                .onAppear { proxy.scrollTo(game.position, anchor: .center) }
                .onChange(of: game.position) { _, position in
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: Wood.Motion.returnDuration)) {
                        proxy.scrollTo(position, anchor: .center)
                    }
                }
                .onChange(of: game.index) { _, _ in proxy.scrollTo(game.position, anchor: .center) }
            }
            Text(store.duckSelected ? "点一片荷叶，让小鸭跳过去" : "滑动看荷叶，也可以用下面的箭头跳")
                .woodText(Wood.Typography.support).foregroundStyle(Wood.Palette.textSecondary)
        }
    }

    private func pad(_ number: Int) -> some View {
        VStack(spacing: Wood.Spacing.xs) {
            ZStack {
                if number == game.position {
                    Button { store.duckSelected.toggle() } label: {
                        LittleDuck().frame(width: 72, height: 68).contentShape(Rectangle())
                            .overlay {
                                if store.duckSelected { RoundedRectangle(cornerRadius: Wood.Radius.control).stroke(Wood.Palette.slotStroke, style: StrokeStyle(lineWidth: 2, dash: [4, 4])) }
                            }
                    }
                    .buttonStyle(IllustrationButtonStyle())
                    .disabled(game.phase != .playing)
                    .accessibilityLabel("小鸭，现在在 \(number)")
                    .accessibilityHint("点选小鸭，再点目标荷叶；也可以用下方的左右跳按钮")
                    .scaleEffect(store.isDragging && !reduceMotion ? Wood.Motion.dragScale : 1)
                    .offset(store.dragOffset)
                    .shadow(color: Wood.Palette.textPrimary.opacity(store.isDragging ? 0.25 : 0), radius: 14, y: 12)
                    .highPriorityGesture(duckDrag)
                    .transition(reduceMotion ? .identity : .offset(y: -8).combined(with: .opacity))
                }
            }.frame(width: Wood.Size.token, height: 68)
                .animation(reduceMotion ? nil : .easeOut(duration: Wood.Motion.liftDuration), value: game.position)
            Button {
                store.move(to: number); store.duckSelected = false
            } label: {
                ZStack {
                    LilyShape().fill(Wood.Palette.successSide).offset(y: 4)
                    LilyShape().fill(Wood.Palette.success)
                    Text("\(number)").woodText(Wood.Typography.heading).foregroundStyle(Wood.Palette.onSuccess)
                        .padding(.top, Wood.Spacing.sm)
                }
                .frame(width: Wood.Size.token, height: Wood.Size.touchMinimum)
                .contentShape(Rectangle())
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: PadFramesKey.self, value: [number: geometry.frame(in: .named("pond"))])
                    }
                }
                .overlay {
                    if number == game.question.start {
                        LilyShape().stroke(Wood.Palette.slotStroke, style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    }
                }
            }
            .buttonStyle(IllustrationButtonStyle())
            .disabled(game.phase != .playing)
            .accessibilityLabel("数字 \(number) 的荷叶\(number == game.question.start ? "，起点" : "")")
            .accessibilityHint("把小鸭移到这里，再按跳好了确认答案")
            .accessibilityIdentifier("pad.\(number)")
            Text(number == game.question.start ? "起点" : " ")
                .woodText(Wood.Typography.support).foregroundStyle(Wood.Palette.textSecondary)
                .accessibilityHidden(true)
        }
    }

    private var duckDrag: some Gesture {
        DragGesture(minimumDistance: Wood.Motion.gestureTolerance, coordinateSpace: .named("pond"))
            .onChanged { value in
                guard game.phase == .playing else { return }
                store.isDragging = true
                store.dragOffset = value.translation
            }
            .onEnded { value in
                let target = store.padFrames.first { $0.value.contains(value.location) }?.key
                if game.phase == .playing, let target {
                    store.dragOffset = .zero
                    store.move(to: target)
                } else {
                    withAnimation(reduceMotion ? nil : .spring(response: Wood.Motion.springResponse, dampingFraction: Wood.Motion.springDamping)) {
                        store.dragOffset = .zero
                    }
                }
                store.isDragging = false
                store.duckSelected = false
            }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            if game.phase == .correct {
                RewardStatusView(game:.numberLine)
                feedback(correct: true, text: "跳对了！\(game.question.equation) = \(game.question.answer)")
                Button(game.index + 1 == game.questions.count ? "这一轮完成了" : "下一题") {
                    store.duckSelected = false; store.next()
                }
                .buttonStyle(WoodenPrimaryButtonStyle()).accessibilityIdentifier("game.next")
            } else {
                if let hint = game.hint {
                    feedback(correct: false, text: hint)
                }
                HStack(spacing: Wood.Spacing.controlGap) {
                    Button { store.jump(-1); store.duckSelected = false } label: { Label("往左跳", systemImage: "arrow.left") }
                        .buttonStyle(SecondaryWoodStyle()).disabled(game.position == 0)
                        .accessibilityLabel("往左跳一格").accessibilityIdentifier("game.left")
                    Button { store.jump(1); store.duckSelected = false } label: { Label("往右跳", systemImage: "arrow.right") }
                        .buttonStyle(SecondaryWoodStyle()).disabled(game.position == game.limit)
                        .accessibilityLabel("往右跳一格").accessibilityIdentifier("game.right")
                }
                HStack(spacing:12) {
                    WoodIconButton(symbol:"arrow.counterclockwise",label:"回到起点") { store.resetPosition(); store.duckSelected = false }
                    Button("跳好了") { store.duckSelected = false; store.check() }
                        .buttonStyle(WoodenPrimaryButtonStyle()).accessibilityIdentifier("game.check")
                }
            }
        }
    }

    private func feedback(correct: Bool, text: String) -> some View {
        Label(text, systemImage: correct ? "checkmark.circle.fill" : "lightbulb.fill")
            .woodText(Wood.Typography.body)
            .foregroundStyle(correct ? Wood.Palette.successText : Wood.Palette.hintText)
            .padding(Wood.Spacing.md).frame(maxWidth: .infinity, alignment: .leading)
            .background(correct ? Wood.Palette.successBackground : Wood.Palette.hintBackground,
                        in: RoundedRectangle(cornerRadius: Wood.Radius.control))
            .accessibilityElement(children: .combine)
    }

    private var completion: some View {
        Tray {
            VStack(spacing: Wood.Spacing.lg) {
                PondArtwork().frame(height: 180)
                Text("这一轮跳完了！").woodText(Wood.Typography.title).multilineTextAlignment(.center)
                Text(library.isReviewing(.numberLine) ? "这是复习练习，积分不会重复发放。" : "这一组还有 \(library.remaining(.numberLine)) 道新题。")
                    .woodText(Wood.Typography.body).multilineTextAlignment(.center)
                Text("你陪小鸭完成了 \(game.questions.count) 道题。")
                    .woodText(Wood.Typography.support).foregroundStyle(Wood.Palette.textSecondary)
            }
        }
    }
}
