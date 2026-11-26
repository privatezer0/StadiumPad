import SwiftUI
import StadiumProtocol
import StadiumNetwork
import UIKit

@main struct StadiumPadApp:App {
    @StateObject private var monitor=StadiumMonitor()
    @StateObject private var discovery=StadiumDiscovery()
    @Environment(\.scenePhase) private var phase
    var body:some Scene {WindowGroup {
        Group {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--preset-folder-harness") {PresetFolderHarness()}else if ProcessInfo.processInfo.arguments.contains("--matrix-scroll-harness") {MatrixScrollHarness()}else{StadiumView()}
            #else
            StadiumView()
            #endif
        }.environmentObject(monitor).environmentObject(discovery).preferredColorScheme(.dark)
            .onAppear{UIApplication.shared.isIdleTimerDisabled=true}
            .onChange(of:phase){_,value in
                if value == .background {UIApplication.shared.isIdleTimerDisabled=false;discovery.stop();monitor.pauseForBackground()}
                else if value == .active {UIApplication.shared.isIdleTimerDisabled=true;monitor.resumeFromBackground()}
            }
    }}
}
struct StadiumView:View {
    @EnvironmentObject var monitor:StadiumMonitor
    @EnvironmentObject var discovery:StadiumDiscovery
    @AppStorage("stadiumHost") private var address=""
    @AppStorage("followStadiumSelection") private var followExternal=true
    @State private var localSelectionAt=Date.distantPast
    @State private var blocksPresetID:Int?
    @State private var selected:BlockSelection?
    @State private var showConnection=false
    @AppStorage("stadiumConnectionRoute") private var connectionRoute:StadiumConnectionRoute = .automatic
    @StateObject private var usbDiscovery=USBStadiumDiscovery()
    @StateObject private var bridgeSettings=PedalBridgeSettings()
    @StateObject private var bridgeDiscovery=StadiumDiscovery(serviceType:"_pedalbridge._tcp.")
    @State private var bridgeLink=""
    @ObservedObject private var bluetoothHelpers=BluetoothEditorHub.shared
    @State private var choosingHelper=false
    @State private var bridgePreferencesTab=false
    @State private var showSave=false
    @State private var saveID:Int?
    @State private var saveLabel=""
    @State private var showCopy=false
    @State private var copyName=""
    @State private var copySourceID:Int?
    @State private var libraryRevision=0
    @State private var pendingCompanionLink:String?
    @State private var libraryLinkRevision=UUID()
    @State private var section:EditorSection = .home
    @State private var showInfo=false
    @State private var mode:EditorMode = .preset
    @State private var showAcknowledgments=false
    @State private var showFocus=false
    @State private var showModels=false
    @State private var pendingModel:ModelDefinition?
    @State private var pendingSelection:BlockSelection?
    @State private var showReplace=false
    let preview:Bool
    let libraryCategory:LibraryCategory
    init(initialSelection:BlockSelection?=nil,preview:Bool=false,initialSection:EditorSection = .home,initialMode:EditorMode = .preset,initialFocus:Bool=false,initialLibraryCategory:LibraryCategory = .presets) {_showFocus=State(initialValue:initialFocus);_mode=State(initialValue:initialMode);_selected=State(initialValue:initialSelection);_section=State(initialValue:initialSection);self.preview=preview;self.libraryCategory=initialLibraryCategory}
    var body:some View {
        GeometryReader {geometry in
            VStack(spacing:0) {
                header
                if section == .librarian {
                    Text("Librarian").font(.system(size:28,weight:.light)).frame(maxWidth:.infinity).frame(height:58).background(EditorTheme.header)
                } else if section != .commands && section != .eq {presetBar(compact:geometry.size.width<1150)}
                HStack(spacing:0) {
                    if section != .librarian && section != .commands && section != .eq {PresetSidebar(refreshID:libraryRevision).frame(width:max(190,min(290,geometry.size.width*0.245)))}
                    Group {
                        if section == .home {
                            if let state=monitor.snapshot {
                                switch mode {
                                case .tuner:TunerBoard(exit:{selectSection(.home)})
                                case .scene:SceneBoard(state:state).id(state.origin)
                                case .footswitch:FootswitchBoard(state:state).id(state.origin)
                                case .preset:
                                    VStack(spacing:0) {
                                        Group {
                                            if showFocus,let selected {FocusSurfaceView(selection:selected,close:{showFocus=false}).id(selected.focusIdentity)}
                                            else {SignalChainView(state:state,selected:selected,select:select)}
                                        }.frame(height:max(showFocus ? 210:155,min(300,(geometry.size.height-150)*0.37)))
                                        Rectangle().fill(EditorTheme.border).frame(height:1)
                                        HStack(spacing:0) {
                                            if geometry.size.width>=1000 {ModelBrowser(selection:selected,choose:prepareReplacement).frame(width:min(360,(geometry.size.width-max(190,min(290,geometry.size.width*0.245)))*0.35))}
                                            InlineBlockEditor(selection:selected,select:select,browse:{showModels=true},focusShown:showFocus,toggleFocus:{showFocus.toggle()})
                                        }
                                    }
                                }
                            } else {
                                VStack(spacing:18) {Image(systemName:"waveform.path").font(.system(size:42,weight:.ultraLight));Text("Your Stadium, on your iPad").font(.title2);Button("Connect to Stadium"){showConnection=true}.buttonStyle(.borderedProminent)}.foregroundStyle(.secondary).frame(maxWidth:.infinity,maxHeight:.infinity)
                            }
                        } else if section == .librarian {LibrarianView(openEditor:{section = .home},pairingLink:pendingCompanionLink,initialCategory:libraryCategory).id(libraryLinkRevision).onAppear{pendingCompanionLink=nil}}
                        else if section == .commands {CommandCenterView(preview:preview)}
                        else if section == .eq {GlobalEQView(preview:preview)}
                        else if section == .songs {LibraryRows(title:"Songs",entries:(monitor.libraryEntries[-7] ?? []).filter{$0.type==4},canOpen:false).overlay(alignment:.bottom){Text("Showcase editing and transport are not connected yet").font(.caption).padding(10).background(.black)}}
                        else {SectionStatusView(section:section)}
                    }.frame(maxWidth:.infinity,maxHeight:.infinity)
                }.frame(maxWidth:.infinity,maxHeight:.infinity)
                HStack(spacing:8) {
                    Circle().fill(monitor.connected ? .green:.orange).frame(width:5,height:5)
                    Text(monitor.busy ? "Updating Stadium…":monitor.lastAction ?? monitor.status).lineLimit(1)
                    Spacer(minLength:4)
                    if monitor.snapshot?.dirty==true {Text("UNSAVED").foregroundStyle(.orange)}
                    Text("STADIUMPAD").tracking(1).foregroundStyle(.gray)
                }.font(.system(size:10)).padding(.horizontal,12).frame(height:22).background(Color(white:0.08))
            }.background(.black).foregroundStyle(.white)
        }
        #if DEBUG
        .task {if ProcessInfo.processInfo.arguments.contains("--show-connection") {showConnection=true}}
        .task {if ProcessInfo.processInfo.arguments.contains("--verify-bridge-resume") {await verifyBridgeResume(monitor)}}
        .task {if ProcessInfo.processInfo.arguments.contains("--verify-bluetooth") {await verifyBluetooth(monitor,settings:bridgeSettings)}}
        .task {if ProcessInfo.processInfo.arguments.contains("--verify-read-timing") {await verifyReadTiming(monitor)}}
        #endif
        .onOpenURL {url in
            if url.scheme=="pedalbridge" {do{try bridgeSettings.configure(url.absoluteString);connectionRoute = .bridge;showConnection=true}catch{monitor.errorText=error.localizedDescription};return}
            guard url.scheme=="stadiumpad",url.host=="companion" else{return}
            pendingCompanionLink=url.absoluteString;libraryLinkRevision=UUID();section = .librarian
        }
        .sheet(isPresented:$showAcknowledgments){AcknowledgmentsView()}
        .sheet(isPresented:$showModels){ModelBrowser(selection:selected,choose:{model in showModels=false;prepareReplacement(model)}).preferredColorScheme(.dark)}
        .confirmationDialog("Replace this block with \(pendingModel?.name ?? "the selected model")?",isPresented:$showReplace,titleVisibility:.visible) {
            Button("Replace Model") {if let pendingSelection,let pendingModel {Task {if let block=await monitor.replace(context:pendingSelection.context,destination:pendingModel) {select(block)}}}}
        } message:{Text("The new model starts with its own settings. The current preset is backed up before replacement; choose Save to keep the change.")}
        .popover(isPresented:$showInfo){presetInfo.frame(width:360).padding(20).presentationCompactAdaptation(.popover)}
        .popover(isPresented:$showConnection,arrowEdge:.top){connection.frame(width:420).padding(20).presentationCompactAdaptation(.popover)}
        .confirmationDialog("Save changes to \(saveLabel)?",isPresented:$showSave,titleVisibility:.visible) {
            Button("Save Preset"){if let saveID {Task {await monitor.save(expectedID:saveID)}}}
        } message:{Text("The previous saved contents are backed up locally.")}
        .alert("Save a new copy",isPresented:$showCopy) {
            TextField("Preset name",text:$copyName)
            Button("Cancel",role:.cancel){}
            Button("Save Copy"){Task {await monitor.copy(name:copyName,expectedID:copySourceID);libraryRevision+=1;chooseInitialBlock()}}
        } message:{Text("Creates a verified copy in an empty User location and opens it.")}
        .alert("StadiumPad",isPresented:Binding(get:{monitor.errorText != nil},set:{if !$0 {monitor.errorText=nil}})) {Button("OK"){monitor.errorText=nil}} message:{Text(monitor.errorText ?? "")}
        .onChange(of:mode){old,new in
            guard !preview else{return}
            if old == .tuner || new == .tuner {Task {await monitor.setTuner(new == .tuner)}}
        }
        .onChange(of:section){_,new in if new != .home && mode == .tuner {mode = .preset}}
        .onChange(of:monitor.connectionID){_,_ in mode = .preset;showFocus=false;selected=nil;pendingSelection=nil;pendingModel=nil;showSave=false;showCopy=false;showReplace=false;showModels=false;saveID=nil;copySourceID=nil;blocksPresetID=nil}
        .onChange(of:monitor.snapshot?.presetID){_,_ in chooseInitialBlock()}
        .onChange(of:monitor.snapshot?.activeSnapshot){_,_ in chooseInitialBlock()}
        .onChange(of:monitor.snapshot?.blocks){old,new in reconcileSelection(old:old ?? [],new:new ?? [])}
        .onChange(of:monitor.focusedBlock){_,focus in
            guard followExternal,let focus else{return}
            Task {@MainActor in
                await Task.yield()
                guard followExternal,monitor.focusedBlock?.id==focus.id,focus.receivedAt>localSelectionAt,let state=monitor.snapshot else{return}
                let slot=selected?.context.path==focus.path && selected?.context.position==focus.position ? (selected?.context.slot ?? 0):0
                let block=state.blocks.first{$0.path-1==focus.path && $0.position==focus.position && $0.slot==slot}
                if let block {applySelection(block,remember:false)}
            }
        }
        .onChange(of:monitor.lastCopy?.preset.contentID){_,_ in libraryRevision+=1}
        .task(id:monitor.connected){if monitor.connected,!preview {do {try await monitor.refreshInventory()}catch is CancellationError {}catch {if monitor.connected && !Task.isCancelled {monitor.errorText=error.localizedDescription}}}}
        .task {
            guard !preview else{return}
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--connect-pedalbridge") {
                let file=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("pedalbridge-pair-private.txt")
                do {let link=try String(contentsOf:file,encoding:.utf8);try bridgeSettings.configure(link);try FileManager.default.removeItem(at:file);connectionRoute = .bridge}catch{monitor.errorText="Could not load the private PedalBridge test pairing.";return}
            }
            #endif
            let host=ProcessInfo.processInfo.environment["STADIUM_DEVICE_HOST"] ?? address
            #if DEBUG
            if let route=ProcessInfo.processInfo.environment["STADIUM_CONNECTION_ROUTE"],let selectedRoute=StadiumConnectionRoute(rawValue:route) {connectionRoute=selectedRoute}
            #endif
            if ProcessInfo.processInfo.arguments.contains("--verify-bluetooth") {return}
            if connectionRoute == .bridge {
                if let pair=bridgeSettings.pair,pair.bluetooth {monitor.connect(host:pair.host,route:.bridge,bridgePair:pair)}else{monitor.status="Choose a nearby PedalBridge.";showConnection=true}
            }else if connectionRoute == .usb {
                usbDiscovery.search()
                for _ in 0..<50 {if !usbDiscovery.devices.isEmpty || Task.isCancelled {break};try? await Task.sleep(for:.milliseconds(150))}
                if !Task.isCancelled,let device=usbDiscovery.devices.first {address=device.host;monitor.connect(host:device.host,port:device.port,route:.usb,interface:device.interface)}
                else if !Task.isCancelled {monitor.status="No USB Stadium found. Check the cable and search again."}
                usbDiscovery.stop()
            } else if !host.isEmpty {address=host;monitor.connect(host:host,route:connectionRoute)}
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--verify-tuner-navigation") || ProcessInfo.processInfo.arguments.contains("--capture-matrix-layout") || ProcessInfo.processInfo.arguments.contains("--verify-matrix-solo") || ProcessInfo.processInfo.arguments.contains("--verify-matrix-pan") || ProcessInfo.processInfo.arguments.contains("--show-matrix") || ProcessInfo.processInfo.arguments.contains("--prepare-usb-spares") || ProcessInfo.processInfo.arguments.contains("--inspect-usb-matrix") || ProcessInfo.processInfo.arguments.contains("--verify-global-eq-stream") || ProcessInfo.processInfo.arguments.contains("--show-global-eq") || ProcessInfo.processInfo.arguments.contains("--verify-global-eq") || ProcessInfo.processInfo.arguments.contains("--verify-command-center") || ProcessInfo.processInfo.arguments.contains("--verify-library-backup") || ProcessInfo.processInfo.arguments.contains("--verify-clones") || ProcessInfo.processInfo.arguments.contains("--verify-selection-memory") || ProcessInfo.processInfo.arguments.contains("--verify-live-sync") || ProcessInfo.processInfo.arguments.contains("--verify-discard") || ProcessInfo.processInfo.arguments.contains("--verify-focus") || ProcessInfo.processInfo.arguments.contains("--verify-reorder-resume") || ProcessInfo.processInfo.arguments.contains("--verify-reorder") || ProcessInfo.processInfo.arguments.contains("--verify-tuner") || ProcessInfo.processInfo.arguments.contains("--verify-performance") || ProcessInfo.processInfo.arguments.contains("--verify-spare-edit") || ProcessInfo.processInfo.arguments.contains("--verify-layout") || ProcessInfo.processInfo.arguments.contains("--verify-models") {
                for _ in 0..<70 {if monitor.connected {break};try? await Task.sleep(for:.milliseconds(200))}
                if ProcessInfo.processInfo.arguments.contains("--prepare-usb-spares") {await prepareUSBSpareChecks(monitor)}
                if ProcessInfo.processInfo.arguments.contains("--inspect-usb-matrix") {await inspectUSBConnections(monitor)}
                if ProcessInfo.processInfo.arguments.contains("--capture-matrix-layout") {await captureMatrixLayouts(monitor)}
                if ProcessInfo.processInfo.arguments.contains("--verify-matrix-pan") {await verifyMatrixPanTiming(monitor)}
                if ProcessInfo.processInfo.arguments.contains("--verify-matrix-solo") {_ = await verifyMatrixSoloRoundTrip(monitor)}
                if ProcessInfo.processInfo.arguments.contains("--show-global-eq") {section = .eq;await monitor.refreshGlobalEQ();await captureGlobalEQLayouts(monitor:monitor,discovery:discovery)}
                if ProcessInfo.processInfo.arguments.contains("--show-command-center") {section = .commands}
                if ProcessInfo.processInfo.arguments.contains("--verify-spare-edit") {
                    let plan=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("spare-plan.json")
                    await verifySpareEditing(monitor,planURL:plan)
                }
                if ProcessInfo.processInfo.arguments.contains("--verify-global-eq-stream") {section = .eq;await verifyGlobalEQStream(monitor)}
                if ProcessInfo.processInfo.arguments.contains("--verify-global-eq") {section = .eq;await verifyGlobalEQ(monitor);await captureGlobalEQLayouts(monitor:monitor,discovery:discovery)}
                if ProcessInfo.processInfo.arguments.contains("--verify-command-center") {section = .commands;await verifyCommandCenter(monitor)}
                if ProcessInfo.processInfo.arguments.contains("--verify-clones") {await verifyCloneLibrary(monitor)}
                if ProcessInfo.processInfo.arguments.contains("--verify-library-backup") {await verifyLibraryBackup(monitor)}
                if ProcessInfo.processInfo.arguments.contains("--verify-selection-memory") {try? await Task.sleep(for:.milliseconds(400));await verifyRememberedSelection(monitor,selection:{selected})}
                if ProcessInfo.processInfo.arguments.contains("--verify-live-sync") {await verifyLiveSelection(monitor,selection:{selected})}
                if ProcessInfo.processInfo.arguments.contains("--verify-discard") {await verifyDiscard(monitor)}
                if ProcessInfo.processInfo.arguments.contains("--verify-focus") {await verifyFocus(monitor)}
                if ProcessInfo.processInfo.arguments.contains("--verify-models") {await verifyModelAndSnapshots(monitor)}
                if ProcessInfo.processInfo.arguments.contains("--verify-performance") {await verifyPerformance(monitor)}
                if ProcessInfo.processInfo.arguments.contains("--verify-reorder-resume") {await verifyReorder(monitor,resume:true)}
                else if ProcessInfo.processInfo.arguments.contains("--verify-reorder") {await verifyReorder(monitor)}
                if ProcessInfo.processInfo.arguments.contains("--verify-tuner-navigation") {
                    await verifyTunerNavigation(monitor:monitor,chooseMode:selectMode,chooseSection:selectSection,currentMode:{mode},currentSection:{section})
                }
                if ProcessInfo.processInfo.arguments.contains("--verify-tuner") {
                    await monitor.setTuner(true)
                    let opened=monitor.errorText==nil
                    let openError=monitor.errorText ?? ""
                    await monitor.setTuner(false)
                    let report:[String:Any] = ["openAcknowledged":opened,"openError":openError,"exitAcknowledged":monitor.errorText==nil,"exitError":monitor.errorText ?? "","pitchReadingsAvailable":false]
                    let url=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("tuner-verification.json")
                    try? JSONSerialization.data(withJSONObject:report).write(to:url,options:.atomic)
                }
                if !ProcessInfo.processInfo.arguments.contains("--verify-live-sync") {chooseInitialBlock()}
                try? await Task.sleep(for:.seconds(1))
                if !ProcessInfo.processInfo.arguments.contains("--show-matrix") || ProcessInfo.processInfo.arguments.contains("--verify-layout") {await captureEditorLayouts(monitor:monitor,discovery:discovery,selection:selected)}
            }
#endif
        }
    }
    private func selectSection(_ item:EditorSection) {
        // Home is already selected while tuning, so a section change alone would
        // never fire its observer. Explicitly leave tuner for every main button.
        if mode == .tuner {mode = .preset}
        section=item
    }
    private func selectMode(_ item:EditorMode) {
        let reopenTuner = mode == .tuner && item == .tuner
        section = .home
        mode=item
        if reopenTuner,!preview {Task {await monitor.setTuner(true)}}
    }
    private var header:some View {
        GeometryReader {geometry in
            ZStack {
                HStack(spacing:10) {
                    MatrixVolumeBar(preview:preview,beforeOpen:{if mode == .tuner {selectSection(.home)}})
                    Rectangle().fill(EditorTheme.border).frame(width:1,height:36)
                    HStack(spacing:2) {ForEach(EditorSection.allCases,id:\.self) {item in
                        navigationButton(item.rawValue,icon:item.icon,width:item == .commands ? 69:50,selected:section==item) {selectSection(item)}
                    }}
                    Rectangle().fill(EditorTheme.border).frame(width:1,height:36)
                    HStack(spacing:2) {ForEach(EditorMode.allCases,id:\.self) {item in
                        navigationButton(item.rawValue,icon:item.icon,width:item == .footswitch ? 58:44,footPedal:item == .footswitch,selected:section == .home && mode==item) {
                            selectMode(item)
                        }
                    }}
                }.fixedSize(horizontal:true,vertical:false)
                // The mode group is 112 points wider than Matrix Mixer. Compensate
                // so Home through Songs stay at the screen center, with adjacent flanks.
                .offset(x:56)
                HStack(spacing:10) {
                    if geometry.size.width>=1250 {Text("StadiumPad").font(.headline)}
                    Spacer(minLength:0)
                    Button {showConnection=true} label:{
                        VStack(spacing:3) {
                            if monitor.tabletTransport=="Bluetooth" {BluetoothConnectionGlyph().stroke(lineWidth:2).frame(width:18,height:22)}
                            else {Image(systemName:monitor.tabletTransport=="USB" ? "cable.connector":monitor.tabletTransport=="Wi-Fi" ? "wifi":"circle.slash").font(.system(size:20)).frame(height:22)}
                            Text(monitor.tabletTransport).font(.system(size:9)).lineLimit(1)
                        }.frame(width:76,height:52)
                    }.accessibilityLabel(monitor.tabletTransport+" connection").accessibilityValue(monitor.connected ? "Connected":"No connection").buttonStyle(.plain).foregroundStyle(monitor.connected ? Color.green:Color.orange)
                }
            }.padding(.horizontal,12).frame(maxWidth:.infinity,maxHeight:.infinity)
        }.frame(height:66).background(EditorTheme.header)
    }
    private func navigationButton(_ title:String,icon:String,width:CGFloat,footPedal:Bool=false,selected:Bool,action:@escaping ()->Void)->some View {
        Button(action:action) {VStack(spacing:2) {
            if footPedal {FootPressIcon().frame(width:24,height:24)}
            else {Image(systemName:icon).font(.system(size:20,weight:.light)).frame(height:24)}
            Text(title).font(.system(size:9)).lineLimit(1).minimumScaleFactor(0.75)
        }.frame(width:width,height:46).foregroundStyle(selected ? .white:.gray).background(selected ? .white.opacity(0.055):.clear,in:RoundedRectangle(cornerRadius:5))}
        .buttonStyle(.plain).accessibilityLabel(title).accessibilityAddTraits(selected ? [.isSelected]:[])
    }
    private func presetBar(compact:Bool)->some View {
        VStack(spacing:0) {
            GeometryReader {geometry in
                ZStack {
                    HStack(spacing:8) {
                        Text(monitor.snapshot?.location.label ?? "—").font(.title3.monospacedDigit().bold()).foregroundStyle(EditorTheme.gold)
                        Text(monitor.snapshot?.presetName ?? "No preset loaded").font(.title3.weight(.medium)).lineLimit(1).frame(maxWidth:.infinity,alignment:.leading)
                        if monitor.snapshot?.dirty==true {Circle().fill(.orange).frame(width:6,height:6)}
                        Spacer()
                        Button {showInfo=true} label:{Image(systemName:"info.circle").font(.title3).frame(width:40,height:38)}.accessibilityLabel("Preset information")
                        Button {prepareSave()} label:{SaveDiskIcon().frame(width:40,height:38)}.accessibilityLabel("Save Preset").disabled(!monitor.connected || monitor.busy)
                    }
                }.frame(maxWidth:.infinity,maxHeight:.infinity)
            }.frame(height:56)
            HStack {presetActions;Spacer()}.frame(height:40)
        }.buttonStyle(.plain).padding(.horizontal,14).background(EditorTheme.header).overlay(alignment:.bottom){Rectangle().fill(EditorTheme.border).frame(height:1)}
    }
    private var presetActions:some View {
        let displayed=monitor.snapshot
        return HStack(spacing:8) {
            Button {stepPreset(-1)} label:{Image(systemName:"chevron.left").frame(width:24,height:34)}.disabled(!canStep(-1)).accessibilityLabel("Previous preset")
            Button {stepPreset(1)} label:{Image(systemName:"chevron.right").frame(width:24,height:34)}.disabled(!canStep(1)).accessibilityLabel("Next preset")
            Menu {
                ForEach(monitor.snapshot?.snapshots ?? []) {choice in Button {Task {await monitor.activate(choice.id,expectedID:displayed?.presetID,expectedSnapshot:displayed?.activeSnapshot)}} label:{Label(choice.name,systemImage:choice.id==monitor.snapshot?.activeSnapshot ? "checkmark.circle.fill":"circle")}.disabled(!choice.defined || monitor.busy || !monitor.connected)}
            } label:{HStack(spacing:5) {Image(systemName:"square.stack");Text("\((monitor.snapshot?.activeSnapshot ?? 0)+1) · \(monitor.snapshot?.snapshots.first{$0.id==monitor.snapshot?.activeSnapshot}?.name ?? "Snapshot")").lineLimit(1);Image(systemName:"chevron.down").font(.caption2)}.font(.callout).padding(.horizontal,8).frame(maxWidth:180).frame(height:34).background(.black.opacity(0.35),in:RoundedRectangle(cornerRadius:5))}.accessibilityLabel("Select snapshot")
            Button {prepareCopy()} label:{Image(systemName:"doc.on.doc").frame(width:32,height:34)}.accessibilityLabel("Save Copy").disabled(!monitor.connected || monitor.busy)
        }
    }
    private var connection:some View {
        VStack(alignment:.leading,spacing:16) {
            Text("Stadium connection").font(.title2.bold())
            Text(monitor.status).font(.callout)
            if monitor.connected || monitor.connecting || monitor.reconnectingBridge {Button("Disconnect"){monitor.stop()}.buttonStyle(.bordered).disabled(monitor.busy)}
            Picker("Connection",selection:$connectionRoute){ForEach(StadiumConnectionRoute.allCases,id:\.self){Text($0.rawValue).tag($0)}}.pickerStyle(.segmented)
            if connectionRoute == .bridge {
                Picker("PedalBridge settings",selection:$bridgePreferencesTab){Text("Connection").tag(false);Text("PedalBridge").tag(true)}.pickerStyle(.segmented).accessibilityIdentifier("pedalbridge-settings-tabs")
                if bridgePreferencesTab,let pair=bridgeSettings.pair {
                    PedalBridgePreferences(pair:pair,restarting:{monitor.waitForHelperRestart()})
                }else{
                Text("Choose a nearby PedalBridge. Your tablet can stay on home Wi-Fi.").font(.callout)
                Button("Find PedalBridge over Bluetooth"){bluetoothHelpers.search()}
                Text(bluetoothHelpers.message).font(.caption)
                ScrollView {VStack(alignment:.leading,spacing:8){ForEach(bluetoothHelpers.helpers){helper in
                    Button {Task {choosingHelper=true;defer{choosingHelper=false}
                        do {monitor.stop();let pair=try await PedalBridgeConnection.automaticBluetooth(helper.id);try bridgeSettings.configure(pair);monitor.connect(host:pair.host,route:.bridge,bridgePair:pair);showConnection=false}
                        catch{monitor.errorText=error.localizedDescription}
                    }} label:{Label(helper.name,systemImage:"antenna.radiowaves.left.and.right").frame(maxWidth:.infinity,alignment:.leading)}.buttonStyle(.bordered).disabled(choosingHelper)
                }}}.frame(maxHeight:190).task{bluetoothHelpers.search()}.onDisappear{bluetoothHelpers.stopSearch()}
                if choosingHelper {ProgressView("Connecting…")}
                if let pair=bridgeSettings.pair,pair.bluetooth {Button("Reconnect last PedalBridge"){monitor.connect(host:pair.host,route:.bridge,bridgePair:pair);showConnection=false}.disabled(choosingHelper || monitor.busy)}
                Text("Matrix requires Stadium connected to PedalBridge by USB.").font(.caption)
                }

            } else {
            TextField("Stadium address",text:$address).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
            HStack {
                Button(connectionRoute == .usb ? "Find USB Stadium":(monitor.connected ? "Switch to Address":"Connect")) {if connectionRoute == .usb {usbDiscovery.search()}else{discovery.stop();monitor.connect(host:address.trimmingCharacters(in:.whitespacesAndNewlines),route:connectionRoute);showConnection=false}}.buttonStyle(.borderedProminent).disabled(monitor.busy || (connectionRoute != .usb && address.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty))
                Button(discovery.searching ? "Searching…":(connectionRoute == .usb ? "Search USB":"Search Network")){if connectionRoute == .usb {usbDiscovery.search()}else{discovery.search()}}.disabled(discovery.searching || monitor.busy)
            }
            ScrollView {VStack(alignment:.leading,spacing:12) {ForEach(connectionRoute == .usb ? usbDiscovery.devices:discovery.devices){device in Button {address=device.host;discovery.stop();usbDiscovery.stop();monitor.connect(host:device.host,port:device.port,route:connectionRoute,interface:device.interface);showConnection=false} label:{Label(device.id,systemImage:device.host==monitor.currentHost ? "checkmark.circle.fill":"hifispeaker")}.disabled(monitor.busy)}}}.frame(maxHeight:180)
            if connectionRoute == .usb {Text(usbDiscovery.message).font(.caption).foregroundStyle(.secondary)}
            if let error=discovery.error {Text(error).font(.caption).foregroundStyle(.orange)}
            if discovery.devices.isEmpty,!discovery.searching {Text("Search for Stadium devices or enter a hostname/IP address.").font(.caption).foregroundStyle(.secondary)}
            }
            Toggle("Follow the selected block on Stadium",isOn:$followExternal)
            Button("About StadiumPad & Acknowledgments"){showConnection=false;showAcknowledgments=true}
            Text(connectionRoute == .usb ? "Connect Stadium directly by USB-C, enable Remote Access, then Search Network and choose its hostname. USB mode requires the cable and never falls back to Wi-Fi.":"Use the same local network with Remote Access enabled.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private var presetInfo:some View {
        VStack(alignment:.leading,spacing:14) {Text("Preset information").font(.title2.bold());Text("\(monitor.snapshot?.location.label ?? "") · \(monitor.snapshot?.presetName ?? "No preset")").font(.headline);Text("Firmware \(monitor.snapshot?.firmware ?? "—")");Text(monitor.snapshot?.dirty==true ? "Unsaved changes":"Saved").foregroundStyle(monitor.snapshot?.dirty==true ? .orange:.green);Text("Previous saved and live preset data are backed up locally before edits.").font(.caption).foregroundStyle(.secondary)}
    }
    private func prepareCopy() {copySourceID=monitor.snapshot?.presetID;copyName=String((monitor.snapshot?.presetName ?? "Preset").prefix(25))+" Copy";showCopy=true}
    private func prepareSave() {guard let state=monitor.snapshot else{return};if !state.location.writable {prepareCopy();return};saveID=state.presetID;saveLabel="\(state.location.label) · \(state.presetName)";showSave=true}
    private func canStep(_ step:Int)->Bool {guard monitor.connected,!monitor.busy,monitor.snapshot?.dirty==false,let index=monitor.presets.firstIndex(where:{$0.contentID==monitor.snapshot?.presetID}) else{return false};return monitor.presets.indices.contains(index+step)}
    private func stepPreset(_ step:Int) {guard canStep(step),let index=monitor.presets.firstIndex(where:{$0.contentID==monitor.snapshot?.presetID}) else{return};let preset=monitor.presets[index+step];Task {_ = await monitor.load(preset)}}
    private func prepareReplacement(_ model:ModelDefinition) {guard let selected,selected.context.modelID != model.id else{return};pendingSelection=selected;pendingModel=model;showReplace=true}
    private func select(_ block:SignalBlock) {
        guard preview || !monitor.busy else{return}
        localSelectionAt=Date();applySelection(block)
        if !preview,let context=selected?.context {Task {await monitor.selectBlock(context:context)}}
    }
    private func applySelection(_ block:SignalBlock,remember:Bool=true) {
        guard let state=monitor.snapshot,let context=try? state.context(for:block) else{return}
        let selection=BlockSelection(block:block,context:context);selected=selection
        if remember && !preview {monitor.rememberSelection(block,in:state)}
#if DEBUG
        if !preview,ProcessInfo.processInfo.environment["STADIUM_VERIFY"]=="1" {
            let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
            let report:[String:Any] = ["model":block.model,"name":monitor.blockName(block),"category":monitor.catalog[String(block.model)]?.browserCategory ?? "","path":block.path-1,"position":block.position,"slot":block.slot,"at":Date().timeIntervalSince1970]
            try? JSONSerialization.data(withJSONObject:report,options:.prettyPrinted).write(to:folder.appendingPathComponent("ui-selection.json"),options:.atomic)
            Task {@MainActor in
                try? await Task.sleep(for:.milliseconds(250))
                guard selected?.id==selection.id,let window=UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).flatMap({$0.windows}).first(where:{$0.isKeyWindow}) else{return}
                let image=UIGraphicsImageRenderer(bounds:window.bounds).image {_ in window.drawHierarchy(in:window.bounds,afterScreenUpdates:true)}
                try? image.pngData()?.write(to:folder.appendingPathComponent("live-selection.png"),options:.atomic)
            }
        }
#endif
    }
    private func reconcileSelection(old:[SignalBlock],new:[SignalBlock]) {
        let id=monitor.snapshot?.presetID
        defer {blocksPresetID=id}
        guard blocksPresetID==id else{return}
        if followExternal,let changed=StadiumSelectionFollow.changedModel(previous:old,current:new) {applySelection(changed);return}
        guard let selection=selected else{return}
        if let fresh=new.first(where:{$0.path==selection.block.path && $0.position==selection.block.position && $0.slot==selection.block.slot}) {
            if fresh.model != selection.context.modelID || fresh.blockID != selection.context.blockID {applySelection(fresh)}
        } else if let replacement=new.first(where:{$0.path==selection.block.path && $0.position==selection.block.position}) {applySelection(replacement)}else{selected=nil}
    }
    private func chooseInitialBlock() {
        guard let state=monitor.snapshot else{selected=nil;return}
        let live:SignalBlock?
        if !preview,followExternal,monitor.focusedPresetID==state.presetID,let focus=monitor.focusedBlock,focus.receivedAt>monitor.selectionRememberedAt {
            live=state.blocks.first{$0.path-1==focus.path && $0.position==focus.position && $0.slot==0}
        } else {live=nil}
        let remembered=preview ? nil:monitor.rememberedSelection(in:state)
        let block=live ?? remembered ?? state.blocks.first(where:{$0.position != 0 && $0.position != 13 && $0.position != 14 && $0.position != 27 && !monitor.definitions($0).isEmpty}) ?? state.blocks.first
        if let block {applySelection(block,remember:false)}else{selected=nil}
    }
}

