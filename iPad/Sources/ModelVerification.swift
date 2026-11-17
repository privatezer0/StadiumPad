#if DEBUG
import Foundation
import StadiumProtocol
import StadiumNetwork

@MainActor func verifyModelAndSnapshots(_ monitor:StadiumMonitor)async {
    let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    let planURL=folder.appendingPathComponent("model-test-plan.json")
    var checks=0
    func require(_ value:Bool,_ message:String)throws {guard value else{throw ProtocolError.invalid(message)};checks+=1}
    var report:[String:Any]=[:]
    do {
        // A prior plan means a previous allocation may have succeeded. Never
        // create more copies or retry writes blindly after interruption.
        guard !FileManager.default.fileExists(atPath:planURL.path),let source=monitor.snapshot,let sourceID=source.presetID else{throw ProtocolError.invalid("Review the existing model test plan before starting another test.")}
        await monitor.copy(name:"iPad Preserved Source 1117")
        guard monitor.errorText==nil,let preserved=monitor.lastCopy,let preserveID=preserved.preset.contentID else{throw ProtocolError.invalid("The preserved source copy failed.")}
        try require(preserved.sourceID==sourceID && monitor.snapshot?.presetID==preserveID,"The source copy was not independently verified.")
        try JSONEncoder().encode(preserved).write(to:folder.appendingPathComponent("preserved-source-plan.json"),options:.atomic)
        await monitor.copy(name:"iPad Model Test 1117")
        guard monitor.errorText==nil,let test=monitor.lastCopy,let testID=test.preset.contentID,let start=monitor.snapshot else{throw ProtocolError.invalid("The test copy was not verified.")}
        try require(test.sourceID==preserveID && testID != preserveID && testID != sourceID && start.presetID==testID,"Only the newly allocated test copy may be changed.")
        try JSONEncoder().encode(test).write(to:planURL,options:.atomic)
        guard let block=start.blocks.first(where:{monitor.catalog[String($0.model)]?.category=="reverb"}),let model=monitor.catalog["125"] else{throw ProtocolError.invalid("The source lacks a suitable reverb test block.")}
        let context=try start.context(for:block)
        guard let changed=await monitor.replace(context:context,destination:model) else{throw ProtocolError.invalid(monitor.errorText ?? "Model change failed.")}
        try require(changed.model==model.id,"The effect model did not change.")
        await monitor.save()
        try require(monitor.errorText==nil && monitor.snapshot?.dirty==false,"The changed model did not save.")
        try require(await monitor.load(preserved.preset),"Could not switch to the preserved source.")
        try require(await monitor.load(test.preset),"Could not reload the model test.")
        guard let reloaded=monitor.snapshot else{throw ProtocolError.closed}
        try require(reloaded.blocks.contains{$0.path==block.path && $0.position==block.position && $0.slot==block.slot && $0.model==model.id},"The new effect did not survive save/reload.")
        if let output=reloaded.blocks.first(where:{$0.position==13 && $0.path==2}),let destination=monitor.catalog[output.model==790 ? "783":"790"] {
            let result=await monitor.replace(context:try reloaded.context(for:output),destination:destination)
            try require(result?.model==destination.id,"Output selection was not confirmed.")
            await monitor.save()
            try require(monitor.errorText==nil && monitor.snapshot?.dirty==false,"The output change did not save.")
            try require(await monitor.load(preserved.preset),"Could not switch away after output save.")
            try require(await monitor.load(test.preset),"Could not reload the output test.")
            try require(monitor.snapshot?.blocks.contains{$0.path==2 && $0.position==13 && $0.model==destination.id}==true,"Output selection did not survive reload.")
        } else {throw ProtocolError.invalid("The test source needs an output on path 2.")}
        guard let sceneStart=monitor.snapshot,let alternate=sceneStart.snapshots.first(where:{$0.defined && $0.id != sceneStart.activeSnapshot}) else{throw ProtocolError.invalid("The test source needs two existing snapshots; the model/output test has been saved.")}
        let originalScene=sceneStart.activeSnapshot
        await monitor.activate(alternate.id)
        try require(monitor.errorText==nil && monitor.snapshot?.activeSnapshot==alternate.id,"The pedal did not switch to the requested snapshot.")
        await monitor.activate(originalScene)
        try require(monitor.errorText==nil && monitor.snapshot?.activeSnapshot==originalScene,"The original snapshot was not restored.")
        if monitor.snapshot?.dirty==true {await monitor.save()}
        try require(await monitor.load(preserved.preset),"Could not return to the preserved source copy.")
        report=["passed":true,"checks":checks,"model":model.name,"modelAndOutputSavedReloaded":true,"snapshotRoundTrip":true,"preservedLocation":preserved.preset.label,"testLocation":test.preset.label,"at":Date().timeIntervalSince1970]
    } catch {report=["passed":false,"checks":checks,"error":error.localizedDescription,"at":Date().timeIntervalSince1970]}
    try? JSONSerialization.data(withJSONObject:report,options:.prettyPrinted).write(to:folder.appendingPathComponent("model-verification.json"),options:.atomic)
}
#endif
