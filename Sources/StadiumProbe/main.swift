import Foundation
import StadiumProtocol
import StadiumNetwork

@main struct Probe {
    static func main()async {
        let args=Array(CommandLine.arguments.dropFirst())
        func option(_ key:String)->String? {guard let index=args.firstIndex(of:key),index+1<args.count else{return nil};return args[index+1]}
        guard let host=option("--host") else{print("Usage: stadium-probe --host DEVICE.local [--trace PRIVATE.jsonl] [--watch SECONDS]");return}
        let session=StadiumSession()
        do {
            let trace=try option("--trace").map{try TraceRecorder(path:$0)}
            try await session.connect(host:host,port:UInt16(option("--port") ?? "2001") ?? 2001,trace:trace)
            let state=try await session.snapshot()
            print("Connected • firmware \(state.firmware) • preset read • snapshot \(state.activeSnapshot+1) • \(state.blocks.count) signal blocks")
            if args.contains("--tuner-settings") {let values=try await session.read(.tunerProperties);print("Tuner settings read: \(values["vals"].items.count)")}
            if args.contains("--assignments") {
                print("Scenes: \(state.snapshots.filter(\.defined).count) defined, \(state.snapshots.count) slots")
                for n in StompAssignment.switchNumbers {let a=StompAssignment.read(state,bank:"a",number:n);print("A\(n): \(a.reason ?? "available")")}
            }
            if let output=option("--output") {
                let object:[String:Any]=["product":state.product.json,"edit_buffer":state.editBuffer.json,"preset":state.preset.json,"snapshot":state.activeSnapshot]
                let data=try JSONSerialization.data(withJSONObject:object,options:[.prettyPrinted,.sortedKeys])
                try data.write(to:URL(fileURLWithPath:output),options:.atomic);try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:output)
                print("Private state file saved.")
            }
            let deadline=Date().addingTimeInterval(Double(option("--watch") ?? "0") ?? 0)
            var count=0
            while Date()<deadline {let event=try await session.event(timeout:5);count+=1;print("Received \(event.address) (\(event.values.count) fields)")}
            if count>0 {print("Update channel verified: \(count) incoming messages.")}
            await session.disconnect()
        } catch {await session.disconnect();FileHandle.standardError.write(Data((error.localizedDescription+"\n").utf8));exit(1)}
    }
}
