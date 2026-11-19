import Foundation
import StadiumProtocol

struct LibraryEntry:Identifiable {
    let id:Int;let name:String;let type:Int;let position:Int;let parent:Int;let cloneUUID:String?
    init?(_ value:Value) {guard let id=value["cid_"].integer,let type=value["type"].integer,id>0 || (type==1002 && (-25 ... -1).contains(id)) else{return nil};self.id=id;self.type=type;name=value["name"].text ?? "Untitled";position=value["posi"].integer ?? 0;parent=value["ccid"].integer ?? 0;cloneUUID=value["cluid"].text}
}
