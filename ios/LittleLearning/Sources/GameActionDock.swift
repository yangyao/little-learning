import SwiftUI
#if canImport(LearningCore)
import LearningCore
#endif

/// Kept outside the lesson scroll view: feedback and the next action share the viewport.
struct GameActionDock<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing:8) { content }
            .frame(maxWidth:760)
            .padding(.horizontal,Wood.Size.phoneMargin).padding(.vertical,10)
            .frame(maxWidth:.infinity)
            .background(Wood.Palette.canvas)
            .overlay(alignment:.top) { Rectangle().fill(Wood.Palette.borderDecorative).frame(height:1) }
    }
}

struct CollectionGameActions: View {
    let game: LearningGame
    @EnvironmentObject private var library: CollectionStore
    var body: some View {
        if library.isGroupFinished(game) { StudyFinishedActions(game:game) }
        else if game.isNewPuzzle { NewPuzzleActions(game:game) }
        else if game.isWorkshop { workshop }
        else {
            switch game {
            case .sharing: sharing
            case .clock: clock
            case .matches: matches
            case .sorting: sorting
            case .printing: printing
            default: EmptyView()
            }
        }
    }
    private func restart() -> some View {
        Button("再玩一次") { library.restart(game) }.buttonStyle(WoodenPrimaryButtonStyle()).accessibilityIdentifier("library.restart")
    }
    @ViewBuilder private var sharing: some View {
        let s=library.progress.sharing, t=s.task
        if s.phase == .complete { restart() }
        else if s.phase == .correct {
            RewardStatusView(game:game)
            LibraryFeedback(text:t.remainder > 0 ? "每盘 \(t.each) 个，还剩 \(t.remainder) 个。\(t.total) ÷ \(t.bowls) = \(t.each) 余 \(t.remainder)" : library.group(.sharing)?.id == "sharing-hands" ? "每盘 \(t.each) 个，一样多！" : "每盘 \(t.each) 个，一样多！\(t.total) ÷ \(t.bowls) = \(t.each)",correct:true)
            Button("下一份野餐") { library.advance(.sharing) }.buttonStyle(WoodenPrimaryButtonStyle()).accessibilityIdentifier("sharing.next")
        } else {
            if let hint=s.hint { LibraryFeedback(text:hint) }
            HStack(spacing:12) {
                Button("全部拿回") { library.progress.sharing.reset() }.buttonStyle(SecondaryWoodStyle())
                Button("分好了") { library.progress.sharing.check() }.buttonStyle(WoodenPrimaryButtonStyle()).accessibilityIdentifier("sharing.check")
            }
        }
    }
    @ViewBuilder private var workshop: some View {
        let s=library.session(game), qs=WorkshopContent.questions(for:game), q=qs[s.index]
        if s.phase == .complete { restart() }
        else if s.phase == .correct {
            RewardStatusView(game:game)
            LibraryFeedback(text:q.explanation,correct:true)
            Button("下一题") { library.advance(game) }
                .buttonStyle(WoodenPrimaryButtonStyle()).accessibilityIdentifier("workshop.next")
        } else if s.phase == .followUp {
            Text(q.followUp).woodText(Wood.Typography.label).multilineTextAlignment(.center)
            if let hint=s.hint { LibraryFeedback(text:hint) }
            let order=choices(q,s.index)
            ForEach(order,id:\.self) { i in
                Button(q.choices[i]) { library.editWorkshop(game) { $0.answerFollowUp(i,question:q) } }
                    .buttonStyle(SecondaryWoodStyle()).accessibilityIdentifier("workshop.choice.\(i)")
            }
        } else {
            if let hint=s.hint { LibraryFeedback(text:hint) }
            HStack(spacing:12) {
                WoodIconButton(symbol:"arrow.counterclockwise",label:"重新摆") { library.editWorkshop(game) { $0.reset() } }
                Button(game == .bakery ? "放进烤箱" : game == .pinyin ? "开车啰" : "拼好了") { library.editWorkshop(game) { $0.check(q) } }
                    .buttonStyle(WoodenPrimaryButtonStyle()).accessibilityIdentifier("workshop.check")
            }
        }
    }
    private func choices(_ q: WorkshopQuestion,_ index: Int) -> [Int] {
        var rng=SeededRandom(seed:UInt64(index*19+37))
        return Array(q.choices.indices).shuffled(using:&rng)
    }
    @ViewBuilder private var clock: some View {
        let s=library.progress.clock
        if s.phase == .complete { restart() }
        else if s.phase == .correct {
            RewardStatusView(game:game)
            LibraryFeedback(text:"对了！\(s.task.tip)",correct:true)
            Button("下一题") { library.advance(.clock) }.buttonStyle(WoodenPrimaryButtonStyle()).accessibilityIdentifier("clock.next")
        } else {
            if let hint=s.hint { LibraryFeedback(text:hint) }
            if s.task.mode == .conversion {
                ForEach(s.task.choices.indices,id:\.self) { i in
                    Button(s.task.choices[i]) { library.progress.clock.check(choice:i) }.buttonStyle(SecondaryWoodStyle()).accessibilityIdentifier("clock.choice.\(i)")
                }
            } else {
                if s.task.mode != .seconds {
                    HStack(spacing:12) {
                        clockHand(.hour,title:"时针",selected:s.hand == .hour)
                        clockHand(.minute,title:"分针",selected:s.hand == .minute)
                    }
                }
                HStack(spacing:12) {
                    WoodIconButton(symbol:"minus",label:"退一格") { library.progress.clock.nudge(-1) }.accessibilityIdentifier("clock.minus")
                    Button("拨好了") { library.progress.clock.check() }.buttonStyle(WoodenPrimaryButtonStyle()).accessibilityIdentifier("clock.check")
                    WoodIconButton(symbol:"plus",label:"进一格") { library.progress.clock.nudge(1) }.accessibilityIdentifier("clock.plus")
                }
            }
        }
    }
    private func clockHand(_ hand: ClockSession.Hand,title: String,selected: Bool) -> some View {
        Button { library.progress.clock.select(hand) } label: {
            Label(title,systemImage:selected ? "checkmark.circle.fill" : "circle")
                .woodText(Wood.Typography.label).frame(maxWidth:.infinity,minHeight:64)
                .foregroundStyle(Wood.Palette.textPrimary)
                .background(selected ? Wood.Palette.successBackground : Wood.Palette.secondaryFill,in:RoundedRectangle(cornerRadius:16))
                .overlay(RoundedRectangle(cornerRadius:16).strokeBorder(Wood.Palette.slotStroke,lineWidth:selected ? 3 : 1))
        }.buttonStyle(IllustrationButtonStyle()).accessibilityIdentifier("clock.hand.\(hand.rawValue)")
    }
    @ViewBuilder private var matches: some View {
        let s=library.progress.matches
        if s.phase == .complete { restart() }
        else if s.phase == .correct {
            RewardStatusView(game:game)
            LibraryFeedback(text:"移走一根，再放一根，等式成立了！",correct:true)
            Button("下一题") { library.advance(.matches) }.buttonStyle(WoodenPrimaryButtonStyle()).accessibilityIdentifier("matches.next")
        } else {
            if let hint=s.hint { LibraryFeedback(text:hint) }
            else { Text(s.mask != s.puzzle.initial ? "已移动 1 根，检查一下吧" : s.selectedMatch == nil ? "点一根火柴，再点空位；也可以直接拖动" : "已选中一根，点虚线空位放下")
                .woodText(Wood.Typography.support).multilineTextAlignment(.center) }
            HStack(spacing:12) {
                Button("重新摆") { library.progress.matches.reset() }.buttonStyle(SecondaryWoodStyle()).accessibilityIdentifier("matches.reset")
                Button("检查等式") { library.progress.matches.check() }.buttonStyle(WoodenPrimaryButtonStyle()).accessibilityIdentifier("matches.check")
            }
        }
    }
    @ViewBuilder private var sorting: some View {
        let s=library.progress.fruits
        if s.isSolved {
            RewardStatusView(game:game)
            LibraryFeedback(text:"每一罐都分好了！",correct:true)
            Button("下一关") { library.advance(.sorting) }.buttonStyle(WoodenPrimaryButtonStyle()).accessibilityIdentifier("sorting.next")
        } else {
            if let hint=s.hint { LibraryFeedback(text:hint) }
            HStack(spacing:12) {
                Button("退一步") { library.progress.fruits.undo() }.disabled(s.history.isEmpty).accessibilityIdentifier("sorting.undo")
                Button("重新分") { library.progress.fruits.reset() }.accessibilityIdentifier("sorting.reset")
            }.buttonStyle(SecondaryWoodStyle())
        }
    }
    @ViewBuilder private var printing: some View {
        let s=library.progress.printing
        if let note=s.note { LibraryFeedback(text:note,correct:!s.stamps.isEmpty) }
        HStack(spacing:8) {
            WoodIconButton(symbol:"arrow.uturn.backward",label:"退一笔") { library.progress.printing.undo() }.disabled(s.stamps.isEmpty).accessibilityIdentifier("printing.undo")
            WoodIconButton(symbol:"doc.badge.plus",label:"新画纸") { library.progress.printing.newPaper() }.accessibilityIdentifier("printing.new")
            Button("收好作品") { library.progress.printing.keep() }.buttonStyle(WoodenPrimaryButtonStyle()).accessibilityIdentifier("printing.keep")
        }
    }
}
