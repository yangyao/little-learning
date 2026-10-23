import SwiftUI
#if canImport(LearningCore)
import LearningCore
#endif

enum PrintPalette {
    static let names=["枫红","橘橙","金黄","草绿","湖蓝","紫罗兰"]
    // Paint colors are artwork content, intentionally separate from UI semantic feedback colors.
    static let colors: [Color] = [Color(red:0.67,green:0.24,blue:0.22),Wood.Palette.object,Wood.Palette.hint,Wood.Palette.success,Color(red:0.18,green:0.51,blue:0.62),Color(red:0.48,green:0.31,blue:0.63)]
    static let materials=["树叶","枫叶","银杏","莲藕"]
}

struct PrintingGameView: View {
    @EnvironmentObject private var library: CollectionStore
    private var session: PrintSession { library.progress.printing }
    var body: some View {
        Text("选材料，在画纸上点一下盖章。")
            .woodText(Wood.Typography.body).multilineTextAlignment(.center)
        LazyVGrid(columns:[GridItem(.adaptive(minimum:72),spacing:12)],spacing:12) {
            ForEach(0..<4,id:\.self) { material in
                Button { library.progress.printing.material = material } label: {
                    VStack(spacing:8) {
                        PrintShape(material:material).fill(Wood.Palette.success,style:FillStyle(eoFill:true)).frame(width:40,height:40)
                        Text(PrintPalette.materials[material]).woodText(Wood.Typography.support)
                    }.frame(maxWidth:.infinity,minHeight:92)
                        .background(session.material == material ? Wood.Palette.successBackground : Wood.Palette.secondaryFill,in:RoundedRectangle(cornerRadius:16))
                        .overlay(RoundedRectangle(cornerRadius:16).strokeBorder(Wood.Palette.slotStroke,lineWidth:session.material == material ? 3 : 1))
                }.buttonStyle(IllustrationButtonStyle()).accessibilityIdentifier("printing.material.\(material)")
            }
        }
        LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:8),count:3),spacing:8) {
            ForEach(0..<6,id:\.self) { color in
                Button { library.progress.printing.color = color } label: {
                    ZStack {
                        Circle().fill(PrintPalette.colors[color]).frame(width:40,height:40)
                        if color == session.color { Circle().stroke(Wood.Palette.slotStroke,lineWidth:3).frame(width:54,height:54) }
                    }.frame(maxWidth:.infinity,minHeight:64)
                }.buttonStyle(IllustrationButtonStyle()).accessibilityLabel("\(PrintPalette.names[color])\(color == session.color ? "，已选取" : "")").accessibilityIdentifier("printing.color.\(color)")
            }
        }
        PrintCanvas(stamps:session.stamps)
            .aspectRatio(0.85,contentMode:.fit)
            .background(Wood.Palette.tray)
            .clipShape(RoundedRectangle(cornerRadius:Wood.Radius.control))
            .overlay(RoundedRectangle(cornerRadius:Wood.Radius.control).strokeBorder(Wood.Palette.borderDecorative,lineWidth:2).allowsHitTesting(false))
            .overlay {
                GeometryReader { geometry in
                    Color.clear.contentShape(Rectangle()).gesture(DragGesture(minimumDistance:0).onEnded { value in
                        library.progress.printing.stamp(x:value.location.x/geometry.size.width,y:value.location.y/geometry.size.height)
                    })
                }
            }
            .accessibilityElement(children:.ignore).accessibilityLabel("画纸，已有 \(session.stamps.count) 个印记")
            .accessibilityAction(named:"在中央盖章") { library.progress.printing.stamp(x:0.5,y:0.5) }
            .accessibilityIdentifier("printing.canvas")
        if session.stamps.isEmpty { Text("这是你的空白画纸，盖上第一片叶子吧。")
            .woodText(Wood.Typography.support).foregroundStyle(Wood.Palette.textSecondary) }
        Tray(padding:16) {
            VStack(alignment:.leading,spacing:16) {
                Text("大小").woodText(Wood.Typography.label)
                Slider(value:Binding(get:{session.size},set:{library.progress.printing.size=$0}),in:0.10...0.45)
                    .tint(Wood.Palette.actionPrimary).accessibilityLabel("印记大小")
                Text("旋转 \(Int(session.angle))°").woodText(Wood.Typography.label)
                Slider(value:Binding(get:{session.angle},set:{library.progress.printing.angle=$0}),in:0...360,step:15)
                    .tint(Wood.Palette.actionPrimary).accessibilityLabel("旋转角度")
                Text("力度").woodText(Wood.Typography.label)
                LazyVGrid(columns:[GridItem(.adaptive(minimum:80),spacing:8)],spacing:8) {
                    ForEach(0..<3,id:\.self) { pressure in
                        Button {
                            library.progress.printing.pressure=pressure
                        } label: {
                            Text(["轻轻压","正好压","用力压"][pressure]).woodText(Wood.Typography.support)
                                .frame(maxWidth:.infinity,minHeight:64)
                                .background(session.pressure == pressure ? Wood.Palette.successBackground : Wood.Palette.secondaryFill,in:RoundedRectangle(cornerRadius:12))
                                .overlay(RoundedRectangle(cornerRadius:12).strokeBorder(Wood.Palette.slotStroke,lineWidth:session.pressure == pressure ? 3 : 1))
                        }.buttonStyle(IllustrationButtonStyle())
                    }
                }
            }
        }
        if !session.works.isEmpty {
            Text("收好的作品").woodText(Wood.Typography.heading)
            LazyVGrid(columns:[GridItem(.adaptive(minimum:130),spacing:16)],spacing:16) {
                ForEach(session.works.indices,id:\.self) { index in
                    Button { library.progress.printing.openWork(index) } label: {
                        VStack(spacing:8) {
                            PrintCanvas(stamps:session.works[index].stamps).aspectRatio(0.85,contentMode:.fit).background(Wood.Palette.tray)
                                .clipShape(RoundedRectangle(cornerRadius:12))
                            Text("作品 \(index+1)").woodText(Wood.Typography.support)
                        }
                    }.buttonStyle(IllustrationButtonStyle()).accessibilityLabel("打开作品 \(index+1)").accessibilityIdentifier("printing.work.\(index)")
                }
            }
        }
    }
}

