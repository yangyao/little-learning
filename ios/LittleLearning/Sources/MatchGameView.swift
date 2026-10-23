import SwiftUI
#if canImport(LearningCore)
import LearningCore
#endif

struct MatchGameView: View {
    @EnvironmentObject private var library: CollectionStore
    @StateObject private var drag = MatchDragState()
    private var session: MatchSession { library.progress.matches }
    var body: some View {
        if session.phase == .complete {
            GameCompletion(game:.matches,message:"\(MatchPuzzle.all.count) 道移一根挑战都完成了！") { library.restart(.matches) }
        } else {
            ChallengeHeading(subtitle:library.positionLabel(.matches),title:"移动一根火柴，让等式成立")
            Tray(padding:8) {
                GeometryReader { geometry in
                    let layout=MatchBoardLayout(size:geometry.size)
                    ZStack(alignment:.topLeading) {
                        ForEach(0..<23,id:\.self) { bit in
                            let active=session.mask & (1 << bit) != 0
                            Button { library.progress.matches.tap(bit) } label: {
                                MatchStick(active:active,vertical:layout.vertical(bit),selected:session.selectedMatch == bit || drag.source == bit)
                                    .frame(width:layout.vertical(bit) ? 10 : layout.length,height:layout.vertical(bit) ? layout.length : 10)
                                    .offset(x:bit == 21 ? -layout.length*0.30 : 0,y:bit == 22 ? layout.length*0.30 : 0)
                                    .frame(width:40,height:44).contentShape(Rectangle())
                            }.buttonStyle(IllustrationButtonStyle())
                                .position(layout.hitCenter(bit))
                                .opacity(drag.source == bit ? 0.3 : 1)
                                .disabled(session.phase != .playing || session.mask != session.puzzle.initial)
                                .accessibilityLabel("\(layout.label(bit))，\(active ? "火柴" : "空位")\(session.selectedMatch == bit ? "，已选中" : "")")
                                .accessibilityIdentifier("matches.segment.\(bit)")
                        }
                        VStack(spacing:10) {
                            MatchStick(active:true,vertical:false).frame(width:layout.length*0.65,height:8)
                            MatchStick(active:true,vertical:false).frame(width:layout.length*0.65,height:8)
                        }.position(x:layout.unit*3.5,y:geometry.size.height/2).accessibilityLabel("等号，固定不动")
                        if let point=drag.point {
                            MatchStick(active:true,vertical:false,selected:true).frame(width:layout.length,height:10)
                                .position(point).allowsHitTesting(false)
                        }
                    }
                    .contentShape(Rectangle())
                    .highPriorityGesture(DragGesture(minimumDistance:0)
                        .onChanged { value in
                            guard session.phase == .playing, session.mask == session.puzzle.initial else { return }
                            guard hypot(value.translation.width,value.translation.height) >= 10 else { return }
                            if drag.source == nil, let bit=layout.nearest(value.startLocation), session.mask & (1 << bit) != 0 { drag.source=bit }
                            if drag.source != nil { drag.point=value.location }
                        }.onEnded { value in
                            if let from=drag.source, let to=layout.nearest(value.location) { library.progress.matches.move(from:from,to:to) }
                            else if hypot(value.translation.width,value.translation.height) < 10, let bit=layout.nearest(value.location) { library.progress.matches.tap(bit) }
                            drag.source=nil;drag.point=nil
                        })
                }.aspectRatio(1.9,contentMode:.fit).frame(maxWidth:600)
            }
            Text("实心是火柴，虚线是可以放的位置。等号不能移动。")
                .woodText(Wood.Typography.support).foregroundStyle(Wood.Palette.textSecondary).multilineTextAlignment(.center)
        }
    }
}

private struct MatchStick: View {
    let active: Bool, vertical: Bool
    var selected = false
    var body: some View {
        ZStack(alignment:vertical ? .top : .trailing) {
            Capsule().fill(active ? Wood.Palette.object : Wood.Palette.recess.opacity(0.35))
            if active { Circle().fill(Wood.Palette.objectSide).frame(width:10,height:10) }
            Capsule().strokeBorder(selected ? Wood.Palette.slotStroke : Wood.Palette.borderDecorative,
                                   style:StrokeStyle(lineWidth:selected ? 3 : 1,dash:active ? [] : [3,3]))
        }
    }
}

private struct MatchBoardLayout {
    let size: CGSize
    var unit: CGFloat { size.width/5 }
    var length: CGFloat { unit*0.60 }
    func vertical(_ bit: Int) -> Bool { bit == 22 || (bit < 21 && [1,2,4,5].contains(bit % 7)) }
    func center(_ bit: Int) -> CGPoint {
        if bit >= 21 { return CGPoint(x:unit*1.5,y:size.height/2) }
        let group=bit/7, segment=bit % 7, x=unit*([0.5,2.5,4.5][group]), y=size.height/2
        let dx=unit*0.36, dy=unit*0.84
        let points: [CGPoint] = [.init(x:x,y:y-dy),.init(x:x+dx,y:y-dy/2),.init(x:x+dx,y:y+dy/2),.init(x:x,y:y+dy),.init(x:x-dx,y:y+dy/2),.init(x:x-dx,y:y-dy/2),.init(x:x,y:y)]
        return points[segment]
    }
    func nearest(_ point: CGPoint) -> Int? {
        // The operator's two sticks cross; choose its vertical arm away from the horizontal center.
        let candidates=(0..<23).map { bit -> (Int,CGFloat) in
            let c=hitCenter(bit)
            return (bit,hypot(point.x-c.x,point.y-c.y))
        }
        guard let best=candidates.min(by:{$0.1<$1.1}),best.1 < max(28,unit*0.45) else { return nil }
        return best.0
    }
    func hitCenter(_ bit: Int) -> CGPoint {
        var point=center(bit)
        if bit == 21 { point.x += length*0.30 }
        if bit == 22 { point.y -= length*0.30 }
        return point
    }
    func label(_ bit: Int) -> String {
        if bit >= 21 { return bit == 21 ? "运算符横棒" : "运算符竖棒" }
        return ["左边数字","中间数字","右边数字"][bit/7] + ["上棒","右上棒","右下棒","下棒","左下棒","左上棒","中棒"][bit % 7]
    }
}

@MainActor private final class MatchDragState: ObservableObject {
    @Published var source: Int?
    @Published var point: CGPoint?
}
