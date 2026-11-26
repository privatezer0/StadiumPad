import Foundation
import Network
import StadiumProtocol

public actor StadiumSession {
    private var commands:WireSocket?;private var updates:WireSocket?;private var nextID:Int32=1
    private var batchSnapshotReads=false
    private var snapshotHeader:(id:Int,product:Value)?
    private var occupied=false;private var waiters:[CheckedContinuation<Void,Never>]=[]
    private var allocated:Set<Int>=[]
    private var connectionID=UUID()
    private var matrixLive:[Int:MatrixGuitarUpdate]=[:]
    private var consoleLive:[String:MatrixConsoleUpdate]=[:]
    private var consoleReceipts:[String:UInt64]=[:]
    private var consoleLastMIDI:[String:(value:Int,level:Value)]=[:]
    private var panelRevision:UInt64=0
    private var panelReceipts:[Int:UInt64]=[:]
    private var matrixRevision:UInt64=0
    private var matrixReceipt:[Int:UInt64]=[:]
    private var matrixLastMIDI:[Int:(value:Int,level:Double)]=[:]

    private var eqShadow:GlobalEQState?;private var eqLastRead:GlobalEQState?;private var eqPending:[GlobalEQUpdate]=[];private var eqRevision:UInt64=0
    private var eqWriteRevision:UInt64=0;private var eqCommitHistory:[GlobalEQState]=[]
    private var eqEchoSource:Int?;private var eqReceipts:[Int32:Data]=[:];private var eqReceiptOrder:[Int32]=[]
    private var selectionReceipts:[Int32:StadiumBlockFocus]=[:]
    public init() {}
    private func acquire()async {if !occupied {occupied=true;return};await withCheckedContinuation{waiters.append($0)}}
    private func release() {if waiters.isEmpty {occupied=false}else{waiters.removeFirst().resume()}}
    public func connect(host:String,port:UInt16=2001,trace:TraceRecorder?=nil,route:StadiumConnectionRoute = .automatic,interface:NWInterface?=nil,bridge:PedalBridgeConnection?=nil)async throws {
        guard port>0,port<65535,!host.isEmpty,route != .usb || interface?.type != .wifi else{throw ProtocolError.invalid("Enter a valid Stadium address.")}
        await disconnect();connectionID=UUID();await acquire();defer{release()};try Task.checkCancellation()
        let sub=WireSocket(host:bridge?.pair.host ?? host,port:bridge?.pair.port ?? port,trace:trace,route:route,interface:interface,bridgePair:bridge?.pair,bridgeRequest:bridge?.request("updates")),command=WireSocket(host:bridge?.pair.host ?? host,port:bridge?.pair.port ?? (port+1),trace:trace,route:route,interface:interface,bridgePair:bridge?.pair,bridgeRequest:bridge?.request("commands"))
        do {
            try await sub.start();try await command.start();try await sub.handshake(type:"SUB");try await command.handshake(type:"DEALER")
            updates=sub;commands=command;batchSnapshotReads = bridge != nil
        } catch {await sub.close();await command.close();throw error}
    }
    public func connectionInterface()async->String {await commands?.interfaceName() ?? "Disconnected"}
    public func disconnect()async {await commands?.close();await updates?.close();commands=nil;updates=nil;snapshotHeader=nil;matrixLive=[:];panelRevision=0;panelReceipts=[:];consoleLive=[:];consoleReceipts=[:];consoleLastMIDI=[:];matrixRevision=0;matrixReceipt=[:];matrixLastMIDI=[:];allocated=[];selectionReceipts=[:];eqShadow=nil;eqLastRead=nil;eqPending=[];eqRevision=0;eqWriteRevision=0;eqCommitHistory=[];eqEchoSource=nil;eqReceipts=[:];eqReceiptOrder=[]}
    private func exchange(_ make:(Int32)throws->OSCMessage,reply:String)async throws->OSCMessage {
        try Task.checkCancellation();guard let socket=commands else{throw ProtocolError.closed}
        let id=nextID;nextID = nextID==Int32.max ? 1:nextID+1
        try await socket.send(Frame(payload:try make(id).encode()).encode())
        let deadline=Date().addingTimeInterval(5)
        while deadline.timeIntervalSinceNow>0 {
            let frame=try await socket.frame(timeout:deadline.timeIntervalSinceNow)
            if frame.flags&4 != 0 || frame.more || frame.payload.isEmpty {continue}
            let message=try OSCMessage.decode(frame.payload)
            guard message.values.first?.integer==Int(id) else{continue}
            if message.address=="/error" {throw ProtocolError.invalid("The Stadium rejected the request. No success was confirmed.")}
            if message.address==reply {return message}
        };throw ProtocolError.timeout
    }
    /// Pipeline only independent read requests inside the already-held FIFO
    /// transaction. Every reply is matched by request ID AND typed reply address.
    /// No edit is pipelined, retried, or allowed between snapshot guard phases.
    private func readBatchUnlocked(_ requests:[ReadCommand])async throws->[Value] {
        try Task.checkCancellation()
        guard !requests.isEmpty,requests.count<=8,let socket=commands else{throw ProtocolError.closed}
        var pending:[Int32:Int]=[:],packet=Data(),results=[Value?](repeating:nil,count:requests.count)
        for (index,request) in requests.enumerated() {
            let id=nextID;nextID = nextID==Int32.max ? 1:nextID+1
            pending[id]=index
            packet.append(try Frame(payload:request.message(id:id).encode()).encode())
        }
        try await socket.send(packet)
        let deadline=Date().addingTimeInterval(5)
        while !pending.isEmpty,deadline.timeIntervalSinceNow>0 {
            try Task.checkCancellation()
            let frame=try await socket.frame(timeout:deadline.timeIntervalSinceNow)
            if frame.flags&4 != 0 || frame.more || frame.payload.isEmpty {continue}
            let message=try OSCMessage.decode(frame.payload)
            guard let value=message.values.first?.integer,let id=Int32(exactly:value),let index=pending[id] else{continue}
            if message.address=="/error" {throw ProtocolError.invalid("The Stadium rejected a state read. Nothing further was sent.")}
            guard message.address==requests[index].replyAddress else{continue}
            results[index]=try requests[index].decode(message);pending[id]=nil
        }
        guard pending.isEmpty else{throw ProtocolError.timeout}
        let values=results.compactMap{$0}
        guard values.count==requests.count else{throw ProtocolError.invalid("Incomplete Stadium state read.")}
        return values
    }
    private func readUnlocked(_ command:ReadCommand)async throws->Value {try command.decode(await exchange(command.message,reply:command.replyAddress))}
    private func editUnlocked(_ command:EditCommand)async throws->OSCMessage {try await exchange(command.message,reply:"/status")}
    public func read(_ command:ReadCommand)async throws->Value {await acquire();defer{release()};return try await readUnlocked(command)}
    public func event(timeout:Double=5)async throws->OSCMessage {
        guard let socket=updates else{throw ProtocolError.closed};let origin=connectionID;let deadline=Date().addingTimeInterval(timeout)
        while deadline.timeIntervalSinceNow>0 {
            let frame=try await socket.frame(timeout:deadline.timeIntervalSinceNow)
            if frame.flags&4 != 0 || frame.more || frame.payload.isEmpty {continue}
            guard origin==connectionID else{throw ProtocolError.closed}
            let message=try OSCMessage.decode(frame.payload)
            if let update=MatrixAttachedOutput.decode(message) {panelRevision &+= 1;panelReceipts[update.output]=panelRevision}
            if let update=MatrixConsoleUpdate.decode(message) {
                matrixRevision &+= 1;consoleLive[update.key]=update;consoleReceipts[update.key]=matrixRevision;consoleLastMIDI[update.key]=nil
            }
            if let update=MatrixGuitarUpdate.decode(message) {
                matrixRevision &+= 1;matrixLive[update.output]=update;matrixReceipt[update.output]=matrixRevision;matrixLastMIDI[update.output]=nil
            }
            if let update=GlobalEQUpdate.decode(message) {
                // Correlate our own echoes by request ID AND exact native bytes,
                // then pin their observed source. Delayed copies must not rewind
                // newer acknowledged live state; other sources still apply.
                if let source=message.values[0].integer,let request=message.values[1].integer,let id=Int32(exactly:request),let blob=message.values[2].data,eqReceipts[id]==blob {
                    if eqEchoSource==nil {eqEchoSource=source}
                    if eqEchoSource==source {return message}
                }
                if case .sync(let value)=update,let state=try? GlobalEQState(value:value),eqCommitHistory.contains(where:{$0.sameSettings(state)}),eqShadow?.sameSettings(state)==false {return message}
                eqRevision &+= 1
                if case .sync(let value)=update {eqLastRead=try GlobalEQState(value:value,origin:connectionID)}
                if let current=eqShadow {eqShadow=try update.applying(to:current)}
                else {
                    // EQ can change while Home is open, before its first full read.
                    // Coalesce the finite typed property set instead of accumulating gestures.
                    if case .sync=update {eqPending=[]}
                    if case .output(let output,.replace)=update {eqPending.removeAll{if case .output(let prior,_ )=$0 {return prior==output};return false}}
                    eqPending.removeAll{$0.pendingKey==update.pendingKey};eqPending.append(update)
                }
            }
            if case .selection(let path,let position)=StadiumLiveUpdate.decode(message),let id=message.values[1].integer,let key=Int32(exactly:id) {
                if selectionReceipts.count>=64 {selectionReceipts.removeAll()}
                selectionReceipts[key]=StadiumBlockFocus(path:path,position:position)
            }
            return message
        };throw ProtocolError.timeout
    }
    /// Selection is transient UI state. Firmware emits /setSelectedBlock instead of /status.
    /// The live event reader remains active while this FIFO transaction awaits its echo.
    public func selectBlock(context:EditContext)async throws->DeviceSnapshot {
        await acquire();defer{release()};try Task.checkCancellation()
        let origin=connectionID,before=try await snapshotUnlocked();_ = try verify(context,in:before)
        guard let socket=commands else{throw ProtocolError.closed}
        let id=nextID;nextID = nextID==Int32.max ? 1:nextID+1;selectionReceipts[id]=nil
        try await socket.send(Frame(payload:try EditCommand.selection(context).message(id:id).encode()).encode())
        let deadline=Date().addingTimeInterval(3)
        while Date()<deadline {
            try Task.checkCancellation();guard connectionID==origin,commands != nil else{throw ProtocolError.closed}
            if let receipt=selectionReceipts.removeValue(forKey:id),receipt.path==context.path,receipt.position==context.position {
                let after=try await snapshotUnlocked(product:before.product);_ = try verify(context,in:after);return after
            }
            try await Task.sleep(for:.milliseconds(20))
        }
        throw ProtocolError.invalid("Block selection was not confirmed. Nothing was retried or saved.")
    }
    public func snapshot(product:Value?=nil)async throws->DeviceSnapshot {await acquire();defer{release()};return try await snapshotUnlocked(product:product)}
    private func snapshotUnlocked(product:Value?=nil)async throws->DeviceSnapshot {
        let result=try await (batchSnapshotReads ? batchedSnapshotUnlocked(product:product):sequentialSnapshotUnlocked(product:product))
        if let id=result.presetID {snapshotHeader=(id,result.product)}
        return result
    }
    private func batchedSnapshotUnlocked(product:Value?=nil)async throws->DeviceSnapshot {
        var productValue=product
        for _ in 0..<3 {
            if let header=snapshotHeader {
                // The cached ID only addresses a FRESH content-reference read.
                // Identity, native bytes, dirty flag and trailing identity are
                // still read every time. No cached tone data authorizes edits.
                let body=try await readBatchUnlocked([.activePreset,.activeSnapshot,.editBufferBytes,.contentRef(header.id),.dirty])
                let after=try await readBatchUnlocked([.activeSnapshot,.activePreset])
                if body[0]["val_"].integer==header.id,after[1]["val_"].integer==header.id,body[1]==after[0] {
                    guard let raw=body[2].data,body[3]["cid_"].integer==header.id,let dirty=body[4]["val_"].boolean else{throw ProtocolError.invalid("Incomplete native state read.")}
                    return DeviceSnapshot(product:productValue ?? header.product,editBuffer:try MessagePack.decode(raw),preset:body[3],activeSnapshot:after[0].integer ?? 0,rawEditBuffer:raw,dirty:dirty,origin:connectionID)
                }
                snapshotHeader=nil // A preset change uses the general discovery path.
            }
            let before=try await readBatchUnlocked(productValue == nil ? [.activePreset,.activeSnapshot,.product]:[.activePreset,.activeSnapshot])
            if productValue == nil {productValue=before[2]}
            guard let id=before[0]["val_"].integer,let productValue else{throw ProtocolError.invalid("Missing active preset reference.")}
            let body=try await readBatchUnlocked([.editBufferBytes,.contentRef(id),.dirty])
            guard let raw=body[0].data else{throw ProtocolError.invalid("Missing edit buffer.")}
            let edit=try MessagePack.decode(raw)
            let after=try await readBatchUnlocked([.activeSnapshot,.activePreset])
            guard let edited=body[2]["val_"].boolean else{throw ProtocolError.invalid("Could not verify unsaved changes.")}
            if after[1]["val_"].integer==id,after[0]==before[1] {
                return DeviceSnapshot(product:productValue,editBuffer:edit,preset:body[1],activeSnapshot:after[0].integer ?? 0,rawEditBuffer:raw,dirty:edited,origin:connectionID)
            }
        }
        throw ProtocolError.invalid("The preset changed during reading. Try again.")
    }
    private func sequentialSnapshotUnlocked(product:Value?=nil)async throws->DeviceSnapshot {
        let productValue:Value
        if let product {productValue=product}else{productValue=try await readUnlocked(.product)}
        for _ in 0..<3 {
            let before=try await readUnlocked(.activePreset),beforeSnapshot=try await readUnlocked(.activeSnapshot)
            guard let id=before["val_"].integer else{throw ProtocolError.invalid("Missing active preset reference.")}
            guard let raw=try await readUnlocked(.editBufferBytes).data else{throw ProtocolError.invalid("Missing edit buffer.")}
            let edit=try MessagePack.decode(raw),preset=try await readUnlocked(.contentRef(id)),index=try await readUnlocked(.activeSnapshot),dirty=try await readUnlocked(.dirty)
            let after=try await readUnlocked(.activePreset)
            guard let edited=dirty["val_"].boolean else{throw ProtocolError.invalid("Could not verify unsaved changes.")}
            if after["val_"].integer==id,index==beforeSnapshot {return DeviceSnapshot(product:productValue,editBuffer:edit,preset:preset,activeSnapshot:index.integer ?? 0,rawEditBuffer:raw,dirty:edited,origin:connectionID)}
        };throw ProtocolError.invalid("The preset changed during reading. Try again.")
    }
    #if DEBUG
    /// Read-only timing check; validates both guarded reads before opting in.
    public func benchmarkSnapshotReads()async throws->[String:Double] {
        await acquire();defer{release()}
        let product=try await readUnlocked(.product)
        var sequential=0.0,batched=0.0
        for _ in 0..<2 {
            let start=Date();let before=try await sequentialSnapshotUnlocked(product:product)
            sequential += Date().timeIntervalSince(start)*1000
            let next=Date();let after=try await batchedSnapshotUnlocked(product:product)
            batched += Date().timeIntervalSince(next)*1000
            guard before.presetID==after.presetID,before.activeSnapshot==after.activeSnapshot,before.rawEditBuffer==after.rawEditBuffer,before.dirty==after.dirty else{throw ProtocolError.invalid("The preset changed during the read-only timing check.")}
        }
        batchSnapshotReads=true
        return ["sequentialMilliseconds":sequential/2,"batchedMilliseconds":batched/2]
    }
    #endif
    private func verify(_ context:EditContext,in state:DeviceSnapshot)throws->SignalBlock {
        try context.validate()
        guard context.origin==connectionID,state.presetID==context.presetID,state.activeSnapshot==context.snapshot,let block=state.blocks.first(where:{$0.path-1==context.path && $0.blockID==context.blockID && $0.position==context.position && $0.slot==context.slot}),block.model==context.modelID else{throw ProtocolError.invalid("The preset, snapshot or block changed. Close and reopen this editor.")};return block
    }
    private func confirmIdentity(_ state:DeviceSnapshot)async throws {
        if batchSnapshotReads {
            let identity=try await readBatchUnlocked([.activePreset,.activeSnapshot])
            guard let id=state.presetID,identity[0]["val_"].integer==id,identity[1].integer==state.activeSnapshot else{throw ProtocolError.invalid("The active preset or snapshot changed. Nothing further was sent.")}
            return
        }
        guard let id=state.presetID,try await readUnlocked(.activePreset)["val_"].integer==id,try await readUnlocked(.activeSnapshot).integer==state.activeSnapshot else{throw ProtocolError.invalid("The active preset or snapshot changed. Nothing further was sent.")}
    }
    private func backup(_ state:DeviceSnapshot,to backups:PresetBackupStore)async throws {
        let id=state.preset["rcid"].integer ?? state.presetID
        guard let id,let bytes=try await readUnlocked(.contentData(id)).data else{throw ProtocolError.invalid("The saved preset could not be backed up.")}
        try await backups.retain(contentID:id,name:state.presetName,data:bytes)
        try await backups.retain(contentID:id,name:state.presetName+" (live)",data:state.rawEditBuffer)
    }
    public func setParameter(context:EditContext,definition:ParameterDefinition,value:Value,expected:Value,backups:PresetBackupStore)async throws->DeviceSnapshot {
        let wire=try definition.validated(value);await acquire();defer{release()};try Task.checkCancellation()
        let before=try await snapshotUnlocked(),block=try verify(context,in:before)
        guard let old=block.value(definition),sameParameterValue(old,expected) else{throw ProtocolError.invalid("This parameter changed elsewhere. Refresh before editing it.")}
        try await backup(before,to:backups);try await confirmIdentity(before)
        try EditCommand.acknowledge(await editUnlocked(.parameter(context,definition,wire)))
        let after=try await snapshotUnlocked(product:before.product),changed=try verify(context,in:after)
        guard let received=changed.value(definition),sameParameterValue(received,wire) else{throw ProtocolError.invalid("The Stadium did not confirm the requested value. Check the current value before retrying.")}
        return after
    }
    /// One FIFO transaction for a Focus gesture. Validate the whole batch before
    /// any write, preserve starting bytes, apply discrete switches first, and
    /// stop on any uncertainty. No automatic save or retry.
    public func setParameters(context:EditContext,changes:[ParameterChange],backups:PresetBackupStore)async throws->DeviceSnapshot {
        guard !changes.isEmpty,changes.count<=128,Set(changes.map{$0.definition.identity}).count==changes.count else{throw ProtocolError.invalid("Invalid parameter batch.")}
        let wires=try changes.map{try $0.definition.validated($0.value)}
        await acquire();defer{release()};try Task.checkCancellation()
        let before=try await snapshotUnlocked(),block=try verify(context,in:before)
        for change in changes {
            guard let old=block.value(change.definition),sameParameterValue(old,change.expected) else{throw ProtocolError.invalid("The tone changed elsewhere. Reopen Focus View before adjusting it.")}
        }
        let indices=changes.indices.filter{!sameParameterValue(changes[$0].expected,wires[$0])}.sorted {a,b in
            let af=changes[a].definition.type=="f",bf=changes[b].definition.type=="f"
            return af==bf ? a<b:!af
        }
        if indices.isEmpty {return before}
        try await backup(before,to:backups)
        for (offset,index) in indices.enumerated() {
            try Task.checkCancellation()
            if offset%4==0 {_ = try verify(context,in:await snapshotUnlocked(product:before.product))}
            try await confirmIdentity(before)
            try EditCommand.acknowledge(await editUnlocked(.parameter(context,changes[index].definition,wires[index])))
        }
        let after=try await snapshotUnlocked(product:before.product),actual=try verify(context,in:after)
        guard changes.indices.allSatisfy({index in actual.value(changes[index].definition).map{sameParameterValue($0,wires[index])}==true}) else{throw ProtocolError.invalid("Not every Focus value was confirmed. Check the current tone before retrying.")}
        return after
    }
    public func savePreset(expectedID:Int,backups:PresetBackupStore)async throws->DeviceSnapshot {
        await acquire();defer{release()};try Task.checkCancellation()
        let before=try await snapshotUnlocked()
        guard before.presetID==expectedID,before.location.writable else{throw ProtocolError.invalid("Save is available only for the current User preset. Save a copy for Factory presets.")}
        try await backup(before,to:backups);try await confirmIdentity(before)
        try EditCommand.acknowledge(await editUnlocked(.save(expectedID)))
        for attempt in 0..<8 {
            let after=try await snapshotUnlocked(product:before.product)
            guard after.presetID==expectedID,after.activeSnapshot==before.activeSnapshot else{throw ProtocolError.invalid("The active preset changed before saving was confirmed.")}
            if !after.dirty {
                guard let bytes=try await readUnlocked(.contentData(expectedID)).data else{throw ProtocolError.invalid("The saved preset could not be read back.")}
                let stored=DeviceSnapshot(product:before.product,editBuffer:try MessagePack.decode(bytes),preset:before.preset,activeSnapshot:before.activeSnapshot)
                guard stored.blocks.count==after.blocks.count,stored.snapshots==after.snapshots else{throw ProtocolError.invalid("The saved signal chain has not been verified.")}
                for block in after.blocks {
                    guard let saved=stored.blocks.first(where:{$0.id==block.id && $0.blockID==block.blockID && $0.model==block.model}),saved.enabled==block.enabled,saved.values.count==block.values.count,saved.harnessValues.count==block.harnessValues.count,block.values.allSatisfy({sameParameterValue($0.value,saved.values[$0.key] ?? .null)}),block.harnessValues.allSatisfy({sameParameterValue($0.value,saved.harnessValues[$0.key] ?? .null)}) else{throw ProtocolError.invalid("Some saved parameter values have not been confirmed. Check the device before leaving this preset.")}
                }
                try await confirmIdentity(after);return after
            }
            if attempt<7 {try await Task.sleep(for:.milliseconds(250))}
        };throw ProtocolError.invalid("The Stadium still reports unsaved changes. Saving was not confirmed.")
    }
    public func replaceModel(context:EditContext,source:ModelDefinition,destination:ModelDefinition,backups:PresetBackupStore)async throws->DeviceSnapshot {
        await acquire();defer{release()};try Task.checkCancellation()
        let before=try await snapshotUnlocked();_ = try verify(context,in:before)
        guard source.id==context.modelID else{throw ProtocolError.invalid("The selected model changed.")}
        let output=context.position%14==13
        if output {
            guard source.ioRole=="outputs",destination.ioRole=="outputs",!(context.path==1 && [779,784,788].contains(destination.id)) else{throw ProtocolError.invalid("Choose an output destination for this block.")}
        } else {
            guard (1...12).contains(context.position%14),source.ioRole==nil,!["split","join"].contains(source.category ?? ""),destination.replaceable,source.isCab==destination.isCab else{throw ProtocolError.invalid("This model cannot replace the selected block. Cab models stay in cab slots; input and routing blocks are separate.")}
        }
        if destination.id==source.id {return before}
        if destination.category=="amp" {
            guard let auto=try await readUnlocked(.autoCab)["val_"].boolean,!auto else{throw ProtocolError.invalid("Turn off Auto Cab on the Stadium before changing to an amp, so another block cannot be added automatically.")}
        }
        try await backup(before,to:backups);try await confirmIdentity(before)
        try EditCommand.acknowledge(await editUnlocked(.model(context,destination.id)))
        for attempt in 0..<8 {
            let after=try await snapshotUnlocked(product:before.product)
            guard after.presetID==before.presetID,after.activeSnapshot==before.activeSnapshot else{throw ProtocolError.invalid("The preset or snapshot changed before replacement was confirmed.")}
            if after.blocks.contains(where:{$0.path-1==context.path && $0.position==context.position && $0.slot==context.slot && $0.model==destination.id}) {
                let unchanged=before.blocks.filter{!($0.path-1==context.path && $0.position==context.position && $0.slot==context.slot)}
                guard after.blocks.count==before.blocks.count,unchanged.allSatisfy({old in after.blocks.contains(where:{$0.id==old.id && $0.model==old.model && $0.values==old.values && $0.harnessValues==old.harnessValues && $0.enabled==old.enabled})}) else{throw ProtocolError.invalid("The model changed, but other block changes were detected. Inspect the signal chain before saving.")}
                return after
            }
            if attempt<7 {try await Task.sleep(for:.milliseconds(150))}
        }
        throw ProtocolError.invalid("The requested model was not confirmed. No retry was sent.")
    }
    private func sendOnly(_ command:EditCommand)async throws {
        guard let socket=commands else{throw ProtocolError.closed}
        let id=nextID;nextID = nextID==Int32.max ? 1:nextID+1
        try await socket.send(Frame(payload:try command.message(id:id).encode()).encode())
    }
    public func activateSnapshot(_ index:Int,expectedID:Int,expectedSnapshot:Int,backups:PresetBackupStore)async throws->DeviceSnapshot {
        await acquire();defer{release()};try Task.checkCancellation()
        let before=try await snapshotUnlocked()
        guard before.presetID==expectedID,before.activeSnapshot==expectedSnapshot,before.snapshots.contains(where:{$0.id==index && $0.defined}) else{throw ProtocolError.invalid("The preset or snapshot changed, or this snapshot is empty.")}
        if index==before.activeSnapshot {return before}
        try await backup(before,to:backups);try await confirmIdentity(before)
        try await sendOnly(.snapshot(index))
        for _ in 0..<12 {
            let after=try await snapshotUnlocked(product:before.product)
            guard after.presetID==expectedID else{throw ProtocolError.invalid("The preset changed during snapshot selection.")}
            if after.activeSnapshot==index {return after}
            try await Task.sleep(for:.milliseconds(150))
        }
        throw ProtocolError.invalid("Snapshot selection was not confirmed. No retry was sent.")
    }
    public func createSnapshot(_ target:Int,expectedID:Int,expectedSnapshot:Int,backups:PresetBackupStore)async throws->DeviceSnapshot {
        await acquire();defer{release()};let before=try await snapshotUnlocked()
        guard before.presetID==expectedID,before.activeSnapshot==expectedSnapshot,before.snapshots.contains(where:{$0.id==expectedSnapshot && $0.defined}),before.snapshots.contains(where:{$0.id==target && !$0.defined}) else{throw ProtocolError.invalid("Only an empty scene can be created. Refresh before trying again.")}
        try await backup(before,to:backups);try await confirmIdentity(before)
        try EditCommand.acknowledge(await editUnlocked(.copySnapshot(expectedSnapshot,target)))
        for _ in 0..<8 {
            let after=try await snapshotUnlocked(product:before.product)
            guard after.presetID==expectedID,after.activeSnapshot==expectedSnapshot else{throw ProtocolError.invalid("The preset or scene changed during creation.")}
            if after.snapshots.contains(where:{$0.id==target && $0.defined}) {return after}
            try await Task.sleep(for:.milliseconds(150))
        }
        throw ProtocolError.invalid("Scene creation was not confirmed. No retry was sent.")
    }
    public func reorderBlock(context:EditContext,to:Int,models:[Int:ModelDefinition],backups:PresetBackupStore)async throws->DeviceSnapshot {
        await acquire();defer{release()};try Task.checkCancellation()
        let before=try await snapshotUnlocked();_ = try verify(context,in:before)
        let plan=try BlockReorderPlan(state:before,context:context,to:to,models:models)
        try await backup(before,to:backups);try await confirmIdentity(before)
        try EditCommand.acknowledgeAgenda(await editUnlocked(.reorder(flow:plan.flow,from:plan.from,to:plan.to)))
        for _ in 0..<8 {
            let after=try await snapshotUnlocked(product:before.product)
            guard after.presetID==before.presetID,after.activeSnapshot==before.activeSnapshot else{throw ProtocolError.invalid("The preset or scene changed during the move. Nothing was retried.")}
            if plan.matches(after) {return after}
            try await Task.sleep(for:.milliseconds(150))
        }
        throw ProtocolError.invalid("The reordered blocks or their settings were not confirmed. Check the chain before retrying; no automatic retry or save was sent.")
    }
    /// Explicit tuner open/exit events only. An ACK confirms command acceptance;
    /// this firmware does not expose live note/cents through the known protocol.
    public func setTuner(_ enabled:Bool)async throws {
        await acquire();defer{release()};try Task.checkCancellation()
        try EditCommand.acknowledge(await editUnlocked(.tuner(enabled)))
    }
    public func pressStomp(_ plan:StompPlan,backups:PresetBackupStore)async throws->DeviceSnapshot {
        await acquire();defer{release()};try Task.checkCancellation()
        func validate(_ state:DeviceSnapshot)throws->StompPlan {
            guard plan.origin==connectionID,state.presetID==plan.presetID,state.activeSnapshot==plan.snapshot,let current=StompAssignment.read(state,bank:plan.bank,number:plan.number).plan,current.sourceID==plan.sourceID,current.fingerprint==plan.fingerprint else{throw ProtocolError.invalid("The preset, scene or footswitch assignments changed. Refresh before pressing it.")}
            return current
        }
        let before=try await snapshotUnlocked(),current=try validate(before)
        guard current.input==plan.input,current.controllers==plan.controllers else{throw ProtocolError.invalid("The switch values changed elsewhere. Check the current state before pressing it.")}
        try await backup(before,to:backups);var confirmed=0;var after=before
        do {
            for controller in plan.controllers {
                let fresh=try await snapshotUnlocked(product:before.product);_ = try validate(fresh)
                guard let old=controller.target.value(in:fresh),sameParameterValue(old,controller.current) else{throw ProtocolError.invalid("An assigned value changed elsewhere.")}
                try await confirmIdentity(fresh)
                try EditCommand.acknowledge(await editUnlocked(.controller(controller.id,plan.input)))
                after=try await snapshotUnlocked(product:before.product);_ = try validate(after)
                let wanted=plan.input==1 ? controller.high:controller.low
                guard let actual=controller.target.value(in:after),sameParameterValue(actual,wanted) else{throw ProtocolError.invalid("An assigned effect did not confirm its new value.")}
                confirmed+=1
            }
            for controller in plan.controllers {
                guard let actual=controller.target.value(in:after),sameParameterValue(actual,plan.input==1 ? controller.high:controller.low) else{throw ProtocolError.invalid("An assigned effect changed before the switch completed.")}
            }
            return after
        } catch {throw ProtocolError.invalid("\(confirmed) of \(plan.controllers.count) assigned actions confirmed. \(error.localizedDescription) Nothing was retried.")}
    }
    public func presetLibrary(container:Int)async throws->[PresetSlot] {await acquire();defer{release()};return try await readUnlocked(.container(container)).items.map(PresetSlot.init)}
    public func userPresets()async throws->[PresetSlot] {await acquire();defer{release()};return try await readUnlocked(.container(-2)).items.map(PresetSlot.init)}
    public func copyCurrent(name:String,expectedID:Int,backups:PresetBackupStore)async throws->PreservedPreset {
        let name=try EditCommand.validName(name);await acquire();defer{release()};try Task.checkCancellation()
        let state=try await snapshotUnlocked()
        guard state.presetID==expectedID else{throw ProtocolError.invalid("The preset changed before copying.")}
        try await backup(state,to:backups)
        let slots=try await readUnlocked(.container(-2)).items.map(PresetSlot.init)
        guard let position=slots.filter(\.empty).compactMap(\.position).min() else{throw ProtocolError.invalid("No empty User preset locations are available.")}
        let fresh=try await readUnlocked(.container(-2)).items.map(PresetSlot.init)
        guard fresh.contains(where:{$0.position==position && $0.empty}) else{throw ProtocolError.invalid("The chosen location is no longer empty.")}
        try await confirmIdentity(state)
        let id=try EditCommand.allocatedID(await editUnlocked(.createUser(position:position,name:name)))
        guard id != expectedID,id != state.preset["rcid"].integer else{throw ProtocolError.invalid("The Stadium did not allocate an independent preset.")}
        let reference=try await readUnlocked(.contentRef(id)),slot=PresetSlot(reference)
        guard slot.writable,slot.position==position,slot.contentID==id,slot.name==name else{throw ProtocolError.invalid("The new preset location was not verified. Check the User library before retrying.")}
        allocated.insert(id)
        try await storeNew(id,bytes:state.rawEditBuffer)
        return PreservedPreset(preset:slot,sourceID:expectedID,sourceSnapshot:state.activeSnapshot,sourceHash:PresetBackupStore.hash(state.rawEditBuffer))
    }
    private func storeNew(_ id:Int,bytes:Data)async throws {
        guard allocated.contains(id) else{throw ProtocolError.invalid("Only a newly allocated preset can receive copied data.")}
        try EditCommand.acknowledge(await editUnlocked(.storeNewPreset(id,bytes)))
        guard try await readUnlocked(.contentData(id)).data==bytes else{throw ProtocolError.invalid("The new copy's stored contents were not verified. Check the User library before retrying.")}
    }
    public func openPreservedCopy(_ copy:PreservedPreset)async throws->DeviceSnapshot {
        await acquire();defer{release()}
        let current=try await snapshotUnlocked()
        guard current.presetID==copy.sourceID,current.activeSnapshot==copy.sourceSnapshot,PresetBackupStore.hash(current.rawEditBuffer)==copy.sourceHash,let id=copy.preset.contentID,try await readUnlocked(.contentData(id)).data.map(PresetBackupStore.hash)==copy.sourceHash else{throw ProtocolError.invalid("The source changed after copying. The copy is saved, but your current preset was left open.")}
        try await loadUnlocked(id);return try await snapshotUnlocked(product:current.product)
    }
    public func loadPreset(_ id:Int,expectedID:Int,discardingChangesWith backups:PresetBackupStore?=nil)async throws->DeviceSnapshot {
        await acquire();defer{release()};try Task.checkCancellation()
        let current=try await snapshotUnlocked()
        guard current.presetID==expectedID else{throw ProtocolError.invalid("The active preset changed. Select the preset again.")}
        if let backups {
            // Explicit user selection means discard. Keep both saved and live
            // bytes locally, including edits the device dirty flag may omit.
            try await backup(current,to:backups)
        } else {
            guard !current.dirty else{throw ProtocolError.invalid("Save the current changes or save a copy before opening another preset.")}
        }
        try await confirmIdentity(current)
        try await loadUnlocked(id)
        let after=try await snapshotUnlocked(product:current.product)
        guard after.presetID==id else{throw ProtocolError.invalid("The selected preset was not confirmed as active.")}
        return after
    }
    private func loadUnlocked(_ id:Int)async throws {
        let ref=PresetSlot(try await readUnlocked(.contentRef(id)))
        guard ref.contentID==id,ref.type==2 else{throw ProtocolError.invalid("This preset is unavailable.")}
        try EditCommand.acknowledge(await editUnlocked(.load(id)))
        for _ in 0..<12 {if try await readUnlocked(.activePreset)["val_"].integer==id {return};try await Task.sleep(for:.milliseconds(150))}
        throw ProtocolError.invalid("The new preset was not confirmed as active.")
    }
}

