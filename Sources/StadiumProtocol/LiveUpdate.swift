import Foundation

public enum StadiumLiveUpdate:Equatable,Sendable {
    case selection(path:Int,position:Int)
    case stateChanged
    public static func decode(_ message:OSCMessage)->StadiumLiveUpdate? {
        if message.address=="/setSelectedBlock" {
            // Observed firmware 1.4.2: source and command metadata precede
            // zero-based flow + visible position. Never use the internal ID.
            guard message.values.count==4,message.values.allSatisfy({$0.integer != nil}),let path=message.values[2].integer,let position=message.values[3].integer,(0...1).contains(path),(0...27).contains(position) else{return nil}
            return .selection(path:path,position:position)
        }
        if ["/attachCommandWithType","/attachCommandWithBlob","/setCommandParamVal","/setCommandType","/removeCommand","/assignSnapshotCommandParam","/removeSnapshotCommandParam","/pasteAllCommands","/removeAllCommands","/setControllerValue","/setTargetValue","/setModelWithMID","/setParamValue","/setParamWithPID","/setHarnessParamValue","/setBlockEnable","/activateSnapshot","/loadPresetWithCID","/setEditBuffer","/setPropertyValue"].contains(message.address) {return .stateChanged}
        return nil
    }
}
public struct StadiumBlockFocus:Equatable,Sendable {
    public let id:UUID;public let path:Int;public let position:Int;public let receivedAt:Date
    public init(path:Int,position:Int) {id=UUID();self.path=path;self.position=position;receivedAt=Date()}
}

/// Fallback when the device broadcasts a model change without a selection event.
/// Match the visible slot; replacement can allocate a different internal block ID.
public enum StadiumSelectionFollow {
    public static func changedModel(previous:[SignalBlock],current:[SignalBlock])->SignalBlock? {
        current.first {block in previous.contains {old in
            old.path==block.path && old.position==block.position && old.slot==block.slot && old.model != block.model
        }}
    }
}
