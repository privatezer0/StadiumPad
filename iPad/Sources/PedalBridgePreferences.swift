import SwiftUI
import StadiumProtocol
import StadiumNetwork

/// Helper administration stays separate from pedal tone controls.
struct PedalBridgePreferences:View {
    let pair:PedalBridgePair
    var restarting:()->Void
    @State private var status:[String:Any]=[:]
    @State private var busy=false
    @State private var error=""
    @State private var message=""
    @State private var ssid=""
    @State private var password=""
    @State private var page=0
    @State private var networks:[[String:Any]]=[]
    @State private var confirmRestart=false
    private var network:[String:Any] {status["network"] as? [String:Any] ?? [:]}
    private var isPi:Bool {status["kind"] as? String == "pi"}
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            Text(status["name"] as? String ?? "Selected helper").font(.headline)
            Picker("Helper settings",selection:$page){Text("Status").tag(0);if isPi{Text("Pi Wi-Fi").tag(1)};Text("Troubleshooting").tag(2)}.pickerStyle(.segmented)
            if page==0 {
                Label(pair.bluetooth ? "Bluetooth connection":"Network connection",systemImage:"antenna.radiowaves.left.and.right").font(.callout)
                ForEach([("stadium","Helix Stadium"),("quadCortex","Quad Cortex")],id:\.0) {key,name in
                    let pedal=status[key] as? [String:Any] ?? [:]
                    let online=pedal["connected"] as? Bool==true
                    HStack {Image(systemName:online ? "checkmark.circle.fill":"circle").foregroundStyle(online ? Color.green:Color.secondary);Text(name);Spacer();Text(online ? "Online · \(pedal["upstream"] as? String ?? "USB")":pedal["usbPresent"] as? Bool==true ? "USB detected · editor unavailable":"Offline")}
                }
                Button("Refresh status"){perform("status")}.disabled(busy)
            }else if page==1,isPi {
                Text(network["connected"] as? Bool==true ? "Connected · \(network["name"] as? String ?? network["profile"] as? String ?? "home")":"Wi-Fi disconnected").font(.caption)
                HStack {TextField("Network name",text:$ssid).textInputAutocapitalization(.never).autocorrectionDisabled();Button("Find networks"){perform("scan")}.disabled(busy)}
                if !networks.isEmpty {Menu("Choose network"){ForEach(Array(networks.enumerated()),id:\.offset){_,row in Button(row["name"] as? String ?? "Network"){ssid=row["name"] as? String ?? ""}}}}
                SecureField("Wi-Fi password",text:$password).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Connect Pi to Wi-Fi"){perform("connect")}.disabled(busy || ssid.isEmpty)
                Text("Bluetooth control stays connected while Pi Wi-Fi changes.").font(.caption).foregroundStyle(.secondary)
            }else {
                if isPi {Toggle("Web dashboard",isOn:Binding(get:{network["dashboard"] as? Bool ?? false},set:{perform("dashboard",enabled:$0)})).disabled(busy)}
                Button("Restart PedalBridge service"){confirmRestart=true}.disabled(busy || status.isEmpty)
                Text("Restarts the helper without rebooting its Mac or Pi. The editor reconnects with fresh state; edits are never replayed.").font(.caption).foregroundStyle(.secondary)
            }
            if busy {ProgressView("Working…")}
            if !message.isEmpty {Text(message).font(.caption)}
            if !error.isEmpty {Text(error).font(.caption).foregroundStyle(.orange)}
        }.textFieldStyle(.roundedBorder).task{perform("status")}
        .confirmationDialog("Restart the selected PedalBridge service?",isPresented:$confirmRestart,titleVisibility:.visible){Button("Restart service"){perform("restart")}} message:{Text("The machine stays on. StadiumPad reconnects automatically with fresh state.")}
    }
    private func perform(_ action:String,enabled:Bool?=nil) {
        guard !busy else{return};busy=true;error="";message=""
        let name=ssid,secret=password
        Task {
            defer{busy=false}
            do {
                let result=try await PedalBridgeConnection.settings(pair,action:action,ssid:action=="connect" ? name:nil,password:action=="connect" ? secret:nil,enabled:enabled)
                if action=="restart" {message="PedalBridge is restarting. Reconnecting…";restarting();return}
                if let rows=(result["network"] as? [String:Any])?["networks"] as? [[String:Any]] {networks=rows}else{status=result}
                if action=="connect" {password="";message="Pi joined Wi-Fi."}
            }catch{self.error=error.localizedDescription}
        }
    }
}
