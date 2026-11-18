#if DEBUG
import Foundation
import StadiumProtocol
import StadiumNetwork

private struct DiscardSparePlan:Decodable {let preserved:PreservedPreset;let test:PreservedPreset}
@MainActor func verifyDiscard(_ monitor:StadiumMonitor)async {
    let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    var checks=0,report:[String:Any]=[:]
    func require(_ ok:Bool,_ message:String)throws {guard ok else{throw ProtocolError.invalid(message)};checks+=1}
    do {
        let plan=try JSONDecoder().decode(DiscardSparePlan.self,from:Data(contentsOf:folder.appendingPathComponent("focus-test-plan.json")))
        guard let preserved=plan.preserved.preset.contentID,let test=plan.test.preset.contentID,preserved != test,test != plan.test.sourceID,preserved != plan.preserved.sourceID,plan.test.preset.name=="StadiumPad Focus Test",plan.preserved.preset.name=="StadiumPad Focus Preserve",monitor.snapshot?.presetID==preserved,monitor.snapshot?.dirty==false else{throw ProtocolError.invalid("Review the existing clean Focus copies before discard verification.")}
        try require(await monitor.load(plan.test.preset),"Could not open the reviewed test copy.")
        guard let before=monitor.snapshot,before.dirty==false,let block=before.blocks.first(where:{monitor.focusCatalog[String($0.model)] != nil}),let parameter=monitor.definitions(block).first(where:{!$0.harness && $0.type=="f" && $0.maximum>$0.minimum}),let old=block.value(parameter),let number=old.numeric else{throw ProtocolError.invalid("A clean spare and test parameter are required.")}
        let saved=try await monitor.focusStoredBytesForVerification(test)
        let step=(parameter.maximum-parameter.minimum)/100
        let next:Value = .number(number+step<=parameter.maximum ? number+step:number-step)
        await monitor.edit(context:try before.context(for:block),definition:parameter,value:next,expected:old)
        try require(monitor.errorText==nil && monitor.snapshot?.dirty==true,"The test did not produce an unsaved edit.")
        try require(await monitor.load(plan.preserved.preset),"Preset selection failed to discard the unsaved edit.")
        try require(monitor.snapshot?.presetID==preserved && monitor.snapshot?.dirty==false,"The preserved destination was not opened cleanly.")
        try require(await monitor.load(plan.test.preset),"Could not return to the test copy.")
        try require(monitor.snapshot?.blocks==before.blocks && monitor.snapshot?.dirty==false,"Discard did not restore the saved settings.")
        let after=try await monitor.focusStoredBytesForVerification(test)
        try require(saved==after,"Discard must not change saved preset bytes.")
        try require(await monitor.load(plan.preserved.preset),"Could not leave the preserved copy open.")
        report=["passed":true,"checks":checks,"unsavedEditDiscarded":true,"savedBytesUnchanged":true,"returnedToPreservedCopy":true]
    }catch {report=["passed":false,"checks":checks,"error":error.localizedDescription]}
    report["at"]=Date().timeIntervalSince1970
    try? JSONSerialization.data(withJSONObject:report,options:.prettyPrinted).write(to:folder.appendingPathComponent("discard-verification.json"),options:.atomic)
}
#endif
