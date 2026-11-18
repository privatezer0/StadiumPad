import SwiftUI
import StadiumProtocol

extension BlockSelection {
    var focusIdentity:String {"\(context.origin?.uuidString ?? "")-\(context.presetID)-\(context.snapshot)-\(context.path)-\(context.blockID)-\(context.position)-\(context.slot)-\(context.modelID)"}
}
struct FocusSurfaceView:View {
    @EnvironmentObject var monitor:StadiumMonitor
    let selection:BlockSelection
    let close:()->Void
    @State private var starting:[String:Value]=[:]
    @State private var point:CGPoint?
    @State private var pending:[String:FocusChange]=[:]
    @State private var runner:Task<Void,Never>?
    @State private var active=false
    @State private var problem:String?
    @State private var precise=false
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    private var model:ModelDefinition? {monitor.catalog[String(selection.context.modelID)]}
    private var definition:FocusDefinition? {monitor.focusCatalog[String(selection.context.modelID)]}
    private var block:SignalBlock? {monitor.snapshot?.blocks.first{$0.blockID==selection.context.blockID && $0.path-1==selection.context.path && $0.slot==selection.context.slot && $0.position==selection.context.position && $0.model==selection.context.modelID}}
    private var controls:[ParameterDefinition] {model?.parameters.filter{!$0.harness && block?.value($0) != nil} ?? []}
    private var cab:Bool {controls.contains{$0.key=="Position"} && controls.contains{$0.key=="Distance"}}
    private var color:Color {block.map{BlockStyle.forBlock($0,monitor:monitor).color} ?? .cyan}
    private var enabled:Bool {active && monitor.connected && problem==nil && (!monitor.busy || runner != nil)}
    var body:some View {
        VStack(spacing:0) {
            HStack {
                Button(action:close){Label("Signal Chain",systemImage:"point.3.connected.trianglepath.dotted")}
                Spacer(minLength:4)
                Text("FOCUS VIEW").font(.caption.weight(.semibold)).tracking(1)
                Spacer(minLength:4)
                Button("Restore starting tone"){restore()}.disabled(starting.isEmpty || !enabled || runner != nil)
                if definition != nil {Button {precise.toggle()} label:{Image(systemName:"slider.horizontal.3")}.accessibilityLabel("Precise Focus X and Y controls")}
            }.font(.caption).padding(.horizontal,12).frame(height:32).background(color.opacity(0.10))
            if let problem {Text(problem+" Close and reopen Focus View to refresh.").font(.caption).foregroundStyle(.orange).padding(8).frame(maxWidth:.infinity,maxHeight:.infinity)}
            else if let definition {
                if precise || voiceOver {preciseControls(definition)}else {xyPad(definition)}
            } else if cab {cabPad}
            else if model?.category=="eq" {FocusEQView(selection:selection,queue:enqueue).tint(color)}
            else {VStack(spacing:8){Image(systemName:model?.needsLibraryFile==true ? "waveform":"slider.horizontal.3").font(.largeTitle);Text(model?.needsLibraryFile==true ? "Clone tone controls":"No factory Focus surface for this model");Text("Use the model's parameter controls below").font(.caption).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,maxHeight:.infinity)}
            HStack {Text(runner != nil ? "Applying tone…":point==nil ? "Current tone preserved":"Focus tone · unsaved");Spacer();Text(definition != nil ? "Tap a named tone · Drag to blend":cab ? "Drag to place microphone":"Select a band · Drag to adjust")}.font(.system(size:10)).foregroundStyle(.secondary).padding(.horizontal,12).frame(height:22)
        }.background(LinearGradient(colors:[color.opacity(0.12),Color(white:0.025)],startPoint:.topLeading,endPoint:.bottomTrailing)).tint(color)
        .onAppear {active=true;for control in controls {starting[control.identity]=block?.value(control)}}
        .onDisappear {active=false;pending=[:]}
    }
    private func xyPad(_ d:FocusDefinition)->some View {
        GeometryReader {g in
            let inset:CGFloat=min(100,g.size.width/6),vertical:CGFloat=24,w=max(1,g.size.width-2*inset),h=max(1,g.size.height-2*vertical)
            ZStack {
                Canvas {ctx,size in
                    for n in 0...4 {
                        let x=inset+w*CGFloat(n)/4,y=vertical+h*CGFloat(n)/4
                        var line=Path();line.move(to:CGPoint(x:x,y:vertical));line.addLine(to:CGPoint(x:x,y:vertical+h));line.move(to:CGPoint(x:inset,y:y));line.addLine(to:CGPoint(x:inset+w,y:y));ctx.stroke(line,with:.color(color.opacity(0.13)),lineWidth:1)
                    }
                }.allowsHitTesting(false)
                Image(systemName:model?.category=="amp" || model?.category=="preamp" ? "hifispeaker.2":"guitars.fill").font(.system(size:min(100,g.size.height*0.5),weight:.ultraLight)).foregroundStyle(color.opacity(0.12)).allowsHitTesting(false)
                if let point {Circle().fill(color.opacity(0.25)).overlay(Circle().stroke(.white,lineWidth:2)).frame(width:30,height:30).position(x:inset+(point.x+1)*w/2,y:vertical+(1-point.y)*h/2).allowsHitTesting(false)}
                ForEach(0..<5) {i in
                    let p=Self.points[i]
                    Button(d.names.indices.contains(i) ? d.names[i]:"Tone \(i+1)"){move(x:p.x,y:p.y)}.font(.system(size:12,weight:.medium)).frame(maxWidth:160).lineLimit(2).multilineTextAlignment(.center).padding(.horizontal,8).padding(.vertical,7).background(.black.opacity(0.7),in:Capsule()).overlay(Capsule().stroke(point==p ? color:.white.opacity(0.15),lineWidth:1)).position(x:inset+(p.x+1)*w/2,y:vertical+(1-p.y)*h/2).disabled(!enabled)
                }
            }.contentShape(Rectangle()).highPriorityGesture(DragGesture(minimumDistance:8).onChanged{v in move(x:(v.location.x-inset)/w*2-1,y:1-(v.location.y-vertical)/h*2)}.onEnded{v in move(x:(v.location.x-inset)/w*2-1,y:1-(v.location.y-vertical)/h*2)})
            .accessibilityElement(children:.contain).accessibilityLabel("Focus tone blend pad")
        }
    }
    private func preciseControls(_ d:FocusDefinition)->some View {
        VStack(spacing:4) {
            HStack {ForEach(0..<5){i in Button(d.names[i]){move(x:Self.points[i].x,y:Self.points[i].y)}.font(.caption).buttonStyle(.bordered)}}
            HStack {Text("X");Slider(value:Binding(get:{Double(point?.x ?? 0)},set:{move(x:$0,y:Double(point?.y ?? 0))}),in:-1...1,step:0.01).accessibilityLabel("Focus X, left to right");Text(String(format:"%.2f",point?.x ?? 0)).monospacedDigit()}
            HStack {Text("Y");Slider(value:Binding(get:{Double(point?.y ?? 0)},set:{move(x:Double(point?.x ?? 0),y:$0)}),in:-1...1,step:0.01).accessibilityLabel("Focus Y, bottom to top");Text(String(format:"%.2f",point?.y ?? 0)).monospacedDigit()}
        }.padding(12).disabled(!enabled).frame(maxHeight:.infinity)
    }
    private var cabPad:some View {
        GeometryReader {g in
            ZStack {
                RoundedRectangle(cornerRadius:12).fill(.black.opacity(0.45)).overlay(RoundedRectangle(cornerRadius:12).stroke(color.opacity(0.5))).padding(16)
                Circle().stroke(color.opacity(0.4),lineWidth:3).frame(width:g.size.height*0.6,height:g.size.height*0.6).position(x:g.size.width/2,y:g.size.height/2)
                VStack {HStack {Text("MIC POSITION / DISTANCE");Spacer();Text("Far")};Spacer();HStack {Text("Center");Spacer();Text("Edge")};Spacer();Text("Near")}.font(.caption2).padding(24).foregroundStyle(.secondary).allowsHitTesting(false)
                Image(systemName:"mic.fill").font(.title).foregroundStyle(color).position(x:24+CGFloat(cabAxis("Position"))*(g.size.width-48),y:24+(1-CGFloat(cabAxis("Distance")))*(g.size.height-48)).allowsHitTesting(false)
            }.contentShape(Rectangle()).gesture(DragGesture(minimumDistance:0).onChanged{v in moveCab(x:(v.location.x-24)/max(1,g.size.width-48),y:1-(v.location.y-24)/max(1,g.size.height-48))}).disabled(!enabled)
            .accessibilityLabel("Cabinet microphone placement; precise controls below")
        }
    }
    private func cabAxis(_ key:String)->Double {guard let p=controls.first(where:{$0.key==key}),let n=block?.value(p)?.numeric,p.maximum>p.minimum else{return 0.5};return (n-p.minimum)/(p.maximum-p.minimum)}
    private func moveCab(x:Double,y:Double) {
        let changes=[("Position",x),("Distance",y)].compactMap {key,axis -> FocusChange? in
            guard let p=controls.first(where:{$0.key==key}) else{return nil}
            var n=p.minimum+max(0,min(1,axis))*(p.maximum-p.minimum)
            if key=="Distance" {n=(n*4).rounded()/4};n=max(p.minimum,min(p.maximum,n))
            return FocusChange(definition:p,value:.number(n))
        };point=CGPoint(x:x,y:y);enqueue(changes)
    }
    private func move(x:Double,y:Double) {
        guard enabled,let definition,let model else{return}
        do {
            let p=CGPoint(x:try FocusDefinition.normalized(x),y:try FocusDefinition.normalized(y))
            if p==point {return};point=p;enqueue(try definition.changes(x:p.x,y:p.y,model:model))
        }catch {problem=error.localizedDescription}
    }
    private func restore() {
        let allowed=Set(definition?.params.map(\.id) ?? controls.map(\.id))
        enqueue(controls.filter{allowed.contains($0.id)}.compactMap{p in starting[p.identity].map{FocusChange(definition:p,value:$0)}});point=nil
    }
    private func enqueue(_ changes:[FocusChange]) {
        guard enabled,!changes.isEmpty else{return}
        for change in changes {pending[change.definition.identity]=change}
        guard runner==nil else{return}
        runner=Task {@MainActor in
            defer{runner=nil}
            do {
                while active && !pending.isEmpty {
                    try Task.checkCancellation()
                    let batch=Array(pending.values);pending=[:]
                    guard let current=block else{throw ProtocolError.invalid("The selected block changed.")}
                    let expected=Dictionary(uniqueKeysWithValues:controls.compactMap{p in current.value(p).map{(p.identity,$0)}})
                    try await monitor.applyFocus(context:selection.context,changes:batch,expected:expected)
                }
            }catch is CancellationError {pending=[:]}
            catch {pending=[:];problem=error.localizedDescription}
        }
    }
    private static let points=[CGPoint(x:0,y:0),CGPoint(x:-1,y:-1),CGPoint(x:-1,y:1),CGPoint(x:1,y:-1),CGPoint(x:1,y:1)]
}

