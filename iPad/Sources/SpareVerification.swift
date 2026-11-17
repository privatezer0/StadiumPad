#if DEBUG
import Foundation
import StadiumProtocol
import StadiumNetwork

private struct NativeSparePlan:Decodable {let first:PreservedPreset;let second:PreservedPreset}
@MainActor func verifySpareEditing(_ monitor:StadiumMonitor,planURL:URL) async {
    var checks=0
    func require(_ ok:Bool,_ message:String)throws {guard ok else{throw ProtocolError.invalid(message)};checks+=1}
    var report:[String:Any]=[:]
    do {
        let plan=try JSONDecoder().decode(NativeSparePlan.self,from:Data(contentsOf:planURL))
        guard let first=plan.first.preset.contentID,let second=plan.second.preset.contentID,let start=monitor.snapshot else{throw ProtocolError.invalid("Spare test context is unavailable.")}
        try require(first != second && first != plan.first.sourceID && second != plan.first.sourceID,"The test plan does not contain independent spares.")
        try require(start.presetID==first && start.presetName==plan.first.preset.name && plan.first.preset.name.hasPrefix("iPad Edit Test"),"Only the named spare may be edited during verification.")
        var target:(SignalBlock,ParameterDefinition,Value)?
        for block in start.blocks {
            for parameter in monitor.definitions(block) where parameter.key=="Decay" && parameter.type=="f" && !parameter.harness && monitor.blockName(block).contains("Room") {
                if let value=block.value(parameter),value.numeric != nil {target=(block,parameter,value);break}
            }
            if target != nil {break}
        }
        guard let (block,parameter,original)=target,let number=original.numeric else{throw ProtocolError.invalid("A non-level test parameter is unavailable.")}
        let delta=(parameter.maximum-parameter.minimum)/100
        let desired:Value = .number(number+delta<=parameter.maximum ? number+delta:number-delta)
        monitor.errorText=nil
        await monitor.edit(context:try start.context(for:block),definition:parameter,value:desired,expected:original)
        try require(monitor.errorText==nil,"Native parameter edit failed: "+(monitor.errorText ?? ""))
        await monitor.save()
        try require(monitor.errorText==nil && monitor.snapshot?.dirty==false && monitor.lastAction?.hasPrefix("Saved to")==true,"Native save was not confirmed.")
        try require(await monitor.load(plan.second.preset),"Could not load the reload-check spare.")
        try require(await monitor.load(plan.first.preset),"Could not reload the edited spare.")
        guard let reloaded=monitor.snapshot,let changed=reloaded.blocks.first(where:{$0.id==block.id})?.value(parameter) else{throw ProtocolError.invalid("The reloaded test value is missing.")}
        try require(sameParameterValue(changed,try parameter.validated(desired)),"The edited parameter did not survive a native save and reload.")
        await monitor.edit(context:try reloaded.context(for:block),definition:parameter,value:original,expected:changed)
        await monitor.save()
        try require(monitor.errorText==nil && monitor.snapshot?.dirty==false,"The original spare value was not restored and saved.")
        try require(await monitor.load(plan.second.preset),"Reload-check spare could not be opened after restoration.")
        try require(await monitor.load(plan.first.preset),"Restored test spare could not be reloaded.")
        guard let final=monitor.snapshot?.blocks.first(where:{$0.id==block.id})?.value(parameter) else{throw ProtocolError.invalid("Restored value is missing.")}
        try require(sameParameterValue(final,original),"Restoration did not survive save/reload.")
        report=["passed":true,"checks":checks,"parameter":parameter.name,"restored":true,"at":Date().timeIntervalSince1970]
    } catch {report=["passed":false,"checks":checks,"error":error.localizedDescription,"at":Date().timeIntervalSince1970]}
    do {
        let root=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("StadiumRemote")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        try JSONSerialization.data(withJSONObject:report,options:.prettyPrinted).write(to:root.appendingPathComponent("spare-verification.json"),options:.atomic)
    } catch {print("Could not write spare verification report.")}
}
#endif
