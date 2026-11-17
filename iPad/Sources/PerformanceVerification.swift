#if DEBUG
import Foundation
import StadiumProtocol

@MainActor func verifyPerformance(_ monitor:StadiumMonitor)async {
    let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    let planURL=folder.appendingPathComponent("performance-test-plan.json")
    var checks=0
    func require(_ condition:Bool,_ message:String)throws {guard condition else{throw ProtocolError.invalid(message)};checks+=1}
    var report:[String:Any]=[:]
    do {
        guard !FileManager.default.fileExists(atPath:planURL.path),let source=monitor.snapshot,let sourceID=source.presetID else{throw ProtocolError.invalid("Review the existing performance test plan before running again.")}
        guard source.snapshots.contains(where:{!$0.defined}),StompAssignment.switchNumbers.contains(where:{StompAssignment.read(source,bank:"a",number:$0).plan != nil}) else{throw ProtocolError.invalid("The source must have an empty scene and an assigned latched effect switch.")}
        // Persist intent before allocation: an interrupted run must be reviewed.
        try Data("{\"started\":true}".utf8).write(to:planURL,options:.atomic)
        await monitor.copy(name:"StadiumPad Preserved")
        guard monitor.errorText==nil,let preserved=monitor.lastCopy,let preserveID=preserved.preset.contentID else{throw ProtocolError.invalid("Source preservation failed.")}
        try require(preserved.sourceID==sourceID && monitor.snapshot?.presetID==preserveID,"The source copy was not verified.")
        try JSONEncoder().encode(preserved).write(to:folder.appendingPathComponent("performance-preserved.json"),options:.atomic)
        await monitor.copy(name:"StadiumPad Gig Test")
        guard monitor.errorText==nil,let test=monitor.lastCopy,let testID=test.preset.contentID,let start=monitor.snapshot else{throw ProtocolError.invalid("The spare test copy failed.")}
        try JSONEncoder().encode(test).write(to:planURL,options:.atomic)
        try require(test.sourceID==preserveID && testID != preserveID && testID != sourceID && start.presetID==testID,"Only the new spare may be changed.")
        let initialBlocks=start.blocks,originalScene=start.activeSnapshot
        guard let empty=start.snapshots.first(where:{!$0.defined}) else{throw ProtocolError.invalid("No empty scene.")}
        try require(await monitor.createScene(empty.id,expectedID:testID,expectedSnapshot:originalScene),monitor.errorText ?? "Scene creation failed.")
        try require(monitor.snapshot?.snapshots.first(where:{$0.id==empty.id})?.defined==true,"Scene was not created.")
        guard let current=monitor.snapshot,let plan=StompAssignment.switchNumbers.compactMap({StompAssignment.read(current,bank:"a",number:$0).plan}).first else{throw ProtocolError.invalid("No supported assigned switch.")}
        try require(await monitor.press(plan),monitor.errorText ?? "Stomp press failed.")
        guard let pressed=monitor.snapshot else{throw ProtocolError.closed}
        try require(plan.controllers.allSatisfy{controller in controller.target.value(in:pressed).map{sameParameterValue($0,plan.input==1 ? controller.high:controller.low)}==true},"Assigned effects did not change.")
        guard let reverse=StompAssignment.read(pressed,bank:plan.bank,number:plan.number).plan else{throw ProtocolError.invalid("The reverse switch was unavailable.")}
        try require(await monitor.press(reverse),monitor.errorText ?? "Reverse stomp failed.")
        try require(monitor.snapshot.map{state in plan.controllers.allSatisfy{controller in controller.target.value(in:state).map{sameParameterValue($0,controller.current)}==true}}==true,"Original assigned values did not return.")
        await monitor.activate(empty.id,expectedID:testID,expectedSnapshot:originalScene)
        try require(monitor.errorText==nil && monitor.snapshot?.activeSnapshot==empty.id,"Created scene did not activate.")
        await monitor.activate(originalScene,expectedID:testID,expectedSnapshot:empty.id)
        try require(monitor.errorText==nil && monitor.snapshot?.activeSnapshot==originalScene,"Original scene did not return.")
        await monitor.save(expectedID:testID)
        try require(monitor.errorText==nil && monitor.snapshot?.dirty==false,"Spare save failed.")
        try require(await monitor.load(preserved.preset),"Could not switch to preserved copy.")
        try require(await monitor.load(test.preset),"Could not reload test copy.")
        try require(monitor.snapshot?.snapshots.first(where:{$0.id==empty.id})?.defined==true,"Created scene did not survive reload.")
        try require(monitor.snapshot?.blocks==initialBlocks,"Effect values were not restored after save/reload.")
        try require(await monitor.load(preserved.preset),"Could not return to preserved source.")
        report=["passed":true,"checks":checks,"sceneCreateSwitchSaveReload":true,"assignedSwitchRoundTrip":true,"switchControllerCount":plan.controllers.count,"preservedLocation":preserved.preset.label,"testLocation":test.preset.label,"at":Date().timeIntervalSince1970]
    } catch {report=["passed":false,"checks":checks,"error":error.localizedDescription,"at":Date().timeIntervalSince1970]}
    try? JSONSerialization.data(withJSONObject:report,options:.prettyPrinted).write(to:folder.appendingPathComponent("performance-verification.json"),options:.atomic)
}
#endif