#if DEBUG
/// Synthetic folder loading only; no device connection or preset writes.
private struct PresetFolderHarness:View {
    @EnvironmentObject var monitor:StadiumMonitor
    private let key="PresetSidebar.Tests.FolderMemory"
    var body:some View {
        PresetSidebar(refreshID:0,debugFolderMemoryKey:key).frame(width:300)
            .task {
                if ProcessInfo.processInfo.arguments.contains("--reset-folder-memory") {UserDefaults.standard.removeObject(forKey:key)}
                try? await Task.sleep(for:.milliseconds(200))
                monitor.presetFolders=[(101,"Practice"),(202,"Working")].compactMap {id,name in
                    PresetFolder(reference:.object(["type":.int(1003),"cid_":.int(Int64(id)),"name":.string(name)]),contents:.array([]))
                }
            }
    }
}
#endif

#if DEBUG
@MainActor private func verifyBridgeResume(_ monitor:StadiumMonitor)async {
    func waitForConnection()async->Bool {
        for _ in 0..<160 {if monitor.connected {return true};try? await Task.sleep(for:.milliseconds(250))}
        return false
    }
    let before=await waitForConnection(),preset=monitor.snapshot?.presetID
    let oldConnection=monitor.connectionID
    if before,monitor.connectionRoute == .bridge {monitor.pauseForBackground();monitor.resumeFromBackground()}
    let after=before ? await waitForConnection():false
    let result:[String:Any]=["connectedBefore":before,"connectedAfter":after,"freshConnection":monitor.connectionID != oldConnection,"presetUnchanged":preset != nil && preset==monitor.snapshot?.presetID]
    if let data=try? JSONSerialization.data(withJSONObject:result) {try? data.write(to:FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("bridge-resume-check.json"),options:.atomic)}
}
#endif

