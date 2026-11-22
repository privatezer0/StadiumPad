import SwiftUI
import UIKit
import StadiumProtocol

/// Opens the Matrix console locally; channel editing still uses verified USB MIDI.
struct MatrixVolumeBar:View {
    @State private var showingMixer=false
    @AppStorage("matrixLastOutput") private var lastOutput=1
    let preview:Bool
    var body:some View {
        Button {showingMixer=true}label:{VStack(spacing:2){
            Image(systemName:"slider.vertical.3").font(.system(size:22,weight:.light)).foregroundStyle(.cyan)
            Text("Matrix Mixer").font(.system(size:9))
        }.frame(width:84,height:46)}.buttonStyle(.plain).accessibilityLabel("Open Matrix Mixer")
        #if DEBUG
        .task {if ProcessInfo.processInfo.arguments.contains("--show-matrix") {showingMixer=true}}
        #endif
        .sheet(isPresented:$showingMixer) {
            MatrixMixerView(initialOutput:(1...3).contains(lastOutput) ? lastOutput:1,preview:preview)
                .frame(idealWidth:1100,idealHeight:730).presentationSizing(.fitted).presentationDragIndicator(.visible)
        }
    }
}

@MainActor final class MatrixConsoleModel:ObservableObject {
    @Published var state:MatrixConsoleState?
    @Published var ready=false
    @Published var message="Reading Matrix mixer…"
    @Published var sending=false
    @Published private var gestures=MatrixGestureQueue()
    var positions:[String:Int] {gestures.positions}
    let usb=MatrixUSBMIDI()
    private var deviceID:String?
    private var channels:[Int]=[]
    private var writer:Task<Void,Never>?
    private var token=UUID(),revision=0
    private var blocked=false
    #if DEBUG
    var gestureWorkPending:Bool {writer != nil || sending || !gestures.isEmpty}
    #endif
    private var lastRequested:[String:Any]=[:]
    private var lastTransactionMilliseconds=0.0
    init(previewState:MatrixConsoleState?=nil){state=previewState;if previewState != nil {message="USB Matrix mixer · layout preview"}}
    private func report() {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["STADIUM_VERIFY"]=="1" else{return}
        let root=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
        let rows=(1...3).flatMap{output in (state?.strips(output) ?? []).map{row in ["output":output,"source":row.id,"level":row.level,"pan":row.pan,"mute":row.muted,"solo":row.solo] as [String:Any]}}
        let record:[String:Any]=["ready":ready,"sending":sending,"blocked":blocked,"message":message,"at":Date().timeIntervalSince1970,"channels":rows,"lastRequested":lastRequested,"transactionMilliseconds":lastTransactionMilliseconds,"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "","build":Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? "","usbOnline":usb.online]
        try? JSONSerialization.data(withJSONObject:record).write(to:root.appendingPathComponent("matrix-console-ui.json"),options:.atomic)
        #endif
    }
    func observe(_ monitor:StadiumMonitor)async {
        let epoch=UUID();token=epoch;ready=false;blocked=false;state=nil;gestures.reset();deviceID=nil;channels=[]
        guard monitor.connected,let product=monitor.snapshot?.product,let id=FileCompanion.deviceID(product) else{message="Connect to Stadium to read the mixer.";report();return}
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
                        if let before=state {for output in 1...3 {for row in next.strips(output) {for field in [MatrixField.level,.pan] where row.raw[field.rawValue] != before.strip(output:output,source:row.id)?.raw[field.rawValue] {gestures.externalChange("\(output):\(row.id):\(field.rawValue)")}}}}
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
        if token==epoch {ready=false;gestures.reset()}
    }
    func bind() {do{guard let deviceID else{throw ProtocolError.closed};try usb.bind(to:deviceID);retry()}catch{message=error.localizedDescription}}
    func retry(){blocked=false;revision+=1}
    func dropPending(){gestures.cancelPending()}
    func clearSolos(output:Int,monitor:StadiumMonitor){
        lastRequested=["output":output,"field":"clearSolos"];report()
        guard writer==nil,!sending,usb.online,monitor.connected,let id=deviceID else{return}
        gestures.reset();revision+=1;ready=false
        let epoch=token,connection=monitor.connectionID
        writer=Task {
            sending=true
            defer{sending=false;writer=nil;report()}
            do {
                let before=try await monitor.readMatrixConsole(),actualChannels=try await monitor.matrixChannels()
                let command=try MatrixClearSolosCommand(output:output),channel=actualChannels[output-1]
                let after=try await monitor.clearMatrixSolos(command,expected:before,channel:channel) {
                    try await MainActor.run {
                        guard self.token==epoch,monitor.connected,monitor.connectionID==connection else{throw CancellationError()}
                        try self.usb.clearSolos(command,channel:channel,networkIdentity:id)
                    }
                }
                guard token==epoch else{return};state=after;channels=actualChannels;blocked=false;ready=usb.bound(to:id);message="Solos cleared";lastRequested=["output":output,"field":"clearSolos"]
            }catch {guard token==epoch else{return};ready=false;blocked=true;message=error.localizedDescription}
        }
    }
    func stop(){token=UUID();gestures.reset();ready=false}
    func send(_ command:MatrixConsoleCommand,monitor:StadiumMonitor) {
        lastRequested=["output":command.output,"source":command.source,"field":command.field.rawValue,"value":command.value];report()
        guard ready,usb.online,channels.count==3 else{return}
        // Never coalesce toggles: MIDI mute/solo commands toggle, rather than set.
        if command.field == .mute || command.field == .solo {guard !sending,gestures.isEmpty else{return}}
        gestures.enqueue(command);revision+=1
        guard writer==nil else{return}
        let epoch=token,connection=monitor.connectionID
        writer=Task {
            sending=true
            while token==epoch,!blocked,let ticket=gestures.takeNext() {
                let command=ticket.command
                guard let before=state,let id=deviceID,channels.count==3 else{break}
                let channel=channels[command.output-1]
                do {
                    let started=Date()
                    let after=try await monitor.setMatrixConsole(command,expected:before,channel:channel) {
                        try await MainActor.run {
                            guard self.token==epoch,monitor.connected,monitor.connectionID==connection else{throw CancellationError()}
                            try self.usb.send(command,channel:channel,networkIdentity:id)
                        }
                    }
                    guard token==epoch else{break};lastTransactionMilliseconds=Date().timeIntervalSince(started)*1000;state=after;gestures.confirmed(ticket)
                }catch {guard token==epoch else{break};gestures.reset();ready=false;blocked=true;message=error.localizedDescription}
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
    @AppStorage("matrixLastOutput") private var lastOutput=1
    @State private var homeExpanded=false
    @State private var songExpanded=false
    @State private var showEQ=false
    @State private var selectingOutput=false
    @State private var previousIdleTimer:Bool?
    @State private var matrixPresentation:UUID?
    let preview:Bool
    init(initialOutput:Int,preview:Bool=false,previewState:MatrixConsoleState?=nil,expanded:Bool=false){_output=State(initialValue:initialOutput);self.preview=preview;_model=StateObject(wrappedValue:MatrixConsoleModel(previewState:previewState));_homeExpanded=State(initialValue:expanded);_songExpanded=State(initialValue:expanded)}
    private var sources:[Int] {[5]+(homeExpanded ? [1,2,3,4]:[])+[14]+(songExpanded ? Array(6...13):[])+[15,16,17,18,19]}
    private var enabled:Bool {model.ready && presence.online && !preview && !selectingOutput}
    var body:some View {
        GeometryReader {area in VStack(spacing:0) {
            HStack(spacing:12) {
                Menu {
                    Button("Clear Solos on \(MatrixGuitarLevels.labels[output-1])"){model.clearSolos(output:output,monitor:monitor)}.disabled(!presence.online || !monitor.connected || model.state==nil || model.sending)
                }label:{Image(systemName:"line.3.horizontal").foregroundStyle(.cyan).frame(width:30,height:44)}.accessibilityLabel("Matrix mixer options")
                Text("Matrix Mixer").font(.system(size:26,weight:.light))
                HStack(spacing:6){ForEach(1...3,id:\.self){n in
                    Button {Task{_ = await selectOutput(n)}}label:{Image(systemName:n==3 ? "headphones":n==2 ? "circle.dotted":"cable.connector")
                        .font(.system(size:23,weight:.light)).frame(width:48,height:42)
                        .foregroundStyle(output==n ? Color.cyan:Color.gray)
                        .background(output==n ? Color.cyan.opacity(0.13):.clear,in:RoundedRectangle(cornerRadius:7))
                    }.buttonStyle(.plain).accessibilityLabel(MatrixGuitarLevels.labels[n-1]+" Matrix output").accessibilityValue(output==n ? "Selected":"Not selected")
                }}.disabled(model.sending || selectingOutput)
                Spacer(minLength:0)
                Button {showEQ=true}label:{Label("Global EQ",systemImage:"waveform.path")}.disabled(!monitor.connected || model.sending)
                Button(selectingOutput ? "Please wait…":"Close"){closeMixer()}.disabled(selectingOutput || model.sending).fontWeight(.semibold).padding(.leading,10)
            }.padding(.horizontal,18).frame(height:64).background(EditorTheme.header)
            if let state=model.state {
                ScrollView(.horizontal) {
                    HStack(spacing:1) {ForEach(sources,id:\.self){source in
                        if let row=state.strip(output:output,source:source) {
                            MatrixChannelStrip(row:row,output:output,position:model.positions["\(output):\(source):vol_"],panPosition:model.positions["\(output):\(source):pan_"],enabled:enabled && row.enabled,togglesEnabled:!model.sending,expanded:source==5 ? homeExpanded:songExpanded,toggleExpanded:{if source==5 {homeExpanded.toggle()}else{songExpanded.toggle()}},changed:{field,value in
                                if let command=try? MatrixConsoleCommand(output:output,source:source,field:field,value:value) {model.send(command,monitor:monitor)}
                            }).frame(width:max(90,(area.size.width-24)/7))
                        }
                    }}.fixedSize(horizontal:true,vertical:false).padding(.horizontal,12).padding(.vertical,12)
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
        .onAppear{if !preview {previousIdleTimer=UIApplication.shared.isIdleTimerDisabled;UIApplication.shared.isIdleTimerDisabled=true;if matrixPresentation==nil {matrixPresentation=monitor.beginMatrixPresentation()}}}
        .interactiveDismissDisabled(!preview)
        .onDisappear{finishPresentation()}
        .onChange(of:output){_,value in model.dropPending();if !preview {lastOutput=value}}
        #if DEBUG
        .task {if !preview,ProcessInfo.processInfo.arguments.contains("--verify-matrix-panel-close") {Task{@MainActor in await verifyMatrixPanelClose(monitor,select:selectOutput,close:closeMixerAndPedal)}}}
        .task {if !preview,ProcessInfo.processInfo.arguments.contains("--verify-matrix-output-icons") {await verifyMatrixOutputIcons(monitor,select:selectOutput)}}
        .task {
            guard !preview,!nativeMatrixTestsDisarmed() else{return}
            if ProcessInfo.processInfo.arguments.contains("--verify-matrix-all") {
                if await verifyMatrixSoloRoundTrip(monitor,model:model) {_ = await verifyMatrixGestureTiming(model,monitor:monitor,close:closeMixer)}
            }else {
                if ProcessInfo.processInfo.arguments.contains("--verify-matrix-gesture") {_ = await verifyMatrixGestureTiming(model,monitor:monitor,close:closeMixer)}
                if ProcessInfo.processInfo.arguments.contains("--verify-matrix-solo-ui") {_ = await verifyMatrixSoloRoundTrip(monitor,model:model,close:closeMixer)}
            }
        }
        #endif
        .sheet(isPresented:$showEQ){NavigationStack{GlobalEQView(preview:preview,initialOutput:output==3 ? .phones:output==2 ? .xlr:.quarter).environmentObject(monitor).toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){showEQ=false}}}}}
    }
    @MainActor private func selectOutput(_ next:Int)async->Bool {
        guard !selectingOutput,!model.sending else{return false}
        guard !preview else{output=next;return true}
        selectingOutput=true;defer{selectingOutput=false}
        do {
            _ = try await navigateOutput(next,closing:false)
            model.dropPending();output=next;return true
        }catch {monitor.errorText=error.localizedDescription;return false}
    }
    @MainActor private func navigateOutput(_ requested:Int,closing:Bool)async throws->Bool {
        presence.refresh()
        guard presence.online,monitor.connected else{return false}
        let connection=monitor.connectionID
        guard let product=monitor.snapshot?.product,let id=FileCompanion.deviceID(product) else{throw ProtocolError.closed}
        if monitor.connectionRoute == .usb,monitor.connectionInterface=="USB/Ethernet",!presence.bound(to:id) {try presence.bind(to:id)}
        let target:Int
        if closing {
            let current=try await monitor.readMatrixConsole()
            guard let attached=current.property["val_"]["atto"].integer,(1...3).contains(attached) else{throw ProtocolError.invalid("The pedal's selected output is unavailable.")}
            target=attached
        }else{target=requested}
        let channel=try await monitor.matrixPanelChannel()
        guard monitor.connected,connection==monitor.connectionID else{throw CancellationError()}
        try await monitor.navigateMatrixPanel(MatrixPanelCommand(output:target,closing:closing),channel:channel) {step in
            try await MainActor.run {
                guard monitor.connected,monitor.connectionID==connection else{throw CancellationError()}
                try presence.navigate(output:step,channel:channel,networkIdentity:id)
            }
        }
        return true
    }
    private func closeMixer(){Task{_ = await closeMixerAndPedal()}}
    @MainActor private func closeMixerAndPedal()async->Bool {
        guard !selectingOutput,!model.sending else{return false}
        if preview {model.stop();dismiss();return true}
        selectingOutput=true;defer{selectingOutput=false}
        var sent=false
        do {sent=try await navigateOutput(output,closing:true)}catch{sent=false;monitor.errorText=error.localizedDescription}
        model.stop();dismiss();return sent
    }
    private func finishPresentation(){
        model.stop()
        if let previousIdleTimer {UIApplication.shared.isIdleTimerDisabled=previousIdleTimer}
        if let id=matrixPresentation {monitor.endMatrixPresentation(id);matrixPresentation=nil}
        #if DEBUG
        if !preview {recordMatrixClose(monitor,expectedIdle:previousIdleTimer)}
        #endif
    }
}

private struct MatrixChannelStrip:View {
    let row:MatrixStrip,output:Int,position:Int?,panPosition:Int?,enabled:Bool,togglesEnabled:Bool,expanded:Bool
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
            MatrixVerticalFader(value:Binding(get:{draft ?? Double(position ?? MatrixGuitarLevels.estimatedMIDI(row.level))},set:{v in draft=v;changed(.level,Int(v.rounded()))}),enabled:enabled,released:{draft=nil}).accessibilityIdentifier("matrix-fader-\(row.id)")
            HStack(spacing:4) {
                Image(systemName:row.id==5 ? "house":row.id==14 ? "music.note":row.id==15 ? "metronome":row.id==17 ? "cable.connector":row.id==18 ? "dot.radiowaves.left.and.right":"waveform").font(.system(size:15))
                if row.id==5 || row.id==14 {Button(action:toggleExpanded){Image(systemName:expanded ? "minus.circle":"plus.circle").font(.system(size:23))}.buttonStyle(.plain).accessibilityLabel("\(expanded ? "Hide":"Show") \(row.id==5 ? "Home paths":"Song tracks")")}
            }.frame(height:30)
            Text(row.id==5 ? "Home":row.id==16 ? "Count In":row.name).font(.system(size:12,weight:.medium)).lineLimit(1).minimumScaleFactor(0.7)
        }.padding(.horizontal,9).padding(.vertical,14).background(tint.opacity(row.id==5 || row.id==14 ? 0.13:0.05)).opacity(row.enabled ? 1:0.4)
        .onChange(of:output){_,_ in draft=nil;panDraft=nil;showPan=false}
        .onChange(of:enabled){_,available in if !available {draft=nil;panDraft=nil}}
        .popover(isPresented:$showPan){VStack(spacing:20){Text("\(row.name) · Pan").font(.headline);Slider(value:Binding(get:{panDraft ?? Double(panPosition ?? (try? MatrixPan.midi(forValue:row.pan)) ?? 64)},set:{panDraft=$0;changed(.pan,Int($0.rounded()))}),in:0...127,step:1,onEditingChanged:{active in if !active {panDraft=nil}}).frame(width:260).disabled(!enabled);HStack{Text("Left");Spacer();Button("Center"){panDraft=64;changed(.pan,64)};Spacer();Text("Right")};Button("Done"){showPan=false}}.padding(24).presentationCompactAdaptation(.popover)}
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
        }.overlay{MatrixFaderTouchSurface(value:$value,enabled:enabled,released:released)}}
        .frame(minHeight:130).opacity(enabled ? 1:0.5).accessibilityElement().accessibilityLabel("Volume").accessibilityValue("\(Int(value)) of 127").accessibilityAdjustableAction{direction in guard enabled else{return};switch direction{case .increment:value=min(127,value+1);case .decrement:value=max(0,value-1);@unknown default:break};released()}
    }
}

/// UIKit can fail the horizontal pan before it competes with the enclosing scroll.
private struct MatrixFaderTouchSurface:UIViewRepresentable {
    @Binding var value:Double
    let enabled:Bool,released:()->Void
    func makeCoordinator()->Coordinator {Coordinator(self)}
    func makeUIView(context:Context)->UIView {
        let view=UIView();view.backgroundColor = .clear
        let pan=UIPanGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.pan(_:)))
        pan.maximumNumberOfTouches=1;pan.delegate=context.coordinator
        let tap=UITapGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.tap(_:)))
        tap.delegate=context.coordinator
        view.addGestureRecognizer(pan);view.addGestureRecognizer(tap)
        return view
    }
    func updateUIView(_ view:UIView,context:Context){context.coordinator.parent=self;view.isUserInteractionEnabled=enabled}
    final class Coordinator:NSObject,UIGestureRecognizerDelegate {
        var parent:MatrixFaderTouchSurface
        init(_ parent:MatrixFaderTouchSurface){self.parent=parent}
        func gestureRecognizerShouldBegin(_ recognizer:UIGestureRecognizer)->Bool {
            guard parent.enabled else{return false}
            guard let pan=recognizer as? UIPanGestureRecognizer else{return true}
            let velocity=pan.velocity(in:pan.view)
            return abs(velocity.y)>abs(velocity.x)
        }
        private func update(_ recognizer:UIGestureRecognizer){
            guard parent.enabled,let view=recognizer.view else{return}
            parent.value=min(127,max(0,127*(1-(recognizer.location(in:view).y-15)/max(1,view.bounds.height-30))))
        }
        @objc func pan(_ recognizer:UIPanGestureRecognizer){
            switch recognizer.state {
            case .began,.changed:update(recognizer)
            case .ended:parent.released()
            case .cancelled,.failed:parent.released()
            default:break
            }
        }
        @objc func tap(_ recognizer:UITapGestureRecognizer){guard recognizer.state == .ended else{return};update(recognizer);parent.released()}
    }
}

