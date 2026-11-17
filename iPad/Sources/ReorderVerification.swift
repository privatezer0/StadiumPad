#if DEBUG
import Foundation
import StadiumProtocol
import StadiumNetwork

private struct ReorderVerificationPlan:Codable {let preserved:PreservedPreset;let test:PreservedPreset}

@MainActor func verifyReorder(_ monitor:StadiumMonitor,resume:Bool=false)async {
    let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0],planURL=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("reorder-test-plan.json")
    var checks=0,report:[String:Any]=[:]
    func require(_ value:Bool,_ message:String)throws {guard value else{throw ProtocolError.invalid(message)};checks+=1}
    do {
        let preserved:PreservedPreset,test:PreservedPreset
        var interruptedMove=false
        if resume {
            let reviewed=try JSONDecoder().decode(ReorderVerificationPlan.self,from:Data(contentsOf:folder.appendingPathComponent("reorder-resume-plan.json")))
            guard reviewed.preserved.preset.name=="StadiumPad Move Preserve",reviewed.test.preset.name=="StadiumPad Move Test",reviewed.test.sourceID==reviewed.preserved.preset.contentID,reviewed.test.preset.contentID != reviewed.preserved.sourceID,(monitor.snapshot?.presetID==reviewed.preserved.preset.contentID && monitor.snapshot?.dirty==false) || monitor.snapshot?.presetID==reviewed.test.preset.contentID else{throw ProtocolError.invalid("Review the saved test copies and preserve any new source edits before resuming.")}
            preserved=reviewed.preserved;test=reviewed.test
            if monitor.snapshot?.presetID==test.preset.contentID {interruptedMove=true}
            else {try require(await monitor.load(test.preset),"The reviewed new test copy could not be opened.")}
        } else {
            guard !FileManager.default.fileExists(atPath:planURL.path),let source=monitor.snapshot,let sourceID=source.presetID else{throw ProtocolError.invalid("Review the previous reorder test plan first.")}
            try Data("{\"started\":true}".utf8).write(to:planURL,options:.atomic)
            await monitor.copy(name:"StadiumPad Move Preserve")
            guard monitor.errorText==nil,let copy=monitor.lastCopy,let preserveID=copy.preset.contentID else{throw ProtocolError.invalid(monitor.errorText ?? "The source could not be preserved.")}
            preserved=copy
            try JSONEncoder().encode(preserved).write(to:folder.appendingPathComponent("reorder-preserved.json"),options:.atomic)
            try require(preserved.sourceID==sourceID && monitor.snapshot?.presetID==preserveID,"Source preservation was not verified.")
            await monitor.copy(name:"StadiumPad Move Test")
            guard let allocation=monitor.lastCopy,allocation.sourceID==preserveID else{throw ProtocolError.invalid(monitor.errorText ?? "The new spare was not allocated.")}
            // Record allocation even when the conservative source-byte guard
            // refuses automatic opening. Recovery must not allocate again.
            test=allocation
            try JSONEncoder().encode(ReorderVerificationPlan(preserved:preserved,test:test)).write(to:planURL,options:.atomic)
            guard monitor.errorText==nil else{throw ProtocolError.invalid(monitor.errorText!)}
        }
        guard let testID=test.preset.contentID,let preserveID=preserved.preset.contentID,let live=monitor.snapshot else{throw ProtocolError.closed}
        try require(testID != preserved.sourceID && testID != preserveID && test.sourceID==preserveID && live.presetID==testID,"Only the newly allocated test spare may change.")
        let start=interruptedMove ? try await monitor.storedSpareForVerification(testID):live
        try JSONSerialization.data(withJSONObject:start.editBuffer.json,options:.prettyPrinted).write(to:folder.appendingPathComponent("reorder-native-before.json"),options:.atomic)
        let models=Dictionary(uniqueKeysWithValues:monitor.catalog.values.map{($0.id,$0)})
        let candidates=start.blocks.filter{$0.slot==0 && (1...12).contains($0.position)}
        var choice:(SignalBlock,EditContext,BlockReorderPlan)?
        for block in candidates {
            for destination in candidates where destination.path==block.path && destination.position != block.position {
                if let context=try? start.context(for:block),let plan=try? BlockReorderPlan(state:start,context:context,to:destination.position,models:models) {choice=(block,context,plan);break}
            }
            if choice != nil {break}
        }
        guard let (block,context,plan)=choice else{throw ProtocolError.invalid("The spare needs two effects between routing nodes in row A.")}
        let moved:SignalBlock?
        if interruptedMove {
            // A prior ACK may already have moved the block. Verify the actual
            // complete expected result; never send the same agenda again.
            guard plan.matches(live) else{throw ProtocolError.invalid("The interrupted move does not match the reviewed saved layout. Nothing was retried.")}
            moved=live.blocks.first{$0.blockID==block.blockID && $0.slot==0 && $0.position==plan.to}
        } else {moved=await monitor.reorder(context:context,to:plan.to)}
        try require(moved?.blockID==block.blockID,monitor.errorText ?? "Move failed.")
        try require(monitor.snapshot.map(plan.matches)==true,"Full chain/settings readback failed.")
        await monitor.save(expectedID:testID)
        try require(monitor.errorText==nil && monitor.snapshot?.dirty==false,"Moved chain did not save.")
        try require(await monitor.load(preserved.preset),"Could not switch away.")
        try require(await monitor.load(test.preset),"Could not reload test.")
        try require(monitor.snapshot.map(plan.matches)==true,"Moved chain did not survive save/reload.")
        guard let reloaded=monitor.snapshot,let fresh=reloaded.blocks.first(where:{$0.blockID==block.blockID && $0.slot==0}) else{throw ProtocolError.closed}
        try require(await monitor.reorder(context:try reloaded.context(for:fresh),to:block.position) != nil,"Could not restore the original order.")
        await monitor.save(expectedID:testID)
        try require(monitor.errorText==nil && monitor.snapshot?.dirty==false,"Restored chain did not save.")
        try require(await monitor.load(preserved.preset),"Could not switch away after restoration.")
        try require(await monitor.load(test.preset),"Could not reload restored chain.")
        try require(monitor.snapshot?.blocks.sorted(by:{$0.id<$1.id})==start.blocks.sorted(by:{$0.id<$1.id}),"Original order and settings were not restored.")
        try require(await monitor.load(preserved.preset),"Could not return to preserved source.")
        report=["passed":true,"checks":checks,"movedAcrossOccupiedPositions":true,"saveReloadRestored":true,"preservedLocation":preserved.preset.label,"testLocation":test.preset.label]
    } catch {report=["passed":false,"checks":checks,"error":error.localizedDescription]}
    if let state=monitor.snapshot {try? JSONSerialization.data(withJSONObject:state.editBuffer.json,options:.prettyPrinted).write(to:folder.appendingPathComponent("reorder-native-after.json"),options:.atomic)}
    report["at"]=Date().timeIntervalSince1970
    try? JSONSerialization.data(withJSONObject:report,options:.prettyPrinted).write(to:folder.appendingPathComponent("reorder-verification.json"),options:.atomic)
}
#endif
