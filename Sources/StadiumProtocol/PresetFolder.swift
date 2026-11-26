import Foundation

/// Setlists contain reference records (type 1), not User preset records (type 2).
/// Resolve their backing preset for recall, without granting write permission to
/// the folder slot or treating its reference ID as a preset ID.
public struct PresetFolder:Identifiable,Equatable,Sendable {
    public let id:Int
    public let position:Int
    public let name:String
    public let presets:[PresetSlot]
    public init?(reference:Value,contents:Value) {
        guard reference["type"].integer==1003,let id=reference["cid_"].integer,id>0 else{return nil}
        self.id=id;position=reference["posi"].integer ?? 0;name=reference["name"].text ?? "Setlist"
        presets=contents.items.compactMap {row in
            guard let type=row["type"].integer,[1,2].contains(type),let target=type==1 ? row["rcid"].integer:row["cid_"].integer,target>0,target<=Int(Int32.max) else{return nil}
            var values=row.object;values["cid_"] = .int(Int64(target));values["type"] = .int(2)
            return PresetSlot(.object(values))
        }.sorted{($0.position ?? 0)<($1.position ?? 0)}
    }
}

/// Sidebar choices use folder membership without changing a pedal's preset state.
public enum PresetFolderSelection {
    public static func restore(folders:[PresetFolder],remembered:Int?,presetID:Int?)->Int {
        if let remembered,remembered == -2 || folders.contains(where:{$0.id==remembered}) {return remembered}
        return follow(folders:folders,preferred:nil,presetID:presetID)
    }
    public static func follow(folders:[PresetFolder],preferred:Int?,presetID:Int?)->Int {
        guard let presetID else{return -2}
        let matches=folders.filter{$0.presets.contains{$0.contentID==presetID}}
        if let preferred,matches.contains(where:{$0.id==preferred}) {return preferred}
        return matches.first?.id ?? -2
    }
}
