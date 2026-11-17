import SwiftUI
import StadiumProtocol

struct ModelBrowser:View {
    @EnvironmentObject var monitor:StadiumMonitor
    let selection:BlockSelection?
    var choose:((ModelDefinition)->Void)?
    @State private var category="All"
    @State private var search=""
    private let categories=["All","Amp","Preamp","Cab / IR","Distortion","Delay","Reverb","Modulation","Dynamics","EQ","Pitch / Synth","Wah / Filter","Volume / Pan","Looper","FX Loop","Utility","Clones","Input","Output"]
    private var models:[ModelDefinition] {
        monitor.catalog.values.filter {model in
            (category=="All" || (category=="Clones" ? [836,838,839,840].contains(model.id):model.browserCategory==category)) &&
            (search.isEmpty || model.name.localizedCaseInsensitiveContains(search) || (model.basedOn ?? "").localizedCaseInsensitiveContains(search))
        }.sorted {a,b in a.name==b.name ? a.id<b.id:a.name.localizedStandardCompare(b.name) == .orderedAscending}
    }
    var body:some View {
        GeometryReader {geometry in
            VStack(spacing:0) {
                HStack {Image(systemName:"magnifyingglass");TextField("Search models",text:$search).textInputAutocapitalization(.never).autocorrectionDisabled();if !search.isEmpty {Button {search=""} label:{Image(systemName:"xmark.circle.fill")}}}.font(.caption).padding(.horizontal,10).frame(height:42).background(.white.opacity(0.045))
                HStack(spacing:0) {
                    ScrollViewReader {categoryProxy in ScrollView {
                        LazyVStack(spacing:0) {
                            ForEach(categories,id:\.self) {name in
                                Button {category=name} label:{Text(name).font(.system(size:12,weight:.medium)).lineLimit(1).frame(maxWidth:.infinity,alignment:.leading).padding(.horizontal,8).frame(height:36).background(category==name ? EditorTheme.categoryColor(name).opacity(0.24):.clear)}.buttonStyle(.plain).foregroundStyle(EditorTheme.categoryColor(name)).id(name)
                            }
                        }
                    }.onChange(of:category){_,name in categoryProxy.scrollTo(name,anchor:.center)}}.frame(width:max(86,min(130,geometry.size.width*0.36))).background(.white.opacity(0.025))
                    Rectangle().fill(EditorTheme.border).frame(width:1)
                    ScrollViewReader {modelProxy in ScrollView {
                        LazyVStack(spacing:0) {
                            ForEach(models,id:\.id) {model in
                                Button {choose?(model)} label:{
                                    VStack(alignment:.leading,spacing:3) {
                                        HStack {Text(model.name).font(.system(size:13,weight:.medium)).lineLimit(2);Spacer(minLength:0);if model.id==selection?.context.modelID {Image(systemName:"checkmark").font(.caption)}}
                                        if !model.variant.isEmpty {Text(model.variant).font(.system(size:10)).foregroundStyle(.secondary)}
                                        if let based=model.basedOn,!based.isEmpty {Text(based).font(.system(size:10)).foregroundStyle(.secondary).lineLimit(1)}
                                        if model.needsLibraryFile {Text("Requires library file").font(.system(size:10)).foregroundStyle(.orange)}
                                    }.padding(.horizontal,9).padding(.vertical,9).frame(maxWidth:.infinity,alignment:.leading).background(model.id==selection?.context.modelID ? EditorTheme.categoryColor(model.browserCategory).opacity(0.35):.clear).overlay(alignment:.bottom){Rectangle().fill(.white.opacity(0.06)).frame(height:0.5)}
                                }.buttonStyle(.plain).id(model.id).disabled(choose != nil && (!canChoose(model) || monitor.busy || !monitor.connected))
                            }
                        }
                    }
                    .onChange(of:selection?.id){_,_ in synchronize(modelProxy)}
                    .onChange(of:category){_,_ in if let id=selection?.context.modelID {modelProxy.scrollTo(id,anchor:.center)}}
                    .onAppear{synchronize(modelProxy)}
                    }
                }
                HStack {Text("\(models.count) models");Spacer();if choose != nil {Text("Select to replace")}}.font(.system(size:10)).foregroundStyle(.secondary).padding(.horizontal,8).frame(height:24).background(.white.opacity(0.035))
            }.background(EditorTheme.panel)

        }.overlay(alignment:.trailing){Rectangle().fill(EditorTheme.border).frame(width:1)}
    }
    private func synchronize(_ proxy:ScrollViewProxy) {
        guard let id=selection?.context.modelID,let model=monitor.catalog[String(id)] else{return}
        category=model.browserCategory;search=""
        Task {@MainActor in await Task.yield();proxy.scrollTo(id,anchor:.center)}
    }
    private func canChoose(_ model:ModelDefinition)->Bool {
        guard let selection,let source=monitor.catalog[String(selection.context.modelID)] else{return false}
        if selection.context.position%14==13 {return model.ioRole=="outputs" && !(selection.context.path==1 && [779,784,788].contains(model.id))}
        return (1...12).contains(selection.context.position%14) && source.ioRole==nil && !["split","join"].contains(source.category ?? "") && model.replaceable && model.isCab==source.isCab
    }
}
struct SaveDiskIcon:View {
    var body:some View {
        ZStack {
            RoundedRectangle(cornerRadius:2).stroke(lineWidth:1.5)
            Rectangle().stroke(lineWidth:1).frame(width:13,height:8).offset(y:-7)
            Rectangle().fill(.primary).frame(width:3,height:6).offset(x:4,y:-7)
            RoundedRectangle(cornerRadius:1).stroke(lineWidth:1).frame(width:15,height:9).offset(y:6)
        }.frame(width:24,height:25)
    }
}
