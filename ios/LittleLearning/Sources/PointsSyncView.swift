import SwiftUI
import Combine
import CoreImage.CIFilterBuiltins
#if os(iOS)
import UIKit
#endif
#if canImport(LearningCore)
import LearningCore
#endif

@MainActor final class PointsSyncScreen: ObservableObject {
    @Published var scanning=false
    @Published var frames: [String]=[]
    @Published var index=0
    @Published var received=0
    @Published var expected=0
    @Published var message: String?
    @Published var incoming: PointsSyncSnapshot?
    @Published var preview: [String:RewardLedger]=[:]
    private var collector=PointsSyncScanner()
    func display(_ library: CollectionStore) {
        scanning=false;incoming=nil;index=0
        do { frames=try PointsSyncCode.frames(library.pointsSnapshot()) }
        catch { frames=[];message=error.localizedDescription }
    }
    func scan() {
        collector=PointsSyncScanner();received=0;expected=0;incoming=nil;message=nil;scanning=true
    }
    func read(_ text: String,library: CollectionStore) {
        guard scanning,incoming == nil else { return }
        do {
            let snapshot=try collector.accept(text)
            received=collector.received;expected=collector.expected
            if let snapshot { preview=try library.previewPointsSync(snapshot);incoming=snapshot;message=nil }
        } catch { message=error.localizedDescription }
    }
    func merge(_ library: CollectionStore) {
        guard let incoming else { return }
        do {
            try library.mergePointsSync(incoming)
            display(library)
            message="已合并。现在请让另一台手机扫描此二维码，完成双向同步。"
        } catch { message=error.localizedDescription }
    }
}

struct PointsSyncView: View {
    @EnvironmentObject private var library: CollectionStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var screen=PointsSyncScreen()
    private let tick=Timer.publish(every:0.9,on:.main,in:.common).autoconnect()
    var body: some View {
        VStack(spacing:12) {
            HStack {
                WoodIconButton(symbol:"xmark",label:"关闭积分同步") { dismiss() }.accessibilityIdentifier("sync.close")
                Spacer();Text("面对面同步").woodText(Wood.Typography.heading);Spacer()
                Color.clear.frame(width:64,height:1)
            }
            HStack(spacing:10) {
                Button("显示二维码") { screen.message=nil;screen.display(library) }
                    .buttonStyle(SecondaryWoodStyle()).accessibilityIdentifier("sync.show")
                Button("扫码合并") { screen.scan() }
                    .buttonStyle(SecondaryWoodStyle()).accessibilityIdentifier("sync.scan")
            }
            ScrollView {
                VStack(spacing:16) {
                    if screen.incoming != nil {
                        Text("确认合并两人的积分记录").woodText(Wood.Typography.label)
                        ForEach(FamilyChild.allCases) { child in
                            let local=(try? library.pointsSnapshot())?.ledgers[child.rawValue]?.balance ?? 0
                            HStack {
                                Text("\(child.avatar) \(child.name)")
                                Spacer()
                                Text("\(local) → \(screen.preview[child.rawValue]?.balance ?? local) 分").monospacedDigit()
                            }.woodText(Wood.Typography.body)
                        }
                        Text("合并首次得分、兑换和撤销记录；保留本机游戏进度。")
                            .woodText(Wood.Typography.support)
                        Button("确认合并") { screen.merge(library) }
                            .buttonStyle(WoodenPrimaryButtonStyle()).accessibilityIdentifier("sync.confirm")
                        Button("重新扫描") { screen.scan() }.buttonStyle(SecondaryWoodStyle())
                    } else if screen.scanning {
                        #if os(iOS)
                        PointsCameraView { screen.read($0,library:library) }
                            .frame(height:300).clipShape(RoundedRectangle(cornerRadius:16))
                        #else
                        Text("请在 iPhone 上使用摄像头扫描另一台手机。")
                        #endif
                        Text(screen.expected == 0 ? "对准另一台手机的同步二维码" : "已收集 \(screen.received) / \(screen.expected) 张")
                            .woodText(Wood.Typography.label).monospacedDigit().accessibilityIdentifier("sync.scanProgress")
                        Text("保持对准，轮播二维码会自动收集，无需逐张点击。")
                            .woodText(Wood.Typography.support)
                        Button("重新扫描") { screen.scan() }.buttonStyle(SecondaryWoodStyle())
                    } else if !screen.frames.isEmpty {
                        QRCodeImage(text:screen.frames[screen.index])
                            .frame(maxWidth:320).aspectRatio(1,contentMode:.fit)
                            .accessibilityLabel("积分同步二维码，第\(screen.index+1)张，共\(screen.frames.count)张")
                        Text(screen.frames.count == 1 ? "让另一台手机点「扫码合并」" : "自动轮播 \(screen.index+1) / \(screen.frames.count) 张")
                            .woodText(Wood.Typography.label).monospacedDigit().accessibilityIdentifier("sync.frame")
                        Text("对方合并后，再用本机扫描对方的二维码，两边就一致了。")
                            .woodText(Wood.Typography.support)
                    }
                    if let message=screen.message {
                        Text(message).woodText(Wood.Typography.body).padding(12)
                            .frame(maxWidth:.infinity).background(Wood.Palette.hintBackground,in:RoundedRectangle(cornerRadius:12))
                            .accessibilityIdentifier("sync.message")
                    }
                    Text("仅同步千一和臻一的积分记录，不上传网络。兑换尽量固定一台手机操作，兑换后再同步。游戏剩余时长留在购买它的手机上。")
                        .font(.system(size:14)).foregroundStyle(Wood.Palette.textSecondary)
                }.frame(maxWidth:500).frame(maxWidth:.infinity).padding(.vertical,8)
            }
        }.padding(20).background(Wood.Palette.canvas.ignoresSafeArea())
            #if os(macOS)
            .frame(width:390,height:740)
            #endif
            .onAppear {
                library.save();screen.display(library)
                #if os(iOS)
                UIApplication.shared.isIdleTimerDisabled=true
                #endif
            }
            .onDisappear {
                #if os(iOS)
                UIApplication.shared.isIdleTimerDisabled=false
                #endif
            }
            .onReceive(tick) { _ in
                guard !screen.scanning,screen.frames.count > 1 else { return }
                screen.index=(screen.index+1)%screen.frames.count
            }
    }
}

private struct QRCodeImage: View {
    let text: String
    var body: some View {
        if let image=makeImage() {
            Image(decorative:image,scale:1).interpolation(.none).resizable().scaledToFit()
                .padding(16).background(.white,in:RoundedRectangle(cornerRadius:12))
        } else { Text("二维码生成失败，请重新打开同步页面。") }
    }
    private func makeImage() -> CGImage? {
        let filter=CIFilter.qrCodeGenerator();filter.message=Data(text.utf8);filter.correctionLevel="L"
        guard let output=filter.outputImage else { return nil }
        let scaled=output.transformed(by:CGAffineTransform(scaleX:4,y:4))
        return CIContext().createCGImage(scaled,from:scaled.extent)
    }
}