extension StadiumSession {
    /// Ascend the real folder records; a positive number alone never grants access.
    @discardableResult private func verifyUserCloneFolder(_ id:Int)async throws->Int {
        var current=id;var visited:Set<Int>=[]
        for _ in 0..<8 {
            if [-22,-23,-24,-25].contains(current) {return current}
            guard current>0,visited.insert(current).inserted else{break}
            let row=try await readUnlocked(.contentRef(current))
            guard row["type"].integer==1002,CloneLibraryCommand.userEditable(row),let parent=row["ccid"].integer else{break}
            current=parent
        }
        throw ProtocolError.invalid("Choose a folder inside User Clones.")
    }
    public func createCloneFolder(parent:Int,name:String)async throws->Value {
        await acquire();defer{release()};try await verifyUserCloneFolder(parent)
        let clean=try CloneLibraryCommand.name(name),before=try await readUnlocked(.container(parent))
        guard !before.items.contains(where:{$0["name"].text?.localizedCaseInsensitiveCompare(clean) == .orderedSame}) else{throw ProtocolError.invalid("This clone folder already contains that name.")}
        let position=(before.items.compactMap{$0["posi"].integer}.max() ?? -1)+1
        let response=try await exchange(CloneLibraryCommand.createFolder(parent:parent,position:position,name:clean).message,reply:"/status")
        let id=try EditCommand.allocatedID(response)
        let after=try await readUnlocked(.container(parent))
        guard let created=after.items.first(where:{$0["cid_"].integer==id}),created["type"].integer==1002,created["ownr"].integer==1,created["name"].text==clean,created["ccid"].integer==parent else{throw ProtocolError.invalid("Folder creation was not confirmed. Refresh before trying again.")}
        return created
    }
    public func changeClone(id:Int,parent:Int,uuid:String?,expectedName:String,newName:String?=nil,remove:Bool=false)async throws->Value {
        guard id>0 else{throw ProtocolError.invalid("Built-in clone folders cannot be modified.")}
        await acquire();defer{release()};try await verifyUserCloneFolder(parent)
        let before=try await readUnlocked(.contentRef(id))
        guard before["ccid"].integer==parent,CloneLibraryCommand.userEditable(before),before["name"].text==expectedName,let type=before["type"].integer,[11,1002].contains(type),type != 11 || before["cluid"].text==uuid else{throw ProtocolError.invalid("The selected clone or folder changed. Refresh before continuing.")}
        if remove {
            if type==1002 {guard try await readUnlocked(.container(id)).items.isEmpty else{throw ProtocolError.invalid("Only empty clone folders can be deleted.")}}
            try EditCommand.acknowledge(await exchange(CloneLibraryCommand.remove(parent:parent,id:id).message,reply:"/status"))
            let after=try await readUnlocked(.container(parent))
            guard !after.items.contains(where:{$0["cid_"].integer==id}) else{throw ProtocolError.invalid("Deletion was not confirmed. Nothing was retried.")}
            return .object(["removed":.int(Int64(id))])
        }
        guard let newName else{throw ProtocolError.invalid("Enter the clone name.")}
        let clean=try CloneLibraryCommand.name(newName),siblings=try await readUnlocked(.container(parent))
        guard !siblings.items.contains(where:{$0["cid_"].integer != id && $0["name"].text?.localizedCaseInsensitiveCompare(clean) == .orderedSame}) else{throw ProtocolError.invalid("This folder already contains that name.")}
        try EditCommand.acknowledge(await exchange(CloneLibraryCommand.rename(id:id,attributes:before,name:clean).message,reply:"/status"))
        let after=try await readUnlocked(.contentRef(id))
        var intended=before.object;intended["name"] = .string(clean)
        guard after == .object(intended) else{throw ProtocolError.invalid("The renamed clone/folder was not fully confirmed. Check the library before continuing.")}
        return after
    }
}

