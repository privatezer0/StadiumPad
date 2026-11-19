import Foundation
import StadiumProtocol
import StadiumNetwork

struct ReviewedReorderPlan:Codable {let preserved:PreservedPreset;let test:PreservedPreset}
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
            if args.contains("--command-transaction-check") {
                guard host=="127.0.0.1" else{throw ProtocolError.invalid("Synthetic command checks are loopback-only.")}
                let context=try CommandContext(state:state,source:CommandSource(.stomp,number:1,bank:1),slot:0)
                let created=try await session.editCommand(context:context,operation:.family(.midi),backups:backups)
                let next=try CommandContext(state:created,source:context.source,slot:0)
                _ = try await session.editCommand(context:next,operation:.parameter(CommandParameter(id:1,name:"Command",minimum:0,maximum:3),.int(1)),backups:backups)
                print("PASS command transaction and independent readback.");await session.disconnect();return
            }
            if args.contains("--command-appearance-check"),let catalogue=option("--catalog") {
                let plan=try JSONDecoder().decode(SparePlan.self,from:Data(contentsOf:URL(fileURLWithPath:path)))
                let marker=path+".appearance-started"
                guard !FileManager.default.fileExists(atPath:marker),plan.first.preset.name=="StadiumPad Commands Preserve",plan.second.preset.name=="StadiumPad Commands Test",let testID=plan.second.preset.contentID,let preserveID=plan.first.preset.contentID,testID != preserveID,testID != plan.first.sourceID,preserveID != plan.first.sourceID,[testID,preserveID].contains(state.presetID ?? -1) else{throw ProtocolError.invalid("Review the allocated spares and test intent. Never replay a partial appearance check.")}
                try Data("started".utf8).write(to:URL(fileURLWithPath:marker),options:.atomic)
                var current=state
                if state.presetID != testID {current=try await session.loadPreset(testID,expectedID:preserveID,discardingChangesWith:backups)}
                try await Task.sleep(for:.milliseconds(300));current=try await session.snapshot()
                let initial=current,source=CommandSource(.stomp,number:1,bank:1)
                let definitions=try JSONDecoder().decode([String:[CommandParameter]].self,from:Data(contentsOf:URL(fileURLWithPath:catalogue)))
                for action in [3,0] {
                    let c=try CommandContext(state:current,source:source,slot:0)
                    guard let p=definitions[source.catalogueKey(c.family)]?.first(where:{$0.name=="Action"}) else{throw ProtocolError.invalid("Missing Action metadata.")}
                    current=try await session.editCommand(context:c,operation:.parameter(p,.int(Int64(action))),backups:backups)
                }
                let peer=try CommandContext(state:current,source:source,slot:1)
                if peer.command["pvla"].integer != 0,let action=definitions[source.catalogueKey(peer.family)]?.first(where:{$0.name=="Action"}) {current=try await session.editCommand(context:peer,operation:.parameter(action,.int(0)),backups:backups)}
                for appearance in [StompAppearance.label("Tablet Commands"),.color(8)] {
                    current=try await session.setStompAppearance(context:CommandContext(state:current,source:source,slot:0),appearance:appearance,backups:backups)
                }
                current=try await session.savePreset(expectedID:testID,backups:backups)
                _ = try await session.loadPreset(preserveID,expectedID:testID)
                current=try await session.loadPreset(testID,expectedID:preserveID)
                let props=try await session.read(.stompProperties)
                guard props["vals"].items.first(where:{$0["key_"].text=="preset.floorboard.stomp.a.1.label"})?["val_"].text=="Tablet Commands",props["vals"].items.first(where:{$0["key_"].text=="preset.floorboard.stomp.a.1.color"})?["val_"].integer==8,current.blocks==initial.blocks else{throw ProtocolError.invalid("Appearance persistence or tone preservation failed.")}
                _ = try await session.loadPreset(preserveID,expectedID:testID)
                try Data("passed".utf8).write(to:URL(fileURLWithPath:path+".appearance-passed"),options:.atomic)
                print("PASS paired toggle, label/color save/reload and unchanged tone; returned to preserved copy.");await session.disconnect();return
            }
            if args.contains("--command-center-check"),let catalogue=option("--catalog") {
                let plan=try JSONDecoder().decode(SparePlan.self,from:Data(contentsOf:URL(fileURLWithPath:path)))
                let marker=path+".commands-started"
                guard !FileManager.default.fileExists(atPath:marker),plan.first.preset.name=="StadiumPad Commands Preserve",plan.second.preset.name=="StadiumPad Commands Test",let preserveID=plan.first.preset.contentID,let testID=plan.second.preset.contentID,state.presetID==testID,let saved=try await session.read(.contentData(testID)).data,PresetBackupStore.hash(saved)==plan.second.sourceHash else{throw ProtocolError.invalid("Only fresh reviewed Command Center spares may be tested. Do not replay a partial run.")}
                let definitions=try JSONDecoder().decode([String:[CommandParameter]].self,from:Data(contentsOf:URL(fileURLWithPath:catalogue)))
                try Data("started".utf8).write(to:URL(fileURLWithPath:marker),options:.atomic)
                var current=state
                _ = try await session.loadPreset(preserveID,expectedID:testID,discardingChangesWith:backups)
                current=try await session.loadPreset(testID,expectedID:preserveID)
                try await Task.sleep(for:.milliseconds(250))
                current=try await session.snapshot()
                let initial=current
                let source=CommandSource(.stomp,number:1,bank:1)
                func update(_ operation:CommandCenterOperation,_ target:CommandSource?=nil,_ slot:Int=0)async throws {
                    print("Checking command operation at source \((target ?? source).name), slot \(slot+1)")
                    let context=try CommandContext(state:current,source:target ?? source,slot:slot)
                    current=try await session.editCommand(context:context,operation:operation,backups:backups)
                }
                func definition(_ name:String,_ target:CommandSource?=nil,_ slot:Int=0)throws->CommandParameter {
                    let context=try CommandContext(state:current,source:target ?? source,slot:slot)
                    guard let p=definitions[context.source.catalogueKey(context.family)]?.first(where:{$0.name==name}) else{throw ProtocolError.invalid("Missing command metadata for \(name).")};return p
                }
                var checks=0
                for family in CommandFamily.allCases where family != .none {
                    try await update(.family(family));checks+=1
                }
                try await update(.family(.midi));try await update(.parameter(definition("Command"),.int(1)));checks+=2
                try await update(.parameter(definition("CC#"),.int(73)));try await update(.parameter(definition("Value"),.int(45)));checks+=2
                try await update(.snapshot(definition("Value"),true));try await update(.snapshot(definition("Value"),false));checks+=2
                let copy=try CommandCopy(context:CommandContext(state:current,source:source,slot:0),catalog:definitions)
                try await update(.paste(copy.family,copy.parameters,copy.command),nil,1);checks+=1
                let axis=CommandSource(.axis,number:0)
                try await update(.family(.midi),axis);try await update(.parameter(definition("CC#",axis),.int(14)),axis);checks+=2
                try await update(.family(.none),axis);checks+=1
                let instant=CommandSource(.instant,number:15)
                try await update(.family(.midi),instant);try await update(.parameter(definition("Wait",instant),.int(5)),instant);try await update(.family(.none),instant);checks+=3
                let properties=try await session.read(.commandProperties)
                let propertyMap=Dictionary(uniqueKeysWithValues:properties["vals"].items.compactMap{r in r["key_"].text.map{($0,r["val_"])}})
                let all=try CommandCopy.all(state:current,catalog:definitions,properties:propertyMap)
                current=try await session.replaceCommands(expected:current,copies:[],backups:backups);checks+=1
                current=try await session.replaceCommands(expected:current,copies:all,backups:backups);checks+=1
                let intended=try CommandCopy.all(state:current,catalog:definitions,properties:propertyMap)
                current=try await session.savePreset(expectedID:testID,backups:backups)
                _ = try await session.loadPreset(preserveID,expectedID:testID)
                current=try await session.loadPreset(testID,expectedID:preserveID)
                let stored=try CommandCopy.all(state:current,catalog:definitions,properties:propertyMap)
                guard intended.count==stored.count,zip(intended,stored).allSatisfy({a,b in a.source==b.source && a.slot==b.slot && a.family==b.family && a.parameters.allSatisfy({sameParameterValue(a.command[$0.valueKey],b.command[$0.valueKey])})}),current.blocks==initial.blocks else{throw ProtocolError.invalid("Command assignments did not survive save/reload, or tone settings changed.")};checks+=1
                _ = try await session.loadPreset(preserveID,expectedID:testID)
                let result:[String:Any]=["checks":checks,"savedReloaded":true,"tonePreserved":true,"returnedToPreservedCopy":true]
                try JSONSerialization.data(withJSONObject:result,options:.prettyPrinted).write(to:URL(fileURLWithPath:path+".commands-result.json"),options:.atomic)
                print("PASS \(checks) Command Center checks; save/reload and unchanged tone; returned to preserved copy.")
                await session.disconnect();return
            }
            if args.contains("--prepare-command-center") {
                guard !FileManager.default.fileExists(atPath:path),!FileManager.default.fileExists(atPath:path+".first"),let id=state.presetID else{throw ProtocolError.invalid("Choose a fresh command-center plan; never repeat a partial allocation.")}
                let preserved=try await session.copyCurrent(name:"StadiumPad Commands Preserve",expectedID:id,backups:backups)
                try JSONEncoder().encode(preserved).write(to:URL(fileURLWithPath:path+".first"),options:.atomic)
                try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:path+".first")
                let test=try await session.copyCurrent(name:"StadiumPad Commands Test",expectedID:id,backups:backups)
                try JSONEncoder().encode(SparePlan(first:preserved,second:test)).write(to:URL(fileURLWithPath:path),options:.atomic)
                try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:path)
                _ = try await session.openPreservedCopy(preserved)
                guard let preserveID=preserved.preset.contentID,let testID=test.preset.contentID else{throw ProtocolError.invalid("The spare IDs were not confirmed.")}
                _ = try await session.loadPreset(testID,expectedID:preserveID)
                print("Preserved current live tone in a new copy; opened a separate Command Center test copy.")
                await session.disconnect();return
            }
            if args.contains("--selection-check") {
                let listener=Task {while !Task.isCancelled {_ = try await session.event(timeout:5)}}
                defer {listener.cancel()}
                guard let block=state.blocks.first else{throw ProtocolError.invalid("No selectable block.")}
                let after=try await session.selectBlock(context:state.context(for:block))
                guard after.rawEditBuffer==state.rawEditBuffer,after.presetID==state.presetID,after.activeSnapshot==state.activeSnapshot,after.dirty==state.dirty else{throw ProtocolError.invalid("Preset changed during selection check.")}
                print("PASS selection echo correlated; preset bytes and dirty state unchanged")
                await session.disconnect();return
            }
            if args.contains("--discard-check") || args.contains("--strict-load-check") {
                let plan=try JSONDecoder().decode(SparePlan.self,from:Data(contentsOf:URL(fileURLWithPath:path)))
                guard let first=plan.first.preset.contentID,let second=plan.second.preset.contentID,first != second,first != plan.first.sourceID,second != plan.first.sourceID,state.presetID==first,plan.first.preset.name.hasPrefix("iPad Edit Test"),plan.second.preset.name.hasPrefix("iPad Reload Check"),let saved=try await session.read(.contentData(first)).data else{throw ProtocolError.invalid("Only the reviewed test spares may be used.")}
                let after:DeviceSnapshot
                if args.contains("--strict-load-check") {after=try await session.loadPreset(second,expectedID:first)}
                else {after=try await session.loadPreset(second,expectedID:first,discardingChangesWith:backups)}
                guard after.presetID==second,try await session.read(.contentData(first)).data==saved else{throw ProtocolError.invalid("Discard changed the saved source.")}
                let restored=try await session.loadPreset(first,expectedID:second,discardingChangesWith:backups)
                let stored=DeviceSnapshot(product:state.product,editBuffer:try MessagePack.decode(saved),preset:state.preset,activeSnapshot:state.activeSnapshot)
                guard restored.blocks==stored.blocks else{throw ProtocolError.invalid("Saved source did not reload after discard.")}
                print("PASS discard/load/return; saved bytes unchanged");await session.disconnect();return
            } else if args.contains("--reorder-resume"),let catalogue=option("--catalog") {
                let plan=try JSONDecoder().decode(ReviewedReorderPlan.self,from:Data(contentsOf:URL(fileURLWithPath:path)))
                guard let testID=plan.test.preset.contentID,let preserveID=plan.preserved.preset.contentID,plan.test.preset.name=="StadiumPad Move Test",plan.preserved.preset.name=="StadiumPad Move Preserve",plan.test.sourceID==preserveID,testID != preserveID,testID != plan.preserved.sourceID,state.presetID==testID,state.presetName==plan.test.preset.name,let saved=try await session.read(.contentData(testID)).data,PresetBackupStore.hash(saved)==plan.test.sourceHash else{throw ProtocolError.invalid("Only the independently reviewed new test copy may resume. Nothing was retried.")}
                let models=try JSONDecoder().decode([String:ModelDefinition].self,from:Data(contentsOf:URL(fileURLWithPath:catalogue))),definitions=Dictionary(uniqueKeysWithValues:models.values.map{($0.id,$0)})
                let original=DeviceSnapshot(product:state.product,editBuffer:try MessagePack.decode(saved),preset:state.preset,activeSnapshot:state.activeSnapshot,rawEditBuffer:saved,origin:state.origin)
                let candidates=original.blocks.filter{$0.slot==0 && (1...12).contains($0.position)}
                var selected:(SignalBlock,BlockReorderPlan)?
                // An independently observed touchscreen move can end in an empty
                // cell. Explicit positions identify it; never replay the forward move.
                let requestedSource=option("--source-position").flatMap(Int.init)
                let requestedDestination=option("--destination").flatMap(Int.init)
                for block in candidates where requestedSource==nil || block.position==requestedSource {
                    let destinations=requestedDestination.map{[$0]} ?? candidates.filter{$0.path==block.path}.map(\.position)
                    for destination in destinations where block.position != destination {
                        if let pending=try? BlockReorderPlan(state:original,context:original.context(for:block),to:destination,models:definitions),pending.matches(state) {selected=(block,pending);break}
                    }
                    if selected != nil {break}
                }
                guard let (source,expected)=selected,expected.matches(state) else{throw ProtocolError.invalid("The existing move does not match all reviewed block settings and assignments. Nothing was retried.")}
                print("Confirmed previous move by independent full state/settings/assignment readback; no duplicate agenda sent.")
                _ = try await session.savePreset(expectedID:testID,backups:backups)
                _ = try await session.loadPreset(preserveID,expectedID:testID)
                let loaded=try await session.loadPreset(testID,expectedID:preserveID)
                guard expected.matches(loaded),let moved=loaded.blocks.first(where:{$0.blockID==source.blockID && $0.slot==0}) else{throw ProtocolError.invalid("Moved settings/assignments did not survive save/reload.")}
                _ = try await session.reorderBlock(context:loaded.context(for:moved),to:source.position,models:definitions,backups:backups)
                _ = try await session.savePreset(expectedID:testID,backups:backups)
                _ = try await session.loadPreset(preserveID,expectedID:testID)
                let restored=try await session.loadPreset(testID,expectedID:preserveID)
                guard restored.blocks.sorted(by:{$0.id<$1.id})==original.blocks.sorted(by:{$0.id<$1.id}) else{throw ProtocolError.invalid("Restored block layout/settings did not survive save/reload.")}
                _ = try await session.loadPreset(preserveID,expectedID:testID)
                print("PASS real-device reorder/save/reload/restore; assignments verified; returned to preserved copy.")
                await session.disconnect();return
            } else if args.contains("--prepare") || args.contains("--prepare-focus") {
                guard !FileManager.default.fileExists(atPath:path),let id=state.presetID else{throw ProtocolError.invalid("Choose a new plan filename.")}
                let first=try await session.copyCurrent(name:args.contains("--prepare-focus") ? "StadiumPad Focus Preserve":"iPad Edit Test 1117",expectedID:id,backups:backups)
                // Persist each allocation before attempting another; never retry blindly.
                let partial=URL(fileURLWithPath:path+".first");try JSONEncoder().encode(first).write(to:partial,options:.atomic)
                try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:partial.path)
                let second=try await session.copyCurrent(name:args.contains("--prepare-focus") ? "StadiumPad Focus Test":"iPad Reload Check 1117",expectedID:id,backups:backups)
                let plan=SparePlan(first:first,second:second)
                try JSONEncoder().encode(plan).write(to:URL(fileURLWithPath:path),options:.atomic)
                try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:path)
                _ = try await session.openPreservedCopy(first)
                print("Independent spare copies verified and opened: \(first.preset.label), \(second.preset.label). Original stored preset was not written.")
            } else if (args.contains("--exercise") || args.contains("--replace-check") || args.contains("--reorder-check") || args.contains("--focus-check")),let catalogPath=option("--catalog") {
                let plan=try JSONDecoder().decode(SparePlan.self,from:Data(contentsOf:URL(fileURLWithPath:path)))
                guard let firstID=plan.first.preset.contentID,let secondID=plan.second.preset.contentID,firstID != secondID,firstID != plan.first.sourceID,secondID != plan.first.sourceID,state.presetID==firstID,state.presetName==plan.first.preset.name,plan.first.preset.name.hasPrefix("iPad Edit Test"),plan.second.preset.name.hasPrefix("iPad Reload Check") else{throw ProtocolError.invalid("Only the prepared spare presets may be tested.")}
                let catalog=try JSONDecoder().decode([String:ModelDefinition].self,from:Data(contentsOf:URL(fileURLWithPath:catalogPath)))
                if args.contains("--focus-check") {
                    guard let block=state.blocks.first,let model=catalog[String(block.model)] else{throw ProtocolError.invalid("Missing Focus test model.")}
                    let parameters=model.parameters.filter{!$0.harness && block.value($0) != nil}
                    guard !parameters.isEmpty,parameters.count<=32 else{throw ProtocolError.invalid("Choose a bounded synthetic Focus test model.")}
                    let changes=try parameters.map {p -> ParameterChange in
                        let old=block.value(p)!,next:Value
                        if p.type=="b" {next = .bool(!(old.boolean ?? false))}
                        else {let step=p.type=="i" ? 1:(p.maximum-p.minimum)/10,n=old.numeric ?? p.minimum;next = try p.validated(.number(n+step<=p.maximum ? n+step:n-step))}
                        return ParameterChange(definition:p,value:next,expected:old)
                    }
                    let context=try state.context(for:block)
                    _ = try await session.setParameters(context:context,changes:changes,backups:backups)
                    _ = try await session.savePreset(expectedID:firstID,backups:backups)
                    _ = try await session.loadPreset(secondID,expectedID:firstID)
                    let loaded=try await session.loadPreset(firstID,expectedID:secondID)
                    guard let actual=loaded.blocks.first(where:{$0.blockID==block.blockID && $0.slot==block.slot}),changes.allSatisfy({sameParameterValue(actual.value($0.definition) ?? .null,$0.value)}) else{throw ProtocolError.invalid("Focus batch did not survive reload.")}
                    _ = try await session.setParameters(context:loaded.context(for:actual),changes:changes.map{ParameterChange(definition:$0.definition,value:$0.expected,expected:$0.value)},backups:backups)
                    _ = try await session.savePreset(expectedID:firstID,backups:backups)
                    _ = try await session.loadPreset(secondID,expectedID:firstID)
                    let restored=try await session.loadPreset(firstID,expectedID:secondID)
                    guard restored.blocks==state.blocks else{throw ProtocolError.invalid("Focus restoration failed.")}
                    print("PASS Focus batch/save/reload/restore");await session.disconnect();return
                }
                if args.contains("--reorder-check") {
                    guard let source=state.blocks.first,let target=Int(option("--destination") ?? "7") else{throw ProtocolError.invalid("Missing reorder target.")}
                    let models=Dictionary(uniqueKeysWithValues:catalog.values.map{($0.id,$0)})
                    let context=try state.context(for:source),plan=try BlockReorderPlan(state:state,context:context,to:target,models:models)
                    _ = try await session.reorderBlock(context:context,to:target,models:models,backups:backups)
                    _ = try await session.savePreset(expectedID:firstID,backups:backups)
                    _ = try await session.loadPreset(secondID,expectedID:firstID)
                    let reloaded=try await session.loadPreset(firstID,expectedID:secondID)
                    guard plan.matches(reloaded),let moved=reloaded.blocks.first(where:{$0.blockID==source.blockID && $0.slot==0}) else{throw ProtocolError.invalid("Move did not survive save/reload.")}
                    _ = try await session.reorderBlock(context:try reloaded.context(for:moved),to:source.position,models:models,backups:backups)
                    _ = try await session.savePreset(expectedID:firstID,backups:backups)
                    _ = try await session.loadPreset(secondID,expectedID:firstID)
                    let restored=try await session.loadPreset(firstID,expectedID:secondID)
                    guard restored.blocks.sorted(by:{$0.id<$1.id})==state.blocks.sorted(by:{$0.id<$1.id}) else{throw ProtocolError.invalid("Original block layout/settings were not restored.")}
                    print("PASS reorder/save/reload/restore")
                    await session.disconnect();return
                }
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
