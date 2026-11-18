#if DEBUG
import Foundation
import StadiumProtocol

/// Explicitly invoked selection-only check. No preset/model/parameter writes or Save.
@MainActor func verifyLiveSelection(_ monitor:StadiumMonitor,selection:()->BlockSelection?)async {
    var report:[String:Any]=[:]
    do {
        guard let before=monitor.snapshot else{throw ProtocolError.invalid("Not connected")}
        let effects=before.blocks.filter{$0.slot==0 && (1...12).contains($0.position%14)}
        let amp=effects.first{monitor.catalog[String($0.model)]?.category=="amp"} ?? effects.first
        let delay=effects.first{["delay","reverb"].contains(monitor.catalog[String($0.model)]?.category ?? "")} ?? effects.last
        guard let amp,let delay,amp.id != delay.id else{throw ProtocolError.invalid("Need two different blocks")}
        var checks=0
        for block in [amp,delay] {
            await monitor.selectBlock(context:try before.context(for:block))
            guard monitor.errorText==nil,let after=monitor.snapshot,after.presetID==before.presetID,after.activeSnapshot==before.activeSnapshot,after.blocks==before.blocks,after.dirty==before.dirty,monitor.focusedBlock?.path==block.path-1,monitor.focusedBlock?.position==block.position else{throw ProtocolError.invalid(monitor.errorText ?? "Selection/state verification failed")}
            checks+=1;try await Task.sleep(for:.milliseconds(400))
            guard let selected=selection(),selected.context.path==block.path-1,selected.context.position==block.position,selected.context.modelID==block.model else{throw ProtocolError.invalid("Visible editor did not follow the selected block")}
            checks+=1
        }
        report=["passed":true,"checks":checks,"visibleEditorFollows":true,"presetUnchanged":true,"parametersUnchanged":true,"dirtyUnchanged":true,"finalPath":delay.path-1,"finalPosition":delay.position]
    } catch {report=["passed":false,"error":error.localizedDescription]}
    let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    try? JSONSerialization.data(withJSONObject:report,options:.prettyPrinted).write(to:folder.appendingPathComponent("live-sync-verification.json"),options:.atomic)
}
@MainActor func verifyRememberedSelection(_ monitor:StadiumMonitor,selection:()->BlockSelection?)async {
    var report:[String:Any]
    if let state=monitor.snapshot,let remembered=monitor.rememberedSelection(in:state),let visible=selection(),visible.context.presetID==state.presetID,visible.context.path==remembered.path-1,visible.context.blockID==remembered.blockID,visible.context.slot==remembered.slot {
        report=["passed":true,"restoredAfterColdLaunch":true,"path":remembered.path-1,"position":remembered.position,"slot":remembered.slot,"model":remembered.model]
    } else {report=["passed":false,"error":"Visible block did not restore from the active preset preference"]}
    let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    try? JSONSerialization.data(withJSONObject:report,options:.prettyPrinted).write(to:folder.appendingPathComponent("selection-memory-verification.json"),options:.atomic)
}
#endif