/// Draggable band controls in frequency/gain space. This is a control graph,
/// not a live spectrum or a claim about the device's measured filter response.
private struct FocusEQView:View {
    @EnvironmentObject var monitor:StadiumMonitor
    let selection:BlockSelection
    let queue:([FocusChange])->Void
    private var parameters:[ParameterDefinition] {monitor.catalog[String(selection.context.modelID)]?.parameters.filter{!$0.harness} ?? []}
    private var bands:[ParameterDefinition] {parameters.filter{$0.type=="f" && $0.minimum<0 && $0.maximum>0 && ($0.key.lowercased().contains("gain") || $0.unit=="dB") && $0.key != "Level"}}
    private var block:SignalBlock? {monitor.snapshot?.blocks.first{$0.blockID==selection.context.blockID && $0.path-1==selection.context.path && $0.slot==selection.context.slot}}
    private func frequency(_ p:ParameterDefinition)->ParameterDefinition? {parameters.first{$0.key==p.key.replacingOccurrences(of:"Gain",with:"Freq") && $0.key != p.key && $0.minimum>0}}
    private func hz(_ p:ParameterDefinition,index:Int)->Double {
        if let f=frequency(p),let n=block?.value(f)?.numeric {return n}
        let text=p.key.replacingOccurrences(of:"p",with:".").replacingOccurrences(of:"kHz",with:"").replacingOccurrences(of:"Hz",with:"")
        if let n=Double(text) {return n*(p.key.contains("kHz") ? 1000:1)}
        return 20*pow(1000,Double(index+1)/Double(bands.count+1))
    }
    var body:some View {
        GeometryReader {g in
            let width=max(1,g.size.width-64),height=max(1,g.size.height-52)
            ZStack {
                Canvas {ctx,size in
                    for f in [20.0,100,1000,10000,20000] {
                        let x=32+log10(f/20)/3*width
                        var line=Path();line.move(to:CGPoint(x:x,y:24));line.addLine(to:CGPoint(x:x,y:24+height));ctx.stroke(line,with:.color(.gray.opacity(0.3)),lineWidth:1)
                        ctx.draw(Text(f>=1000 ? "\(Int(f/1000))k":"\(Int(f))").font(.system(size:9)).foregroundColor(.gray),at:CGPoint(x:x,y:12))
                    }
                    for n in [-24.0,-12,0,12,24] {
                        let y=24+(24-n)/48*height
                        var line=Path();line.move(to:CGPoint(x:32,y:y));line.addLine(to:CGPoint(x:32+width,y:y));ctx.stroke(line,with:.color(.gray.opacity(n==0 ? 0.7:0.2)),lineWidth:1)
                    }
                }.allowsHitTesting(false)
                ForEach(Array(bands.enumerated()),id:\.element.identity) {index,p in
                    let n=block?.value(p)?.numeric ?? 0,x=32+log10(max(20,min(20000,hz(p,index:index)))/20)/3*width,y=24+(24-max(-24,min(24,n)))/48*height
                    Text(p.key.replacingOccurrences(of:"Gain",with:"")).font(.system(size:9,weight:.semibold)).lineLimit(1).minimumScaleFactor(0.6).frame(width:42,height:32).background(.black,in:Capsule()).overlay(Capsule().stroke(.tint,lineWidth:2)).position(x:x,y:y)
                        .gesture(DragGesture(minimumDistance:0,coordinateSpace:.named("focus-eq")).onChanged{v in
                            let gain=max(p.minimum,min(p.maximum,24-(v.location.y-24)/height*48))
                            var changes=[FocusChange(definition:p,value:.number(gain))]
                            if let f=frequency(p) {let h=20*pow(1000,max(0,min(1,(v.location.x-32)/width)));changes.append(FocusChange(definition:f,value:.number(max(f.minimum,min(f.maximum,h)))))}
                            queue(changes)
                        })
                        .accessibilityElement(children:.ignore).accessibilityLabel(p.name).accessibilityValue(p.display(block?.value(p) ?? .null)).accessibilityAdjustableAction {direction in queue([FocusChange(definition:p,value:.number(max(p.minimum,min(p.maximum,n+(direction == .increment ? 0.5 : -0.5)))))])}
                }
                VStack {Spacer();Text(bands.isEmpty ? "EQ controls below":"Drag bands for gain / frequency · Q and filters below").font(.system(size:9)).foregroundStyle(.secondary)}
            }.coordinateSpace(name:"focus-eq")
        }
    }
}
