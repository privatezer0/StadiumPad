import SwiftUI
import Network
import StadiumProtocol
import StadiumNetwork

@MainActor final class StadiumMonitor:ObservableObject {
    @Published var connectionID=UUID()
    @Published var currentHost=""
    @Published var connectionRoute:StadiumConnectionRoute = .automatic
    @Published var connectionInterface="Disconnected"
    @Published var tunerRequested=false
    @Published var tunerReference:Double?
    #if DEBUG
    private(set) var tunerAcknowledgments:[Bool]=[]
    #endif
    @Published var status="Connect to your Stadium to view its current preset."
    @Published var snapshot:DeviceSnapshot?
    @Published var connected=false
    @Published var connecting=false
    private(set) var lastEvent:Date?
    private var matrixPresentations:Set<UUID>=[]
    func beginMatrixPresentation()->UUID {let id=UUID();matrixPresentations.insert(id);return id}
    func endMatrixPresentation(_ id:UUID){matrixPresentations.remove(id)}
    #if DEBUG
    var debugMatrixPresentationCount:Int {matrixPresentations.count}
    #endif
    @Published var focusedBlock:StadiumBlockFocus?
    private(set) var focusedPresetID:Int?
    private(set) var selectionRememberedAt=Date.distantPast
    private var currentPort:UInt16=2001
    @Published var presets:[PresetSlot]=[]
    @Published var presetFolders:[PresetFolder]=[]
    @Published var factoryPresets:[PresetSlot]=[]
    @Published var cloneHierarchy:Value = .null
    @Published var libraryEntries:[Int:[LibraryEntry]]=[:]
    @Published var presetContainer = -2
    @Published var globalEQ:GlobalEQState?
    private var eqCommitTask:Task<Void,Never>?
    private var eqViewRevision:UInt64=0
    @Published var commandProperties:[String:Value]=[:]
    let commandCatalog:[String:[CommandParameter]] = {
        guard let url=Bundle.main.url(forResource:"CommandCatalog",withExtension:"json"),let data=try? Data(contentsOf:url) else{return [:]}
        return (try? JSONDecoder().decode([String:[CommandParameter]].self,from:data)) ?? [:]
    }()
    @Published var stompProperties:[String:Value]=[:]
    @Published private var editorBusy=false
    private var matrixWriting=false
    var busy:Bool {get{editorBusy || matrixWriting}set{editorBusy=newValue}}
    @Published var errorText:String?
    @Published var lastAction:String?
    @Published var lastCopy:PreservedPreset?
    let backups=PresetBackupStore(root:FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("Preset Backups"))
    let catalog:[String:ModelDefinition] = {
        guard let url=Bundle.main.url(forResource:"ParameterCatalog",withExtension:"json"),let data=try? Data(contentsOf:url),let catalog=try? JSONDecoder().decode([String:ModelDefinition].self,from:data) else{return [:]};return catalog
    }()
    let focusCatalog:[String:FocusDefinition] = {
        guard let url=Bundle.main.url(forResource:"FocusCatalog",withExtension:"json"),let data=try? Data(contentsOf:url) else{return [:]}
        return (try? JSONDecoder().decode([String:FocusDefinition].self,from:data)) ?? [:]
    }()
    func applyFocus(context:EditContext,changes:[FocusChange],expected:[String:Value])async throws {
        guard !busy,connected,let current=session else{throw ProtocolError.invalid("Finish the current update before adjusting Focus.")}
        busy=true;defer{busy=false};let token=generation
        let batch=try changes.map {change -> ParameterChange in
            guard let old=expected[change.definition.identity] else{throw ProtocolError.invalid("A Focus parameter is unavailable on this device.")}
            return ParameterChange(definition:change.definition,value:change.value,expected:old)
        }
        do {
            let after=try await current.setParameters(context:context,changes:batch,backups:backups)
            guard token==generation else{throw CancellationError()}
            snapshot=after;lastAction="Focus tone updated · unsaved";report()
        } catch {if token==generation {lastAction=nil};throw error}
    }
    private var worker:Task<Void,Never>?
    private var subscriber:Task<Void,Never>?
    private var refreshTask:Task<Void,Never>?
    private var pendingFocus:StadiumBlockFocus?
    private var liveRevision=0
    private var session:StadiumSession?
    private var generation=UUID()
    let names:[String:String] = {
        guard let url=Bundle.main.url(forResource:"ModelNames",withExtension:"json"),let data=try? Data(contentsOf:url),let names=try? JSONDecoder().decode([String:String].self,from:data) else{return [:]};return names
    }()
    func blockName(_ block:SignalBlock)->String {catalog[String(block.model)]?.name ?? names[String(block.model)] ?? "Effect block \(block.position)"}
    func connect(host:String,port:UInt16=2001,route:StadiumConnectionRoute = .automatic,interface:NWInterface?=nil) {
        guard !busy else{return}
        stop();connectionRoute=route;connectionID=UUID();currentHost=host;currentPort=port;snapshot=nil;presets=[];presetFolders=[];factoryPresets=[];libraryEntries=[:];stompProperties=[:];commandProperties=[:];globalEQ=nil;lastCopy=nil;lastAction=nil
        let token=UUID();generation=token
        lastEvent=nil;let current=StadiumSession();session=current;connecting=true;status="Connecting…"
        worker=Task {
            do {
                #if DEBUG
                let eqTrace:TraceRecorder?
                if ProcessInfo.processInfo.environment["STADIUM_TRACE_MATRIX"]=="1" {
                    let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
                    eqTrace=try TraceRecorder(path:folder.appendingPathComponent("matrix-events-"+UUID().uuidString+".jsonl").path,maximumBytes:2*1024*1024,channels:[Int(port)])
                }else if ProcessInfo.processInfo.environment["STADIUM_TRACE_GLOBAL_EQ"]=="1" {
                    let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
                    eqTrace=try TraceRecorder(path:folder.appendingPathComponent("global-eq-wire-"+UUID().uuidString+".jsonl").path,maximumBytes:8*1024*1024)
                }else{eqTrace=nil}
                try await current.connect(host:host,port:port,trace:eqTrace,route:route,interface:interface)
                #else
                try await current.connect(host:host,port:port,route:route,interface:interface)
                #endif
                let state=try await current.snapshot()
                guard generation==token,!Task.isCancelled else{await current.disconnect();return}
                connectionInterface=await current.connectionInterface();snapshot=state;connecting=false;connected=true;status="Connected · \(connectionInterface)";report()
                subscriber=Task {
                    do {
                        while !Task.isCancelled {
                            let event=try await current.event(timeout:8)
                            guard generation==token,!Task.isCancelled else{return}
                            lastEvent=Date()
                            if let update=StadiumLiveUpdate.decode(event) {
                                liveRevision+=1
                                if case .selection(let path,let position)=update {
                                    let focus=StadiumBlockFocus(path:path,position:position);pendingFocus=focus
                                    if snapshot?.blocks.contains(where:{$0.path-1==path && $0.position==position})==true {focusedPresetID=snapshot?.presetID;focusedBlock=focus}
                                }
                                refreshFromEvent(current,token:token)
                            }
                            report()
                        }
                    } catch {if generation==token,!Task.isCancelled {fail(error)}}
                }
                while !Task.isCancelled {
                    try await Task.sleep(for:.milliseconds(750))
                    if busy || !matrixPresentations.isEmpty {continue}
                    let state=try await current.snapshot(product:state.product)
                    guard generation==token,!Task.isCancelled else{return}
                    snapshot=state
                    if refreshTask==nil,let focus=pendingFocus,state.blocks.contains(where:{$0.path-1==focus.path && $0.position==focus.position}) {focusedPresetID=state.presetID;focusedBlock=focus;rememberExternalSelection(focus,in:state);pendingFocus=nil}
                    report()
                }
            } catch {if generation==token,!Task.isCancelled {fail(error)}}
        }
    }
    private func refreshFromEvent(_ current:StadiumSession,token:UUID) {
        guard refreshTask==nil else{return}
        refreshTask=Task {
            do {
                try await Task.sleep(for:.milliseconds(60))
                for _ in 0..<3 {
                    while (busy || !matrixPresentations.isEmpty) && !Task.isCancelled {try await Task.sleep(for:.milliseconds(75))}
                    guard generation==token,!Task.isCancelled else{return}
                    let revision=liveRevision
                    let state=try await current.snapshot(product:snapshot?.product)
                    guard generation==token,!Task.isCancelled else{return}
                    snapshot=state
                    if revision==liveRevision,let focus=pendingFocus {
                        if state.blocks.contains(where:{$0.path-1==focus.path && $0.position==focus.position}) {focusedPresetID=state.presetID;focusedBlock=focus;rememberExternalSelection(focus,in:state)}
                        pendingFocus=nil
                    }
                    report()
                    if revision==liveRevision {break}
                }
            } catch {if generation==token,!Task.isCancelled {fail(error)}}
            if generation==token {refreshTask=nil}
        }
    }
    #if DEBUG
    func prepareUSBSpare(name:String,expectedID:Int)async throws->PreservedPreset {
        guard connected,connectionRoute == .usb,connectionInterface=="USB/Ethernet",!busy,let session,snapshot?.presetID==expectedID else{throw ProtocolError.invalid("USB spare-copy context changed.")}
        let token=generation;busy=true;defer{busy=false}
        let copy=try await session.copyCurrent(name:name,expectedID:expectedID,backups:backups)
        guard token==generation else{throw CancellationError()};return copy
    }
    func readUSBSource()async throws->DeviceSnapshot {guard connected,let session else{throw ProtocolError.closed};return try await session.snapshot()}
    func readUSBSavedSource(_ id:Int)async throws->Data {
        guard connected,let session,snapshot?.presetID==id,let data=try await session.read(.contentData(id)).data else{throw ProtocolError.invalid("Source saved bytes are unavailable.")};return data
    }
    func matrixProperty()async throws->Value {guard connected,let session else{throw ProtocolError.closed};return try await session.read(.matrixMixer)}
    func matrixMIDIProperty()async throws->Value {guard connected,let session else{throw ProtocolError.closed};return try await session.read(.matrixMIDI)}
    #endif
    func readMatrixLevels()async throws->MatrixGuitarLevels {
        guard connected,let session else{throw ProtocolError.closed}
        let token=generation
        let value=try await session.matrixGuitarLevels()
        guard generation==token else{throw CancellationError()};return value
    }
    func navigateMatrixPanel(_ command:MatrixPanelCommand,channel:Int,send:@Sendable @escaping (Int)async throws->Void)async throws {
        guard connected,!busy,let session else{throw ProtocolError.invalid("Finish the current update before selecting an output.")};let token=generation
        matrixWriting=true;defer{if generation==token {matrixWriting=false;if matrixPresentations.isEmpty {objectWillChange.send()}}}
        try await session.navigateMatrixPanel(command,channel:channel,send:send)
        guard token==generation else{throw CancellationError()}
    }
    func matrixPanelChannel()async throws->Int {
        guard connected,let session else{throw ProtocolError.closed};let token=generation
        let channel=try await session.matrixPanelChannel();guard generation==token else{throw CancellationError()};return channel
    }
    func matrixChannels()async throws->[Int] {
        guard connected,let session else{throw ProtocolError.closed};let token=generation
        let channels=try await session.matrixMIDIChannels();guard generation==token else{throw CancellationError()};return channels
    }
    func setMatrixGuitar(output:Int,midi:Int,expected:MatrixGuitarLevels,channel:Int,send:@Sendable @escaping ()async throws->Void)async throws->MatrixGuitarLevels {
        guard connected,let session else{throw ProtocolError.closed};let token=generation
        let state=try await session.setMatrixGuitar(output:output,midi:midi,expected:expected,channel:channel,send:send)
        guard generation==token else{throw CancellationError()};return state
    }
    func readMatrixConsole()async throws->MatrixConsoleState {
        guard connected,let session else{throw ProtocolError.closed};let token=generation
        let state=try await session.matrixConsole();guard generation==token else{throw CancellationError()};return state
    }
    func setMatrixConsole(_ command:MatrixConsoleCommand,expected:MatrixConsoleState,channel:Int,send:@Sendable @escaping ()async throws->Void)async throws->MatrixConsoleState {
        guard connected,!busy,let session else{throw ProtocolError.invalid("Finish the current editor update before adjusting Matrix.")};let token=generation
        matrixWriting=true;defer{if generation==token {matrixWriting=false;if matrixPresentations.isEmpty {objectWillChange.send()}}}
        let state=try await session.setMatrixConsole(command,expected:expected,channel:channel,send:send)
        guard generation==token else{throw CancellationError()};return state
    }
    func clearMatrixSolos(_ command:MatrixClearSolosCommand,expected:MatrixConsoleState,channel:Int,send:@Sendable @escaping ()async throws->Void)async throws->MatrixConsoleState {
        guard connected,!busy,let session else{throw ProtocolError.invalid("Finish the current editor update before clearing solos.")}
        let token=generation;matrixWriting=true;defer{if token==generation {matrixWriting=false;if matrixPresentations.isEmpty {objectWillChange.send()}}}
        let state=try await session.clearMatrixSolos(command,expected:expected,channel:channel,send:send)
        guard token==generation else{throw CancellationError()};return state
    }
    func stop() {
        eqCommitTask?.cancel();eqCommitTask=nil
        generation=UUID();matrixWriting=false;editorBusy=false;refreshTask?.cancel();refreshTask=nil;pendingFocus=nil;focusedBlock=nil;focusedPresetID=nil;worker?.cancel();worker=nil;subscriber?.cancel();subscriber=nil
        let closeTuner=tunerRequested;tunerRequested=false
        if let old=session {Task {if closeTuner {try? await old.setTuner(false)};await old.disconnect()}}
        session=nil;connected=false;connecting=false;status="Disconnected. Last received values remain visible.";report()
    }
    private func selectionKey(_ state:DeviceSnapshot)->String? {
        RememberedBlockSelection.storageKey(product:state.product,endpoint:"\(currentHost):\(currentPort)",presetID:state.presetID)
    }
    private func rememberExternalSelection(_ focus:StadiumBlockFocus,in state:DeviceSnapshot) {
        guard UserDefaults.standard.object(forKey:"followStadiumSelection") as? Bool ?? true else{return}
        let previous=rememberedSelection(in:state)
        let slot=previous?.path==focus.path+1 && previous?.position==focus.position ? (previous?.slot ?? 0):0
        if let block=state.blocks.first(where:{$0.path-1==focus.path && $0.position==focus.position && $0.slot==slot}) {rememberSelection(block,in:state)}
    }
    func rememberSelection(_ block:SignalBlock,in state:DeviceSnapshot) {
        guard let key=selectionKey(state),state.blocks.contains(block),let data=try? JSONEncoder().encode(RememberedBlockSelection(block)) else{return}
        UserDefaults.standard.set(data,forKey:key);selectionRememberedAt=Date()
    }
    func rememberedSelection(in state:DeviceSnapshot)->SignalBlock? {
        guard let key=selectionKey(state),let data=UserDefaults.standard.data(forKey:key),data.count<512,let memory=try? JSONDecoder().decode(RememberedBlockSelection.self,from:data) else{return nil}
        return memory.resolve(in:state.blocks)
    }
    func selectBlock(context:EditContext)async {
        guard !busy,connected,let current=session else{return}
        busy=true;defer{busy=false};let token=generation
        do {let after=try await current.selectBlock(context:context);guard generation==token else{return};snapshot=after;lastAction="Block selected on Stadium";report()}
        catch {if generation==token {errorText=error.localizedDescription;lastAction=nil}}
    }
    func definitions(_ block:SignalBlock)->[ParameterDefinition] {catalog[String(block.model)]?.parameters.filter{$0.focusOnly != true && block.value($0) != nil} ?? []}
    func edit(context:EditContext,definition:ParameterDefinition,value:Value,expected:Value) async {
        guard !busy,connected,let current=session else{return};busy=true;defer{busy=false}
        let token=generation
        do {
            let state=try await current.setParameter(context:context,definition:definition,value:value,expected:expected,backups:backups)
            guard generation==token else{return};snapshot=state;lastAction="\(definition.name) updated · unsaved";report()
        } catch {if generation==token {errorText=error.localizedDescription;lastAction=nil;stop()}}
    }
    func save(expectedID:Int?=nil)async {
        guard !busy,connected,let current=session,let currentID=snapshot?.presetID else{return};let id=expectedID ?? currentID
        guard currentID==id else{errorText="The preset changed after you opened Save. Review the current preset before saving.";return}
        busy=true;defer{busy=false};let token=generation
        do {let state=try await current.savePreset(expectedID:id,backups:backups);guard generation==token else{return};snapshot=state;lastAction="Saved to \(state.location.label) · \(state.presetName)";report()}
        catch {if generation==token {errorText=error.localizedDescription;lastAction=nil;stop()}}
    }
    func copy(name:String,expectedID:Int?=nil)async {
        guard !busy,connected,let current=session,let id=snapshot?.presetID else{return}
        guard expectedID==nil || expectedID==id else{errorText="The preset changed. Reopen Save Copy before copying it.";return}
        busy=true;defer{busy=false};let token=generation
        do {
            let copy=try await current.copyCurrent(name:name,expectedID:id,backups:backups)
            lastCopy=copy
            guard generation==token else{return};lastAction="Copy saved in \(copy.preset.label) · \(copy.preset.name)"
            do {let state=try await current.openPreservedCopy(copy);guard generation==token else{return};snapshot=state;report()}
            catch {if generation==token {errorText=error.localizedDescription}}
        } catch {if generation==token {errorText=error.localizedDescription}}
    }
#if DEBUG
    func focusStoredBytesForVerification(_ id:Int)async throws->Data {
        guard connected,let current=session,let state=snapshot,state.presetID==id,state.presetName=="StadiumPad Focus Test",let bytes=try await current.read(.contentData(id)).data else{throw ProtocolError.invalid("Only the reviewed Focus spare may be inspected.")}
        return bytes
    }
    func storedSpareForVerification(_ id:Int)async throws->DeviceSnapshot {
        guard connected,let current=session,let state=snapshot,state.presetID==id,state.presetName=="StadiumPad Move Test",let bytes=try await current.read(.contentData(id)).data else{throw ProtocolError.invalid("Only the reviewed reorder test spare may be inspected.")}
        return DeviceSnapshot(product:state.product,editBuffer:try MessagePack.decode(bytes),preset:state.preset,activeSnapshot:state.activeSnapshot,rawEditBuffer:bytes,origin:state.origin)
    }
#endif
    func reorder(context:EditContext,to:Int)async->SignalBlock? {
        guard !busy,connected,let current=session else{return nil};busy=true;defer{busy=false};let token=generation
        do {
            let definitions=Dictionary(uniqueKeysWithValues:catalog.values.map{($0.id,$0)})
            let after=try await current.reorderBlock(context:context,to:to,models:definitions,backups:backups)
            guard generation==token else{return nil};snapshot=after;lastAction="Block rearranged · unsaved";report()
            return after.blocks.first{$0.path-1==context.path && $0.position==to && $0.blockID==context.blockID && $0.slot==0}
        } catch {if generation==token {errorText=error.localizedDescription};return nil}
    }
    func replace(context:EditContext,destination:ModelDefinition)async->SignalBlock? {
        guard !busy,connected,let current=session,let source=catalog[String(context.modelID)] else{return nil}
        busy=true;defer{busy=false};let token=generation
        do {
            let state=try await current.replaceModel(context:context,source:source,destination:destination,backups:backups)
            guard generation==token else{return nil};snapshot=state;lastAction="\(destination.name) selected · unsaved";report()
            return state.blocks.first{$0.path-1==context.path && $0.position==context.position && $0.slot==context.slot}
        } catch {if generation==token {errorText=error.localizedDescription;lastAction=nil;stop()};return nil}
    }
    func activate(_ index:Int,expectedID:Int?=nil,expectedSnapshot:Int?=nil)async {
        guard !busy,connected,let current=session,let state=snapshot,let id=state.presetID else{return}
        guard (expectedID==nil || expectedID==id),(expectedSnapshot==nil || expectedSnapshot==state.activeSnapshot) else{errorText="The preset or snapshot changed. Reopen the snapshot selector.";return}
        busy=true;defer{busy=false};let token=generation
        do {let after=try await current.activateSnapshot(index,expectedID:id,expectedSnapshot:state.activeSnapshot,backups:backups);guard generation==token else{return};snapshot=after;lastAction="Snapshot \(index+1) · \(after.snapshots.first{$0.id==index}?.name ?? "")";report()}
        catch {if generation==token {errorText=error.localizedDescription}}
    }
    func setTuner(_ enabled:Bool)async {
        // Navigation must not silently drop tuner entry/exit while another editor
        // operation is busy. StadiumSession serializes these explicit commands
        // through the same FIFO transaction lock as all other device operations.
        guard connected,let current=session else{return};let token=generation
        tunerRequested=enabled
        do {
            try await current.setTuner(enabled);guard generation==token else{return}
            #if DEBUG
            tunerAcknowledgments.append(enabled)
            #endif
            lastAction=enabled ? "Tuner open command acknowledged · read pitch on Stadium":"Tuner exit acknowledged"
            if enabled {
                let values=try await current.read(.tunerProperties);guard generation==token else{return}
                tunerReference=values["vals"].items.first{$0["key_"].text=="global.tuner.reference.pitch"}?["val_"].numeric
            }
        } catch {if generation==token {errorText=error.localizedDescription}}
    }
    func refreshGlobalEQ()async {
        guard !busy,connected,let current=session else{return};let token=generation,revision=eqViewRevision
        do {let value=try await current.globalEQ();guard token==generation,revision==eqViewRevision else{return};globalEQ=value
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--observe-global-eq") {
                let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
                let report:[String:Any] = ["receivedAt":Date().timeIntervalSince1970,"settings":value.value.json]
                try JSONSerialization.data(withJSONObject:report).write(to:folder.appendingPathComponent("global-eq-observed.json"),options:.atomic)
            }
            #endif
        }catch is CancellationError {}catch {if token==generation && !Task.isCancelled {errorText=error.localizedDescription}}
    }
    func editGlobalEQ(_ expected:GlobalEQState,_ output:EQOutput,_ operation:GlobalEQOperation,live:Bool=false)async->Bool {
        eqCommitTask?.cancel();eqCommitTask=nil
        #if DEBUG
        reportEQEdit("requested",expected,output,operation)
        #endif
        guard !busy,connected,let current=session else{return false};busy=true;eqViewRevision &+= 1;defer{busy=false};let token=generation
        do {let value:GlobalEQState
            if live {value=try await current.stageGlobalEQ(expected:expected,output:output,operation:operation,backups:backups)}else{value=try await current.editGlobalEQ(expected:expected,output:output,operation:operation,backups:backups)}
            guard token==generation else{return false};globalEQ=value;lastAction=live ? "Global EQ live":"Global EQ \(output.name) updated"
            #if DEBUG
            reportEQEdit(live ? "live-acknowledged":"stored-readback-confirmed",expected,output,operation)
            #endif
            return true}
        catch {
            #if DEBUG
            reportEQEdit("failed",expected,output,operation,error:error.localizedDescription)
            #endif
            if token==generation {errorText=error.localizedDescription};return false}
    }
    func finishGlobalEQGesture(output:EQOutput) {
        guard connected,let current=session,let expected=globalEQ else{return}
        eqCommitTask?.cancel();let token=generation
        eqCommitTask=Task {
            do {
                guard let value=try await current.commitGlobalEQ(expected:expected),token==generation,!Task.isCancelled else{return}
                globalEQ=value;lastAction="Global EQ updated"
                #if DEBUG
                reportEQEdit("stored-readback-confirmed",expected,output,.parameters([]))
                #endif
            }catch is CancellationError {}catch {
                if token==generation && !Task.isCancelled {
                    #if DEBUG
                    reportEQEdit("commit-failed",expected,output,.parameters([]),error:error.localizedDescription)
                    #endif
                    errorText=error.localizedDescription
                }
            }
        }
    }
    #if DEBUG
    func waitForGlobalEQConfirmation()async {await eqCommitTask?.value}
    private func reportEQEdit(_ stage:String,_ expected:GlobalEQState,_ output:EQOutput,_ operation:GlobalEQOperation,error:String?=nil) {
        guard ProcessInfo.processInfo.environment["STADIUM_TRACE_GLOBAL_EQ"]=="1" else{return}
        let updates=(try? operation.liveUpdates(in:expected,output:output)) ?? []
        var report:[String:Any] = ["diagnosticSchema":2,"build":Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? "unknown","at":Date().timeIntervalSince1970,"stage":stage,"busy":busy,"connected":connected,"output":output.rawValue,"settings":expected.value.json,"updates":updates.map{["key":$0.key,"value":$0.value.json]}]
        if let error {report["error"]=error}
        let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
        do {
            let data=try JSONSerialization.data(withJSONObject:report,options:.sortedKeys)
            try data.write(to:folder.appendingPathComponent("global-eq-last-edit.json"),options:.atomic)
            if stage.contains("failed") {try data.write(to:folder.appendingPathComponent("global-eq-last-failure.json"),options:.atomic)}
        }catch {try? Data(error.localizedDescription.utf8).write(to:folder.appendingPathComponent("global-eq-diagnostic-error.txt"),options:.atomic)}
    }
    #endif
    func editCommand(_ context:CommandContext,_ operation:CommandCenterOperation)async->Bool {
        guard !busy,connected,let current=session else{return false};busy=true;defer{busy=false};let token=generation
        do {let state=try await current.editCommand(context:context,operation:operation,backups:backups);guard token==generation else{return false};snapshot=state;lastAction="Command assignment updated · unsaved";report();return true}
        catch {if token==generation {errorText=error.localizedDescription};return false}
    }
    func replaceCommands(expected:DeviceSnapshot,copies:[CommandCopy])async->Bool {
        guard !busy,connected,let current=session else{return false};busy=true;defer{busy=false};let token=generation
        do {let state=try await current.replaceCommands(expected:expected,copies:copies,backups:backups);guard token==generation else{return false};snapshot=state;lastAction="Command layout updated · unsaved";report();return true}
        catch {if token==generation {errorText=error.localizedDescription};return false}
    }
    func setStompAppearance(_ context:CommandContext,_ appearance:StompAppearance)async->Bool {
        guard !busy,connected,let current=session else{return false};busy=true;defer{busy=false};let token=generation
        do {let state=try await current.setStompAppearance(context:context,appearance:appearance,backups:backups);guard token==generation else{return false};snapshot=state;await refreshStompProperties();lastAction="Stomp appearance updated · unsaved";return true}
        catch {if token==generation {errorText=error.localizedDescription};return false}
    }
    func refreshCommandProperties()async {
        guard connected,let current=session else{return};let token=generation
        do {let values=try await current.read(.commandProperties);guard token==generation else{return};commandProperties=Dictionary(uniqueKeysWithValues:values["vals"].items.compactMap{row in row["key_"].text.map{($0,row["val_"])}})}catch {if token==generation {commandProperties=[:]}}
    }
    func refreshStompProperties()async {
        guard connected,let session,let id=snapshot?.presetID else{return};let token=generation
        do {let response=try await session.read(.stompProperties);guard generation==token,snapshot?.presetID==id else{return};var properties:[String:Value]=[:];for item in response["vals"].items {if let key=item["key_"].text {properties[key]=item["val_"]}};stompProperties=properties}
        catch {if generation==token {stompProperties=[:]}}
    }
    func createScene(_ index:Int,expectedID:Int,expectedSnapshot:Int)async->Bool {
        guard !busy,connected,let current=session else{return false};busy=true;defer{busy=false};let token=generation
        do {let state=try await current.createSnapshot(index,expectedID:expectedID,expectedSnapshot:expectedSnapshot,backups:backups);guard generation==token else{return false};snapshot=state;lastAction="Scene \(index+1) created · unsaved";report();return true}
        catch {if generation==token {errorText=error.localizedDescription};return false}
    }
    func press(_ plan:StompPlan)async->Bool {
        guard !busy,connected,let current=session else{return false};busy=true;defer{busy=false};let token=generation
        do {let state=try await current.pressStomp(plan,backups:backups);guard generation==token else{return false};snapshot=state;lastAction="Stomp \(plan.bank.uppercased())\(plan.number) · assigned effects updated";report();return true}
        catch {if generation==token {errorText=error.localizedDescription;lastAction=nil;stop()};return false}
    }
    func readLibraryFolder(_ id:Int)async throws {
        guard connected,let session else{throw ProtocolError.closed};let token=generation
        let value=try await session.read(.container(id));guard generation==token else{throw CancellationError()}
        libraryEntries[id]=value.items.compactMap(LibraryEntry.init)
    }
    func refreshInventory()async throws {
        guard let session else{throw ProtocolError.closed};let token=generation
        for container in [-1,-2,-3,-4,-5,-6,-7,-8,-10,-11,-13,-14,-22,-23,-24,-25] {
            let value=try await session.read(.container(container));guard generation==token else{throw ProtocolError.closed};libraryEntries[container]=value.items.compactMap(LibraryEntry.init)
            if container == -1 {factoryPresets=value.items.map(PresetSlot.init).filter{($0.contentID ?? 0)>0}}
        }
        var folders:[PresetFolder]=[]
        for entry in libraryEntries[-5] ?? [] {
            let contents=try await session.read(.container(entry.id));guard generation==token else{throw ProtocolError.closed}
            let reference:Value = .object(["cid_":.int(Int64(entry.id)),"type":.int(1003),"posi":.int(Int64(entry.position)),"name":.string(entry.name)])
            if let folder=PresetFolder(reference:reference,contents:contents) {folders.append(folder)}
        }
        presetFolders=folders
        let clones=try await session.read(.cloneHierarchy);guard generation==token else{throw ProtocolError.closed};cloneHierarchy=clones
    }
    func library()async throws->[PresetSlot] {
        guard let session else{throw ProtocolError.closed}
        let token=generation;let container=presetContainer
        let fetched=try await session.presetLibrary(container:container)
        guard generation==token,presetContainer==container else{throw ProtocolError.closed}
        presets=fetched.filter{($0.contentID ?? 0)>0 && $0.type==2}.sorted{($0.position ?? 0)<($1.position ?? 0)}
        return fetched
    }
    func load(_ preset:PresetSlot)async->Bool {
        guard !busy,connected,let current=session,let id=preset.contentID,let expected=snapshot?.presetID else{return false}
        busy=true;defer{busy=false};let token=generation
        do {let state=try await current.loadPreset(id,expectedID:expected,discardingChangesWith:backups);guard generation==token else{return false};snapshot=state;lastAction="Opened \(preset.label) · \(preset.name)";report();return true}
        catch {if generation==token {errorText=error.localizedDescription};return false}
    }
    private func fail(_ error:Error) {stop();status=error.localizedDescription;report()}
    private func report() {
        guard ProcessInfo.processInfo.environment["STADIUM_VERIFY"]=="1" else{return}
        let object:[String:Any]=["connected":connected,"firmware":snapshot?.firmware ?? "","blocks":snapshot?.blocks.count ?? 0,"snapshot":snapshot?.activeSnapshot ?? -1,"receivedEvent":lastEvent != nil,"dirty":snapshot?.dirty ?? false,"focusPath":focusedBlock?.path ?? -1,"focusPosition":focusedBlock?.position ?? -1,"namedParameters":snapshot?.blocks.reduce(0){$0+definitions($1).count} ?? 0,"at":Date().timeIntervalSince1970,"status":status]
        do {
            let root=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("StadiumRemote")
            try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
            try JSONSerialization.data(withJSONObject:object,options:.prettyPrinted).write(to:root.appendingPathComponent("verification.json"),options:.atomic)
        } catch {print("Could not write the local verification report.")}
    }
}
struct StadiumDevice:Identifiable {var id:String;var host:String;var port:UInt16;var interface:NWInterface?=nil}
@MainActor final class StadiumDiscovery:NSObject,ObservableObject,@preconcurrency NetServiceBrowserDelegate,@preconcurrency NetServiceDelegate {
    @Published var devices:[StadiumDevice]=[]
    @Published var searching=false
    @Published var error:String?
    private let browser=NetServiceBrowser()
    private var pending:[NetService]=[]
    private var timer:Task<Void,Never>?
    override init() {super.init();browser.delegate=self}
    func search() {stop();devices=[];error=nil;searching=true;browser.searchForServices(ofType:"_stadiumserver._tcp.",inDomain:"local.");timer=Task {try? await Task.sleep(for:.seconds(6));if !Task.isCancelled {stop()}}}
    func stop() {timer?.cancel();timer=nil;browser.stop();for service in pending {service.stop()};pending=[];searching=false}
    func netServiceBrowser(_ browser:NetServiceBrowser,didFind service:NetService,moreComing:Bool) {pending.append(service);service.delegate=self;service.resolve(withTimeout:4)}
    func netServiceDidResolveAddress(_ sender:NetService) {
        guard let host=sender.hostName,sender.port>0,sender.port<65535 else{return}
        let device=StadiumDevice(id:sender.name,host:host,port:UInt16(sender.port))
        if !devices.contains(where:{$0.id==device.id}) {devices.append(device)}
    }
    func netServiceBrowser(_ browser:NetServiceBrowser,didNotSearch errorDict:[String:NSNumber]) {error="Search was unavailable. Allow Local Network access in Settings or enter your Stadium's address.";stop()}
}