extension StadiumSession {
    public func prepareCloneExport(id:Int,uuid:String,expectedName:String)async throws->Value {
        guard id>0,UUID(uuidString:uuid)?.uuidString.lowercased()==uuid else{throw ProtocolError.invalid("Invalid clone export identity.")}
        await acquire();defer{release()};let origin=connectionID
        let before=try await readUnlocked(.contentRef(id))
        guard before["type"].integer==11,CloneLibraryCommand.userEditable(before),before["cluid"].text==uuid,before["name"].text==expectedName,let parent=before["ccid"].integer else{throw ProtocolError.invalid("The clone changed before export.")}
        try await verifyUserCloneFolder(parent)
        guard let socket=commands else{throw ProtocolError.closed}
        let commandID=nextID;nextID = nextID==Int32.max ? 1:nextID+1
        try await socket.send(Frame(payload:try OSCMessage("/ExportCloneArchive",[.int(Int64(commandID)),.int(Int64(id))]).encode()).encode())
        let deadline=Date().addingTimeInterval(15)
        while Date()<deadline {
            let event=try await self.event(timeout:max(0.1,deadline.timeIntervalSinceNow))
            guard origin==connectionID else{throw ProtocolError.closed}
            guard event.address=="/cloneArchiveExportReady",event.values.count==6,event.values[2].integer==id else{continue}
            let path="/data/stadium-family-fw/proxy/exports/"+uuid+".clone"
            guard event.values[3].text==path,event.values[4].text==uuid+".clone",let size=event.values[5].integer,size>24,size<=8*1024*1024,try await readUnlocked(.contentRef(id))==before else{throw ProtocolError.invalid("The Stadium did not confirm the requested clone archive.")}
            return .object(["path":.string(path),"size":.int(Int64(size))])
        }
        throw ProtocolError.invalid("Clone export was not confirmed. Nothing was retried.")
    }
}


