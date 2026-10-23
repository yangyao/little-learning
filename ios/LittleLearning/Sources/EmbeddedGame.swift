import SwiftUI
import WebKit
#if canImport(LearningCore)
import LearningCore
#endif

/// One local web view per game keeps the physics scene alive while returning to the drawer.
@MainActor
final class WebGameSession: NSObject, ObservableObject, WKScriptMessageHandler, WKNavigationDelegate {
    private static var sessions: [FunGame:WebGameSession] = [:]
    static func cached(_ game: FunGame) -> WebGameSession {
        if let existing=sessions[game] { return existing }
        let session=WebGameSession(game:game);sessions[game]=session;return session
    }
    @Published private(set) var ready=false
    @Published private(set) var error: String?
    let game: FunGame
    private(set) var view: WKWebView!
    private var timeout: Task<Void,Never>?
    private var paused=true
    private var bridgeTemplate=""
    private var file: URL {
        FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask).first!
            .appendingPathComponent("LittleLearning/WebGames",isDirectory:true).appendingPathComponent(game.rawValue+".json")
    }
    init(game: FunGame) {
        self.game=game;super.init()
        let configuration=WKWebViewConfiguration()
        configuration.setURLSchemeHandler(LocalGameFiles(),forURLScheme:"familygame")
        let controller=configuration.userContentController
        controller.add(WeakGameHandler(self),name:"family")
        let bridge="""
        window.familyPaused=true;
        window.familyGame={initialState:__FAMILY_SAVED_STATE__,setPaused:function(){},snapshot:function(){return null},
          ready:function(){window.webkit.messageHandlers.family.postMessage({type:'ready'})},
          save:function(){try{var s=this.snapshot();if(s)window.webkit.messageHandlers.family.postMessage({type:'save',state:s})}catch(e){window.webkit.messageHandlers.family.postMessage({type:'error'})}}};
        for(const name of ['pointerdown','pointerup','mousedown','mouseup','click','touchstart','touchmove','touchend'])document.addEventListener(name,function(e){if(window.familyPaused){e.preventDefault();e.stopImmediatePropagation()}},true);
        window.open=function(){return null};
        window.addEventListener('error',function(e){window.webkit.messageHandlers.family.postMessage({type:'error',detail:String(e.message)})});
        """
        bridgeTemplate=bridge
        // Local games have no ads, analytics, remote assets or external network access.
        view=WKWebView(frame:.zero,configuration:configuration);view.navigationDelegate=self
        #if os(iOS)
        view.scrollView.isScrollEnabled=false;view.scrollView.bounces=false
        view.isOpaque=false;view.backgroundColor = .clear
        #endif
        reload()
    }
    func reload() {
        ready=false;error=nil;paused=true
        let saved=(try? Data(contentsOf:file)).flatMap { try? JSONSerialization.jsonObject(with:$0) }
        let initial=(saved.flatMap { try? JSONSerialization.data(withJSONObject:$0) }).flatMap { String(data:$0,encoding:.utf8) } ?? "null"
        let controller=view.configuration.userContentController
        controller.removeAllUserScripts()
        controller.addUserScript(WKUserScript(source:bridgeTemplate.replacingOccurrences(of:"__FAMILY_SAVED_STATE__",with:initial),injectionTime:.atDocumentStart,forMainFrameOnly:true))
        view.load(URLRequest(url:URL(string:"familygame://\(game.rawValue)/index.html")!))
        timeout?.cancel();timeout=Task { [weak self] in
            try? await Task.sleep(nanoseconds:20_000_000_000)
            guard !Task.isCancelled,let self,!self.ready else { return }
            self.error="请重新载入，未开始计时。"
        }
    }
    func pause(_ value: Bool) {
        paused=value
        view.evaluateJavaScript("window.familyPaused=\(value ? "true" : "false");window.familyGame.setPaused(window.familyPaused)") { [weak self] _,failure in
            if failure != nil,self?.ready == true { self?.error="游戏已暂停，请重新载入。" }
        }
    }
    func userContentController(_ userContentController: WKUserContentController,didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame,let body=message.body as? [String:Any],let type=body["type"] as? String else { return }
        if type == "ready" { gameDiagnostic("ready",["game":game.rawValue]);timeout?.cancel();ready=true;error=nil;pause(paused) }
        else if type == "save",let state=body["state"] as? [String:Any] {
            do {
                let data=try JSONSerialization.data(withJSONObject:state)
                guard data.count < 1_000_000 else { return }
                try FileManager.default.createDirectory(at:file.deletingLastPathComponent(),withIntermediateDirectories:true)
                try data.write(to:file,options:.atomic)
            } catch { self.error="本局进度暂时无法保存，已暂停。" }
        } else if type == "error" { print("WebGame error: \(body["detail"] ?? "snapshot")");error="游戏运行遇到问题，请重新载入。" }
    }
    func webView(_ webView: WKWebView,decidePolicyFor navigationAction: WKNavigationAction,decisionHandler: @escaping (WKNavigationActionPolicy)->Void) {
        decisionHandler(navigationAction.request.url?.scheme == "familygame" ? .allow : .cancel)
    }
    func webView(_ webView: WKWebView,didFailProvisionalNavigation navigation: WKNavigation!,withError error: Error) { gameDiagnostic("navigation-failed",["game":game.rawValue,"error":String(describing:error)]);self.error="游戏资源未能载入（\((error as NSError).code)），请重试。" }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { ready=false;error="游戏已暂停，请重新载入。" }
}
private final class WeakGameHandler: NSObject,WKScriptMessageHandler {
    weak var target: WebGameSession?
    init(_ target: WebGameSession) { self.target=target }
    func userContentController(_ userContentController: WKUserContentController,didReceive message: WKScriptMessage) { target?.userContentController(userContentController,didReceive:message) }
}
private final class LocalGameFiles: NSObject,WKURLSchemeHandler {
    func webView(_ webView: WKWebView,start urlSchemeTask: WKURLSchemeTask) {
        guard let url=urlSchemeTask.request.url,let host=url.host,["bubbles","watermelon"].contains(host),
              let root=Bundle.main.resourceURL?.appendingPathComponent("WebGames/\(host)",isDirectory:true).resolvingSymlinksInPath().standardizedFileURL else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist));return
        }
        let path=root.appendingPathComponent(String(url.path.drop(while: { $0 == "/" }))).resolvingSymlinksInPath().standardizedFileURL
        guard path.path.hasPrefix(root.path+"/"),let data=try? Data(contentsOf:path) else {
            gameDiagnostic("missing-file",["url":url.absoluteString,"root":root.path,"path":path.path,"exists":FileManager.default.fileExists(atPath:path.path)]);urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist));return
        }
        let mime=["html":"text/html","js":"application/javascript","json":"application/json","css":"text/css","png":"image/png","jpg":"image/jpeg","gif":"image/gif","mp3":"audio/mpeg","wav":"audio/wav","ttf":"font/ttf"]
        let headers=["Content-Type":mime[path.pathExtension] ?? "application/octet-stream","Content-Security-Policy":"default-src 'self' data: blob:; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; connect-src 'self'; img-src 'self' data: blob:; media-src 'self' data: blob:; frame-src 'none'"]
        urlSchemeTask.didReceive(HTTPURLResponse(url:url,statusCode:200,httpVersion:"HTTP/1.1",headerFields:headers)!)
        urlSchemeTask.didReceive(data);urlSchemeTask.didFinish()
    }
    func webView(_ webView: WKWebView,stop urlSchemeTask: WKURLSchemeTask) {}
}
#if os(iOS)
struct EmbeddedGame: UIViewRepresentable {
    let session: WebGameSession
    func makeUIView(context:Context)->WKWebView { session.view }
    func updateUIView(_ uiView:WKWebView,context:Context) {}
}
#else
struct EmbeddedGame: NSViewRepresentable {
    let session: WebGameSession
    func makeNSView(context:Context)->WKWebView { session.view }
    func updateNSView(_ nsView:WKWebView,context:Context) {}
}
#endif

private func gameDiagnostic(_ phase:String,_ details:[String:Any]) {
    #if DEBUG
    guard ProcessInfo.processInfo.arguments.contains("--check-offline-game") else { return }
    let root=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask).first!.appendingPathComponent("LittleLearning",isDirectory:true)
    try? FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    var data=details;data["phase"]=phase
    if let encoded=try? JSONSerialization.data(withJSONObject:data,options:.sortedKeys) { try? encoded.write(to:root.appendingPathComponent("web-diagnostic.json"),options:.atomic) }
    #endif
}
