import Foundation
import StadiumProtocol
import StadiumNetwork

// Explicit read-only hardware qualification. Pairing comes from a private file,
// never a command-line token or a committed fixture. No edits, MIDI or saves.
@main struct Check {
 static func main()async {
  do {
   guard CommandLine.arguments.count==2 else{throw ProtocolError.invalid("Pass a private PedalBridge pairing-link file.")}
   let pair=try PedalBridgePair(link:String(contentsOfFile:CommandLine.arguments[1],encoding:.utf8))
   let bridge=try await PedalBridgeConnection.open(pair),session=StadiumSession()
   do {
    try await session.connect(host:pair.host,route:.bridge,bridge:bridge)
    let state=try await session.snapshot(),console=try await session.matrixConsole(),channels=try await session.matrixMIDIChannels()
    let result:[String:Any]=["connected":true,"firmware":state.firmware,"blocks":state.blocks.count,"matrixUSBAvailable":bridge.matrixAvailable,"matrixStrips":(1...3).reduce(0){$0+console.strips($1).count},"matrixChannelCount":channels.count,"upstream":bridge.upstream,"readOnly":true]
    print(String(data:try JSONSerialization.data(withJSONObject:result,options:.sortedKeys),encoding:.utf8)!)
    await session.disconnect()
   }catch{await session.disconnect();throw error}
  }catch{fputs("Read-only bridge check failed: \(error.localizedDescription)\n",stderr);exit(1)}
 }
}
