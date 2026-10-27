import Foundation
#if canImport(LearningCore)
import LearningCore
#endif

struct NASConfiguration: Codable {
    let url: String
    let token: String
    var isValid: Bool {
        guard let base=URL(string:url),let scheme=base.scheme, ["http","https"].contains(scheme),base.host != nil,
              base.user == nil,base.password == nil,base.query == nil,base.fragment == nil,token.count >= 32 else{return false}
        return true
    }
    static func load() -> Self? {
        #if SWIFT_PACKAGE
        let bundle=Bundle.module
        #else
        let bundle=Bundle.main
        #endif
        // Root lookup preserves compatibility with earlier private builds.
        let file=bundle.url(forResource:"NASConfig",withExtension:"json",subdirectory:"Configuration") ?? bundle.url(forResource:"NASConfig",withExtension:"json")
        guard let file,let data=try? Data(contentsOf:file),let config=try? JSONDecoder().decode(Self.self,from:data),config.isValid else{return nil}
        return config
    }
}
enum NASSyncFailure: Error {case offline,invalid,server(String)}
private final class NASRedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
struct NASClient {
    static func exchange(_ request: ServerSyncRequest) async throws -> ServerSyncResponse {
        guard let settings=NASConfiguration.load(),let base=URL(string:settings.url) else{throw NASSyncFailure.invalid}
        var r=URLRequest(url:base.appendingPathComponent("v1/sync"));r.httpMethod="POST";r.timeoutInterval=8
        r.setValue("Bearer "+settings.token,forHTTPHeaderField:"Authorization");r.setValue("application/json",forHTTPHeaderField:"Content-Type")
        let encoder=JSONEncoder();encoder.dateEncodingStrategy = .millisecondsSince1970;r.httpBody=try encoder.encode(request)
        let config=URLSessionConfiguration.ephemeral;config.timeoutIntervalForRequest=8;config.timeoutIntervalForResource=12;config.waitsForConnectivity=false
        let session=URLSession(configuration:config,delegate:NASRedirectPolicy(),delegateQueue:nil);defer{session.finishTasksAndInvalidate()}
        let(data,response)=try await session.data(for:r)
        guard let http=response as? HTTPURLResponse else {throw NASSyncFailure.offline}
        let decoder=JSONDecoder();decoder.dateDecodingStrategy = .millisecondsSince1970
        guard let result=try? decoder.decode(ServerSyncResponse.self,from:data),Set(result.children.keys)==Set(FamilyChild.allCases.map(\.rawValue)) else {throw NASSyncFailure.invalid}
        if http.statusCode==200 || http.statusCode==409 {return result}
        throw NASSyncFailure.server("同步服务暂时不可用，本机记录已保留。")
    }
}
