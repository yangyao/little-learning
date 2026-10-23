import Foundation

/// A local use/rest cycle, shared by every screen after choosing a child.
public struct UsageAllowance: Codable, Equatable, Sendable {
    public static let budgetMilliseconds=30*60*1000
    public static let restSeconds: TimeInterval=2*60*60
    public private(set) var usedMilliseconds=0
    public private(set) var restUntil: Date?
    public init() {}
    public var isValid: Bool {
        (0...Self.budgetMilliseconds).contains(usedMilliseconds) &&
        (restUntil == nil ? usedMilliseconds < Self.budgetMilliseconds : usedMilliseconds == Self.budgetMilliseconds && restUntil!.timeIntervalSince1970.isFinite)
    }
    public mutating func refresh(at now: Date) {
        if let restUntil,now >= restUntil { self = .init() }
    }
    public func remaining(at now: Date) -> Int {
        if let restUntil { return now >= restUntil ? Self.budgetMilliseconds : 0 }
        return Self.budgetMilliseconds-usedMilliseconds
    }
    public func restingSeconds(at now: Date) -> Int {
        guard let restUntil else { return 0 }
        return Int(min(Self.restSeconds,max(0,ceil(restUntil.timeIntervalSince(now)))))
    }
    public mutating func consume(_ milliseconds: Int,endingAt now: Date) {
        guard milliseconds > 0,restUntil == nil else { return }
        let available=Self.budgetMilliseconds-usedMilliseconds
        let consumed=min(milliseconds,available)
        usedMilliseconds += consumed
        if usedMilliseconds == Self.budgetMilliseconds {
            // If the UI was busy, rest starts at the instant the allowance ran out.
            restUntil=now.addingTimeInterval(Self.restSeconds-Double(milliseconds-consumed)/1000)
        }
    }
}

public struct FamilyUsage: Codable, Equatable, Sendable {
    public var version=1
    public var children=Dictionary(uniqueKeysWithValues:FamilyChild.allCases.map { ($0.rawValue,UsageAllowance()) })
    public init() {}
    public var isValid: Bool {
        version == 1 && Set(children.keys) == Set(FamilyChild.allCases.map(\.rawValue)) && children.values.allSatisfy(\.isValid)
    }
    public static func restore(_ data: Data) -> Self? {
        guard let value=try? JSONDecoder().decode(Self.self,from:data),value.isValid else { return nil }
        return value
    }
}