extension StadiumSession {
    public func moveClone(id:Int,parent:Int,uuid:String,expectedName:String,destination:Int)async throws->Value {
        await acquire();defer{release()}
        guard id>0,parent != destination else{throw ProtocolError.invalid("Choose a different clone folder.")}
        let sourceCategory=try await verifyUserCloneFolder(parent),targetCategory=try await verifyUserCloneFolder(destination)
        guard sourceCategory==targetCategory else{throw ProtocolError.invalid("Clones can only move within their own Amp, Amp+Cab, Preamp or Distortion category.")}
        let before=try await readUnlocked(.contentRef(id)),contents=try await readUnlocked(.container(destination))
        guard before["type"].integer==11,CloneLibraryCommand.userEditable(before),before["ccid"].integer==parent,before["cluid"].text==uuid,before["name"].text==expectedName else{throw ProtocolError.invalid("The selected clone changed before moving.")}
        guard !contents.items.contains(where:{$0["name"].text?.localizedCaseInsensitiveCompare(expectedName) == .orderedSame}) else{throw ProtocolError.invalid("The destination already has a clone with this name.")}
        let position=(contents.items.compactMap{$0["posi"].integer}.max() ?? -1)+1
        try EditCommand.acknowledge(await exchange(CloneLibraryCommand.move(id:id,parent:destination,position:position).message,reply:"/status"))
        let after=try await readUnlocked(.contentRef(id)),remaining=try await readUnlocked(.container(parent))
        var intended=before.object;intended["ccid"] = .int(Int64(destination));intended["posi"] = .int(Int64(position))
        guard after == .object(intended),!remaining.items.contains(where:{$0["cid_"].integer==id}) else{throw ProtocolError.invalid("The clone move was not confirmed. Refresh before trying again.")}
        return after
    }
}

