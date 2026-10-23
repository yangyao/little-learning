import SwiftUI
#if canImport(LearningCore)
import LearningCore
#endif

struct ClockGameView: View {
    @EnvironmentObject private var library: CollectionStore
    private var session: ClockSession { library.progress.clock }
    var body: some View {
        if session.phase == .complete {
            GameCompletion(game:.clock,message:"1 时 = 60 分，1 分 = 60 秒。") { library.restart(.clock) }
        } else {
            ChallengeHeading(subtitle:library.positionLabel(.clock),title:session.task.prompt)
            if session.task.mode == .conversion {
                Image(systemName:"hourglass").font(.system(size:80)).foregroundStyle(Wood.Palette.actionPrimary).padding()

            } else {
                Tray(padding:16) {
                    VStack(spacing:16) {
                        ClockDial(minutes:session.minutes,seconds:session.seconds,showSeconds:session.task.mode == .seconds,selected:session.hand)
                            .aspectRatio(1,contentMode:.fit).frame(maxWidth:240)
                            .overlay {
                                GeometryReader { geometry in
                                    Color.clear.contentShape(Circle())
                                        .gesture(DragGesture(minimumDistance:0).onChanged { value in
                                            let dx=value.location.x-geometry.size.width/2, dy=value.location.y-geometry.size.height/2
                                            guard hypot(dx,dy) > geometry.size.width * 0.08 else { return }
                                            let angle=atan2(dx,-dy), fraction=(angle + 2 * .pi).truncatingRemainder(dividingBy:2 * .pi)/(2 * .pi)
                                            library.progress.clock.setTick(Int((fraction*60).rounded()) % 60,carry:library.clockDragging)
                                            library.clockDragging = true
                                        }.onEnded { _ in library.clockDragging = false })
                                }
                            }
                            .accessibilityElement(children:.ignore)
                            .accessibilityLabel(session.task.mode == .seconds ? "秒针 \(session.seconds) 秒" : "钟面 \(ClockTask.text(session.minutes))")
                            .accessibilityValue(session.hand == .hour ? "正在调时针" : session.hand == .minute ? "正在调分针" : "正在调秒针")
                            .accessibilityAdjustableAction { direction in library.progress.clock.nudge(direction == .increment ? 1 : -1) }
                        Text(session.task.mode == .seconds ? "\(session.seconds) 秒" : ClockTask.text(session.minutes))
                            .woodText(Wood.Typography.display).monospacedDigit().accessibilityIdentifier("clock.value")
                    }.frame(maxWidth:.infinity)
                }

            }

        }
    }

}

struct ClockDial: View {
    let minutes: Int, seconds: Int
    let showSeconds: Bool
    let selected: ClockSession.Hand
    var body: some View {
        GeometryReader { geometry in
            let side=min(geometry.size.width,geometry.size.height), center=CGPoint(x:side/2,y:side/2)
            ZStack {
                Circle().fill(Wood.Palette.traySide).offset(y:4)
                Circle().fill(Wood.Palette.surface).overlay(Circle().strokeBorder(Wood.Palette.actionPrimary,lineWidth:4))
                ForEach(0..<60,id:\.self) { tick in
                    Rectangle().fill(Wood.Palette.textSecondary).frame(width:tick % 5 == 0 ? 3 : 1,height:tick % 5 == 0 ? 12 : 5)
                        .offset(y:-side*0.455).rotationEffect(.degrees(Double(tick)*6))
                }
                ForEach(1...12,id:\.self) { number in
                    Text("\(number)").woodText(Wood.Typography.heading)
                        .position(point(center:center,radius:side*0.36,angle:Double(number)*30))
                }
                hand(center:center,length:side*0.22,angle:Double(minutes)*0.5,width:selected == .hour ? 9 : 7,color:Wood.Palette.actionPrimary)
                hand(center:center,length:side*0.33,angle:Double(minutes % 60)*6,width:selected == .minute ? 7 : 5,color:Wood.Palette.successText)
                if showSeconds { hand(center:center,length:side*0.39,angle:Double(seconds)*6,width:3,color:Wood.Palette.objectSide) }
                Circle().fill(Wood.Palette.textPrimary).frame(width:16,height:16)
            }.frame(width:side,height:side)
        }
    }
    private func point(center: CGPoint,radius: CGFloat,angle: Double) -> CGPoint {
        CGPoint(x:center.x+sin(angle * .pi/180)*radius,y:center.y-cos(angle * .pi/180)*radius)
    }
    private func hand(center: CGPoint,length: CGFloat,angle: Double,width: CGFloat,color: Color) -> some View {
        Path { path in path.move(to:center); path.addLine(to:point(center:center,radius:length,angle:angle)) }
            .stroke(color,style:StrokeStyle(lineWidth:width,lineCap:.round))
    }
}
