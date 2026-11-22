import SwiftUI
import StadiumProtocol

/// Compact output selectors. The mixer owns editing only while its modal is open.
struct MatrixVolumeBar:View {
    @EnvironmentObject var monitor:StadiumMonitor
    @StateObject private var usb=MatrixUSBMIDI()
    @State private var selected:Int?
    let preview:Bool
    var body:some View {
        HStack(spacing:8) {
            ForEach(1...3,id:\.self){output in
                Button {selected=output}label:{VStack(spacing:3){
                    Image(systemName:output==3 ? "headphones":output==2 ? "circle.dotted":"cable.connector").font(.system(size:21,weight:.light))
                    Text(MatrixGuitarLevels.labels[output-1]).font(.system(size:10,weight:.semibold))
                }.frame(width:58,height:46).foregroundStyle(usb.online && monitor.connected ? .white:.gray)}.buttonStyle(.plain).accessibilityLabel("Open \(MatrixGuitarLevels.labels[output-1]) Matrix mixer")
            }
            Spacer(minLength:0)
        }
        #if DEBUG
        .task {if ProcessInfo.processInfo.arguments.contains("--show-matrix") {selected=3}}
        #endif
        .sheet(isPresented:Binding(get:{selected != nil},set:{if !$0 {selected=nil}})) {
            MatrixMixerView(initialOutput:selected ?? 1,preview:preview)
                .environmentObject(monitor).frame(idealWidth:1100,idealHeight:730).presentationSizing(.fitted).presentationDragIndicator(.visible)
        }
    }
}