extension StadiumSession {
    /// One FIFO command assignment transaction: fresh identity/config, backup, one write,
    /// independent full-state readback. No command is executed and no preset is saved.
    public func editCommand(context:CommandContext,operation:CommandCenterOperation,backups:PresetBackupStore)async throws->DeviceSnapshot {
        await acquire();defer{release()};try Task.checkCancellation()
        let before=try await snapshotUnlocked(),fresh=try CommandContext(state:before,source:context.source,slot:context.slot)
        guard context.origin==connectionID,fresh==context else{let changed=context.origin != connectionID ? "connection":fresh.presetID != context.presetID ? "preset":fresh.snapshot != context.snapshot ? "snapshot":fresh.sourceRow != context.sourceRow ? "source":fresh.command != context.command ? "command":"context";throw ProtocolError.invalid("The \(changed) changed. Refresh Command Center before editing.")}
        if let config=context.source.externalConfiguration {
            let properties=try await readUnlocked(.commandProperties)
            guard properties["vals"].items.first(where:{$0["key_"].text==config.key})?["val_"].integer==config.value else{throw ProtocolError.invalid("This external jack is configured differently. Refresh its source before editing.")}
        }
        _ = try operation.message(context:context,id:1)
        try await backup(before,to:backups);try await confirmIdentity(before)
        let address:String
        switch operation {case .family(.none):address="/removeCommand";case .family where context.commandID==nil:address="/attachCommandWithType";case .paste:address="/attachCommandWithType";default:address="/status"}
        let response=try await exchange({try operation.message(context:context,id:$0)},reply:address)
        var allocated:Int?
        if address=="/attachCommandWithType" {
            guard response.values.count==3,let command=response.values[1].integer,command>0,command<=Int(Int32.max),let echoed=response.values[2].integer,echoed==command else{throw ProtocolError.invalid("Command allocation was not confirmed. Nothing was retried.")};allocated=command
        }else if address=="/removeCommand" {
            guard response.values.count==3,response.values[1].integer==context.commandID,response.values[2].integer==0 else{throw ProtocolError.invalid("Command removal was not confirmed.")}
        }else {try EditCommand.acknowledge(response)}
        let after=try await snapshotUnlocked(product:before.product),result=try CommandContext(state:after,source:context.source,slot:context.slot)
        guard after.presetID==before.presetID,after.activeSnapshot==before.activeSnapshot else{throw ProtocolError.invalid("The active preset or snapshot changed during command editing.")}
        guard before.editBuffer["sfg_"]==after.editBuffer["sfg_"],before.editBuffer["dvcp"]==after.editBuffer["dvcp"],before.editBuffer["pm__"]==after.editBuffer["pm__"] else{throw ProtocolError.invalid("Other preset settings changed during command editing. Review the pedal; no retry or Save was sent.")}
        let oldEntities=before.editBuffer["cg__"]["entt"],newEntities=after.editBuffer["cg__"]["entt"]
        guard oldEntities["ctrl"]==newEntities["ctrl"] else{throw ProtocolError.invalid("Effect controller assignments changed during command editing.")}
        let changedIDs=Set([context.commandID,result.commandID].compactMap{$0}),oldTarget=context.command["tid_"].integer
        for old in oldEntities["cmnd"].items where !changedIDs.contains(old["cid_"].integer ?? -1) {guard newEntities["cmnd"].items.contains(where:{$0.object.filter{$0.key != "togl"}==old.object.filter{$0.key != "togl"} || operation.permitsPairedToggle(old:old,new:$0,context:context)}) else{throw ProtocolError.invalid("Another command changed. Review the pedal before continuing.")}}
        for old in oldEntities["srcs"].items {
            if old["id__"]==context.sourceRow["id__"] {
                if result.sourceRow == .null {
                    guard case .family(.none)=operation,old["cmds"].items.enumerated().allSatisfy({$0.offset==context.slot || $0.element.integer == -1}),!oldEntities["ctrl"].items.contains(where:{$0["trig"]==old["id__"]}) else{throw ProtocolError.invalid("An assigned source disappeared unexpectedly.")};continue
                }
                let a=old.object.filter{$0.key != "cmds"},b=result.sourceRow.object.filter{$0.key != "cmds"}
                guard a==b else{throw ProtocolError.invalid("The source configuration changed unexpectedly.")}
                for index in 0..<2 where index != context.slot {guard old["cmds"].items[index]==result.sourceRow["cmds"].items[index] else{throw ProtocolError.invalid("The other command slot changed.")}}
            }else {guard newEntities["srcs"].items.contains(old) else{throw ProtocolError.invalid("Another source changed during command editing.")}}
        }
        for old in oldEntities["trgs"].items where old["id__"].integer != oldTarget {guard newEntities["trgs"].items.contains(old) else{throw ProtocolError.invalid("An unrelated assignment target changed.")}}
        switch operation {
        case .family(let family):guard result.family==family,(allocated==nil || result.commandID==allocated) else{throw ProtocolError.invalid("The command type was not independently confirmed.")}
        case .paste(let family,let definitions,let copied):
            guard result.family==family,result.commandID==allocated,definitions.allSatisfy({sameParameterValue(result.command[$0.valueKey],copied[$0.valueKey])}) else{throw ProtocolError.invalid("The pasted command did not match its original values.")}
        case .parameter(let p,let value):
            guard result.commandID==context.commandID,result.family==context.family,sameParameterValue(result.command[p.valueKey],try p.validated(value)) else{throw ProtocolError.invalid("The command parameter was not confirmed.")}
            let derived:Set<String>=[p.valueKey,p.name=="Action" ? "behv":p.name=="Command" ? "func":p.name=="Curve" ? "curv":p.valueKey]
            guard context.command.object.filter({!derived.contains($0.key) && $0.key != "togl"})==result.command.object.filter({!derived.contains($0.key) && $0.key != "togl"}) else{throw ProtocolError.invalid("Other command values changed. Refresh before editing again.")}
        case .snapshot(let p,let enabled):
            guard result.commandID==context.commandID,result.command[p.snapshotKey].boolean==enabled,context.command.object.filter({$0.key != p.snapshotKey})==result.command.object.filter({$0.key != p.snapshotKey}) else{throw ProtocolError.invalid("Snapshot control was not independently confirmed.")}
        }
        return after
    }
}

