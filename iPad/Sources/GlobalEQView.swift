import SwiftUI
import StadiumProtocol

private extension EQBand {
    var tint:Color {switch self {case .lowCut,.highCut:return EditorTheme.gold;case .lowShelf:return .orange;case .low:return .red;case .mid:return .purple;case .high:return .blue;case .highShelf:return .green}}
    var glyph:String {switch self {case .low:return "L";case .mid:return "M";case .high:return "H";case .lowShelf:return "⊣";case .highShelf:return "⊢";case .lowCut:return "╱";case .highCut:return "╲"}}
}
struct GlobalEQView:View {
    @EnvironmentObject var monitor:StadiumMonitor
    @State private var output=EQOutput.quarter
    @State private var band=EQBand.lowCut
    @State private var clipboard:Value?
    @State private var entry:EQParameter?
    @State private var entryText=""
    @State private var pending:[String:GlobalEQChange]=[:]
    @State private var runner:Task<Void,Never>?
    @State private var draft:GlobalEQState?
    @State private var active=false
    let preview:Bool
    init(preview:Bool,initialOutput:EQOutput = .quarter,initialBand:EQBand = .lowCut){self.preview=preview;_output=State(initialValue:initialOutput);_band=State(initialValue:initialBand)}
    private var state:GlobalEQState? {draft ?? monitor.globalEQ}
    private var available:Bool {monitor.connected && state != nil && active && (!monitor.busy || runner != nil)}
    var body:some View {
        GeometryReader {g in VStack(spacing:0) {
            Text("Global EQ").font(.system(size:28,weight:.light)).frame(maxWidth:.infinity).frame(height:58).background(EditorTheme.header)
            HStack(spacing:0) {
                if let state {EQPlot(output:state.output(output),selected:$band,changed:enqueue).padding(.horizontal,16).padding(.vertical,10)}else {Text("Connect to Stadium to read Global EQ.").foregroundStyle(.secondary).frame(maxWidth:.infinity,maxHeight:.infinity)}
                VStack(alignment:.leading,spacing:18) {
                    Button {clipboard=state?.output(output)}label:{Label("Copy EQ",systemImage:"doc.on.doc")}.disabled(state==nil)
                    Button {if let clipboard {apply(.replace(clipboard))}}label:{Label("Paste EQ",systemImage:"doc.on.clipboard")}.disabled(clipboard==nil || !available || runner != nil)
                    Button {apply(.reset)}label:{Label("Reset EQ",systemImage:"arrow.counterclockwise")}.disabled(state?.output(output)["drty"].boolean != true || !available || runner != nil)
                    Spacer(minLength:0)
                }.font(.system(size:g.size.width<900 ? 12:15)).padding(.top,12).frame(width:g.size.width<900 ? 108:145,alignment:.leading)
            }.frame(height:max(205,min(355,g.size.height*0.4))).background(Color(white:0.035))
            HStack(spacing:0) {
                ForEach(EQOutput.allCases,id:\.self){item in Button {output=item;draft=nil}label:{Label(item.name,systemImage:item == .phones ? "headphones":item == .xlr ? "circle.dotted":"hexagon").font(.system(size:13)).padding(.horizontal,10).frame(height:32).background(output==item ? .white.opacity(0.23):.clear)}.disabled(runner != nil || monitor.busy)}
                Spacer(minLength:5);Text("Global EQ").foregroundStyle(EditorTheme.gold).font(.system(size:19,weight:.semibold));Text(output.name).font(.system(size:19,weight:.light));Spacer(minLength:5)
                Button {if let state {apply(.enabled(state.output(output)["enab"].boolean != true))}}label:{Image(systemName:"power").font(.system(size:25)).foregroundStyle(state?.output(output)["enab"].boolean==true ? EditorTheme.gold:.gray).frame(width:44,height:42)}.disabled(!available || runner != nil).accessibilityLabel("Global EQ bypass").accessibilityValue(state?.output(output)["enab"].boolean==true ? "On":"Bypassed")
            }.padding(.horizontal,5).frame(height:42).background(Color(white:0.25))
            if let state {GeometryReader {area in
                let controls=band.parameters+[.level],height=max(32,min(70,(area.size.height-12)/CGFloat(controls.count+1)))
                VStack(spacing:0) {
                    HStack {Text("Band").font(.system(size:13)).foregroundStyle(.gray);Spacer();ViewThatFits(in:.horizontal) {
                        HStack(spacing:1){ForEach(EQBand.allCases,id:\.self){item in Button{band=item}label:{Text(item.name).font(.system(size:11)).padding(.horizontal,7).frame(height:29).foregroundStyle(band==item ? .black:item.tint).background(band==item ? item.tint:Color(white:0.12))}}}.clipShape(RoundedRectangle(cornerRadius:4))
                        Menu {ForEach(EQBand.allCases,id:\.self){item in Button(item.name){band=item}}}label:{Text(band.name).foregroundStyle(band.tint)}
                    }}.frame(height:height)
                    ForEach(controls,id:\.self){parameter in control(parameter,state:state,height:height)}
                    Spacer(minLength:0)
                }.padding(.horizontal,g.size.width<900 ? 14:24).padding(.vertical,6)
            }}else {Spacer(minLength:0)}
        }}.background(.black).buttonStyle(.plain)
        .onAppear{active=true}
        .onDisappear{active=false;pending=[:]}
        .onChange(of:monitor.connectionID){_,_ in pending=[:];draft=nil;clipboard=nil;entry=nil;output = .quarter;band = .lowCut}
        .task {guard !preview else{return};while !Task.isCancelled {await monitor.refreshGlobalEQ();try? await Task.sleep(for:.milliseconds(300))}}
        .alert(entry?.name ?? "Value",isPresented:Binding(get:{entry != nil},set:{if !$0 {entry=nil}})){TextField("Value",text:$entryText).keyboardType(.numbersAndPunctuation);Button("Cancel",role:.cancel){entry=nil};Button("Set"){if let entry,let n=Double(entryText){enqueue([GlobalEQChange(band,entry,.number(n))])};entry=nil}}
    }
    @ViewBuilder private func control(_ p:EQParameter,state:GlobalEQState,height:CGFloat)->some View {
        let value=state.parameter(output,band,p),tint=p == .level ? EditorTheme.gold:band.tint
        VStack(alignment:.leading,spacing:2) {
            HStack {
                Text(p.name).font(.system(size:13)).foregroundStyle(.gray);Spacer(minLength:5)
                if p == .enable {HStack(spacing:1){ForEach([false,true],id:\.self){flag in Button {enqueue([GlobalEQChange(band,p,.bool(flag))])}label:{Text(flag ? "On":"Off").font(.system(size:12)).frame(width:44,height:27).foregroundStyle(value.boolean==flag ? .black:tint).background(value.boolean==flag ? tint:Color(white:0.12))}}}.clipShape(RoundedRectangle(cornerRadius:4))}
                else if p == .slope {HStack(spacing:1){ForEach(0..<4){index in Button {enqueue([GlobalEQChange(band,p,.int(Int64(index)))])}label:{Text("\((index+1)*6) dB/oct").font(.system(size:11)).padding(.horizontal,7).frame(height:27).foregroundStyle(value.integer==index ? .black:tint).background(value.integer==index ? tint:Color(white:0.12))}}}.clipShape(RoundedRectangle(cornerRadius:4))}
                else {Button {entryText=value.scalar;entry=p}label:{Text(p.display(value)).font(.system(size:14).monospacedDigit()).foregroundStyle(tint)};Stepper("",onIncrement:{step(p,value,1)},onDecrement:{step(p,value,-1)}).labelsHidden().scaleEffect(0.65).frame(width:65,height:25)}
            }
            if p != .enable && p != .slope {EQSlider(parameter:p,value:value,tint:tint){enqueue([GlobalEQChange(band,p,.number($0))])}.frame(height:max(8,min(22,height-32)))}
        }.frame(height:height,alignment:.top).disabled(!available)
    }
    private func step(_ p:EQParameter,_ value:Value,_ direction:Double){let n=value.numeric ?? p.range.lowerBound;let increment=p == .frequency ? (n>=1000 ? 100.0:1.0):0.1;enqueue([GlobalEQChange(band,p,.number(min(p.range.upperBound,max(p.range.lowerBound,n+direction*increment))))])}
    private func apply(_ operation:GlobalEQOperation){guard !preview,let expected=monitor.globalEQ else{return};Task {_ = await monitor.editGlobalEQ(expected,output,operation)}}
    private func enqueue(_ changes:[GlobalEQChange]) {
        guard available,let state,!preview else{return}
        do {draft=try GlobalEQOperation.parameters(changes).applying(to:state,output:output)}catch {monitor.errorText=error.localizedDescription;return}
        for change in changes {pending[change.id]=change}
        guard runner==nil else{return};let destination=output,origin=monitor.connectionID
        runner=Task {@MainActor in
            defer{runner=nil;draft=nil}
            while active && !pending.isEmpty && origin==monitor.connectionID {
                try? await Task.sleep(for:.milliseconds(40));guard active,!pending.isEmpty,origin==monitor.connectionID else{return};let changes=Array(pending.values);pending=[:]
                guard let expected=monitor.globalEQ,await monitor.editGlobalEQ(expected,destination,.parameters(changes)) else{pending=[:];return}
            }
        }
    }
}
private struct EQSlider:View {
    let parameter:EQParameter;let value:Value;let tint:Color;let changed:(Double)->Void
    var body:some View {GeometryReader{g in let fraction=((value.numeric ?? parameter.range.lowerBound)-parameter.range.lowerBound)/(parameter.range.upperBound-parameter.range.lowerBound)
        ZStack(alignment:.leading){Rectangle().fill(tint.opacity(0.2));RoundedRectangle(cornerRadius:2).fill(tint).frame(width:4).offset(x:max(0,min(g.size.width-4,g.size.width*fraction)))}.contentShape(Rectangle()).gesture(DragGesture(minimumDistance:0).onChanged{v in changed(parameter.range.lowerBound+(parameter.range.upperBound-parameter.range.lowerBound)*max(0,min(1,v.location.x/max(1,g.size.width))))})
    }}
}
private struct EQPlot:View {
    @State private var dragBand:EQBand?
    let output:Value;@Binding var selected:EQBand;let changed:([GlobalEQChange])->Void
    private let low=20.0,high=20000.0
    var body:some View {GeometryReader {g in
        let left:CGFloat=23,right:CGFloat=23,top:CGFloat=35,bottom:CGFloat=18,w=max(1,g.size.width-left-right),h=max(1,g.size.height-top-bottom)
        let frequencies:[Double]=[20,40,80,100,200,400,600,1000,2000,4000,6000,10000,20000]
        let x:(Double)->CGFloat = {frequency in left+w*log(max(low,min(high,frequency))/low)/log(high/low)}
        let y:(Double)->CGFloat = {gain in top+h*(0.5-max(-24,min(24,gain))/48)}
        ZStack {
            Canvas {context,size in
                for frequency in frequencies {var line=Path();line.move(to:CGPoint(x:x(frequency),y:top));line.addLine(to:CGPoint(x:x(frequency),y:top+h));context.stroke(line,with:.color(EditorTheme.gold.opacity(0.25)),lineWidth:0.5)}
                for db in stride(from:-24,through:24,by:6) {var line=Path();line.move(to:CGPoint(x:left,y:y(Double(db))));line.addLine(to:CGPoint(x:left+w,y:y(Double(db))));context.stroke(line,with:.color(EditorTheme.gold.opacity(0.25)),lineWidth:0.5)}
                var curve=Path();for i in 0...240 {let frequency=low*pow(high/low,Double(i)/240),point=CGPoint(x:x(frequency),y:y(EQResponse.gain(output:output,frequency:frequency)));if i==0 {curve.move(to:point)}else{curve.addLine(to:point)}}
                context.stroke(curve,with:.color(.white.opacity(0.8)),lineWidth:2)
                var selectedCurve=Path();for i in 0...240 {let frequency=low*pow(high/low,Double(i)/240),point=CGPoint(x:x(frequency),y:y(EQResponse.gain(output:output,frequency:frequency,only:selected)));if i==0 {selectedCurve.move(to:point)}else{selectedCurve.addLine(to:point)}}
                context.stroke(selectedCurve,with:.color(selected.tint.opacity(0.7)),lineWidth:1)
            }
            ForEach(frequencies,id:\.self){frequency in if g.size.width>700 || [20,100,1000,10000,20000].contains(frequency) {Text(frequency>=1000 ? "\(Int(frequency/1000))k":"\(Int(frequency))").font(.system(size:10)).foregroundStyle(EditorTheme.gold).position(x:x(frequency),y:13)}}
            ForEach(EQBand.allCases,id:\.self){band in
                let f=GlobalEQState.parameter(in:output,band:band,parameter:.frequency).numeric ?? 1000,db=GlobalEQState.parameter(in:output,band:band,parameter:.gain).numeric ?? 0
                Text(band.glyph).font(.system(size:18,weight:.light)).frame(width:36,height:36).background(band.tint.opacity(0.14),in:Circle()).overlay(Circle().stroke(selected==band ? .white:band.tint,lineWidth:selected==band ? 2:1)).foregroundStyle(band.tint).opacity(GlobalEQState.parameter(in:output,band:band,parameter:.enable).boolean==true ? 1:0.35).position(x:x(f),y:y(db))
                    .accessibilityLabel(band.name).accessibilityAddTraits(.isButton).accessibilityAction{selected=band}
            }
        }.opacity(output["enab"].boolean==true ? 1:0.5).contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance:0).onChanged{v in
                if dragBand==nil {
                    dragBand=EQBand.allCases.min(by:{a,b in
                        func distance(_ band:EQBand)->CGFloat {
                            let frequency=GlobalEQState.parameter(in:output,band:band,parameter:.frequency).numeric ?? 1000,gain=GlobalEQState.parameter(in:output,band:band,parameter:.gain).numeric ?? 0
                            return hypot(v.startLocation.x-x(frequency),v.startLocation.y-y(gain))
                        }
                        return distance(a)<distance(b)
                    })
                    if let candidate=dragBand {
                        let frequency=GlobalEQState.parameter(in:output,band:candidate,parameter:.frequency).numeric ?? 1000,gain=GlobalEQState.parameter(in:output,band:candidate,parameter:.gain).numeric ?? 0
                        if hypot(v.startLocation.x-x(frequency),v.startLocation.y-y(gain))>27 {dragBand=nil;return}
                        selected=candidate
                    }
                }
                guard let band=dragBand,hypot(v.translation.width,v.translation.height)>=3 else{return}
                let frequency=low*pow(high/low,Double(max(0,min(1,(v.location.x-left)/w))))
                var edits=[GlobalEQChange(band,.frequency,.number(frequency))]
                if band.parameters.contains(.gain) {edits.append(GlobalEQChange(band,.gain,.number(Double(max(-24,min(24,(0.5-(v.location.y-top)/h)*48))))))}
                changed(edits)
            }.onEnded{_ in dragBand=nil})
    }}
}