@MainActor final class MatrixConsoleModel:ObservableObject {
    @Published var state:MatrixConsoleState?
    @Published var ready=false
    @Published var message="Reading Matrix mixer…"
    @Published var sending=false
    @Published var positions:[String:Int]=[:]
    let usb=MatrixUSBMIDI()
    private var deviceID:String?
    private var channels:[Int]=[]
    private var queue:[MatrixConsoleCommand]=[]
    private var writer:Task<Void,Never>?
    private var token=UUID(),revision=0
    private var blocked=false
    private var lastRequested:[String:Any]=[:]
    init(previewState:MatrixConsoleState?=nil){state=previewState;if previewState != nil {message="USB Matrix mixer · layout preview"}}
    private func report() {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["STADIUM_VERIFY"]=="1" else{return}
        let root=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
        let rows=(1...3).flatMap{output in (state?.strips(output) ?? []).map{row in ["output":output,"source":row.id,"level":row.level,"pan":row.pan,"mute":row.muted,"solo":row.solo] as [String:Any]}}
        let record:[String:Any]=["ready":ready,"sending":sending,"blocked":blocked,"message":message,"at":Date().timeIntervalSince1970,"channels":rows,"lastRequested":lastRequested]
        try? JSONSerialization.data(withJSONObject:record).write(to:root.appendingPathComponent("matrix-console-ui.json"),options:.atomic)
        #endif
    }
    func observe(_ monitor:StadiumMonitor)async {
        let epoch=UUID();token=epoch;ready=false;blocked=false;state=nil;positions=[:];queue=[]
        guard monitor.connected,let product=monitor.snapshot?.product,let id=FileCompanion.deviceID(product) else{message="Connect to Stadium to read the mixer.";return}
        deviceID=id
        while !Task.isCancelled,token==epoch {
            usb.refresh()
            if !sending {
                let stamp=revision
                do {
                    let next=try await monitor.readMatrixConsole(),midi=try await monitor.matrixChannels()
                    guard !Task.isCancelled,token==epoch else{return}
                    if stamp==revision,!sending {
                        if monitor.connectionRoute == .usb,monitor.connectionInterface=="USB/Ethernet",usb.online,!usb.bound(to:id) {try usb.bind(to:id)}
                        if let before=state {for output in 1...3 {for row in next.strips(output) {for field in [MatrixField.level,.pan] where row.raw[field.rawValue] != before.strip(output:output,source:row.id)?.raw[field.rawValue] {positions["\(output):\(row.id):\(field.rawValue)"]=nil}}}}
                        state=next;channels=midi;ready=usb.bound(to:id) && next.linked==0 && !blocked
                        if !usb.online {message="Connect Stadium directly to this iPad by USB-C to control the mixer."}
                        else if !usb.bound(to:id) {message="Confirm this USB Stadium to enable mixer controls."}
                        else if next.linked != 0 {message="Outputs are linked. Unlink them on Stadium before editing independent mixes."}
                        else if !blocked {message="USB Matrix mixer"}
                    }
                }catch {guard token==epoch else{return};ready=false;message=error.localizedDescription}
            }
            report()
            try? await Task.sleep(for:.milliseconds(300))
        }
        if token==epoch {ready=false;queue=[]}
    }
    func bind() {do{guard let deviceID else{throw ProtocolError.closed};try usb.bind(to:deviceID);retry()}catch{message=error.localizedDescription}}
    func retry(){blocked=false;revision+=1}
    func dropPending(){queue=[]}
    func clearSolos(output:Int,monitor:StadiumMonitor){
        guard ready,!sending,let state else{return}
        let commands=state.strips(output).filter{$0.enabled && $0.solo}.compactMap{try? MatrixConsoleCommand(output:output,source:$0.id,field:.solo,value:127)}
        guard let first=commands.first else{return};send(first,monitor:monitor);queue.append(contentsOf:commands.dropFirst())
    }
    func stop(){token=UUID();queue=[];ready=false}
    func send(_ command:MatrixConsoleCommand,monitor:StadiumMonitor) {
        lastRequested=["output":command.output,"source":command.source,"field":command.field.rawValue,"value":command.value];report()
        guard ready,usb.online,channels.count==3 else{return}
        // Never coalesce toggles: MIDI mute/solo commands toggle, rather than set.
        if command.field == .level || command.field == .pan {queue.removeAll{$0.key==command.key}}
        else {guard !sending,queue.isEmpty else{return}}
        queue.append(command);revision+=1
        guard writer==nil else{return}
        let epoch=token,connection=monitor.connectionID
        writer=Task {
            sending=true
            while !queue.isEmpty,token==epoch,!blocked {
                let command=queue.removeFirst()
                guard let before=state,let id=deviceID,channels.count==3 else{break}
                let channel=channels[command.output-1]
                do {
                    let after=try await monitor.setMatrixConsole(command,expected:before,channel:channel) {
                        try await MainActor.run {
                            guard self.token==epoch,monitor.connected,monitor.connectionID==connection else{throw CancellationError()}
                            try self.usb.send(command,channel:channel,networkIdentity:id)
                        }
                    }
                    guard token==epoch else{break};state=after;positions[command.key]=command.value
                }catch {guard token==epoch else{break};queue=[];ready=false;blocked=true;message=error.localizedDescription}
            }
            sending=false;writer=nil;report()
        }
    }
}

