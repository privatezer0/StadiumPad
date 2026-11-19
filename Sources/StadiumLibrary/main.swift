import Foundation
import CryptoKit
import StadiumProtocol
import StadiumNetwork

/// Private local IPC for the Mac file companion. No arbitrary OSC or filesystem paths.
@main struct LibraryAgent {
    static func main()async {
        let session=StadiumSession()
        do {
            var input=Data()
            while let next=try FileHandle.standardInput.read(upToCount:4097-input.count),!next.isEmpty {input.append(next);guard input.count<=4096 else{throw ProtocolError.invalid("The library request is too large.")}}
            guard input.count<=4096,let request=try JSONSerialization.jsonObject(with:input) as? [String:Any],let host=request["host"] as? String,!host.isEmpty else{throw ProtocolError.invalid("Choose a Stadium.")}
            let port=request["port"] as? Int ?? 2001
            guard port>0,port<65535 else{throw ProtocolError.invalid("Invalid Stadium port.")}
            try await session.connect(host:host,port:UInt16(port))
            let product=try await session.read(.product)
            guard let serial=product["host"]["snum"].text?.trimmingCharacters(in:.whitespacesAndNewlines),!serial.isEmpty else{throw ProtocolError.invalid("The Stadium identity is unavailable.")}
            let deviceID=SHA256.hash(data:Data(serial.utf8)).map{String(format:"%02x",$0)}.joined()
            if let expected=request["deviceID"] as? String,expected != deviceID {throw ProtocolError.invalid("This companion is connected to a different Stadium.")}
            var visited:Set<Int>=[];var entries:[Value]=[]
            func readFolder(_ id:Int,_ depth:Int)async throws {
                guard depth<8,visited.insert(id).inserted,entries.count<2048 else{throw ProtocolError.invalid("The clone folder tree is too large or cyclic.")}
                let contents=try await session.read(.container(id))
                for row in contents.items {
                    guard let cid=row["cid_"].integer,let type=row["type"].integer,[11,1002].contains(type) else{continue}
                    guard entries.count<2048 else{throw ProtocolError.invalid("The clone library is too large for this version.")}
                    entries.append(row)
                    if type==1002 {try await readFolder(cid,depth+1)}
                }
            }
            try await readFolder(-14,0)
            let operation=request["op"] as? String ?? "read"
            var changed:Value = .null
            if operation != "read" {
                guard let expected=request["deviceID"] as? String,expected==deviceID else{throw ProtocolError.invalid("A current Stadium identity is required for library changes.")}
                let parent=request["parent"] as? Int ?? 0
                if operation=="move",let id=request["id"] as? Int,let uuid=request["uuid"] as? String,let name=request["expectedName"] as? String,let destination=request["destination"] as? Int {changed=try await session.moveClone(id:id,parent:parent,uuid:uuid,expectedName:name,destination:destination)}
                else if operation=="export",let id=request["id"] as? Int,let uuid=request["uuid"] as? String,let name=request["expectedName"] as? String {changed=try await session.prepareCloneExport(id:id,uuid:uuid,expectedName:name)}
                else if operation=="mkdir",let name=request["name"] as? String {changed=try await session.createCloneFolder(parent:parent,name:name)}
                else if ["rename","delete"].contains(operation),let id=request["id"] as? Int,let expectedName=request["expectedName"] as? String {
                    changed=try await session.changeClone(id:id,parent:parent,uuid:request["uuid"] as? String,expectedName:expectedName,newName:request["name"] as? String,remove:operation=="delete")
                }else{throw ProtocolError.invalid("Unsupported clone library operation.")}
                entries=[];visited=[];try await readFolder(-14,0)
            }
            var irEntries:[Value]=[]
            if request["includeIRs"] as? Bool==true {
                for row in try await session.read(.container(-11)).items {
                    guard row["type"].integer==8,row["ownr"].integer==1,let id=row["cid_"].integer,id>0 else{continue}
                    var item=row.object;item["path"]=try await session.read(.contentPath(id));irEntries.append(.object(item))
                }
            }
            await session.disconnect()
            let result:[String:Any]=["deviceID":deviceID,"entries":entries.map(\.json),"changed":changed.json,"irEntries":irEntries.map(\.json)]
            FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject:result,options:.sortedKeys))
        } catch {
            await session.disconnect()
            let result:[String:Any]=["error":error.localizedDescription]
            FileHandle.standardOutput.write((try? JSONSerialization.data(withJSONObject:result)) ?? Data())
            exit(1)
        }
    }
}