#if DEBUG
/// Synthetic local controls for native swipe tests. No monitor, session or MIDI sender.
struct MatrixScrollHarness:View {
    @State private var homeExpanded=false
    @State private var songExpanded=false
    @State private var positions:[Int:Int]=[:]
    @State private var changes=0
    private var sources:[Int] {[5]+(homeExpanded ? [1,2,3,4]:[])+[14]+(songExpanded ? Array(6...13):[])+[15,16,17,18,19]}
    private func row(_ id:Int)->MatrixStrip {
        let names=[5:"Home",14:"Song",15:"Click",16:"Count In",17:"USB 1/2",18:"Bluetooth",19:"AUX In"]
        let name=names[id] ?? (id<5 ? "Path \(id)":"Track \(id-5)")
        return try! MatrixStrip(.object(["src_":.int(Int64(id)),"name":.string(name),"enbl":.int(1),"vol_":.number(0),"pan_":.number(0),"mute":.bool(false),"solo":.bool(false)]))
    }
    var body:some View {
        GeometryReader{area in VStack {
            Text("Matrix scrolling verification").font(.title2)
            Text("Changes: \(changes)").accessibilityIdentifier("matrix-qa-changes")
            ScrollView(.horizontal){HStack(spacing:1){ForEach(sources,id:\.self){source in
                MatrixChannelStrip(row:row(source),output:3,position:positions[source],panPosition:nil,enabled:source != 16,togglesEnabled:true,expanded:source==5 ? homeExpanded:songExpanded,toggleExpanded:{if source==5 {homeExpanded.toggle()}else{songExpanded.toggle()}},changed:{field,value in
                    changes+=1;if field == .level {positions[source]=value}
                }).frame(width:max(90,(area.size.width-24)/7))
            }}.fixedSize(horizontal:true,vertical:false).padding(.horizontal,12).padding(.vertical,12)}.accessibilityIdentifier("matrix-qa-scroll")
        }}.background(.black).foregroundStyle(.white).preferredColorScheme(.dark)
    }
}
#endif
