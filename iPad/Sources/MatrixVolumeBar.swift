import SwiftUI
import StadiumProtocol

@MainActor final class MatrixVolumeModel:ObservableObject {
    @Published var levels:[Double]=[]
    @Published var ready=false
    @Published var message="Connect Stadium directly to iPad by USB-C"
    @Published var sending=false
    @Published var positions:[Int:Int]=[:]
    private var deviceID:String?
    private var channels:[Int]=[]
    private var pending:[Int:Int]=[:]
    private var token=UUID()
    private var writer:Task<Void,Never>?
    private var refreshRevision=0
    private var blocked=false
    let usb=MatrixUSBMIDI()
    private var mixer:MatrixGuitarLevels?
    func observe(_ monitor:StadiumMonitor)async {
        let epoch=UUID();token=epoch;ready=false;levels=[];positions=[:];pending=[:];deviceID=nil;channels=[];blocked=false;mixer=nil
        guard monitor.connected,let state=monitor.snapshot,let id=FileCompanion.deviceID(state.product) else{message="Connect to Stadium";return}
        deviceID=id
        while !Task.isCancelled,token==epoch {
            usb.refresh()
            if !sending {
                let revision=refreshRevision
                do {
                    let direct=try await monitor.readMatrixLevels()
                    let actualChannels=try await monitor.matrixChannels()
                    guard !Task.isCancelled,token==epoch else{return}
                    if revision==refreshRevision,!sending {
                        if monitor.connectionRoute == .usb,monitor.connectionInterface=="USB/Ethernet",usb.online,!usb.bound(to:id) {try usb.bind(to:id)}
                        if levels.count==3 {for output in 0..<3 where levels[output] != direct.levels[output] {positions[output]=nil}}
                        levels=direct.levels;mixer=direct;channels=actualChannels
                        ready=direct.linked==0 && usb.bound(to:id) && !blocked
                        if !usb.online {message="Connect Stadium directly to iPad by USB-C"}
                        else if !usb.bound(to:id) {message="Confirm the connected USB Stadium"}
                        else if direct.linked != 0 {message="Unlink Matrix outputs for independent guitar volume"}
                        else if !blocked {message="Guitar volume · direct USB MIDI"}
                    }
                }catch {if token==epoch {ready=false;message=error.localizedDescription}}
            }
            try? await Task.sleep(for:.milliseconds(500))
        }
        if token==epoch {ready=false;pending=[:]}
    }
    func bindUSB()throws {guard let deviceID else{throw ProtocolError.closed};try usb.bind(to:deviceID);retry()}
    func retry(){blocked=false;message="Checking USB connection…"}
    func move(output:Int,midi:Int,monitor:StadiumMonitor) {
        guard ready,usb.online,!blocked,(0..<3).contains(output),deviceID != nil,levels.count==3,channels.count==3 else{return}
        pending[output]=min(127,max(0,midi));refreshRevision+=1
        guard writer==nil else{return}
        let epoch=token,connection=monitor.connectionID
        writer=Task {
            sending=true
            while !pending.isEmpty,token==epoch,!blocked {
                let output=pending.keys.sorted()[0],value=pending.removeValue(forKey:output)!
                guard let id=deviceID,let before=mixer,channels.count==3 else{break}
                let channel=channels[output]
                do {
                    let after=try await monitor.setMatrixGuitar(output:output,midi:value,expected:before,channel:channel) {
                        try await MainActor.run {
                            guard self.token==epoch,monitor.connected,monitor.connectionID==connection else{throw CancellationError()}
                            try self.usb.send(channel:channel,value:value,networkIdentity:id)
                        }
                    }
                    guard token==epoch else{break};levels=after.levels;mixer=after;positions[output]=value
                }catch {
                    guard token==epoch else{break};pending=[:];blocked=true;ready=false;message=error.localizedDescription
                }
            }
            sending=false;writer=nil
        }
    }
}

struct MatrixVolumeBar:View {
    @EnvironmentObject var monitor:StadiumMonitor
    @StateObject private var model=MatrixVolumeModel()
    @StateObject private var usbPresence=MatrixUSBMIDI()
    @State private var drafts:[Int:Double]=[:]
    @State private var dragging:Set<Int>=[]
    @State private var showSetup=false
    @State private var setupError:String?
    let preview:Bool
    var body:some View {
        HStack(spacing:10) {
            ForEach(0..<3,id:\.self) {output in
                VStack(spacing:0) {
                    HStack(spacing:3) {
                        Text(MatrixGuitarLevels.labels[output]).font(.system(size:11,weight:.semibold)).lineLimit(1)
                        Spacer(minLength:0)
                        Text(model.levels.count==3 ? MatrixGuitarLevels.label(model.levels[output]):"—").font(.system(size:10).monospacedDigit()).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    Slider(value:Binding(get:{drafts[output] ?? model.positions[output].map(Double.init) ?? (model.levels.count==3 ? Double(MatrixGuitarLevels.estimatedMIDI(model.levels[output])):0)},set:{value in drafts[output]=value;model.move(output:output,midi:Int(value.rounded()),monitor:monitor)}),in:0...127,step:1,onEditingChanged:{active in
                        if active {dragging.insert(output)}else{dragging.remove(output);drafts[output]=nil}
                    }).tint(.cyan).disabled(!model.ready || !usbPresence.online).accessibilityLabel("\(MatrixGuitarLevels.labels[output]) guitar volume").accessibilityValue(model.levels.count==3 ? MatrixGuitarLevels.label(model.levels[output]):"Unavailable")
                }.frame(minWidth:84,maxWidth:.infinity)
            }
            Button {showSetup=true} label:{Image(systemName:model.ready && usbPresence.online ? "slider.horizontal.3":"cable.connector").font(.system(size:15)).foregroundStyle(model.ready && usbPresence.online ? .cyan:.gray).frame(width:30,height:44)}.buttonStyle(.plain).accessibilityLabel("Guitar volume connection").help(model.message)
        }
        .task(id:"\(monitor.connectionID)-\(monitor.connected)") {if !preview {await model.observe(monitor)}}
        .onChange(of:model.levels){_,_ in for output in 0..<3 where !dragging.contains(output) {drafts[output]=nil}}
        .sheet(isPresented:$showSetup) {
            NavigationStack {VStack(alignment:.leading,spacing:18) {
                Text("Guitar volume").font(.title2)
                Text("These faders adjust all Home guitar paths feeding each Matrix output. The pedal’s output knob sets your overall ceiling. Backing tracks and Bluetooth have separate levels.").font(.callout)
                Text(model.message).foregroundStyle(model.ready && usbPresence.online ? .cyan:.gray).font(.callout)
                Text("Connect Stadium directly to this iPad by USB-C. No computer is needed. For cable-only editing, choose USB in the connection menu and select Stadium’s hostname.").font(.callout)
                Text(model.usb.deviceName).font(.callout)
                HStack {
                    Button("Use this USB Stadium") {do {try model.bindUSB();setupError=nil}catch{setupError=error.localizedDescription}}.disabled(!usbPresence.online || !monitor.connected)
                    Button("Refresh connection"){model.retry();setupError=nil}
                }.buttonStyle(.bordered)
                Text("Confirm only when this USB cable connects to the same Stadium selected in the editor. A different USB device needs a new confirmation.").font(.caption).foregroundStyle(.secondary)
                if let setupError {Text(setupError).foregroundStyle(.orange)}
                Spacer()
            }.padding(24).navigationTitle("Guitar Volume").toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){showSetup=false}}}}
        }
    }
}
