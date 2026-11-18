#if DEBUG
import Foundation
import StadiumProtocol
import StadiumNetwork

private struct FocusSparePlan:Decodable {let preserved:PreservedPreset;let test:PreservedPreset}
@MainActor func verifyFocus(_ monitor:StadiumMonitor)async {
    let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    var checks=0,report:[String:Any]=[:]
    func require(_ ok:Bool,_ message:String)throws {guard ok else{throw ProtocolError.invalid(message)};checks+=1}
    do {
        let plan=try JSONDecoder().decode(FocusSparePlan.self,from:Data(contentsOf:folder.appendingPathComponent("focus-test-plan.json")))
        guard let preserveID=plan.preserved.preset.contentID,let testID=plan.test.preset.contentID,preserveID != testID,plan.test.sourceID==plan.preserved.sourceID && testID != plan.preserved.sourceID && preserveID != plan.preserved.sourceID,plan.preserved.preset.name=="StadiumPad Focus Preserve",plan.test.preset.name=="StadiumPad Focus Test",monitor.snapshot?.presetID==preserveID,monitor.snapshot?.dirty==false else{throw ProtocolError.invalid("Review the clean preserved source and existing test spare before Focus testing.")}
        try require(await monitor.load(plan.test.preset),"Could not open the reviewed Focus test spare.")
        guard let start=monitor.snapshot,start.dirty==false,let block=start.blocks.first(where:{monitor.focusCatalog[String($0.model)] != nil}),let definition=monitor.focusCatalog[String(block.model)],let model=monitor.catalog[String(block.model)] else{throw ProtocolError.invalid("A clean test spare with a mapped model is required.")}
        let context=try start.context(for:block)
        let controls=model.parameters.filter{!$0.harness && definition.params.map(\.id).contains($0.id)}
        func expected(_ state:DeviceSnapshot)throws->[String:Value] {
            guard let b=state.blocks.first(where:{$0.blockID==block.blockID && $0.path==block.path && $0.slot==block.slot}) else{throw ProtocolError.invalid("The test block disappeared.")}
            return Dictionary(uniqueKeysWithValues:controls.compactMap{p in b.value(p).map{(p.identity,$0)}})
        }
        let starting=try expected(start)
        var applied:[FocusChange]=[]
        for point in [(0.0,0.0),(-1.0,1.0),(0.37,-0.62)] {
            applied=try definition.changes(x:point.0,y:point.1,model:model)
            guard let before=monitor.snapshot else{throw ProtocolError.closed}
            try await monitor.applyFocus(context:context,changes:applied,expected:expected(before))
            guard let after=monitor.snapshot,let changed=after.blocks.first(where:{$0.blockID==block.blockID && $0.path==block.path && $0.slot==block.slot}) else{throw ProtocolError.closed}
            try require(applied.allSatisfy{sameParameterValue(changed.value($0.definition) ?? .null,$0.value)},"A Focus point was not confirmed.")
        }
        await monitor.save(expectedID:testID);try require(monitor.errorText==nil && monitor.snapshot?.dirty==false,"Focus save was not confirmed.")
        try require(await monitor.load(plan.preserved.preset),"Could not switch away.")
        try require(await monitor.load(plan.test.preset),"Could not reload Focus tone.")
        guard let loaded=monitor.snapshot,let changed=loaded.blocks.first(where:{$0.blockID==block.blockID && $0.path==block.path && $0.slot==block.slot}) else{throw ProtocolError.closed}
        try require(applied.allSatisfy{sameParameterValue(changed.value($0.definition) ?? .null,$0.value)},"Focus values did not survive reload.")
        let restore=applied.compactMap{p in starting[p.definition.identity].map{FocusChange(definition:p.definition,value:$0)}}
        try await monitor.applyFocus(context:context,changes:restore,expected:expected(loaded))
        await monitor.save(expectedID:testID);try require(monitor.errorText==nil && monitor.snapshot?.dirty==false,"Restoration save failed.")
        try require(await monitor.load(plan.preserved.preset),"Could not switch away after restoring.")
        try require(await monitor.load(plan.test.preset),"Could not reload restored spare.")
        try require(monitor.snapshot?.blocks==start.blocks,"Restored settings did not survive reload.")
        try require(await monitor.load(plan.preserved.preset),"Could not return to preserved copy.")
        report=["passed":true,"checks":checks,"model":model.name,"focusParameters":definition.params.count,"saveReloadRestored":true]
    }catch {report=["passed":false,"checks":checks,"error":error.localizedDescription]}
    report["at"]=Date().timeIntervalSince1970
    try? JSONSerialization.data(withJSONObject:report,options:.prettyPrinted).write(to:folder.appendingPathComponent("focus-verification.json"),options:.atomic)
}
#endif