struct PrintCanvas: View {
    let stamps: [PrintStamp]
    var body: some View {
        Canvas { context,size in
            for stamp in stamps {
                var layer=context
                layer.translateBy(x:stamp.x*size.width,y:stamp.y*size.height)
                layer.rotate(by:.degrees(stamp.angle)); layer.opacity=stamp.opacity
                let side=stamp.size*min(size.width,size.height)
                let rect=CGRect(x:-side/2,y:-side/2,width:side,height:side)
                layer.fill(PrintShape(material:stamp.material).path(in:rect),with:.color(PrintPalette.colors[stamp.color]),style:FillStyle(eoFill:true))
                if stamp.material < 3 {
                    var veins=Path(); veins.move(to:CGPoint(x:0,y:side*0.38)); veins.addLine(to:CGPoint(x:0,y:-side*0.35))
                    for row in 0..<4 {
                        let y=side*(Double(row)*0.13-0.16)
                        for sign in [-1.0,1.0] { veins.move(to:CGPoint(x:0,y:y+side*0.12)); veins.addLine(to:CGPoint(x:sign*side*0.20,y:y-side*0.08)) }
                    }
                    layer.stroke(veins,with:.color(Wood.Palette.tray.opacity(0.65)),style:StrokeStyle(lineWidth:1,lineCap:.round))
                }
            }
        }
    }
}

struct PrintShape: Shape {
    let material: Int
    func path(in rect: CGRect) -> Path {
        var p=Path(); let x=rect.minX,y=rect.minY,w=rect.width,h=rect.height
        func point(_ a: Double,_ b: Double) -> CGPoint { CGPoint(x:x+w*a,y:y+h*b) }
        switch material {
        case 0:
            p.move(to:point(0.5,0.02)); p.addCurve(to:point(0.5,0.98),control1:point(1.10,0.32),control2:point(0.88,0.77))
            p.addCurve(to:point(0.5,0.02),control1:point(0.12,0.77),control2:point(-0.10,0.32)); p.closeSubpath()
        case 1:
            let points: [(Double,Double)]=[(0.5,0.0),(0.60,0.28),(0.80,0.14),(0.76,0.43),(1.0,0.45),(0.78,0.67),(0.82,0.78),(0.55,0.80),(0.5,1),(0.45,0.80),(0.18,0.78),(0.22,0.67),(0,0.45),(0.24,0.43),(0.20,0.14),(0.40,0.28)]
            p.move(to:point(points[0].0,points[0].1)); for v in points.dropFirst() { p.addLine(to:point(v.0,v.1)) }; p.closeSubpath()
        case 2:
            p.move(to:point(0.5,0.96));p.addLine(to:point(0.04,0.32));p.addCurve(to:point(0.46,0.12),control1:point(0.02,-0.06),control2:point(0.35,0.01));p.addLine(to:point(0.50,0.25));p.addLine(to:point(0.54,0.12));p.addCurve(to:point(0.96,0.32),control1:point(0.65,0.01),control2:point(0.98,-0.06));p.closeSubpath()
        default:
            p.addEllipse(in:rect.insetBy(dx:w*0.02,dy:h*0.02));p.addEllipse(in:CGRect(x:x+w*0.44,y:y+h*0.44,width:w*0.12,height:h*0.12))
            for hole in 0..<7 {
                let angle=Double(hole)*2 * .pi/7
                p.addEllipse(in:CGRect(x:x+w*(0.5+cos(angle)*0.27)-w*0.07,y:y+h*(0.5+sin(angle)*0.27)-h*0.10,width:w*0.14,height:h*0.20))
            }
        }
        return p
    }
}
