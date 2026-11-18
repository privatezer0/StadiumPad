import Foundation
import CryptoKit

/// Local view preference only. Restoring never sends a command to the Stadium.
public struct RememberedBlockSelection:Codable,Equatable,Sendable {
    public let path:Int,position:Int,blockID:Int,slot:Int
    public init(_ block:SignalBlock) {path=block.path-1;position=block.position;blockID=block.blockID;slot=block.slot}
    public func resolve(in blocks:[SignalBlock])->SignalBlock? {
        guard (0...1).contains(path),(0...27).contains(position),(0...255).contains(blockID),(0...1).contains(slot) else{return nil}
        let matches=blocks.filter{$0.path-1==path && $0.blockID==blockID && $0.slot==slot}
        // Internal identity follows a move within its flow. Removed/ambiguous blocks fall back.
        return matches.count==1 ? matches[0]:nil
    }
    public static func storageKey(product:Value,endpoint:String,presetID:Int?)->String? {
        guard let presetID,presetID>0 else{return nil}
        let serial=product["host"]["snum"].text?.trimmingCharacters(in:.whitespacesAndNewlines) ?? ""
        let scope=serial.isEmpty ? "endpoint:"+endpoint.trimmingCharacters(in:.whitespacesAndNewlines).lowercased():"serial:"+serial
        guard scope != "endpoint:" else{return nil}
        let digest=SHA256.hash(data:Data(scope.utf8)).map{String(format:"%02x",$0)}.joined()
        return "rememberedBlock.v1.\(digest).\(presetID)"
    }
}