extension StadiumSession {
    /// Native Copy All/Paste first clears commands, then attaches each copied source.
    /// Effect controllers remain untouched. A partial/uncertain batch is never replayed.
    public func replaceCommands(expected:DeviceSnapshot,copies:[CommandCopy],backups:PresetBackupStore)async throws->DeviceSnapshot {
        guard copies.count<=96 else{throw ProtocolError.invalid("Too many commands in this layout.")}
        await acquire();defer{release()};try Task.checkCancellation()
        let before=try await snapshotUnlocked()
        guard before.origin==expected.origin,before.presetID==expected.presetID,before.activeSnapshot==expected.activeSnapshot,before.editBuffer["cg__"]==expected.editBuffer["cg__"] else{throw ProtocolError.invalid("The command layout changed. Copy or review it again.")}
        var unique:Set<String>=[]
        for copy in copies {
            let c=try CommandContext(state:before,source:copy.source,slot:copy.slot)
            guard unique.insert(copy.source.id+"-\(copy.slot)").inserted else{throw ProtocolError.invalid("Duplicate copied command slot.")}
            _ = try CommandCenterOperation.paste(copy.family,copy.parameters,copy.command).message(context:c,id:1)
        }
        if copies.contains(where:{$0.source.externalConfiguration != nil}) {
            let properties=try await readUnlocked(.commandProperties)
            for copy in copies {if let config=copy.source.externalConfiguration {guard properties["vals"].items.first(where:{$0["key_"].text==config.key})?["val_"].integer==config.value else{throw ProtocolError.invalid("A copied external control is no longer configured for that source. Nothing was cleared.")}}}
        }
        try await backup(before,to:backups);try await confirmIdentity(before)
        let response=try await exchange({OSCMessage("/removeAllCommands",[.int(Int64($0))])},reply:"/removeAllCommands")
        guard response.values.count==2,response.values[1].integer==0 else{throw ProtocolError.invalid("Command reset was not confirmed. Nothing was retried.")}
        var current=try await snapshotUnlocked(product:before.product)
        guard current.editBuffer["cg__"]["entt"]["cmnd"].items.isEmpty else{throw ProtocolError.invalid("Commands were not cleared. No paste was attempted.")}
        for copy in copies {
            if let config=copy.source.externalConfiguration {
                let properties=try await readUnlocked(.commandProperties)
                guard properties["vals"].items.first(where:{$0["key_"].text==config.key})?["val_"].integer==config.value else{throw ProtocolError.invalid("An external jack changed during paste. The batch stopped; no retry was sent.")}
            }
            try await confirmIdentity(current)
            let c=try CommandContext(state:current,source:copy.source,slot:copy.slot),operation=CommandCenterOperation.paste(copy.family,copy.parameters,copy.command)
            let reply=try await exchange({try operation.message(context:c,id:$0)},reply:"/attachCommandWithType")
            guard reply.values.count==3,let commandID=reply.values[2].integer,commandID>0 else{throw ProtocolError.invalid("Command paste stopped before completion. Review the layout; do not blindly retry.")}
            current=try await snapshotUnlocked(product:before.product)
            let result=try CommandContext(state:current,source:copy.source,slot:copy.slot)
            guard result.commandID==commandID,result.family==copy.family,copy.parameters.allSatisfy({sameParameterValue(copy.command[$0.valueKey],result.command[$0.valueKey])}) else{throw ProtocolError.invalid("A pasted command did not match. No further commands were sent.")}
        }
        let old=before.editBuffer,new=current.editBuffer
        guard before.presetID==current.presetID,before.activeSnapshot==current.activeSnapshot,old["sfg_"]==new["sfg_"],old["dvcp"]==new["dvcp"],old["cg__"]["entt"]["ctrl"]==new["cg__"]["entt"]["ctrl"],new["cg__"]["entt"]["cmnd"].items.count==copies.count else{throw ProtocolError.invalid("Command layout readback changed other settings. Nothing was retried or saved.")}
        return current
    }
}

extension StadiumSession {
    public func setStompAppearance(context:CommandContext,appearance:StompAppearance,backups:PresetBackupStore)async throws->DeviceSnapshot {
        await acquire();defer{release()};try Task.checkCancellation()
        let before=try await snapshotUnlocked()
        guard context.origin==connectionID,try CommandContext(state:before,source:context.source,slot:context.slot)==context else{throw ProtocolError.invalid("The command selection changed. Refresh before changing its label or color.")}
        let (key,value)=try appearance.property(source:context.source)
        if case .label=appearance {
            for slot in 0..<context.source.slots {guard try CommandContext(state:before,source:context.source,slot:slot).family != .presetSnapshot else{throw ProtocolError.invalid("Preset/Snapshot commands label their switch automatically.")}}
        }
        let prior=try await readUnlocked(.stompProperties)
        try await backup(before,to:backups);try await confirmIdentity(before)
        let reply=try await exchange({try appearance.message(source:context.source,id:$0)},reply:"/status");try EditCommand.acknowledge(reply)
        let after=try await snapshotUnlocked(product:before.product),properties=try await readUnlocked(.stompProperties)
        guard after.presetID==before.presetID,after.activeSnapshot==before.activeSnapshot,after.editBuffer["sfg_"]==before.editBuffer["sfg_"],after.editBuffer["cg__"]==before.editBuffer["cg__"],properties["vals"].items.first(where:{$0["key_"].text==key})?["val_"]==value else{throw ProtocolError.invalid("Stomp appearance was not independently confirmed. Nothing was retried or saved.")}
        for row in prior["vals"].items where row["key_"].text != key {guard properties["vals"].items.contains(row) else{throw ProtocolError.invalid("Another switch property changed. Review before saving.")}}
        return after
    }
}

