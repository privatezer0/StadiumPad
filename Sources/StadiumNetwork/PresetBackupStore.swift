import Foundation
import CryptoKit
import StadiumProtocol

public actor PresetBackupStore {
    private let root:URL
    public init(root:URL) {self.root=root}
    @discardableResult public func retain(contentID:Int,name:String,data:Data)throws->URL {
        guard !data.isEmpty else{throw ProtocolError.invalid("Cannot back up an empty preset.")}
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        let hash=Self.hash(data),path=root.appendingPathComponent("\(contentID)-\(hash).bin")
        if FileManager.default.fileExists(atPath:path.path) {guard try Data(contentsOf:path)==data else{throw ProtocolError.invalid("The existing preset backup is unreadable.")};return path}
        try data.write(to:path,options:.atomic);try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:path.path)
        let metadata:[String:Any]=["contentID":contentID,"name":name,"sha256":hash,"created":Date().timeIntervalSince1970]
        try JSONSerialization.data(withJSONObject:metadata,options:.prettyPrinted).write(to:path.appendingPathExtension("json"),options:.atomic)
        return path
    }
    public static func hash(_ data:Data)->String {SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()}
}
public struct PreservedPreset:Codable,Sendable {
    public let preset:PresetSlot;public let sourceID:Int;public let sourceSnapshot:Int;public let sourceHash:String
}
