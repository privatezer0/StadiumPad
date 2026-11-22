import SwiftUI
import StadiumProtocol

enum EditorMode:String,CaseIterable {
    case preset="Preset",scene="Scene",footswitch="Footswitch",tuner="Tuner"
    var icon:String {switch self {
    case .preset:return "point.3.connected.trianglepath.dotted"
    case .scene:return "square.grid.2x2"
    case .footswitch:return "shoe"
    case .tuner:return "tuningfork"
    }}
}
/// Original side-view foot pressing a stomp pedal, drawn in the toolbar's outline style.
struct FootPressIcon:View {
    var body:some View {
        GeometryReader {geometry in
            Path {p in
                p.move(to:CGPoint(x:6,y:2));p.addLine(to:CGPoint(x:4,y:9))
                p.addQuadCurve(to:CGPoint(x:5,y:14),control:CGPoint(x:2,y:12))
                p.addLine(to:CGPoint(x:18,y:18))
                p.addQuadCurve(to:CGPoint(x:22,y:16),control:CGPoint(x:23,y:19))
                p.addQuadCurve(to:CGPoint(x:19,y:13),control:CGPoint(x:22,y:14))
                p.addLine(to:CGPoint(x:12,y:9));p.addLine(to:CGPoint(x:13,y:3))
                p.move(to:CGPoint(x:5,y:12));p.addLine(to:CGPoint(x:20,y:17))
                p.move(to:CGPoint(x:12,y:19));p.addLine(to:CGPoint(x:11,y:22))
                p.addLine(to:CGPoint(x:23,y:22));p.addLine(to:CGPoint(x:22,y:19))
                p.move(to:CGPoint(x:14,y:20));p.addLine(to:CGPoint(x:20,y:20))
            }.applying(CGAffineTransform(scaleX:geometry.size.width/24,y:geometry.size.height/24))
                .stroke(style:StrokeStyle(lineWidth:1.2,lineCap:.round,lineJoin:.round))
        }.accessibilityHidden(true)
    }
}
enum PerformanceColors {
    static let palette:[Color]=[.cyan,.purple,.pink,.green,.orange,.blue,.red,.yellow]
    static func color(_ value:Int,fallback:Int)->Color {
        switch value {case 11:return .white;case 2:return .red;case 3:return Color(red:0.8,green:0.3,blue:0.05);case 4:return .orange;case 5:return .yellow;case 6:return .green;case 7:return .teal;case 8:return .blue;case 9:return .purple;case 10:return .pink;default:return palette[fallback%palette.count]}
    }
}
struct SceneBoard:View {
    @EnvironmentObject var monitor:StadiumMonitor
    let state:DeviceSnapshot
    @State private var showCreate=false
    @State private var createIndex=0
    @State private var createPreset=0
    @State private var createSource=0
    var body:some View {
        GeometryReader {geometry in
            let columns=geometry.size.width>=650 ? 4:2
            let rows=8/columns
            let height=max(70,(geometry.size.height-76-CGFloat(rows-1)*12)/CGFloat(rows))
            VStack(spacing:12) {
                HStack {Text("SCENES").font(.headline).tracking(2);Spacer();Text("\(state.snapshots.filter(\.defined).count) / 8 configured").font(.caption).foregroundStyle(.secondary)}.frame(height:28)
                LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:12),count:columns),spacing:12) {
                    ForEach(0..<8,id:\.self) {index in
                        let scene=state.snapshots.first{$0.id==index}
                        let defined=scene?.defined==true
                        let active=state.activeSnapshot==index
                        let color=PerformanceColors.color(scene?.color ?? 0,fallback:index)
                        Button {
                            if defined {Task {await monitor.activate(index,expectedID:state.presetID,expectedSnapshot:state.activeSnapshot)}}
                            else if let id=state.presetID {createIndex=index;createPreset=id;createSource=state.activeSnapshot;showCreate=true}
                        } label:{
                            VStack(alignment:.leading,spacing:8) {
                                HStack {Text(String(index+1)).font(.title2.monospacedDigit().bold());Spacer();Image(systemName:active ? "checkmark.circle.fill":defined ? "circle":"plus.circle").font(.title2)}
                                Spacer(minLength:2)
                                Text(defined ? scene?.name ?? "Scene \(index+1)":"Create Scene \(index+1)").font(.system(size:geometry.size.width>=650 ? 23:20,weight:.semibold)).lineLimit(2).minimumScaleFactor(0.7)
                                Spacer(minLength:2)
                                Text(active ? "ACTIVE":defined ? "TAP TO SELECT":"COPY CURRENT SCENE").font(.system(size:10,weight:.semibold)).tracking(1)
                            }.padding(16).frame(maxWidth:.infinity,alignment:.leading).frame(height:height).foregroundStyle(defined ? color:color.opacity(0.6))
                                .background(LinearGradient(colors:[color.opacity(active ? 0.33:0.12),Color(white:0.055)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:14))
                                .overlay(RoundedRectangle(cornerRadius:14).stroke(active ? color:color.opacity(0.32),lineWidth:active ? 3:1))
                        }.buttonStyle(.plain).disabled(monitor.busy || !monitor.connected).accessibilityLabel("Scene \(index+1), \(scene?.name ?? "empty"), \(active ? "active":"")")
                    }
                }
            }.padding(16).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.top)
        }.confirmationDialog("Create Scene \(createIndex+1) from the current scene?",isPresented:$showCreate,titleVisibility:.visible) {
            Button("Create Scene") {Task {if await monitor.createScene(createIndex,expectedID:createPreset,expectedSnapshot:createSource) {await monitor.activate(createIndex,expectedID:createPreset,expectedSnapshot:createSource)}}}
        } message:{Text("Only this empty scene slot is filled. Choose Save Preset to keep the new scene.")}
    }
}
struct FootswitchBoard:View {
    @EnvironmentObject var monitor:StadiumMonitor
    let state:DeviceSnapshot
    @State private var bank="a"
    var body:some View {
        GeometryReader {geometry in
            let columns=geometry.size.width>=650 ? 5:2
            let rows=10/columns
            let height=max(72,(geometry.size.height-80-CGFloat(rows-1)*12)/CGFloat(rows))
            VStack(spacing:12) {
                HStack {Text("VIRTUAL PEDALBOARD").font(.headline).tracking(1);Spacer();Picker("Stomp bank",selection:$bank){Text("Stomp A").tag("a");Text("Stomp B").tag("b")}.pickerStyle(.segmented).frame(width:185)}.frame(height:32)
                LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:12),count:columns),spacing:12) {
                    ForEach(StompAssignment.switchNumbers,id:\.self) {number in
                        let assignment=StompAssignment.read(state,bank:bank,number:number)
                        StompTile(assignment:assignment,state:state,height:height)
                    }
                }
            }.padding(16).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.top)
        }.task(id:state.presetID){await monitor.refreshStompProperties()}
    }
}
struct StompTile:View {
    @EnvironmentObject var monitor:StadiumMonitor
    let assignment:StompAssignment;let state:DeviceSnapshot;let height:CGFloat
    private var prefix:String {"preset.floorboard.stomp.\(assignment.bank).\(assignment.number)"}
    private var blocks:[SignalBlock] {
        guard let plan=assignment.plan else{return []}
        return plan.controllers.compactMap {controller in state.blocks.first{$0.path-1==controller.target.path && $0.position==controller.target.position && $0.model==controller.target.modelID && $0.slot==controller.target.slot}}
    }
    private var title:String {
        if let label=monitor.stompProperties[prefix+".label"]?.text,!label.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {return label}
        let names=blocks.map{monitor.blockName($0)}
        return names.isEmpty ? assignment.reason ?? "Unassigned":Array(NSOrderedSet(array:names)).compactMap{$0 as? String}.joined(separator:" / ")
    }
    private var color:Color {
        if let value=monitor.stompProperties[prefix+".color"]?.integer,value>1 {return PerformanceColors.color(value,fallback:assignment.number)}
        return blocks.first.map{BlockStyle.forBlock($0,monitor:monitor).color} ?? .gray
    }
    var body:some View {
        let active=assignment.plan?.active
        Button {if let plan=assignment.plan {Task {_ = await monitor.press(plan)}}} label:{
            VStack(spacing:6) {
                HStack {Text("\(assignment.bank.uppercased())\(assignment.number)").font(.caption.monospacedDigit().bold());Spacer();if let count=assignment.plan?.controllers.count,count>1 {Text("\(count) FX").font(.caption2)}}
                Spacer(minLength:0)
                Text(title).font(.system(size:height>130 ? 17:13,weight:.semibold)).lineLimit(2).minimumScaleFactor(0.7).multilineTextAlignment(.center).frame(maxWidth:.infinity)
                Spacer(minLength:0)
                ZStack {
                    Circle().stroke(color.opacity(active==true ? 1:0.22),lineWidth:5).frame(width:48,height:48)
                    Circle().fill(LinearGradient(colors:[Color(white:0.40),Color(white:0.12),Color(white:0.28)],startPoint:.topLeading,endPoint:.bottomTrailing)).frame(width:34,height:34).overlay(Circle().stroke(.white.opacity(0.25),lineWidth:1))
                    Image(systemName:"power").font(.system(size:16,weight:.medium)).foregroundStyle(active==true ? color:.gray)
                }
                Text(assignment.plan==nil ? "UNAVAILABLE":active==true ? "ON":active==false ? "OFF":"MIXED").font(.system(size:9,weight:.semibold)).tracking(1)
            }.padding(12).frame(maxWidth:.infinity).frame(height:height).foregroundStyle(assignment.plan==nil ? .gray:color)
                .background(LinearGradient(colors:[color.opacity(active==true ? 0.20:0.07),Color(white:0.04)],startPoint:.top,endPoint:.bottom),in:RoundedRectangle(cornerRadius:14))
                .overlay(RoundedRectangle(cornerRadius:14).stroke(color.opacity(active==true ? 0.8:0.24),lineWidth:active==true ? 2:1))
        }.buttonStyle(.plain).disabled(assignment.plan==nil || monitor.busy || !monitor.connected).accessibilityLabel("Stomp \(assignment.id.uppercased()), \(title), \(active==true ? "on":"off")")
    }
}

struct TunerBoard:View {
    @EnvironmentObject var monitor:StadiumMonitor
    let exit:()->Void
    var body:some View {
        VStack(spacing:22) {
            Image(systemName:"tuningfork").font(.system(size:64,weight:.ultraLight)).foregroundStyle(.cyan)
            Text("Tuner").font(.largeTitle.bold())
            Text(monitor.tunerRequested ? "Tuner requested on Stadium":"Tuner is off").font(.title3)
            if let reference=monitor.tunerReference {Text("Reference: \(reference,format:.number.precision(.fractionLength(0...1))) Hz").foregroundStyle(.secondary)}
            Text("Read the note and tuning needle on the Stadium display. Live pitch readings are not available through the known network protocol.").multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth:450)
            Button("Turn Tuner Off",action:exit).buttonStyle(.borderedProminent)
            Text("Leaving Tuner mode sends the exit command automatically.").font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(maxWidth:.infinity,maxHeight:.infinity)
    }
}
