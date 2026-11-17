import Foundation
import StadiumProtocol
import StadiumNetwork

struct SparePlan:Codable {let first:PreservedPreset;let second:PreservedPreset}
@main struct EditCheck {
    static func main()async {
        let args=Array(CommandLine.arguments.dropFirst())
        func option(_ key:String)->String? {guard let index=args.firstIndex(of:key),index+1<args.count else{return nil};return args[index+1]}
        guard let host=option("--host"),let path=option("--plan"),let backupsPath=option("--backups") else{print("Usage: stadium-edit-check --host HOST --plan PRIVATE.json --backups PRIVATE_DIR [--prepare | --exercise --catalog PRIVATE.json]");return}
        let session=StadiumSession(),backups=PresetBackupStore(root:URL(fileURLWithPath:backupsPath))
        do {
            let trace=try option("--trace").map{try TraceRecorder(path:$0)}
            try await session.connect(host:host,port:UInt16(option("--port") ?? "2001") ?? 2001,trace:trace)
            let state=try await session.snapshot()
            if args.contains("--prepare") {
                guard !FileManager.default.fileExists(atPath:path),let id=state.presetID else{throw ProtocolError.invalid("Choose a new plan filename.")}
                let first=try await session.copyCurrent(name:"iPad Edit Test 1117",expectedID:id,backups:backups)
                // Persist each allocation before attempting another; never retry blindly.
                let partial=URL(fileURLWithPath:path+".first");try JSONEncoder().encode(first).write(to:partial,options:.atomic)
                try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:partial.path)
                let second=try await session.copyCurrent(name:"iPad Reload Check 1117",expectedID:id,backups:backups)
                let plan=SparePlan(first:first,second:second)
                try JSONEncoder().encode(plan).write(to:URL(fileURLWithPath:path),options:.atomic)
                try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:path)
                _ = try await session.openPreservedCopy(first)
                print("Independent spare copies verified and opened: \(first.preset.label), \(second.preset.label). Original stored preset was not written.")
            } else if (args.contains("--exercise") || args.contains("--replace-check")),let catalogPath=option("--catalog") {
                let plan=try JSONDecoder().decode(SparePlan.self,from:Data(contentsOf:URL(fileURLWithPath:path)))
                guard let firstID=plan.first.preset.contentID,let secondID=plan.second.preset.contentID,firstID != secondID,firstID != plan.first.sourceID,secondID != plan.first.sourceID,state.presetID==firstID,state.presetName==plan.first.preset.name,plan.first.preset.name.hasPrefix("iPad Edit Test"),plan.second.preset.name.hasPrefix("iPad Reload Check") else{throw ProtocolError.invalid("Only the prepared spare presets may be tested.")}
                let catalog=try JSONDecoder().decode([String:ModelDefinition].self,from:Data(contentsOf:URL(fileURLWithPath:catalogPath)))
                if args.contains("--replace-check") {
                    guard let block=state.blocks.first,let source=catalog[String(block.model)],let destination=catalog[option("--replacement") ?? "43"] else{throw ProtocolError.invalid("Missing test model metadata.")}
                    _ = try await session.replaceModel(context:try state.context(for:block),source:source,destination:destination,backups:backups)
                    _ = try await session.savePreset(expectedID:firstID,backups:backups)
                    _ = try await session.loadPreset(secondID,expectedID:firstID)
                    let loaded=try await session.loadPreset(firstID,expectedID:secondID)
                    guard loaded.blocks.contains(where:{$0.position==block.position && $0.model==destination.id}) else{throw ProtocolError.invalid("Replacement did not survive reload.")}
                    let next=try await session.activateSnapshot(1,expectedID:firstID,expectedSnapshot:loaded.activeSnapshot,backups:backups)
                    _ = try await session.activateSnapshot(0,expectedID:firstID,expectedSnapshot:next.activeSnapshot,backups:backups)
                    print("PASS replacement/save/reload and snapshot round trip")
                    await session.disconnect();return
                }
                var targets:[(SignalBlock,ParameterDefinition,Value,Value)]=[]
                for block in state.blocks {
                    guard let model=catalog[String(block.model)] else{continue}
                    for definition in model.parameters {
                        guard let old=block.value(definition) else{continue}
                        if !definition.harness,definition.type=="f",definition.key=="Decay",model.name.contains("Room"),let number=old.numeric,definition.maximum>definition.minimum {
                            let delta=(definition.maximum-definition.minimum)/100
                            let new=number+delta<=definition.maximum ? number+delta:number-delta
                            targets.append((block,definition,old,.number(new)))
                        }
                        if !definition.harness,definition.type=="b",definition.key=="Mode",model.name=="Elephant Man",let value=old.boolean {targets.append((block,definition,old,.bool(!value)))}
                        if definition.harness,definition.key=="Trails",model.name=="Elephant Man",let value=old.boolean {targets.append((block,definition,old,.bool(!value)))}
                        if !definition.harness,block.slot==0,definition.key=="Mic",definition.type=="i",model.name=="4x12 Greenback 30",let number=old.numeric {
                            targets.append((block,definition,old,.int(Int64(number<definition.maximum ? number+1:number-1))))
                        }
                        if !definition.harness,block.slot==1,definition.key=="Distance",definition.type=="f",let number=old.numeric {
                            let delta=(definition.maximum-definition.minimum)/100
                            let new=number+delta<=definition.maximum ? number+delta:number-delta
                            targets.append((block,definition,old,.number(new)))
                        }
                    }
                }
                guard !targets.isEmpty else{throw ProtocolError.invalid("No appropriate non-level test parameter was found.")}
                let reader:Task<Void,Error>? = args.contains("--concurrent-reads") ? Task {for _ in 0..<3 {_ = try await session.snapshot()}}:nil
                for (block,definition,original,desired) in targets {
                    let before=try await session.snapshot(),context=try before.context(for:block)
                    guard before.presetID==firstID else{throw ProtocolError.invalid("The spare preset changed.")}
                    print("STEP edit: \(definition.name), type \(definition.type)");fflush(stdout)
                    _ = try await session.setParameter(context:context,definition:definition,value:desired,expected:original,backups:backups)
                    print("STEP save");fflush(stdout)
                    _ = try await session.savePreset(expectedID:firstID,backups:backups)
                    _ = try await session.loadPreset(secondID,expectedID:firstID)
                    let reloaded=try await session.loadPreset(firstID,expectedID:secondID)
                    guard let changed=reloaded.blocks.first(where:{$0.id==block.id})?.value(definition),sameParameterValue(changed,try definition.validated(desired)) else{throw ProtocolError.invalid("Edited value did not survive save and reload.")}
                    _ = try await session.setParameter(context:try reloaded.context(for:block),definition:definition,value:original,expected:changed,backups:backups)
                    _ = try await session.savePreset(expectedID:firstID,backups:backups)
                    _ = try await session.loadPreset(secondID,expectedID:firstID)
                    let restored=try await session.loadPreset(firstID,expectedID:secondID)
                    guard let final=restored.blocks.first(where:{$0.id==block.id})?.value(definition),sameParameterValue(final,original) else{throw ProtocolError.invalid("Spare value restoration was not verified.")}
                    print("PASS spare edit/save/reload/restore: \(definition.name), slot \(block.slot+1), type \(definition.type)")
                }
                try await reader?.value
                print("COMPLETE PASS: \(targets.count) spare parameter persistence checks; existing presets were not write destinations.")
            } else {throw ProtocolError.invalid("Select --prepare or --exercise explicitly.")}
            await session.disconnect()
        } catch {await session.disconnect();FileHandle.standardError.write(Data((error.localizedDescription+"\n").utf8));exit(1)}
    }
}
