import SwiftUI
#if canImport(LearningCore)
import LearningCore
#endif

private final class RulerDragState: ObservableObject { var start: Int? }
private struct RulerBody: Shape {
    let broken: Bool
    func path(in r: CGRect) -> Path {
        if !broken { return Path(roundedRect:r,cornerRadius:10) }
        var p=Path();p.move(to:.init(x:10,y:0));p.addLine(to:.init(x:r.width,y:0));p.addLine(to:.init(x:r.width,y:r.height));p.addLine(to:.init(x:10,y:r.height))
        for y in stride(from:r.height,through:0,by:-10) { p.addLine(to:.init(x:Int(y/10)%2 == 0 ? 0 : 10,y:y)) }
        p.closeSubpath();return p
    }
}
struct RulerGameView: View {
    @EnvironmentObject private var library: CollectionStore
    @StateObject private var drag=RulerDragState()
    private var s: RulerSession { library.progress.ruler }
    var body: some View {
        VStack(spacing:14) {
            ChallengeHeading(subtitle:library.positionLabel(.ruler),title:s.task.prompt)
            Tray(padding:12) {
                GeometryReader { geo in board(width:geo.size.width) }.frame(height:225)
            }
            Text(instruction).font(.system(size:16,weight:.medium)).foregroundStyle(Wood.Palette.textSecondary).multilineTextAlignment(.center)
            if s.task.mode == .explore {
                HStack(spacing:8) {
                    ForEach(s.task.distances.sorted(),id:\.self) { n in
                        VStack(spacing:4) {
                            Image(systemName:s.found.contains(n) ? "checkmark.circle.fill" : "circle.dashed")
                            Text("\(n)厘米").font(.system(size:13,weight:.semibold))
                        }.frame(maxWidth:.infinity,minHeight:60).foregroundStyle(s.found.contains(n) ? Wood.Palette.successText : Wood.Palette.textSecondary)
                            .background(s.found.contains(n) ? Wood.Palette.successBackground : Wood.Palette.secondaryFill,in:RoundedRectangle(cornerRadius:12))
                            .accessibilityLabel("\(n)厘米，\(s.found.contains(n) ? "已找到" : "待寻找")")
                    }
                }
            }
        }.onChange(of:s.index) { _,_ in drag.start=nil }
    }
    private var instruction: String {
        switch s.task.mode {
        case .measure:return "拖动尺子，或用下方箭头移动。0对齐物体左端，再选长度。"
        case .offset:return "两端对上刻线后，数中间的间隔。长度不是右端的数字。"
        case .missingNumber:return "每格表示1厘米。看看问号前后的数字。"
        case .target,.explore:return "点两个现存刻度。一次摆放，只能用现有刻度当端点。"
        }
    }
    private func board(width: CGFloat) -> some View {
        let t=s.task,base=t.marks[0],maximum=t.marks.last!+(t.canMove ? 4 : 0)
        let unit=(width-32)/CGFloat(maximum-base)
        let x: (Int)->CGFloat = { value in 16+CGFloat(value-base)*unit }
        let a=t.canMove ? t.objectStart-s.origin : (s.pair.first ?? t.marks[0])
        let b=t.canMove ? a+t.length : (s.pair.last ?? a)
        let help=(s.showUnits || s.phase == .correct) && ((t.canMove && s.aligned) || (!t.canMove && s.pair.count == 2))
        return ZStack(alignment:.topLeading) {
            if t.canMove {
                object(width:unit*CGFloat(t.length)).position(x:x(t.objectStart)+unit*CGFloat(t.length)/2,y:45)
                Path { p in
                    for value in [t.objectStart,t.objectStart+t.length] { p.move(to:.init(x:x(value),y:28));p.addLine(to:.init(x:x(value),y:116)) }
                }.stroke(Wood.Palette.textSecondary,style:StrokeStyle(lineWidth:1,dash:[3,4]))
            } else {
                Text(t.mode == .missingNumber ? "？处应该填几？" : t.mode == .target ? "目标：\(t.length)厘米" : "发现一种，点亮一张长度牌")
                    .font(.system(size:18,weight:.semibold)).foregroundStyle(Wood.Palette.textPrimary)
                    .frame(width:width).position(x:width/2,y:40)
            }
            if help,b > a {
                ForEach(a..<b,id:\.self) { value in
                    RoundedRectangle(cornerRadius:3).fill(Wood.Palette.success.opacity(0.24))
                        .frame(width:max(1,unit-2),height:22).overlay { Text("1").font(.system(size:11,weight:.bold)).foregroundStyle(Wood.Palette.successText) }
                        .position(x:x(value+s.origin)+unit/2,y:99)
                }
            }
            ruler(unit:unit,x:x,width:width)
            if !t.canMove,t.mode != .missingNumber,s.pair.count == 2 {
                Path { p in p.move(to:.init(x:x(a),y:90));p.addLine(to:.init(x:x(a),y:78));p.addLine(to:.init(x:x(b),y:78));p.addLine(to:.init(x:x(b),y:90)) }
                    .stroke(Wood.Palette.success,style:StrokeStyle(lineWidth:3,lineCap:.round))
            }
            Text("厘米 · 示意尺").accessibilityLabel(rulerDescription).font(.system(size:12)).foregroundStyle(Wood.Palette.textSecondary).position(x:width/2,y:208)
        }.frame(width:width,height:225)
    }
    private var rulerDescription: String {
        let t=s.task
        let marks=t.marks.map { t.blank == $0 ? "问号" : String($0) }.joined(separator:"、")
        var text="示意尺，刻度\(marks)，单位厘米。"
        if t.canMove {
            let a=t.objectStart-s.origin,b=a+t.length
            if t.marks.contains(a) && t.marks.contains(b) { text += "物体左端在刻度\(a)，右端在刻度\(b)。可用下方箭头移动尺子。" }
            else { text += "物体两端还没有对齐尺子范围内的刻线。可用下方箭头移动尺子。" }
        }
        return text
    }
    private func ruler(unit: CGFloat,x: @escaping (Int)->CGFloat,width: CGFloat) -> some View {
        let t=s.task,left=t.marks[0]+s.origin,right=t.marks.last!+s.origin
        return ZStack(alignment:.topLeading) {
            RulerBody(broken:t.marks[0] > 0).fill(Wood.Palette.objectSide).frame(width:x(right)-x(left)+22,height:74).position(x:(x(left)+x(right))/2,y:153)
            RulerBody(broken:t.marks[0] > 0).fill(Wood.Palette.secondaryFill).frame(width:x(right)-x(left)+22,height:70).position(x:(x(left)+x(right))/2,y:147)
            ForEach(t.marks,id:\.self) { value in
                if t.mode == .target || t.mode == .explore {
                    Button { library.progress.ruler.tap(value) } label: {
                        VStack(spacing:6) {
                            Rectangle().fill(s.pair.contains(value) ? Wood.Palette.success : Wood.Palette.slotStroke).frame(width:s.pair.contains(value) ? 4 : 2,height:22)
                            Text("\(value)").font(.system(size:18,weight:.bold)).foregroundStyle(Wood.Palette.textPrimary)
                        }.frame(width:min(44,unit),height:65).background(s.pair.contains(value) ? Wood.Palette.successBackground : Color.clear,in:RoundedRectangle(cornerRadius:8))
                    }.buttonStyle(.plain).disabled(s.phase != .playing).position(x:x(value),y:145)
                        .accessibilityLabel("刻度\(value)\(s.pair.contains(value) ? "，已选中" : "")").accessibilityIdentifier("ruler.mark.\(value)")
                } else {
                    VStack(spacing:6) {
                        Rectangle().fill(Wood.Palette.slotStroke).frame(width:2,height:value%2 == 0 ? 24 : 18)
                        Text(t.blank == value ? "？" : "\(value)").font(.system(size:14,weight:.bold)).foregroundStyle(t.blank == value ? Wood.Palette.actionPrimary : Wood.Palette.textPrimary)
                    }.frame(width:unit,height:60,alignment:.top).position(x:x(value+s.origin),y:145).accessibilityHidden(true)
                }
            }
        }.frame(width:width,height:225).contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance:6).onChanged { value in
                guard t.canMove,s.phase == .playing else { return }
                if drag.start == nil { drag.start=s.origin }
                library.progress.ruler.move(to:drag.start!+Int((value.translation.width/unit).rounded()))
            }.onEnded { _ in drag.start=nil })

    }
    private func object(width: CGFloat) -> some View {
        HStack(spacing:0) {
            RoundedRectangle(cornerRadius:3).fill(Color(red:0.83,green:0.38,blue:0.26)).frame(width:8,height:24)
            Rectangle().fill(Wood.Palette.hint).overlay(alignment:.top) { Rectangle().fill(Color.white.opacity(0.35)).frame(height:5) }
            PencilPoint().fill(Wood.Palette.object).frame(width:min(14,max(5,width/4)))
        }.frame(width:max(12,width),height:24).shadow(color:Wood.Palette.objectSide.opacity(0.25),radius:0,x:0,y:3).accessibilityLabel("待测量的铅笔")
    }
}
private struct PencilPoint: Shape {
    func path(in r:CGRect)->Path { var p=Path();p.move(to:.zero);p.addLine(to:.init(x:r.width,y:r.midY));p.addLine(to:.init(x:0,y:r.height));p.closeSubpath();return p }
}
struct RulerActions: View {
    @EnvironmentObject private var library: CollectionStore
    private var s: RulerSession { library.progress.ruler }
    var body: some View {
        if s.phase == .correct {
            RewardStatusView(game:.ruler)
            LibraryFeedback(text:s.explanation,correct:true)
            Button("下一关") { library.advance(.ruler) }.buttonStyle(WoodenPrimaryButtonStyle()).accessibilityIdentifier("ruler.next")
        } else {
            if let hint=s.hint { LibraryFeedback(text:hint,correct:s.task.mode == .explore && hint.hasPrefix("找到")) }
            if s.task.canMove {
                HStack(spacing:12) {
                    Button { library.progress.ruler.move(to:s.origin-1) } label: { Label("左移",systemImage:"arrow.left") }.buttonStyle(SecondaryWoodStyle()).disabled(s.origin == 0).accessibilityIdentifier("ruler.left")
                    Button { library.progress.ruler.move(to:s.origin+1) } label: { Label("右移",systemImage:"arrow.right") }.buttonStyle(SecondaryWoodStyle()).disabled(s.origin == 4).accessibilityIdentifier("ruler.right")
                }
            }
            if s.task.mode != .target && s.task.mode != .explore {
                LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:6),count:5),spacing:6) {
                    ForEach(0...8,id:\.self) { value in
                        Button { library.progress.ruler.choose(value) } label: {
                            Text("\(value)").font(.system(size:19,weight:.semibold)).frame(maxWidth:.infinity,minHeight:44)
                                .foregroundStyle(Wood.Palette.textPrimary).background(s.answer == value ? Wood.Palette.successBackground : Wood.Palette.secondaryFill,in:RoundedRectangle(cornerRadius:10))
                                .overlay(RoundedRectangle(cornerRadius:10).stroke(s.answer == value ? Wood.Palette.success : .clear,lineWidth:2))
                        }.buttonStyle(IllustrationButtonStyle()).accessibilityLabel("选择\(value)").accessibilityIdentifier("ruler.answer.\(value)")
                    }
                }
            }
            HStack(spacing:10) {
                Button("提示") { library.progress.ruler.revealHint() }.buttonStyle(SecondaryWoodStyle()).frame(width:72).lineLimit(1).minimumScaleFactor(0.8).accessibilityIdentifier("ruler.hint")
                if s.task.mode == .target || s.task.mode == .explore {
                    Button("重选") { library.progress.ruler.clearPair() }.buttonStyle(SecondaryWoodStyle()).frame(width:72).lineLimit(1).minimumScaleFactor(0.8).accessibilityIdentifier("ruler.clear")
                }
                Button(s.task.mode == .explore ? "发现了" : s.task.mode == .missingNumber ? "补好了" : "量好了") { library.progress.ruler.check() }.buttonStyle(WoodenPrimaryButtonStyle()).lineLimit(1).minimumScaleFactor(0.8).layoutPriority(1).accessibilityIdentifier("ruler.check")
            }
        }
    }
}
