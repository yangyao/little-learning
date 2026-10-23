import Foundation
import Compression
import CryptoKit

public enum PointsSyncError: Error, LocalizedError {
    case invalid, tooLarge, conflict, overspent
    public var errorDescription: String? {
        switch self {
        case .invalid:return "二维码数据不完整或版本不兼容，请重新扫描。"
        case .tooLarge:return "同步记录过多，暂时无法生成二维码。"
        case .conflict:return "同一笔记录内容不同，未合并，请保留两台手机的记录。"
        case .overspent:return "两台手机合计花费超过已有积分，未合并。请先撤销重复兑换，再重新同步。"
        }
    }
}

public struct PointsSyncSnapshot: Codable, Sendable {
    public var version = 1
    public let ledgers: [String:RewardLedger]
    public init(ledgers: [String:RewardLedger]) { self.ledgers=ledgers }
    public var isValid: Bool {
        version == 1 && Set(ledgers.keys) == Set(FamilyChild.allCases.map(\.rawValue)) && ledgers.values.allSatisfy { $0.entries.count <= 10_000 && $0.isValid }
    }
}

public enum PointsSyncCode {
    static let limit=2_000_000
    static func transform(_ data: Data,encode: Bool) throws -> Data {
        guard !data.isEmpty,data.count <= limit else { throw PointsSyncError.tooLarge }
        var output=[UInt8](repeating:0,count:limit)
        let size=data.withUnsafeBytes { source in
            output.withUnsafeMutableBufferPointer { destination in
                if encode { return compression_encode_buffer(destination.baseAddress!,limit,source.bindMemory(to:UInt8.self).baseAddress!,data.count,nil,COMPRESSION_LZFSE) }
                return compression_decode_buffer(destination.baseAddress!,limit,source.bindMemory(to:UInt8.self).baseAddress!,data.count,nil,COMPRESSION_LZFSE)
            }
        }
        guard size > 0,size < limit else { throw PointsSyncError.invalid }
        return Data(output.prefix(size))
    }
    static func digest(_ data: Data) -> String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
    public static func frames(_ snapshot: PointsSyncSnapshot) throws -> [String] {
        guard snapshot.isValid else { throw PointsSyncError.invalid }
        let encoder=JSONEncoder();encoder.outputFormatting = [.sortedKeys]
        let data=try transform(encoder.encode(snapshot),encode:true)
        let body=Array(data.base64EncodedString()),count=(body.count+699)/700,id=UUID().uuidString,hash=digest(data)
        guard count <= 1024 else { throw PointsSyncError.tooLarge }
        return (0..<count).map { i in "LLSYNC1|\(id)|\(i)|\(count)|\(hash)|"+String(body[(i*700)..<min((i+1)*700,body.count)]) }
    }
}

public struct PointsSyncScanner {
    private var session: String?
    private var hash=""
    private var total=0
    private var parts: [Int:String]=[:]
    public init() {}
    public var received: Int { parts.count }
    public var expected: Int { total }
    public mutating func accept(_ text: String) throws -> PointsSyncSnapshot? {
        let fields=text.split(separator:"|",omittingEmptySubsequences:false).map(String.init)
        guard fields.count == 6,fields[0] == "LLSYNC1",UUID(uuidString:fields[1]) != nil,
              let index=Int(fields[2]),let count=Int(fields[3]),(1...1024).contains(count),(0..<count).contains(index),
              fields[4].count == 64,!fields[5].isEmpty,fields[5].count <= 700 else { throw PointsSyncError.invalid }
        if let session { guard session == fields[1],hash == fields[4],total == count else { throw PointsSyncError.invalid } }
        else { session=fields[1];hash=fields[4];total=count }
        if let previous=parts[index],previous != fields[5] { throw PointsSyncError.invalid }
        parts[index]=fields[5]
        guard received == total else { return nil }
        let joined=(0..<total).map { parts[$0]! }.joined()
        guard let data=Data(base64Encoded:joined),PointsSyncCode.digest(data) == hash else { throw PointsSyncError.invalid }
        let snapshot=try JSONDecoder().decode(PointsSyncSnapshot.self,from:PointsSyncCode.transform(data,encode:false))
        guard snapshot.isValid else { throw PointsSyncError.invalid }
        return snapshot
    }
}
