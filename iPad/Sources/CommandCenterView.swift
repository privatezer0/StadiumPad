import SwiftUI
import StadiumProtocol

private extension CommandFamily {
    var tint:Color {switch self {case .none,.looper,.utility:return Color(white:0.7);case .presetSnapshot:return EditorTheme.gold;case .song:return .teal;case .extAmp:return .red;case .midi:return .yellow;case .hotKey:return .orange}}
    var icon:String {switch self {case .none:return "xmark";case .presetSnapshot:return "square.stack";case .song:return "music.note";case .looper:return "infinity";case .utility:return "case";case .extAmp:return "camera";case .midi:return "circle.dotted";case .hotKey:return "keyboard"}}
}
struct CommandCenterView:View {
    @EnvironmentObject var monitor:StadiumMonitor
    @State private var source=CommandSource(.stomp,number:1,bank:1)
    @State private var slot=0
    @State private var bank=1
    @State private var expressionBank=0
    @State private var clipboard:CommandCopy?
    @State private var allClipboard:[CommandCopy]?
    @State private var confirmPasteAll=false
    @State private var confirmClearAll=false
    @State private var confirmSave=false
    @State private var editParameter:CommandParameter?
    @State private var numericDraft=""
    @State private var showAppearance=false
    @State private var labelDraft=""
    let preview:Bool
    init(preview:Bool=false){self.preview=preview}
    private var context:CommandContext? {guard let state=monitor.snapshot else{return nil};return try? CommandContext(state:state,source:source,slot:slot)}
    private var definitions:[CommandParameter] {guard let c=context else{return []};return monitor.commandCatalog[source.catalogueKey(c.family)] ?? []}
    private var enabled:Bool {!monitor.busy && monitor.connected && context != nil && sourceEnabled(source)}
    var body:some View {
        GeometryReader {geometry in
            VStack(spacing:0) {
                titleBar
                sourceMap.frame(height:max(215,min(310,geometry.size.height*0.43)))
                HStack(spacing:12) {
                    ForEach(0..<source.slots,id:\.self) {index in let family=slotFamily(index);Button {slot=index} label:{Image(systemName:family.icon).foregroundStyle(family.tint).font(.system(size:19)).frame(width:32,height:32).background(index==slot ? .white.opacity(0.12):.clear,in:RoundedRectangle(cornerRadius:3))}.accessibilityLabel("Select Command \(index+1)")}
                    Spacer();Text(source.name).font(.system(size:23,weight:.light));Spacer()
                    Menu {commandActions} label:{Image(systemName:"ellipsis").frame(width:44,height:34)}.accessibilityLabel("Command actions")
                }.padding(.horizontal,10).frame(height:42).background(Color(white:0.25))
                HStack(spacing:1) {
                    slotList.frame(width:geometry.size.width<900 ? 105:138)
                    categoryList.frame(width:geometry.size.width<900 ? 145:172)
                    inspector.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
                }.background(EditorTheme.border)
            }.background(.black)
        }.buttonStyle(.plain)
        .onChange(of:source){_,_ in slot=0}
        .onChange(of:monitor.connectionID){_,_ in source=CommandSource(.stomp,number:1,bank:1);slot=0;clipboard=nil;allClipboard=nil;editParameter=nil;confirmSave=false;confirmClearAll=false;confirmPasteAll=false}
        .onChange(of:monitor.snapshot?.presetID){_,_ in slot=0;editParameter=nil;confirmSave=false;confirmClearAll=false;confirmPasteAll=false}
        .task {guard !preview else{return};while !Task.isCancelled {await monitor.refreshCommandProperties();await monitor.refreshStompProperties();try? await Task.sleep(for:.seconds(3))}}
        .confirmationDialog("Clear/reset every command in this preset?",isPresented:$confirmClearAll,titleVisibility:.visible){Button("Clear/Reset All",role:.destructive){replaceAll([])}}message:{Text("All Command Center sources are cleared. Effect controller assignments stay intact. Choose Save Preset to keep the change.")}
        .confirmationDialog("Replace this preset's command layout?",isPresented:$confirmPasteAll,titleVisibility:.visible){Button("Paste All Commands"){if let allClipboard {replaceAll(allClipboard)}}}message:{Text("Existing commands are backed up first and replaced by the copied layout. The preset is not saved automatically.")}
        .confirmationDialog("Save this preset?",isPresented:$confirmSave,titleVisibility:.visible){Button("Save Preset"){let id=monitor.snapshot?.presetID;Task {await monitor.save(expectedID:id)}}}
        .sheet(isPresented:$showAppearance){VStack(spacing:20){Text("\(source.name) · Label/Color").font(.title2);TextField("Label",text:$labelDraft).textFieldStyle(.roundedBorder).disabled((0..<source.slots).contains{slotFamily($0) == .presetSnapshot});Button("Set Label"){if let c=context {Task{if await monitor.setStompAppearance(c,.label(labelDraft)){showAppearance=false}}}}.disabled(!enabled || (0..<source.slots).contains{slotFamily($0) == .presetSnapshot});LazyVGrid(columns:Array(repeating:GridItem(.flexible()),count:6)){ForEach(0...11,id:\.self){i in Button{if let c=context {Task{if await monitor.setStompAppearance(c,.color(i)){showAppearance=false}}}}label:{Text(i==0 ? "Off":i==1 ? "Auto":" ").foregroundStyle(.white).frame(height:48).frame(maxWidth:.infinity).background(i==0 ? .black:i==1 ? .gray:PerformanceColors.color(i,fallback:i),in:RoundedRectangle(cornerRadius:6))}.disabled(!enabled)}};Button("Done"){showAppearance=false}}.padding(30).presentationDetents([.height(330)])}
        .alert(editParameter?.name ?? "Value",isPresented:Binding(get:{editParameter != nil},set:{if !$0 {editParameter=nil}})){TextField("Value",text:$numericDraft).keyboardType(.numbersAndPunctuation);Button("Cancel",role:.cancel){editParameter=nil};Button("Set"){if let p=editParameter,let n=Double(numericDraft){setParameter(p,.number(n))};editParameter=nil}}
    }
    private var titleBar:some View {
        HStack(spacing:10) {
            Spacer(minLength:0);Text("Command Center").font(.system(size:28,weight:.light));Spacer(minLength:0)
            if let state=monitor.snapshot {
                Menu {ForEach(state.snapshots){s in Button(s.name){Task {await monitor.activate(s.id,expectedID:state.presetID,expectedSnapshot:state.activeSnapshot)}}.disabled(!s.defined)}} label:{Label("\(state.activeSnapshot+1) · \(state.snapshots.first{$0.id==state.activeSnapshot}?.name ?? "Snapshot")",systemImage:"square.stack").font(.callout).lineLimit(1).frame(maxWidth:215).padding(9).background(.black.opacity(0.3),in:RoundedRectangle(cornerRadius:5))}.accessibilityLabel("Command Center snapshot").disabled(monitor.busy)
                ForEach([-1,1],id:\.self){direction in Button {let choices=state.snapshots.filter(\.defined).sorted{$0.id<$1.id};let target=direction>0 ? choices.first{$0.id>state.activeSnapshot} ?? choices.first:choices.last{$0.id<state.activeSnapshot} ?? choices.last;if let target {Task {await monitor.activate(target.id,expectedID:state.presetID,expectedSnapshot:state.activeSnapshot)}}} label:{Image(systemName:direction<0 ? "chevron.left":"chevron.right").frame(width:25,height:36)}.accessibilityLabel(direction<0 ? "Previous snapshot":"Next snapshot").disabled(monitor.busy)}
                Button {confirmSave=true} label:{SaveDiskIcon().frame(width:36,height:36)}.accessibilityLabel("Save Command Center preset").disabled(monitor.busy || state.preset["ownr"].integer != 1)
            }
        }.padding(.horizontal,16).frame(height:58).background(EditorTheme.header)
    }
    private var sourceMap:some View {
        GeometryReader {geometry in
            let scale=min((geometry.size.width-18)/1000,(geometry.size.height-12)/300)
            ZStack {
                ForEach(0..<16,id:\.self) {i in sourceButton(CommandSource(.instant,number:i),shape:.bolt).frame(width:60,height:53).position(x:CGFloat(i%8)*63+64,y:CGFloat(i/8)*53+27)}
                sourceButton(CommandSource(.axis,number:0),shape:.axisX).frame(width:57,height:50).position(x:582,y:50)
                sourceButton(CommandSource(.axis,number:1),shape:.axisY).frame(width:57,height:50).position(x:650,y:50)
                HStack(spacing:0){ForEach(1...2,id:\.self){b in Button {bank=b;if source.kind == .stomp {source=CommandSource(.stomp,number:source.number,bank:b)}} label:{Text("S T O M P  \(b==1 ? "A":"B")").font(.system(size:15,weight:.light)).foregroundStyle(bank==b ? .white:.gray).frame(width:270,height:34).background(bank==b ? .white.opacity(0.025):.clear).overlay(Rectangle().stroke(.gray.opacity(0.5),lineWidth:1))}}}.position(x:305,y:119)
                ForEach(1...12,id:\.self) {number in
                    sourceButton(CommandSource(.stomp,number:number,bank:bank),shape:.stomp).frame(width:68,height:68).position(x:CGFloat((number-1)%6)*88+64,y:number<=6 ? 179:263)
                }
                sourceButton(CommandSource(.toe,number:0),shape:.stomp).frame(width:58,height:57).position(x:650,y:118)
                HStack(spacing:2){ForEach(0...1,id:\.self){b in Button {expressionBank=b;source=CommandSource(.expression,number:0,bank:b)} label:{Rectangle().fill(b==0 ? Color.purple:Color.teal).opacity(expressionBank==b ? 1:0.3)}.accessibilityLabel("Select EXP \(b+1)")}}.frame(width:58,height:9).position(x:650,y:158)
                sourceButton(CommandSource(.expression,number:0,bank:expressionBank),shape:.pedal).frame(width:58,height:115).position(x:650,y:229)
                Rectangle().fill(.gray.opacity(0.2)).frame(width:1,height:284).position(x:696,y:150)
                ForEach(0..<4,id:\.self) {i in
                    sourceButton(CommandSource(.trigger,number:i),shape:.drum).frame(width:55,height:55).position(x:CGFloat(i)*73+744,y:44)
                    sourceButton(CommandSource(.externalSwitch,number:i),shape:.stomp).frame(width:55,height:55).position(x:CGFloat(i)*73+744,y:118)
                    sourceButton(CommandSource(.expression,number:i+1),shape:.pedal).frame(width:58,height:115).position(x:CGFloat(i)*73+744,y:229)
                }
            }.frame(width:1000,height:300).scaleEffect(scale,anchor:.topLeading).frame(width:1000*scale,height:300*scale).position(x:geometry.size.width/2,y:geometry.size.height/2)
        }.background(Color(white:0.065))
    }
    private func sourceButton(_ item:CommandSource,shape:CommandSourceGlyph.Kind)->some View {
        let selected=source==item,available=sourceEnabled(item),assigned=hasCommands(item)
        return Button {source=item} label:{VStack(spacing:1){Image(systemName:"triangle.fill").font(.system(size:9)).foregroundStyle(.mint).opacity(assigned ? 1:0);CommandSourceGlyph(kind:shape,selected:selected,color:ring(item)).opacity(available ? 1:0.22)}}.disabled(!available || monitor.busy).accessibilityLabel(item.name).accessibilityValue(assigned ? "Commands assigned":"Unassigned").contextMenu {Button("Copy Command"){copy(item)}.disabled(!hasCommands(item));Button("Copy All Commands"){copyAll()};Button("Label/Color"){source=item;openAppearance()}.disabled(item.kind != .stomp);Button("Paste Command"){source=item;paste()}.disabled(clipboard==nil || !available);Button("Clear Command",role:.destructive){source=item;if let c=context,c.commandID != nil {send(c,.family(.none))}};Button("Clear/Reset All",role:.destructive){confirmClearAll=true}}
    }
    private func sourceEnabled(_ item:CommandSource)->Bool {
        if item.kind == .stomp {return StompAssignment.switchNumbers.contains(item.number)}
        if item.kind == .trigger || item.kind == .externalSwitch || (item.kind == .expression && item.number>0) {let i=item.kind == .expression ? item.number-1:item.number;let letter=String(UnicodeScalar(97+i)!);return monitor.commandProperties["global.assign.control."+letter]?.integer == (item.kind == .expression ? 0:item.kind == .externalSwitch ? 1:2)}
        return true
    }
    private func hasCommands(_ item:CommandSource)->Bool {guard let state=monitor.snapshot,let row=try? item.row(in:state) else{return false};return row["cmds"].items.contains{($0.integer ?? -1)>0}}
    private func ring(_ item:CommandSource)->Color {
        guard item.kind == .stomp else{return Color(white:0.2)}
        let key="preset.floorboard.stomp.\(item.bank==1 ? "a":"b").\(item.number).color"
        if let color=monitor.stompProperties[key]?.integer,color != 1 {return color==0 ? .black:PerformanceColors.color(color,fallback:item.number)}
        guard let state=monitor.snapshot,let row=try? item.row(in:state) else{return Color(white:0.17)}
        let sourceID=row["id__"].integer
        let controller=state.editBuffer["cg__"]["entt"]["ctrl"].items.first{$0["trig"].integer==sourceID}
        guard let controller else{return Color(white:0.17)}
        let target=state.editBuffer["cg__"]["entt"]["trgs"].items.first{$0["id__"]==controller["tid_"]}
        if let block=state.blocks.first(where:{$0.blockID==target?["eID_"].integer}),let category=monitor.catalog[String(block.model)]?.category {switch category {case "amp":return .red;case "delay":return .green;case "reverb":return .orange;case "distortion":return .orange;case "pitch_synth":return .purple;default:return .yellow}}
        return .yellow
    }
    private func slotFamily(_ index:Int)->CommandFamily {guard let state=monitor.snapshot,let c=try? CommandContext(state:state,source:source,slot:index) else{return .none};return c.family}
    private var slotList:some View {VStack(spacing:0){ForEach(0..<source.slots,id:\.self){index in Button {slot=index} label:{Text("Command \(index+1)").font(.system(size:14,weight:.semibold)).frame(maxWidth:.infinity,alignment:.leading).padding(.leading,9).frame(height:40).background(slot==index ? Color(white:0.25):.black)}};Spacer(minLength:0)}.background(.black)}
    private var categoryList:some View {GeometryReader{geometry in VStack(spacing:0){ForEach(CommandFamily.allCases,id:\.self) {family in Button {guard let c=context else{return};send(c,.family(family))} label:{Label(family.name,systemImage:family.icon).font(.system(size:14)).foregroundStyle(source.supports(family) ? family.tint:family.tint.opacity(0.25)).frame(maxWidth:.infinity,alignment:.leading).padding(.leading,9).frame(height:min(40,geometry.size.height/8)).background(context?.family==family ? Color(white:0.25):.black)}.disabled(!enabled || !source.supports(family) || context?.family==family)};Spacer(minLength:0)}.background(.black)}}
    private var inspector:some View {
        Group {
            if let c=context,c.family != .none {
                if definitions.isEmpty {Text("Command metadata is unavailable for this editor version.").foregroundStyle(.secondary).padding(20)}
                else {GeometryReader {geometry in
                    let fields=definitions.filter{$0.visible(source:source,family:c.family,command:c.command)}
                    VStack(spacing:5) {ForEach(fields){p in parameterRow(p,context:c,height:min(75,max(44,(geometry.size.height-20)/CGFloat(max(1,fields.count))-5))) };Spacer(minLength:0)}.padding(.horizontal,18).padding(.vertical,10)
                }}
            } else if !monitor.connected {Text("Connect to Stadium to edit Command Center.").foregroundStyle(.secondary).padding(20)}
        }.background(.black).id("\(source.id)-\(slot)-\(context?.family.rawValue ?? 0)")
    }
    @ViewBuilder private func parameterRow(_ p:CommandParameter,context c:CommandContext,height:CGFloat)->some View {
        let first=(monitor.snapshot.flatMap{try? CommandContext(state:$0,source:source,slot:0)})
        let locked=p.name=="Action" && c.slot==1 && first?.command["pvla"].integer==3
        let tint=c.family.tint,value=locked ? Value.int(3):c.command[p.valueKey]
        VStack(alignment:.leading,spacing:3) {
            HStack(spacing:8) {
                Text(p.name).font(.system(size:13)).foregroundStyle(.gray).contextMenu{if p.name != "Action" && !(c.family == .midi && p.name=="Command"){Button(c.command[p.snapshotKey].boolean==true ? "Disable Snapshot Control":"Enable Snapshot Control"){send(c,.snapshot(p,c.command[p.snapshotKey].boolean != true))}}}
                if c.command[p.snapshotKey].boolean==true {Image(systemName:"triangle.fill").font(.system(size:7)).rotationEffect(.degrees(-90)).foregroundStyle(.teal).accessibilityLabel("Snapshot controlled")}
                Spacer(minLength:4)
                if let options=p.options {optionsControl(p,options:options,value:value,context:c,tint:tint)}
                else if p.name=="Setlist" || p.name=="Preset" {presetDestination(p,context:c)}
                else {Button {numericDraft=value.scalar;editParameter=p} label:{Text(p.display(value)).font(.system(size:14).monospacedDigit()).foregroundStyle(c.command[p.snapshotKey].boolean==true ? .white:tint)};Stepper("",onIncrement:{step(p,1,c)},onDecrement:{step(p,-1,c)}).labelsHidden().scaleEffect(0.65).frame(width:65,height:28)}
            }
            if p.options==nil && !["Setlist","Preset"].contains(p.name) {CommandValueSlider(parameter:p,value:value,tint:tint){setParameter(p,$0)}.frame(height:max(14,min(22,height-30)))}
        }.frame(height:height,alignment:.top).disabled(!enabled || locked)
    }
    private func optionsControl(_ p:CommandParameter,options:[String],value:Value,context c:CommandContext,tint:Color)->some View {
        ViewThatFits(in:.horizontal) {
            if options.count<=8 {HStack(spacing:1){ForEach(Array(options.enumerated()),id:\.offset){i,name in Button {setParameter(p,.int(Int64(i)+Int64(p.minimum)))} label:{Text(name).font(.system(size:11)).lineLimit(1).padding(.horizontal,7).frame(height:29).foregroundStyle(value.integer==i+Int(p.minimum) ? .black:tint).background(value.integer==i+Int(p.minimum) ? tint:Color(white:0.12))}}}.clipShape(RoundedRectangle(cornerRadius:4))}
            Menu {ForEach(Array(options.enumerated()),id:\.offset){i,name in Button(name){setParameter(p,.int(Int64(i)+Int64(p.minimum)))}}}label:{HStack{Text(p.display(value));Image(systemName:"chevron.down")}.font(.system(size:13)).foregroundStyle(tint).padding(7).background(Color(white:0.12),in:RoundedRectangle(cornerRadius:4))}
        }
    }
    private var destinations:[(value:Int,name:String,presets:[PresetSlot])] {
        [(0,"Factory",monitor.factoryPresets),(1,"User",(monitor.libraryEntries[-2] ?? []).map{PresetSlot(.object(["cid_":.int(Int64($0.id)),"ccid":.int(-2),"posi":.int(Int64($0.position)),"type":.int(2),"name":.string($0.name)]))})] + monitor.presetFolders.sorted{$0.position<$1.position}.map{(2+$0.position,$0.name,$0.presets)}
    }
    private func presetDestination(_ p:CommandParameter,context c:CommandContext)->some View {
        let setlist=c.command["pvlc"].integer ?? 0
        let list=destinations.first{$0.value==setlist}
        let position=c.command[p.valueKey].integer ?? 0
        let name=p.name=="Setlist" ? list?.name:list?.presets.first{$0.position==position}?.name
        return Menu {
            if p.name=="Setlist" {ForEach(destinations,id:\.value){item in Button(item.name){setDestination(p,item.value,c)}}}
            else {ForEach(list?.presets ?? [],id:\.id){preset in if let position=preset.position {Button("\(preset.label) \(preset.name)"){setParameter(p,.int(Int64(position)))}}}}
        }label:{Text(name ?? p.display(c.command[p.valueKey])).font(.callout).foregroundStyle(c.family.tint);Image(systemName:"chevron.down").font(.caption)}
    }
    private func setDestination(_ p:CommandParameter,_ value:Int,_ c:CommandContext){
        guard !preview else{return}
        Task {
            guard await monitor.editCommand(c,.parameter(p,.int(Int64(value)))),let state=monitor.snapshot,state.presetID==c.presetID,state.activeSnapshot==c.snapshot,state.origin==c.origin,let fresh=try? CommandContext(state:state,source:c.source,slot:c.slot),let preset=monitor.commandCatalog[c.source.catalogueKey(c.family)]?.first(where:{$0.name=="Preset"}) else{return}
            _ = await monitor.editCommand(fresh,.parameter(preset,.int(0)))
        }
    }
    private func openAppearance(){guard source.kind == .stomp else{return};labelDraft=monitor.stompProperties["preset.floorboard.stomp.\(source.bank==1 ? "a":"b").\(source.number).label"]?.text ?? "";showAppearance=true}
    private func step(_ p:CommandParameter,_ direction:Double,_ c:CommandContext){let step=p.type=="i" ? 1:0.1;setParameter(p,.number(min(p.maximum,max(p.minimum,(c.command[p.valueKey].numeric ?? p.minimum)+direction*step))))}
    private func setParameter(_ p:CommandParameter,_ value:Value){
        guard let c=context,!preview else{return}
        Task {
            guard await monitor.editCommand(c,.parameter(p,value)) else{return}
            if p.name=="Action",c.slot==0,c.command["pvla"].integer==3,value.integer != 3,let state=monitor.snapshot,state.origin==c.origin,state.presetID==c.presetID,state.activeSnapshot==c.snapshot,let peer=try? CommandContext(state:state,source:c.source,slot:1),peer.commandID != nil,let action=monitor.commandCatalog[c.source.catalogueKey(peer.family)]?.first(where:{$0.name=="Action"}) {_ = await monitor.editCommand(peer,.parameter(action,.int(0)))}
        }
    }
    private func send(_ c:CommandContext,_ operation:CommandCenterOperation){guard !preview else{return};Task {let _=await monitor.editCommand(c,operation)}}
    private func copy(_ item:CommandSource?=nil){guard let state=monitor.snapshot else{return};do{let c=try CommandContext(state:state,source:item ?? source,slot:slot);clipboard=try CommandCopy(context:c,catalog:monitor.commandCatalog);allClipboard=nil}catch{monitor.errorText=error.localizedDescription}}
    private func copyAll(){guard let state=monitor.snapshot else{return};do{allClipboard=try CommandCopy.all(state:state,catalog:monitor.commandCatalog,properties:monitor.commandProperties);clipboard=nil}catch{monitor.errorText=error.localizedDescription}}
    private func paste(){if allClipboard != nil {confirmPasteAll=true;return};guard let copied=clipboard,let c=context else{return};guard copied.source.catalogueKey(copied.family)==c.source.catalogueKey(copied.family) else{monitor.errorText="The copied command uses a different controller type. Choose a compatible source.";return};send(c,.paste(copied.family,copied.parameters,copied.command))}
    private func replaceAll(_ values:[CommandCopy]){guard let state=monitor.snapshot else{return};Task {let _=await monitor.replaceCommands(expected:state,copies:values)}}
    @ViewBuilder private var commandActions:some View {
        Button("Copy Command"){copy()}.disabled(context?.commandID==nil)
        Button("Copy All Commands"){copyAll()}
        Button(allClipboard==nil ? "Paste Command":"Paste All Commands"){paste()}.disabled(clipboard==nil && allClipboard==nil)
        Button("Clear Command",role:.destructive){if let c=context,c.commandID != nil {send(c,.family(.none))}}.disabled(context?.commandID==nil)
        Button("Clear/Reset All",role:.destructive){confirmClearAll=true}
        Button("Label/Color"){openAppearance()}.disabled(source.kind != .stomp)
    }
}
private struct CommandValueSlider:View {
    let parameter:CommandParameter;let value:Value;let tint:Color;let commit:(Value)->Void
    @State private var draft:Double?
    var body:some View {GeometryReader{g in let n=draft ?? value.numeric ?? parameter.minimum;let fraction=(n-parameter.minimum)/max(1,parameter.maximum-parameter.minimum)
        ZStack(alignment:.leading){Rectangle().fill(tint.opacity(0.14));RoundedRectangle(cornerRadius:2).fill(tint).frame(width:4).offset(x:max(0,min(g.size.width-4,g.size.width*fraction)))}.contentShape(Rectangle()).gesture(DragGesture(minimumDistance:0).onChanged{v in let n=parameter.minimum+(parameter.maximum-parameter.minimum)*max(0,min(1,v.location.x/g.size.width));draft=parameter.type=="i" ? n.rounded():n}.onEnded{_ in if let draft {commit(parameter.type=="i" ? .int(Int64(draft)):.number(draft))};draft=nil})
    }}
}
struct CommandSourceGlyph:View {
    enum Kind {case stomp,bolt,axisX,axisY,pedal,drum}
    let kind:Kind;let selected:Bool;let color:Color
    var body:some View {
        GeometryReader {g in let w=g.size.width,h=g.size.height,stroke=selected ? Color.white:Color(white:0.34)
            ZStack {
                switch kind {
                case .bolt:Image(systemName:"bolt").resizable().scaledToFit().padding(5).foregroundStyle(stroke)
                case .axisX,.axisY:Image(systemName:kind == .axisX ? "arrow.left.and.right.circle":"arrow.up.and.down.circle").resizable().scaledToFit().padding(5).foregroundStyle(stroke)
                case .pedal:Path{p in p.move(to:CGPoint(x:w*0.23,y:1));p.addLines([CGPoint(x:w*0.83,y:1),CGPoint(x:w*0.83,y:h*0.35),CGPoint(x:w*0.64,y:h*0.48),CGPoint(x:w*0.64,y:h-1),CGPoint(x:w*0.36,y:h-1),CGPoint(x:w*0.36,y:h*0.48),CGPoint(x:w*0.23,y:h*0.35)]);p.closeSubpath()}.fill(.black.opacity(0.4)).overlay(Path{p in p.move(to:CGPoint(x:w*0.23,y:1));p.addLines([CGPoint(x:w*0.83,y:1),CGPoint(x:w*0.83,y:h*0.35),CGPoint(x:w*0.64,y:h*0.48),CGPoint(x:w*0.64,y:h-1),CGPoint(x:w*0.36,y:h-1),CGPoint(x:w*0.36,y:h*0.48),CGPoint(x:w*0.23,y:h*0.35)]);p.closeSubpath()}.stroke(stroke,lineWidth:selected ? 2:1))
                case .drum:Image(systemName:"drum").resizable().scaledToFit().padding(4).foregroundStyle(stroke)
                case .stomp:
                    Ellipse().fill(color).frame(width:w*0.83,height:h*0.38).offset(y:h*0.26).overlay(Ellipse().stroke(selected ? .white:.clear,lineWidth:2).frame(width:w*0.83,height:h*0.38).offset(y:h*0.26))
                    RoundedRectangle(cornerRadius:w*0.15).fill(LinearGradient(colors:[Color(white:0.3),Color(white:0.1)],startPoint:.top,endPoint:.bottom)).frame(width:w*0.46,height:h*0.58).overlay(RoundedRectangle(cornerRadius:w*0.15).stroke(stroke,lineWidth:selected ? 2:1).frame(width:w*0.46,height:h*0.58))
                    Ellipse().stroke(stroke,lineWidth:1).frame(width:w*0.43,height:h*0.2).offset(y:-h*0.19)
                }
            }.frame(width:w,height:h)
        }
    }
}
