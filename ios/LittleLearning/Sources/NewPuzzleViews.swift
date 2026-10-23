import SwiftUI
#if canImport(LearningCore)
import LearningCore
#endif

private let pieceColors: [Color] = [Color(red:0.77,green:0.36,blue:0.20),Color(red:0.32,green:0.52,blue:0.34),Color(red:0.32,green:0.48,blue:0.66),Color(red:0.67,green:0.44,blue:0.60),Color(red:0.70,green:0.52,blue:0.18),Color(red:0.41,green:0.41,blue:0.62),Color(red:0.28,green:0.56,blue:0.54)]
private struct TangramPolygon: Shape {
    let points: [GridPoint]
    var scale: CGFloat = 7
    func path(in rect: CGRect) -> Path {
        var path=Path()
        for (i,p) in points.enumerated() {
            let point=CGPoint(x:CGFloat(p.x)/scale*rect.width,y:CGFloat(p.y)/scale*rect.height)
            if i == 0 { path.move(to:point) } else { path.addLine(to:point) }
        }
        path.closeSubpath();return path
    }
}
struct TangramGameView: View {
    @EnvironmentObject private var library: CollectionStore
    private var s: TangramSession { library.progress.tangram }
    var body: some View {
        ChallengeHeading(subtitle:library.positionLabel(.tangram),title:"用七块木片，拼满轮廓")
        Tray(padding:8) {
            GeometryReader { geo in
                let cell=geo.size.width/7
                ZStack(alignment:.topLeading) {
                    RoundedRectangle(cornerRadius:8).fill(Wood.Palette.secondaryFill)
                    // Draw the exact silhouette, without relying on a saved-answer comparison.
                    ForEach(0..<7,id:\.self) { i in
                        TangramPolygon(points:TangramGeometry.polygon(i,s.task.solution[i]))
                            .fill(Wood.Palette.recess.opacity(0.55)).allowsHitTesting(false)
                        if s.task.tier == 0 {
                            TangramPolygon(points:TangramGeometry.polygon(i,s.task.solution[i]))
                                .stroke(Wood.Palette.slotStroke,style:StrokeStyle(lineWidth:1.5,dash:[5,3])).allowsHitTesting(false)
                        }
                    }
                    ForEach(0..<7,id:\.self) { y in
                        ForEach(0..<7,id:\.self) { x in
                            Button { library.progress.tangram.place(x:x,y:y) } label: {
                                Rectangle().fill(Color.clear)
                                    .overlay(alignment:.topLeading) { Circle().fill(Wood.Palette.slotStroke.opacity(0.35)).frame(width:3,height:3) }
                                    .frame(width:cell,height:cell).contentShape(Rectangle())
                            }.buttonStyle(.plain).position(x:(CGFloat(x)+0.5)*cell,y:(CGFloat(y)+0.5)*cell)
                                .disabled(s.phase != .playing)
                                .accessibilityLabel("放在第\(y+1)行第\(x+1)列，木片左上角")
                                .accessibilityIdentifier("tangram.cell.\(x).\(y)")
                        }
                    }
                    ForEach(0..<7,id:\.self) { i in
                        if let p=s.pieces[i] {
                            TangramPolygon(points:TangramGeometry.polygon(i,p)).fill(pieceColors[i].opacity(0.88))
                                .overlay { TangramPolygon(points:TangramGeometry.polygon(i,p)).stroke(i == s.selected ? Wood.Palette.textPrimary : Wood.Palette.canvas,lineWidth:i == s.selected ? 3 : 1.5) }
                                .allowsHitTesting(false)
                        }
                    }
                }.contentShape(Rectangle())
                    .highPriorityGesture(DragGesture(minimumDistance:8).onEnded { value in
                        guard s.phase == .playing else { return }
                        let x=value.startLocation.x/cell,y=value.startLocation.y/cell
                        guard let piece=(0..<7).reversed().first(where:{ i in s.pieces[i].map { TangramGeometry.contains(TangramGeometry.polygon(i,$0),x:Double(x),y:Double(y)) } ?? false }),let p=s.pieces[piece] else { return }
                        library.progress.tangram.select(piece)
                        library.progress.tangram.place(x:p.x+Int((value.translation.width/cell).rounded()),y:p.y+Int((value.translation.height/cell).rounded()))
                    })
            }.aspectRatio(1,contentMode:.fit).frame(maxWidth:440)
        }
        Text("选木片，再点格子放左上角；已放的木片也能拖动。")
            .woodText(Wood.Typography.support).foregroundStyle(Wood.Palette.textSecondary).multilineTextAlignment(.center)

    }
}

