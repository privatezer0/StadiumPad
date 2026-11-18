import SwiftUI
import StadiumProtocol

struct BlockSelection:Identifiable {let id=UUID();let block:SignalBlock;let context:EditContext}
struct InlineBlockEditor:View {
    @EnvironmentObject var monitor:StadiumMonitor
    let selection:BlockSelection?
    let select:(SignalBlock)->Void
    let browse:()->Void
    var focusShown=false
    var toggleFocus:()->Void = {}
    @State private var page=0
    var current:SignalBlock? {
        guard let selection,let state=monitor.snapshot,state.presetID==selection.context.presetID,state.activeSnapshot==selection.context.snapshot else{return nil}
        return state.blocks.first{$0.blockID==selection.context.blockID && $0.position==selection.context.position && $0.path-1==selection.context.path && $0.slot==selection.context.slot && $0.model==selection.context.modelID}
    }
    var body:some View {
        GeometryReader {geometry in
            if let block=current,let selection {
                let style=BlockStyle.forBlock(block,monitor:monitor)
                let allDefinitions=monitor.definitions(block)
                let hype=monitor.catalog[String(block.model)]?.hypeParameter.flatMap{block.value($0)==nil ? nil:$0}
                let definitions=allDefinitions.filter{$0.identity != hype?.identity}
                let rows=max(1,Int((geometry.size.height-108)/76))
                let capacity=rows*2
                let pages=max(1,(definitions.count+capacity-1)/capacity)
                let safePage=min(page,pages-1)
                let visible=Array(definitions.dropFirst(safePage*capacity).prefix(capacity))
                VStack(spacing:0) {
                    HStack(spacing:10) {
                        Button(action:toggleFocus){Image(systemName:"camera.aperture").font(.title2).foregroundStyle(focusShown ? .white:style.color)}.accessibilityLabel(focusShown ? "Close Focus View":"Open Focus View")
                        Image(systemName:style.symbol).font(.title2).foregroundStyle(style.color)
                        VStack(alignment:.leading,spacing:2) {Text(style.title.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(style.color);Text(monitor.blockName(block)).font(.title3.weight(.medium)).lineLimit(1)}
                        if let hype,let value=block.value(hype) {
                            Spacer(minLength:4)
                            HypeKnob(definition:hype,value:value,enabled:monitor.connected && !monitor.busy,color:style.color) {desired,expected in
                                Task {await monitor.edit(context:selection.context,definition:hype,value:desired,expected:expected)}
                            }.id(selection.focusIdentity+"-hype")
                        }
                        Spacer(minLength:4)
                        if let state=monitor.snapshot {
                            let siblings=state.blocks.filter{$0.path==block.path && $0.position==block.position}
                            if siblings.count>1 {ForEach(siblings) {sibling in Button("Cab \(sibling.slot+1)"){select(sibling)}.font(.caption).buttonStyle(.bordered).tint(sibling.slot==block.slot ? style.color:.gray)}}
                        }
                        Text(block.enabled ? "ACTIVE":"BYPASSED").font(.caption2).foregroundStyle(block.enabled ? style.color:.gray)
                    }.padding(.horizontal,16).frame(height:58).background(LinearGradient(colors:[style.color.opacity(0.30),style.color.opacity(0.08)],startPoint:.leading,endPoint:.trailing))
                    if visible.isEmpty {Spacer();Text("No named controls available for this block").foregroundStyle(.secondary);Spacer()}
                    else {
                        LazyVGrid(columns:[GridItem(.flexible(),spacing:24),GridItem(.flexible())],alignment:.leading,spacing:0) {
                            ForEach(visible,id:\.identity) {definition in
                                if let value=block.value(definition) {
                                    ParameterRow(definition:definition,value:value,enabled:monitor.connected && !monitor.busy && selection.context.slot<2) {value in Task {await monitor.edit(context:selection.context,definition:definition,value:value,expected:block.value(definition) ?? .null)}}
                                        .id("\(selection.id)-\(definition.identity)").frame(height:76).tint(style.color)
                                }
                            }
                        }.padding(.horizontal,18)
                        Spacer(minLength:0)
                    }
                    HStack {Button("Change Model",action:browse).font(.caption);Text("Path \(block.path) · \(allDefinitions.count) controls").font(.caption).foregroundStyle(.secondary);Spacer();if monitor.snapshot?.dirty==true {Text("Unsaved changes").font(.caption).foregroundStyle(.orange)};PageButtons(page:$page,count:pages)}.padding(.horizontal,14).frame(height:44).background(.white.opacity(0.035))
                }.onChange(of:pages){_,count in page=min(page,count-1)}.background(.black).overlay(alignment:.top){Rectangle().fill(style.color.opacity(0.45)).frame(height:1)}
            } else {
                VStack(spacing:10) {Image(systemName:"slider.horizontal.3").font(.largeTitle);Text(selection==nil ? "Select a block in the signal chain":"The block changed. Select it again.").font(.headline)}.foregroundStyle(.gray).frame(maxWidth:.infinity,maxHeight:.infinity).background(.black)
            }
        }.onChange(of:selection?.id){_,_ in page=0}
    }
}
struct ParameterRow:View {
    let definition:ParameterDefinition
    let value:Value
    let enabled:Bool
    let submit:(Value)->Void
    @State private var draft:Double
    @State private var dragging=false
    init(definition:ParameterDefinition,value:Value,enabled:Bool,submit:@escaping(Value)->Void) {self.definition=definition;self.value=value;self.enabled=enabled;self.submit=submit;_draft=State(initialValue:min(definition.maximum,max(definition.minimum,value.numeric ?? definition.minimum)))}
    var body:some View {
        VStack(alignment:.leading,spacing:10) {
            if definition.type=="b",let flag=value.boolean {
                Toggle(isOn:Binding(get:{flag},set:{submit(.bool($0))})) {HStack {Text(definition.name);Spacer();Text(definition.display(value)).foregroundStyle(.secondary)}}
            } else if let options=definition.options,definition.type=="i",let number=value.numeric,number.rounded()==number {
                HStack {
                    Text(definition.name)
                    Spacer(minLength:4)
                    Picker(definition.name,selection:Binding(get:{Int(number)},set:{submit(.int(Int64($0)))})) {
                        ForEach(Array(options.enumerated()),id:\.offset){index,label in Text(label).tag(Int(definition.minimum)+index)}
                    }.pickerStyle(.menu).labelsHidden()
                }
            } else if let number=value.numeric,number.isFinite,definition.minimum<definition.maximum,definition.containsWireValue(number) {
                HStack {Text(definition.name);Spacer();Text(definition.display(dragging ? draftValue:value)).monospacedDigit().foregroundStyle(.secondary)}
                Slider(value:$draft,in:definition.range,step:definition.type=="i" ? 1:max((definition.maximum-definition.minimum)/1000,0.000001),onEditingChanged:{active in dragging=active;if !active {submit(draftValue)}})
            } else {
                HStack {Text(definition.name);Spacer();Text(definition.display(value)).foregroundStyle(.secondary)}
            }
        }.padding(.vertical,8).disabled(!enabled)
        .onChange(of:value){_,new in if !dragging,let number=new.numeric {draft=min(definition.maximum,max(definition.minimum,number))}}
    }
    var draftValue:Value {definition.type=="i" ? .int(Int64(draft.rounded())):.number(draft)}
}
