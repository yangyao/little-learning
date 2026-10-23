#if os(iOS)
import SwiftUI
import AVFoundation
import UIKit

private final class PointsCamera: NSObject,ObservableObject,AVCaptureMetadataOutputObjectsDelegate {
    let session=AVCaptureSession()
    @Published var message: String?
    private let queue=DispatchQueue(label:"family.points.camera")
    private var configured=false
    private var wanted=false
    private var onCode: ((String)->Void)?
    func start(_ action: @escaping (String)->Void) {
        wanted=true;onCode=action
        switch AVCaptureDevice.authorizationStatus(for:.video) {
        case .authorized:configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for:.video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self,self.wanted else { return }
                    if granted { self.configure() } else { self.message="请允许相机访问，才能扫描同步二维码。" }
                }
            }
        default:message="相机未获授权。请到系统设置中允许「游戏抽屉」使用相机。"
        }
    }
    private func configure() {
        queue.async { [weak self] in
            guard let self else { return }
            if !self.configured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .high
                guard let camera=AVCaptureDevice.default(for:.video),let input=try? AVCaptureDeviceInput(device:camera),self.session.canAddInput(input) else {
                    self.session.commitConfiguration();self.fail();return
                }
                self.session.addInput(input)
                let output=AVCaptureMetadataOutput()
                guard self.session.canAddOutput(output) else { self.session.commitConfiguration();self.fail();return }
                self.session.addOutput(output);output.setMetadataObjectsDelegate(self,queue:.main);output.metadataObjectTypes=[.qr]
                self.session.commitConfiguration();self.configured=true
            }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }
    private func fail() { DispatchQueue.main.async { self.message="相机暂时无法使用，请退出扫描后重试。" } }
    func stop() {
        wanted=false;onCode=nil
        queue.async { [weak self] in if let self,self.session.isRunning { self.session.stopRunning() } }
    }
    func metadataOutput(_ output: AVCaptureMetadataOutput,didOutput metadataObjects: [AVMetadataObject],from connection: AVCaptureConnection) {
        for case let object as AVMetadataMachineReadableCodeObject in metadataObjects {
            if let value=object.stringValue { onCode?(value) }
        }
    }
}

private final class PointsCameraPreview: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
private struct PointsCameraSurface: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PointsCameraPreview {
        let view=PointsCameraPreview();view.preview.session=session;view.preview.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ view: PointsCameraPreview,context: Context) {}
}
struct PointsCameraView: View {
    let onCode: (String)->Void
    @StateObject private var camera=PointsCamera()
    @Environment(\.scenePhase) private var phase
    var body: some View {
        ZStack {
            PointsCameraSurface(session:camera.session)
            if let message=camera.message {
                VStack(spacing:12) {
                    Text(message).multilineTextAlignment(.center)
                    Button("打开系统设置") {
                        if let url=URL(string:UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }.buttonStyle(SecondaryWoodStyle())
                }.padding(20).background(Wood.Palette.canvas)
            }
        }.onAppear { camera.start(onCode) }.onDisappear { camera.stop() }
            .onChange(of:phase) { _,value in
                if value == .active { camera.start(onCode) } else { camera.stop() }
            }
    }
}
#endif