private struct TangramControls: View {
    @EnvironmentObject private var library: CollectionStore
    private var s: TangramSession { library.progress.tangram }
    var body: some View {
        HStack(spacing:4) {
            ForEach(0..<7,id:\.self) { i in
                Button { library.progress.tangram.select(i) } label: {
                    VStack(spacing:2) {
                        TangramPolygon(points:TangramGeometry.polygon(i,.init(x:0,y:0,rotation:s.turns[i],flipped:s.flips[i])),scale:4)
                            .fill(pieceColors[i]).frame(width:28,height:28)
                        Text("\(i+1)\(s.pieces[i] == nil ? "" : "✓")").font(.system(size:12,weight:.bold))
                    }.frame(maxWidth:.infinity,minHeight:52)
                        .background(s.selected == i ? Wood.Palette.successBackground : Wood.Palette.secondaryFill,in:RoundedRectangle(cornerRadius:10))
                        .overlay(RoundedRectangle(cornerRadius:10).stroke(s.selected == i ? Wood.Palette.slotStroke : .clear,lineWidth:2))
                }.buttonStyle(.plain).accessibilityLabel("木片\(i+1)\(s.pieces[i] == nil ? "，未放置" : "，已放置")")
                    .accessibilityIdentifier("tangram.piece.\(i)")
            }
        }
        HStack(spacing:8) {
            control("旋转 ↻",id:"rotate") { library.progress.tangram.rotate() }
            control("翻面",id:"flip") { library.progress.tangram.flip() }.disabled(s.selected != 6)
            control("拿回",id:"remove") { library.progress.tangram.remove() }.disabled(s.pieces[s.selected] == nil)
        }
    }
    private func control(_ title: String,id: String,action: @escaping ()->Void) -> some View {
        Button(action:action) { Text(title).font(.system(size:16,weight:.semibold)).frame(maxWidth:.infinity,minHeight:44).background(Wood.Palette.secondaryFill,in:RoundedRectangle(cornerRadius:10)) }
            .buttonStyle(.plain).accessibilityIdentifier("tangram.\(id)")
    }
}

