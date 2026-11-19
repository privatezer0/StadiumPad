import Foundation

public enum CloneLibraryCommand:Equatable,Sendable {
    case createFolder(parent:Int,position:Int,name:String)
    case rename(id:Int,attributes:Value,name:String)
    case remove(parent:Int,id:Int)
    case move(id:Int,parent:Int,position:Int)
    public func message(id:Int32)throws->OSCMessage {
        var values:[Value]=[.int(Int64(id))];let address:String
        switch self {
        case .createFolder(let parent,let position,let draft):
            guard Self.possibleUserFolder(parent),(0..<2048).contains(position) else{throw ProtocolError.invalid("Invalid clone folder destination.")}
            let name=try Self.name(draft)
            address="/CreateContent";values += [.int(Int64(parent)),.int(Int64(position)),.int(1002),.binary(try MessagePack.encode(.object(["name":.string(name),"colr":.int(0),"ownr":.int(1)])))]
        case .rename(let target,let attributes,let draft):
            guard target>0,attributes["cid_"].integer==target,[11,1002].contains(attributes["type"].integer ?? 0),Self.userEditable(attributes) else{throw ProtocolError.invalid("Only User clones and their custom folders can be renamed.")}
            var attrs=attributes.object;attrs["name"] = .string(try Self.name(draft))
            address="/SetContentAttrs";values += [.int(Int64(target)),.binary(try MessagePack.encode(.object(attrs)))]
        case .move(let target,let parent,let position):
            guard target>0,Self.possibleUserFolder(parent),(0..<2048).contains(position) else{throw ProtocolError.invalid("Invalid clone move destination.")}
            address="/AddContentsToContainer";values += [.int(Int64(parent)),.binary(try MessagePack.encode(.array([.int(Int64(target))]))),.int(Int64(position)),.int(0),.int(1)]
        case .remove(let parent,let target):
            guard Self.possibleUserFolder(parent),target>0 else{throw ProtocolError.invalid("Built-in clone folders cannot be removed.")}
            address="/RemoveContent";values += [.int(Int64(parent)),.binary(try MessagePack.encode(.array([.int(Int64(target))])))]
        }
        return OSCMessage(address,values)
    }
    public static func userEditable(_ value:Value)->Bool {value["ownr"].integer==1 && (value["pric"].integer ?? 0)==0 && !["locked","lckd","lock"].contains(where:{value[$0].boolean==true})}
    public static func possibleUserFolder(_ id:Int)->Bool {[-22,-23,-24,-25].contains(id) || id>0}
    public static func name(_ value:String)throws->String {
        let result=value.trimmingCharacters(in:.whitespacesAndNewlines)
        guard (1...64).contains(result.count),result != ".",result != "..",!result.contains("/"),!result.contains("\\"),!result.unicodeScalars.contains(where:{CharacterSet.controlCharacters.contains($0)}) else{throw ProtocolError.invalid("Use a clone name with 1–64 characters and no slashes or control characters.")}
        return result
    }
}
