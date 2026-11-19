#if DEBUG
import Foundation
import StadiumProtocol
import StadiumNetwork

private struct CommandSparePlan:Decodable {let first:PreservedPreset;let second:PreservedPreset}
@MainActor func verifyCommandCenter(_ monitor:StadiumMonitor)async {
    let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    let marker=folder.appendingPathComponent("command-center-started.json")
    var checks=0
    func require(_ value:Bool,_ message:String)throws {guard value else{throw ProtocolError.invalid(message)};checks+=1}
    do {
        let plan=try JSONDecoder().decode(CommandSparePlan.self,from:Data(contentsOf:folder.appendingPathComponent("command-center-plan.json")))
        guard !FileManager.default.fileExists(atPath:marker.path),plan.first.preset.name=="StadiumPad Commands Preserve",plan.second.preset.name=="StadiumPad Commands Test",let testID=plan.second.preset.contentID,let preserveID=plan.first.preset.contentID,testID != preserveID,testID != plan.first.sourceID,preserveID != plan.first.sourceID,[testID,preserveID].contains(monitor.snapshot?.presetID ?? -1) else{throw ProtocolError.invalid("Review fresh Command Center test intent and the allocated spares. No partial test may be replayed.")}
        try Data("started".utf8).write(to:marker,options:.atomic)
        if monitor.snapshot?.presetID != testID {try require(await monitor.load(plan.second.preset),"Could not open test copy.")}
        try? await Task.sleep(for:.seconds(1))
        guard let initial=monitor.snapshot,initial.presetID==testID else{throw ProtocolError.invalid("Test preset did not settle.")}
        let source=CommandSource(.stomp,number:1,bank:1)
        func context(_ source:CommandSource,_ slot:Int=0)throws->CommandContext {guard let state=monitor.snapshot else{throw ProtocolError.closed};return try CommandContext(state:state,source:source,slot:slot)}
        func set(_ name:String,_ value:Int,_ target:CommandSource?=nil,_ slot:Int=0)async throws {
            let c=try context(target ?? source,slot)
            guard let p=monitor.commandCatalog[c.source.catalogueKey(c.family)]?.first(where:{$0.name==name}) else{throw ProtocolError.invalid("Missing command metadata.")}
            try require(await monitor.editCommand(c,.parameter(p,.int(Int64(value)))),monitor.errorText ?? "Parameter failed.")
        }
        try await set("Value",46)
        try await set("Action",3)
        try await set("Action",0)
        try await set("Action",0,nil,1)
        let c=try context(source)
        guard let p=monitor.commandCatalog[source.catalogueKey(c.family)]?.first(where:{$0.name=="Value"}) else{throw ProtocolError.invalid("Missing snapshot parameter.")}
        try require(await monitor.editCommand(c,.snapshot(p,true)),monitor.errorText ?? "Snapshot control failed.")
        try require(await monitor.editCommand(context(source),.snapshot(p,false)),monitor.errorText ?? "Snapshot removal failed.")
        let exp=CommandSource(.expression,number:0,bank:1)
        try require(await monitor.editCommand(context(exp),.family(.midi)),monitor.errorText ?? "EXP 2 failed.")
        try await set("CC#",15,exp)
        try require(await monitor.editCommand(context(exp),.family(.none)),monitor.errorText ?? "EXP removal failed.")
        try require(await monitor.setStompAppearance(context(source),.label("Tablet Commands")),monitor.errorText ?? "Label failed.")
        try require(await monitor.setStompAppearance(context(source),.color(8)),monitor.errorText ?? "Color failed.")
        await monitor.save(expectedID:testID)
        try require(monitor.errorText==nil && monitor.snapshot?.dirty==false,"Save failed.")
        try require(await monitor.load(plan.first.preset),"Switch-away failed.")
        try require(await monitor.load(plan.second.preset),"Reload failed.")
        try? await Task.sleep(for:.seconds(1))
        await monitor.refreshStompProperties();await monitor.refreshCommandProperties()
        try require(try context(source).command["pvlh"].integer==46,"Command did not survive reload.")
        try require(monitor.stompProperties["preset.floorboard.stomp.a.1.label"]?.text=="Tablet Commands" && monitor.stompProperties["preset.floorboard.stomp.a.1.color"]?.integer==8,"Appearance did not survive reload.")
        try require(monitor.snapshot?.blocks==initial.blocks,"Other tone settings changed.")
        let result:[String:Any] = ["passed":true,"checks":checks,"saveReload":true,"toneUnchanged":true]
        try JSONSerialization.data(withJSONObject:result,options:.prettyPrinted).write(to:folder.appendingPathComponent("command-center-verification.json"),options:.atomic)
    }catch {
        let result:[String:Any] = ["passed":false,"checks":checks,"error":error.localizedDescription]
        try? JSONSerialization.data(withJSONObject:result,options:.prettyPrinted).write(to:folder.appendingPathComponent("command-center-verification.json"),options:.atomic)
    }
}
#endif