struct DeliveryGameView: View {
    @EnvironmentObject private var library: CollectionStore
    private var s: RouteSession { library.progress.delivery }
    private var frame: RouteFrame { library.deliveryFrame ?? (s.phase == .correct ? s.task.trace(s.commands).frames.last! : .init(point:s.task.start,heading:0,collected:s.task.pickup == nil)) }
    var body: some View {
        ChallengeHeading(subtitle:library.positionLabel(.delivery),title:s.task.pickup == nil ? "排好指令，把信送到邮筒" : "先取信，再送到邮筒")
        Tray(padding:8) {
            LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:3),count:s.task.size),spacing:3) {
                ForEach(0..<(s.task.size*s.task.size),id:\.self) { i in
                    let p=GridPoint(i%s.task.size,i/s.task.size)
                    ZStack {
                        RoundedRectangle(cornerRadius:8).fill(s.task.obstacles.contains(p) ? Wood.Palette.successBackground : Wood.Palette.secondaryFill)
                        if s.task.obstacles.contains(p) { Image(systemName:"tree.fill").foregroundStyle(Wood.Palette.success) }
                        if p == s.task.goal { Text("📮").font(.system(size:27)) }
                        if p == s.task.pickup && !frame.collected { Image(systemName:"envelope.fill").foregroundStyle(Wood.Palette.actionPrimary) }
                        if p == frame.point {
                            VStack(spacing:0) {
                                LittleDuck().frame(width:32,height:32)
                                Image(systemName:["arrow.right","arrow.down","arrow.left","arrow.up"][frame.heading]).font(.system(size:13,weight:.black)).foregroundStyle(Wood.Palette.textPrimary)
                            }
                        }
                    }.aspectRatio(1,contentMode:.fit).font(.system(size:26))
                        .accessibilityLabel("第\(p.y+1)行第\(p.x+1)列，\(cellLabel(p))")
                        .accessibilityIdentifier("delivery.cell.\(p.x).\(p.y)")
                }
            }.frame(maxWidth:440)
        }
        Text("小鸭开始朝右 →。转弯只换方向，前进才走一格。")
            .woodText(Wood.Typography.support).foregroundStyle(Wood.Palette.textSecondary).multilineTextAlignment(.center)
        Tray(padding:12) {
            VStack(alignment:.leading,spacing:10) {
                Text(library.deliveryPlaying ? "正在走第 \(library.deliveryStep) 步" : "指令 \(s.commands.count) / 40 · 点指令可删除")
                    .woodText(Wood.Typography.support)
                if s.commands.isEmpty { Text("先在下面添加指令").woodText(Wood.Typography.label).foregroundStyle(Wood.Palette.textSecondary) }
                LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:5),count:6),spacing:6) {
                    ForEach(s.commands.indices,id:\.self) { i in
                        Button { library.stopDelivery();library.progress.delivery.remove(at:i) } label: {
                            VStack(spacing:3) {
                                Image(systemName:s.commands[i].symbol).font(.system(size:20,weight:.bold))
                                Text("\(i+1)").font(.system(size:11))
                            }.frame(maxWidth:.infinity,minHeight:48)
                                .background(library.deliveryPlaying && library.deliveryStep == i+1 ? Wood.Palette.successBackground : Wood.Palette.secondaryFill,in:RoundedRectangle(cornerRadius:8))
                        }.buttonStyle(.plain).disabled(library.deliveryPlaying || s.phase != .playing)
                            .accessibilityLabel("第\(i+1)步\(s.commands[i].title)，删除").accessibilityIdentifier("delivery.command.\(i)")
                    }
                }
            }.frame(maxWidth:.infinity,alignment:.leading)
        }
    }
    private func cellLabel(_ p: GridPoint) -> String {
        if p == frame.point { return "小鸭，朝\(["右","下","左","上"][frame.heading])" }
        if s.task.obstacles.contains(p) { return "树，不能走" }
        if p == s.task.pickup && !frame.collected { return "待取的信" }
        return p == s.task.goal ? "邮筒" : "空地"
    }
}

private struct BeadVisual: View {
    let token: BeadToken
    var body: some View {
        Image(systemName:token.symbol).resizable().scaledToFit().padding(10)
            .foregroundStyle([pieceColors[0],pieceColors[1],pieceColors[2],pieceColors[3]][token.color])
            .shadow(color:Wood.Palette.objectSide.opacity(0.18),radius:0,x:0,y:3)
            .accessibilityLabel(token.name)
    }
}
struct BeadsGameView: View {
    @EnvironmentObject private var library: CollectionStore
    private var s: BeadSession { library.progress.beads }
    var body: some View {
        ChallengeHeading(subtitle:library.positionLabel(.beads),title:"观察顺序，把缺少的珠子补上")
        Tray(padding:12) {
            LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:8),count:3),spacing:18) {
                ForEach(s.task.sequence.indices,id:\.self) { i in
                    let blank=s.task.blanks.firstIndex(of:i)
                    if let blank {
                        Button { library.progress.beads.select(blank) } label: { slot(i,blank:blank) }
                            .buttonStyle(.plain).allowsHitTesting(s.phase == .playing)
                            .accessibilityLabel("第\(i+1)颗，\(s.answers[blank]?.name ?? "空位")")
                            .accessibilityIdentifier("beads.slot.\(i)")
                    } else {
                        slot(i,blank:nil).accessibilityElement(children:.ignore)
                            .accessibilityLabel("第\(i+1)颗，\(s.task.sequence[i].name)")
                            .accessibilityIdentifier("beads.slot.\(i)")
                    }
                }
            }
        }
        Text("按数字顺序看。先点空位，再选下面的珠子。")
            .woodText(Wood.Typography.support).foregroundStyle(Wood.Palette.textSecondary).multilineTextAlignment(.center)
        LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:8),count:4),spacing:8) {
            ForEach(s.task.options.indices,id:\.self) { i in
                Button { library.progress.beads.choose(i) } label: {
                    BeadVisual(token:s.task.options[i]).frame(height:58).frame(maxWidth:.infinity)
                        .background(Wood.Palette.secondaryFill,in:RoundedRectangle(cornerRadius:12))
                }.buttonStyle(IllustrationButtonStyle()).disabled(s.phase != .playing)
                    .accessibilityLabel("选择\(s.task.options[i].name)").accessibilityIdentifier("beads.option.\(i)")
            }
        }
    }
    private func slot(_ i: Int,blank: Int?) -> some View {
        VStack(spacing:4) {
            ZStack {
                RoundedRectangle(cornerRadius:14).fill(blank == s.active ? Wood.Palette.successBackground : Wood.Palette.secondaryFill)
                if let blank {
                    if let token=s.answers[blank] { BeadVisual(token:token) }
                    else { Image(systemName:"questionmark").font(.system(size:27,weight:.bold)).foregroundStyle(Wood.Palette.textSecondary) }
                } else { BeadVisual(token:s.task.sequence[i]) }
            }.frame(height:64)
                .overlay(RoundedRectangle(cornerRadius:14).stroke(blank == s.active ? Wood.Palette.slotStroke : Wood.Palette.borderDecorative,style:StrokeStyle(lineWidth:blank == s.active ? 3 : 1,dash:blank == nil ? [] : [4,3])))
            Text("\(i+1)").font(.system(size:13,weight:.medium)).foregroundStyle(Wood.Palette.textSecondary)
        }
    }

}

