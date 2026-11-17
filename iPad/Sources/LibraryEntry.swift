import Foundation
import StadiumProtocol

struct LibraryEntry:Identifiable {
    let id:Int;let name:String;let type:Int;let position:Int
    init?(_ value:Value) {guard let id=value["cid_"].integer,id>0,let type=value["type"].integer else{return nil};self.id=id;self.type=type;name=value["name"].text ?? "Untitled";position=value["posi"].integer ?? 0}
}