extension StadiumSession {
    private func globalEQUnlocked()async throws->GlobalEQState {
        let revision=eqRevision
        guard let raw=try await readUnlocked(.globalEQBytes).data else{throw ProtocolError.invalid("Missing Global EQ reply.")}
        let envelope=try MessagePack.decode(raw)
        guard envelope["key_"].text=="global.eq.sync",envelope["type"].text=="v" else{throw ProtocolError.invalid("Wrong Global EQ property reply.")}
        let read=try GlobalEQState(value:envelope["val_"],origin:connectionID,raw:raw)
        let staleCommit=eqCommitHistory.contains{$0.sameSettings(read)} && eqShadow?.sameSettings(read)==false
        if eqShadow==nil || (!staleCommit && revision==eqRevision && eqLastRead?.sameSettings(read)==false) {eqShadow=read}
        if eqShadow?.sameSettings(read)==true {eqCommitHistory=[]}
        if revision==eqRevision {eqLastRead=read}
        for update in eqPending {eqShadow=try update.applying(to:eqShadow ?? read)};eqPending=[]
        guard let shadow=eqShadow else{return read}
        return try GlobalEQState(value:shadow.value,origin:connectionID,raw:raw)
    }
    public func globalEQ()async throws->GlobalEQState {await acquire();defer{release()};return try await globalEQUnlocked()}
    public func editGlobalEQ(expected:GlobalEQState,output:EQOutput,operation:GlobalEQOperation,backups:PresetBackupStore)async throws->GlobalEQState {
        let live=try await stageGlobalEQ(expected:expected,output:output,operation:operation,backups:backups)
        guard let confirmed=try await commitGlobalEQ(expected:live) else{throw ProtocolError.invalid("A newer EQ edit superseded this confirmation. Nothing was resent.")}
        return confirmed
    }
    /// Serialize live DSP updates separately from the slower final snapshot check.
    public func stageGlobalEQ(expected:GlobalEQState,output:EQOutput,operation:GlobalEQOperation,backups:PresetBackupStore)async throws->GlobalEQState {
        await acquire();defer{release()};try Task.checkCancellation()
        let before=try await globalEQUnlocked()
        guard expected.origin==connectionID,before.sameSettings(expected) else{throw ProtocolError.invalid("Global EQ changed. Review its current values before editing.")}
        let desired=try operation.applying(to:before,output:output)
        _ = try await backups.retain(contentID:-100,name:"Global EQ native settings",data:before.raw)
        let effective=try GlobalEQOperation.propertyMessage(key:"globals.eq",value:before.value,id:0).values[2].data!
        _ = try await backups.retain(contentID:-100,name:"Global EQ live settings",data:effective)
        eqWriteRevision &+= 1
        for update in try operation.liveUpdates(in:before,output:output) {
            let live=try await exchange({id in
                let message=try update.message(id:id)
                eqReceipts[id]=message.values[2].data;eqReceiptOrder.append(id)
                if eqReceiptOrder.count>256 {eqReceipts.removeValue(forKey:eqReceiptOrder.removeFirst())}
                return message
            },reply:"/status");try EditCommand.acknowledge(live)
        }
        // Check unrelated outputs before the native commit.
        // Neither an echoed property nor an ACK proves a physical-screen refresh.
        let intermediate=try await globalEQUnlocked()
        guard GlobalEQState.isTransition(intermediate.output(output),from:before.output(output),to:desired.output(output)),EQOutput.allCases.filter({$0 != output}).allSatisfy({GlobalEQState.sameOutput(before.output($0),intermediate.output($0))}),before.value["anyl"]==intermediate.value["anyl"],before.value["post"]==intermediate.value["post"] else{throw ProtocolError.invalid("Another EQ output changed during the update. No persistence or retry was sent.")}
        // This is optimistic live state after validated ACKs, not storage proof.
        let staged=try GlobalEQState(value:desired.value,origin:connectionID,raw:intermediate.raw)
        eqShadow=staged
        return staged
    }
    /// A new live gesture supersedes this check without resending the old commit.
    public func commitGlobalEQ(expected:GlobalEQState)async throws->GlobalEQState? {
        let revision=try await beginGlobalEQCommit(expected:expected)
        return try await confirmGlobalEQ(expected:expected,revision:revision)
    }
    private func beginGlobalEQCommit(expected:GlobalEQState)async throws->UInt64 {
        await acquire();defer{release()};try Task.checkCancellation()
        let current=try await globalEQUnlocked()
        guard expected.origin==connectionID,current.sameSettings(expected) else{throw ProtocolError.invalid("Global EQ changed before commit. Review its live values; nothing was resent.")}
        guard eqCommitHistory.count<32 else{throw ProtocolError.invalid("Earlier EQ commits are still settling. The live change was sent; no further commit was sent.")}
        eqCommitHistory.append(expected)
        let committed=try await exchange({try GlobalEQOperation.propertyMessage(key:"globals.eq",value:expected.value,id:$0)},reply:"/status");try EditCommand.acknowledge(committed)
        return eqWriteRevision
    }
    private func globalEQConfirmationRead(revision:UInt64,origin:UUID?)async throws->GlobalEQState? {
        await acquire();defer{release()};try Task.checkCancellation()
        guard origin==connectionID,revision==eqWriteRevision else{return nil}
        return try await globalEQUnlocked()
    }
    private func confirmGlobalEQ(expected:GlobalEQState,revision:UInt64)async throws->GlobalEQState? {
        // The device publishes global.eq.sync after the native commit. Writing
        // that mirror ourselves would make a successful readback circular.
        // The live DSP changes precede the device-owned sync snapshot. Measured
        // native commits can leave that snapshot stale for seconds after ACK.
        // Poll reads only; never repeat a live write or a commit to obtain proof.
        let deadline=Date().addingTimeInterval(5)
        while true {
            guard let after=try await globalEQConfirmationRead(revision:revision,origin:expected.origin) else{return nil}
            let stored=try GlobalEQState(value:MessagePack.decode(after.raw)["val_"],origin:connectionID,raw:after.raw)
            if stored.sameSettings(expected) {return after}
            guard Date()<deadline else{throw ProtocolError.invalid("The EQ change was sent, but its settings could not be confirmed yet. Check the pedal before editing again. Nothing was resent.")}
            try await Task.sleep(for:.milliseconds(150))
        }
    }
}

extension StadiumSession {
    private func matrixMixerUnlocked()async throws->Value {
        var property=try await readUnlocked(.matrixMixer)
        for output in matrixLive.keys.sorted() {property=try matrixLive[output]!.applying(to:property)}
        for key in consoleLive.keys.sorted() {property=consoleLive[key]!.applying(to:property)}
        return property
    }
    public func matrixGuitarLevels()async throws->MatrixGuitarLevels {
        await acquire();defer{release()};return try MatrixGuitarLevels(value:await matrixMixerUnlocked(),origin:connectionID)
    }
    public func matrixMIDIValue(output:Int)->Int? {matrixLastMIDI[output]?.value}
    public func navigateMatrixPanel(_ command:MatrixPanelCommand,channel:Int,send:@Sendable (Int)async throws->Void)async throws {
        await acquire();defer{release()};let origin=connectionID
        for (index,output) in command.outputs.enumerated() {
            try Task.checkCancellation()
            guard origin==connectionID,try MatrixPanelCommand.globalChannel(properties:await readUnlocked(.matrixMIDI))==channel else{throw ProtocolError.invalid("Matrix navigation routing changed. Nothing further was sent.")}
            let watermark=panelRevision
            try await send(output)
            let deadline=Date().addingTimeInterval(1.5)
            while (panelReceipts[output] ?? 0)<=watermark {
                guard origin==connectionID else{throw ProtocolError.closed}
                try Task.checkCancellation()
                guard Date()<deadline else{throw ProtocolError.invalid("Stadium did not confirm the selected output. Nothing was retried.")}
                try await Task.sleep(for:.milliseconds(10))
            }
            // Let the first screen transition finish before selecting the target.
            if index<command.outputs.count-1 {try await Task.sleep(for:.milliseconds(120))}
        }
    }
    public func matrixPanelChannel()async throws->Int {
        await acquire();defer{release()}
        return try MatrixPanelCommand.globalChannel(properties:await readUnlocked(.matrixMIDI))
    }
    public func matrixMIDIChannels()async throws->[Int] {
        await acquire();defer{release()}
        return try await matrixChannelsUnlocked()
    }
    private func matrixChannelsUnlocked()async throws->[Int] {
        let properties=try await readUnlocked(.matrixMIDI),rows=properties["vals"].items
        func value(_ key:String)throws->Int {let found=rows.filter{$0["key_"].text==key};guard found.count==1,let n=found[0]["val_"].integer else{throw ProtocolError.invalid("Matrix MIDI settings are unavailable.")};return n}
        let channels=try ["qtr","xlr","phones"].map{try value("global.midi.matrix.ch."+$0)}
        let global=try value("global.midi.channel"),control=try value("global.midi.bcchannel")
        guard try value("global.midi.over.usb.c") != 0,channels.allSatisfy({(1...16).contains($0) && $0 != global && $0 != control}),Set(channels).count==3 else{throw ProtocolError.invalid("Enable USB-C MIDI and assign separate Matrix MIDI channels on Stadium.")}
        return channels
    }
    public func setMatrixGuitar(output:Int,midi:Int,expected:MatrixGuitarLevels,channel:Int,send:@Sendable ()async throws->Void)async throws->MatrixGuitarLevels {
        guard (0..<3).contains(output),(0...127).contains(midi) else{throw ProtocolError.invalid("Invalid guitar volume.")}
        await acquire();defer{release()};try Task.checkCancellation()
        let origin=connectionID,beforeValue=try await matrixMixerUnlocked(),before=try MatrixGuitarLevels(value:beforeValue,origin:connectionID)
        let channels=try await matrixChannelsUnlocked()
        guard expected.origin==connectionID,before==expected,before.linked==0,channels[output]==channel else{throw ProtocolError.invalid("Matrix settings changed. Refresh before adjusting volume.")}
        if let prior=matrixLastMIDI[output],prior.value==midi,prior.level==before.levels[output] {return before}
        let watermark=matrixRevision
        try await send()
        let deadline=Date().addingTimeInterval(0.8)
        while matrixReceipt[output].map({$0>watermark}) != true {
            guard connectionID==origin else{throw ProtocolError.closed}
            guard Date()<deadline else{matrixLastMIDI[output]=nil;throw ProtocolError.invalid("Stadium did not send a live guitar-volume update. Nothing was retried. Check the USB connection before adjusting again.")}
            try await Task.sleep(for:.milliseconds(10))
        }
        let afterValue=try await matrixMixerUnlocked(),after=try MatrixGuitarLevels(value:afterValue,origin:connectionID)
        // Compare every mixer field except this guitar fader and transient selected layer.
        func preserved(_ value:Value)->Value {
            var root=value["val_"].object;root["atto"]=nil
            root["lyrs"] = .array(root["lyrs"]!.items.map {layer in
                guard layer["out_"]["dst_"].integer==output+1 else{return layer}
                var row=layer.object,home=row["home"]!.object,mix=home["mix_"]!.object
                mix["vol_"]=nil;home["mix_"] = .object(mix);row["home"] = .object(home);return .object(row)
            });return .object(root)
        }
        guard preserved(beforeValue)==preserved(afterValue) else{throw ProtocolError.invalid("Guitar volume was not confirmed by Stadium. The current reading will refresh; nothing was retried.")}
        matrixLastMIDI[output]=(midi,after.levels[output])
        return after
    }
}


