import Foundation

/// The two children in this family; IDs stay stable across display changes.
public enum FamilyChild: String, CaseIterable, Identifiable, Codable, Sendable {
    case qianyi, zhenyi
    public var id: String { rawValue }
    public var name: String { self == .qianyi ? "千一" : "臻一" }
    public var avatar: String { self == .qianyi ? "🐻" : "🐰" }
}

public struct FamilyProgress: Codable, Sendable {
    public var version = 1
    public var children: [String:CollectionProgress]
    public init(legacy: CollectionProgress) {
        var fresh=CollectionProgress()
        fresh.numberLine = .fresh()
        children=[FamilyChild.qianyi.rawValue:fresh,FamilyChild.zhenyi.rawValue:legacy]
    }
    public static func restore(_ data: Data) -> Self? {
        guard var family=try? JSONDecoder().decode(Self.self,from:data), family.version == 1,
              Set(family.children.keys) == Set(FamilyChild.allCases.map(\.rawValue)) else { return nil }
        for child in FamilyChild.allCases {
            guard let data=family.children[child.rawValue]?.encoded(),let state=CollectionProgress.restore(data) else { return nil }
            family.children[child.rawValue]=state
        }
        return family
    }
}