struct MatrixMixerView:View {
    @EnvironmentObject var monitor:StadiumMonitor
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model:MatrixConsoleModel
    @StateObject private var presence=MatrixUSBMIDI()
    @State private var output:Int
    @State private var homeExpanded=false
    @State private var songExpanded=false
    @State private var showEQ=false
    let preview:Bool
    init(initialOutput:Int,preview:Bool=false,previewState:MatrixConsoleState?=nil,expanded:Bool=false){_output=State(initialValue:initialOutput);self.preview=preview;_model=StateObject(wrappedValue:MatrixConsoleModel(previewState:previewState));_homeExpanded=State(initialValue:expanded);_songExpanded=State(initialValue:expanded)}
    private var sources:[Int] {[5]+(homeExpanded ? [1,2,3,4]:[])+[14]+(songExpanded ? Array(6...13):[])+[15,16,17,18,19]}
    private var enabled:Bool {model.ready && presence.online && !preview}
    var body:some View {
        GeometryReader {area in VStack(spacing:0) {
            HStack(spacing:12) {
                Image(systemName:"slider.vertical.3").foregroundStyle(.cyan)
                Text("Matrix").font(.system(size:26,weight:.light))
                Picker("Output",selection:$output){ForEach(1...3,id:\.self){n in Text(MatrixGuitarLevels.labels[n-1]).tag(n)}}.pickerStyle(.segmented).frame(maxWidth:280)
                Spacer(minLength:0)
                if model.state?.strips(output).contains(where:{$0.solo})==true {Button("Clear Solos"){model.clearSolos(output:output,monitor:monitor)}.disabled(!enabled || model.sending)}
                Button {showEQ=true}label:{Label("Global EQ",systemImage:"waveform.path")}.disabled(!monitor.connected || model.sending)
                Button("Close"){model.stop();dismiss()}.fontWeight(.semibold).padding(.leading,10)
            }.padding(.horizontal,18).frame(height:64).background(EditorTheme.header)
            if let state=model.state {
                ScrollView(.horizontal) {
                    HStack(spacing:1) {ForEach(sources,id:\.self){source in
                        if let row=state.strip(output:output,source:source) {
                            MatrixChannelStrip(row:row,output:output,position:model.positions["\(output):\(source):vol_"],enabled:enabled && row.enabled,togglesEnabled:!model.sending,expanded:source==5 ? homeExpanded:songExpanded,toggleExpanded:{if source==5 {homeExpanded.toggle()}else{songExpanded.toggle()}},changed:{field,value in
                                if let command=try? MatrixConsoleCommand(output:output,source:source,field:field,value:value) {model.send(command,monitor:monitor)}
                            }).frame(width:max(90,(area.size.width-24)/7))
                        }
                    }}.padding(.horizontal,12).padding(.vertical,12)
                }.scrollIndicators(.visible)
            }else {VStack(spacing:16){ProgressView();Text(model.message).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,maxHeight:.infinity)}
            HStack(spacing:12) {
                Circle().fill(enabled ? Color.cyan:Color.gray).frame(width:7,height:7)
                Text(model.message).font(.system(size:12)).lineLimit(2)
                Spacer(minLength:5)
                if !model.ready {Button("Use this USB Stadium"){model.bind()}.disabled(!presence.online || !monitor.connected);Button("Refresh"){model.retry()}}
            }.padding(.horizontal,18).frame(minHeight:42).background(Color(white:0.09))
        }}.background(Color(white:0.045)).foregroundStyle(.white).preferredColorScheme(.dark)
        .task(id:"\(monitor.connectionID)-\(monitor.connected)"){if !preview {await model.observe(monitor)}}
        .onDisappear{model.stop()}
        .onChange(of:output){_,_ in model.dropPending()}
        .sheet(isPresented:$showEQ){NavigationStack{GlobalEQView(preview:preview,initialOutput:output==3 ? .phones:output==2 ? .xlr:.quarter).environmentObject(monitor).toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){showEQ=false}}}}}
    }
}