struct NewPuzzleActions: View {
    let game: LearningGame
    @EnvironmentObject private var library: CollectionStore
    private var phase: PlayPhase { game == .tangram ? library.progress.tangram.phase : game == .delivery ? library.progress.delivery.phase : library.progress.beads.phase }
    private var hint: String? { game == .tangram ? library.progress.tangram.hint : game == .delivery ? library.progress.delivery.hint : library.progress.beads.hint }
    var body: some View {
        if phase == .correct {
            RewardStatusView(game:game)
            LibraryFeedback(text:game == .tangram ? "七块刚好拼满，没有重叠！" : game == .delivery ? "信送到了！" : library.progress.beads.task.explanation,correct:true)
            Button("下一关") { library.stopDelivery();library.advance(game) }.buttonStyle(WoodenPrimaryButtonStyle()).accessibilityIdentifier("\(game.rawValue).next")
        } else {
            if game == .tangram { TangramControls() }
            if let hint { LibraryFeedback(text:hint) }
            if game == .delivery {
                HStack(spacing:8) {
                    ForEach(RouteCommand.allCases,id:\.rawValue) { command in
                        Button { library.stopDelivery();library.progress.delivery.append(command) } label: {
                            Label(command.title,systemImage:command.symbol).frame(maxWidth:.infinity,minHeight:48)
                        }.buttonStyle(SecondaryWoodStyle()).disabled(library.deliveryPlaying || library.progress.delivery.commands.count >= 40)
                            .accessibilityIdentifier("delivery.add.\(command.rawValue)")
                    }
                }
            }
            HStack(spacing:12) {
                Button(library.deliveryPlaying && game == .delivery ? "停止" : "重来") {
                    if game == .delivery { if library.deliveryPlaying { library.stopDelivery() } else { library.stopDelivery();library.progress.delivery.reset() } }
                    else if game == .tangram { library.progress.tangram.reset() }
                    else { library.progress.beads.reset() }
                }.buttonStyle(SecondaryWoodStyle()).accessibilityIdentifier("\(game.rawValue).reset")
                Button(game == .delivery ? "走一遍" : "做好了") {
                    if game == .delivery { library.runDelivery() }
                    else if game == .tangram { library.progress.tangram.check() }
                    else { library.progress.beads.check() }
                }.buttonStyle(WoodenPrimaryButtonStyle()).disabled(game == .delivery && (library.deliveryPlaying || library.progress.delivery.commands.isEmpty))
                    .accessibilityIdentifier("\(game.rawValue).check")
            }
        }
    }
}