#if DEBUG
@MainActor private func verifyReadTiming(_ monitor:StadiumMonitor)async {
    for _ in 0..<160 {if monitor.connected {break};try? await Task.sleep(for:.milliseconds(250))}
    var result:[String:Double]=[:]
    do {result=try await monitor.benchmarkReadTiming()}catch{result=["failed":1]}
    if let data=try? JSONSerialization.data(withJSONObject:result) {try? data.write(to:FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("read-timing-check.json"),options:.atomic)}
}
#endif

#if DEBUG
@MainActor private func verifyBluetooth(_ monitor:StadiumMonitor,settings:PedalBridgeSettings)async {
    let file=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("bluetooth-check.json")
    func record(_ result:[String:Any]) {if let data=try? JSONSerialization.data(withJSONObject:result) {try? data.write(to:file,options:.atomic)}}
    record(["stage":"discovering"]);monitor.stop();let hub=BluetoothEditorHub.shared;hub.search()
    for _ in 0..<120 {if !hub.helpers.isEmpty {break};try? await Task.sleep(for:.milliseconds(250))}
    try? await Task.sleep(for:.seconds(2))
    var chosen:BluetoothHelper?
    if let expected=ProcessInfo.processInfo.environment["STADIUM_VERIFY_HELPER_NAME"] {
        for helper in hub.helpers {if let info=try? await hub.information(helper.id),info.name==expected {chosen=helper;break}}
    }else if hub.helpers.count==1 {chosen=hub.helpers.first}
    guard let helper=chosen else{record(["stage":"discovery","helpers":hub.helpers.count,"message":hub.message]);return}
    do {
        record(["stage":"opening Bluetooth"])
        let pair=try await PedalBridgeConnection.automaticBluetooth(helper.id);try settings.configure(pair)
        let helperSettings=try await PedalBridgeConnection.settings(pair)
        UserDefaults.standard.set(StadiumConnectionRoute.bridge.rawValue,forKey:"stadiumConnectionRoute")
        record(["stage":"reading native state"]);monitor.connect(host:pair.host,route:.bridge,bridgePair:pair)
        for _ in 0..<240 {if monitor.connected && monitor.snapshot != nil {break};try? await Task.sleep(for:.milliseconds(250))}
        var result:[String:Any]=["stage":"complete","connected":monitor.connected,"bluetooth":pair.bluetooth,"hasSnapshot":monitor.snapshot != nil,"error":monitor.errorText ?? "","helperKind":helperSettings["kind"] as? String ?? "","settingsOnline":helperSettings["ok"] as? Bool ?? false]
        if monitor.connected {result["timing"]=try await monitor.benchmarkReadTiming()}
        if ProcessInfo.processInfo.arguments.contains("--verify-bluetooth-restart") {
            let beforeRestart=monitor.connectionID
            result["restartAcknowledged"]=(try await PedalBridgeConnection.settings(pair,action:"restart"))["restarting"] as? Bool ?? false
            for _ in 0..<200 {if monitor.connected,monitor.snapshot != nil,monitor.connectionID != beforeRestart{break};try await Task.sleep(for:.milliseconds(250))}
            result["reconnectedAfterServiceRestart"]=monitor.connected && monitor.connectionID != beforeRestart
        }
        record(result)
    }catch{record(["stage":"failed","error":error.localizedDescription])}
}
#endif


private struct BluetoothConnectionGlyph:Shape {
    func path(in rect:CGRect)->Path {
        var path=Path()
        func point(_ x:CGFloat,_ y:CGFloat)->CGPoint {CGPoint(x:rect.minX+x*rect.width/18,y:rect.minY+y*rect.height/22)}
        path.move(to:point(8,1));path.addLine(to:point(8,21));path.addLine(to:point(15,15));path.addLine(to:point(2,5))
        path.move(to:point(2,17));path.addLine(to:point(15,7));path.addLine(to:point(8,1))
        return path
    }
}