private struct MatrixChannelStrip:View {
    let row:MatrixStrip,output:Int,position:Int?,enabled:Bool,togglesEnabled:Bool,expanded:Bool
    let toggleExpanded:()->Void
    let changed:(MatrixField,Int)->Void
    @State private var draft:Double?
    @State private var showPan=false
    @State private var panDraft:Double?
    private var tint:Color {row.id<=5 ? Color(red:0.63,green:0.60,blue:0.27):row.id<=14 ? Color(red:0.15,green:0.65,blue:0.65):Color.gray}
    var body:some View {
        VStack(spacing:10) {
            Button{panDraft=nil;showPan=true}label:{VStack(spacing:4){Text(abs(row.pan)<0.015 ? "Center":String(format:"%@ %.0f%%",row.pan<0 ? "L":"R",abs(row.pan)*100)).font(.system(size:12));GeometryReader{g in ZStack{Capsule().fill(.white.opacity(0.15)).frame(height:2);Circle().fill(.white.opacity(0.7)).frame(width:6,height:6).offset(x:row.pan*g.size.width*0.45)}}.frame(height:8)}}.disabled(!enabled)
            HStack(spacing:5) {
                toggle("M",active:row.muted,color:.red,field:.mute)
                toggle("S",active:row.solo,color:.yellow,field:.solo)
            }
            Text(MatrixGuitarLevels.label(row.level)).font(.system(size:13).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.8)
            MatrixVerticalFader(value:Binding(get:{draft ?? Double(position ?? MatrixGuitarLevels.estimatedMIDI(row.level))},set:{v in draft=v;changed(.level,Int(v.rounded()))}),enabled:enabled,released:{draft=nil})
            HStack(spacing:4) {
                Image(systemName:row.id==5 ? "house":row.id==14 ? "music.note":row.id==15 ? "metronome":row.id==17 ? "cable.connector":row.id==18 ? "dot.radiowaves.left.and.right":"waveform").font(.system(size:15))
                if row.id==5 || row.id==14 {Button(action:toggleExpanded){Image(systemName:expanded ? "minus.circle":"plus.circle").font(.system(size:23))}.buttonStyle(.plain).accessibilityLabel("\(expanded ? "Hide":"Show") \(row.id==5 ? "Home paths":"Song tracks")")}
            }.frame(height:30)
            Text(row.id==5 ? "Home":row.id==16 ? "Count In":row.name).font(.system(size:12,weight:.medium)).lineLimit(1).minimumScaleFactor(0.7)
        }.padding(.horizontal,9).padding(.vertical,14).background(tint.opacity(row.id==5 || row.id==14 ? 0.13:0.05)).opacity(row.enabled ? 1:0.4)
        .onChange(of:output){_,_ in draft=nil;showPan=false}
        .popover(isPresented:$showPan){VStack(spacing:20){Text("\(row.name) · Pan").font(.headline);Slider(value:Binding(get:{panDraft ?? (row.pan<0 ? 64+row.pan*64:64+row.pan*63)},set:{panDraft=$0;changed(.pan,Int($0.rounded()))}),in:0...127,step:1).frame(width:260).disabled(!enabled);HStack{Text("Left");Spacer();Button("Center"){panDraft=64;changed(.pan,64)};Spacer();Text("Right")};Button("Done"){showPan=false}}.padding(24).presentationCompactAdaptation(.popover)}
    }
    private func toggle(_ title:String,active:Bool,color:Color,field:MatrixField)->some View {
        Button{changed(field,127)}label:{Text(title).font(.system(size:15,weight:.medium)).frame(maxWidth:.infinity).frame(height:35).foregroundStyle(active ? .black:color).background(active ? color:Color.black.opacity(0.35),in:RoundedRectangle(cornerRadius:4)).overlay(RoundedRectangle(cornerRadius:4).stroke(color.opacity(0.55),lineWidth:1))}.buttonStyle(.plain).disabled(!enabled || !togglesEnabled).accessibilityLabel("\(row.name) \(title=="M" ? "Mute":"Solo")").accessibilityValue(active ? "On":"Off")
    }
}
private struct MatrixVerticalFader:View {
    @Binding var value:Double
    let enabled:Bool,released:()->Void
    var body:some View {
        GeometryReader{g in ZStack {
            VStack{ForEach(0..<9,id:\.self){_ in Rectangle().fill(.white.opacity(0.08)).frame(height:1);Spacer(minLength:0)}}
            Capsule().fill(.black).frame(width:8).padding(.vertical,14)
            Circle().fill(Color(white:0.25)).overlay(Circle().stroke(.white.opacity(0.55),lineWidth:1.5)).frame(width:30,height:30).position(x:g.size.width/2,y:15+(1-value/127)*max(1,g.size.height-30))
        }.contentShape(Rectangle()).gesture(DragGesture(minimumDistance:0).onChanged{event in guard enabled else{return};value=min(127,max(0,127*(1-(event.location.y-15)/max(1,g.size.height-30))))}.onEnded{_ in released()})}
        .frame(minHeight:130).opacity(enabled ? 1:0.5).accessibilityElement().accessibilityLabel("Volume").accessibilityValue("\(Int(value)) of 127").accessibilityAdjustableAction{direction in guard enabled else{return};switch direction{case .increment:value=min(127,value+1);case .decrement:value=max(0,value-1);@unknown default:break};released()}
    }
}