extension StadiumSession {
    public func matrixConsole()async throws->MatrixConsoleState {
        await acquire();defer{release()};return try MatrixConsoleState(property:await matrixMixerUnlocked(),origin:connectionID)
    }
    public func setMatrixConsole(_ command:MatrixConsoleCommand,expected:MatrixConsoleState,channel:Int,send:@Sendable ()async throws->Void)async throws->MatrixConsoleState {
        await acquire();defer{release()};try Task.checkCancellation()
        let origin=connectionID,before=try MatrixConsoleState(property:await matrixMixerUnlocked(),origin:connectionID)
        let channels=try await matrixChannelsUnlocked()
        guard expected.origin==origin,expected==before,before.linked==0,channels[command.output-1]==channel,
              let target=before.strip(output:command.output,source:command.source),target.enabled else{throw ProtocolError.invalid("Matrix settings changed. Refresh before editing again.")}
        let key=command.key,old=target.raw[command.field.rawValue]
        if let prior=consoleLastMIDI[key],prior.level==old,command.field == .level || command.field == .pan {
            // Pan0 and1 share the clamped left endpoint. A fresh prior receipt
            // can confirm the same physical target without demanding a new echo.
            var samePan=false
            if command.field == .pan {samePan=try MatrixPan.value(forMIDI:command.value)==old.numeric}
            if prior.value==command.value || samePan {return before}
        }
        let watermark=matrixRevision
        // Any new send makes the prior MIDI receipt unsafe for no-op decisions,
        // even if this send subsequently fails or its live event never arrives.
        consoleLastMIDI[key]=nil
        try await send()
        let deadline=Date().addingTimeInterval(0.8)
        while consoleReceipts[key].map({$0>watermark}) != true {
            guard connectionID==origin else{throw ProtocolError.closed}
            guard Date()<deadline else{throw ProtocolError.invalid("Stadium did not confirm this Matrix control. Nothing was retried. Refresh before editing again.")}
            try await Task.sleep(for:.milliseconds(10))
        }
        let after=try MatrixConsoleState(property:await matrixMixerUnlocked(),origin:connectionID)
        guard connectionID==origin,after.linked==before.linked,let actual=after.strip(output:command.output,source:command.source) else{throw ProtocolError.invalid("Matrix output changed during the adjustment.")}
        if command.field == .mute || command.field == .solo {
            guard actual.raw[command.field.rawValue].boolean == !(old.boolean!) else{throw ProtocolError.invalid("The Matrix toggle was not confirmed. Nothing was retried.")}
        }
        if command.field == .pan {
            let wanted=try MatrixPan.value(forMIDI:command.value)
            guard abs(actual.pan-wanted)<0.00001 else{throw ProtocolError.invalid("The Matrix pan was not confirmed. Nothing was retried.")}
        }
        for output in 1...3 {
            for row in before.strips(output) {
                guard let next=after.strip(output:output,source:row.id) else{throw ProtocolError.invalid("A Matrix channel disappeared.")}
                var lhs=row.raw.object,rhs=next.raw.object
                if output==command.output && row.id==command.source {lhs[command.field.rawValue]=nil;rhs[command.field.rawValue]=nil}
                guard lhs==rhs else{throw ProtocolError.invalid("Another Matrix channel changed. Refresh before editing again.")}
            }
            guard before.layer(output)["out_"]==after.layer(output)["out_"] else{throw ProtocolError.invalid("The main output volume changed during the adjustment.")}
        }
        func preserved(_ property:Value)->Value {
            func strip(_ value:Value)->Value {
                switch value {
                case .object(var row):
                    if row["src_"]?.integer==command.source {row[command.field.rawValue]=nil}
                    return .object(row.mapValues{strip($0)})
                case .array(let rows):return .array(rows.map{strip($0)})
                default:return value
                }
            }
            var wrapper=property.object,root=property["val_"].object;root["atto"]=nil
            root["lyrs"] = .array((root["lyrs"] ?? .null).items.map {layer in
                guard layer["out_"]["dst_"].integer==command.output else{return layer}
                var row=strip(layer).object
                // Derived per-layer mute/solo masks may accompany a channel toggle.
                if command.field == .mute {row["mute"]=nil}
                if command.field == .solo {row["solo"]=nil}
                return .object(row)
            });wrapper["val_"] = .object(root);return .object(wrapper)
        }
        guard preserved(before.property)==preserved(after.property) else{throw ProtocolError.invalid("Unrelated Matrix settings changed. Refresh before editing again.")}
        consoleLastMIDI[key]=(command.value,actual.raw[command.field.rawValue]);return after
    }
}

extension StadiumSession {
    /// Absolute recovery remains available after an uncertain toggle. No retries.
    public func clearMatrixSolos(_ command:MatrixClearSolosCommand,expected:MatrixConsoleState,channel:Int,send:@Sendable ()async throws->Void)async throws->MatrixConsoleState {
        await acquire();defer{release()};try Task.checkCancellation()
        let origin=connectionID,before=try MatrixConsoleState(property:await matrixMixerUnlocked(),origin:connectionID)
        let channels=try await matrixChannelsUnlocked()
        guard expected.origin==origin,expected==before,before.linked==0,channels[command.output-1]==channel else{throw ProtocolError.invalid("Matrix settings changed. Refresh before clearing solos.")}
        let active=before.strips(command.output).filter(\.solo).map(\.id),watermark=matrixRevision
        for source in MatrixStrip.order {consoleLastMIDI["\(command.output):\(source):solo"]=nil}
        try await send()
        let deadline=Date().addingTimeInterval(0.8)
        while true {
            guard connectionID==origin else{throw ProtocolError.closed}
            let fresh=MatrixStrip.order.filter {source in
                let key="\(command.output):\(source):solo"
                return (consoleReceipts[key] ?? 0)>watermark && consoleLive[key]?.value.boolean==false
            }
            if !fresh.isEmpty,active.allSatisfy({fresh.contains($0)}) {break}
            guard Date()<deadline else{throw ProtocolError.invalid("Clear Solos was sent, but Stadium did not confirm it. Nothing was retried; check the pedal.")}
            try await Task.sleep(for:.milliseconds(10))
        }
        let after=try MatrixConsoleState(property:await matrixMixerUnlocked(),origin:connectionID)
        guard origin==connectionID,after.strips(command.output).allSatisfy({!$0.solo}) else{throw ProtocolError.invalid("Stadium has not confirmed every Solo is off.")}
        func preserved(_ property:Value)->Value {
            func removeSolo(_ value:Value)->Value {
                switch value {
                case .object(var row):row["solo"]=nil;return .object(row.mapValues{removeSolo($0)})
                case .array(let rows):return .array(rows.map{removeSolo($0)})
                default:return value
                }
            }
            var wrapper=property.object,root=property["val_"].object;root["atto"]=nil
            root["lyrs"] = .array((root["lyrs"] ?? .null).items.map {layer in layer["out_"]["dst_"].integer==command.output ? removeSolo(layer):layer})
            wrapper["val_"] = .object(root);return .object(wrapper)
        }
        guard preserved(before.property)==preserved(after.property) else{throw ProtocolError.invalid("Other Matrix settings changed during Clear Solos. Inspect the pedal.")}
        return after
    }
}
