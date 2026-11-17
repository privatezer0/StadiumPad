import SwiftUI
import StadiumProtocol

struct PresetSidebar:View {
    @EnvironmentObject var monitor:StadiumMonitor
    let refreshID:Int
    @State private var search=""
    @State private var error:String?
    @State private var expanded:Set<Int>=[-2]
    private var isUser:Bool {monitor.presetContainer != -1}
    private func matches(_ preset:PresetSlot)->Bool {search.isEmpty || preset.name.localizedCaseInsensitiveContains(search) || preset.label.localizedCaseInsensitiveContains(search)}
    var body:some View {
        VStack(spacing:0) {
            HStack(spacing:7) {Image(systemName:"magnifyingglass");TextField("Search Presets",text:$search).textInputAutocapitalization(.never).autocorrectionDisabled();if !search.isEmpty {Button {search=""} label:{Image(systemName:"xmark.circle.fill")}}}.font(.callout).padding(.horizontal,10).frame(height:46).background(EditorTheme.gold.opacity(0.10))
            Menu {
                Button("User Presets & Folders"){monitor.presetContainer = -2}
                Button("Factory Presets"){monitor.presetContainer = -1}
            } label:{HStack {Image(systemName:isUser ? "person.crop.rectangle":"building.2");Text(isUser ? "USER":"FACTORY").font(.callout.weight(.medium));Spacer();Image(systemName:"chevron.down").font(.caption)}.padding(.horizontal,12).frame(height:38).background(EditorTheme.gold.opacity(0.14))}
            ScrollViewReader {proxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing:0) {
                        if isUser {
                            ForEach(monitor.presetFolders) {folder in
                                let includeFolder=search.isEmpty || folder.name.localizedCaseInsensitiveContains(search)
                                let children=includeFolder ? folder.presets:folder.presets.filter(matches)
                                if includeFolder || !children.isEmpty {
                                    folderHeader(folder.name,id:folder.id,count:folder.presets.count)
                                    if expanded.contains(folder.id) || !search.isEmpty {ForEach(children) {preset in presetRow(preset,in:folder.id)}}
                                }
                            }
                            folderHeader("All User Presets",id:-2,count:monitor.presets.count)
                            if expanded.contains(-2) || !search.isEmpty {ForEach(monitor.presets.filter(matches)){preset in presetRow(preset,in:-2)}}
                        } else {ForEach(monitor.presets.filter(matches)){preset in presetRow(preset,in:-1)}}
                    }
                }.onChange(of:monitor.snapshot?.presetID){_,id in
                    guard search.isEmpty,let id else{return}
                    if let folder=monitor.presetFolders.first(where:{$0.presets.contains{$0.contentID==id}}),isUser {expanded.insert(folder.id);proxy.scrollTo("\(folder.id)-\(id)",anchor:.center)}
                    else {expanded.insert(-2);proxy.scrollTo("\(monitor.presetContainer)-\(id)",anchor:.center)}
                }
            }
            Text(error ?? (isUser ? "\(monitor.presetFolders.count) folders · \(monitor.presets.count) presets":"\(monitor.presets.count) Factory presets")).font(.caption2).lineLimit(1).frame(height:24).foregroundStyle(EditorTheme.gold.opacity(0.7))
        }.foregroundStyle(EditorTheme.gold).background(LinearGradient(colors:[Color(red:0.10,green:0.095,blue:0.035),EditorTheme.panel],startPoint:.top,endPoint:.bottom)).overlay(alignment:.trailing){Rectangle().fill(EditorTheme.border).frame(width:1)}
        .task(id:"\(refreshID)-\(monitor.connected)-\(monitor.presetContainer)") {
            if monitor.connected {do {_ = try await monitor.library();error=nil}catch is CancellationError {}catch {if !Task.isCancelled && monitor.connected {self.error=error.localizedDescription}}}
        }
    }
    private func folderHeader(_ name:String,id:Int,count:Int)->some View {
        Button {if expanded.contains(id) {expanded.remove(id)}else{expanded.insert(id)}} label:{
            HStack(spacing:7) {Image(systemName:expanded.contains(id) ? "chevron.down":"chevron.right").font(.caption2).frame(width:10);Image(systemName:"folder");Text(name).lineLimit(1);Spacer(minLength:0);Text(String(count)).font(.caption2).opacity(0.6)}.font(.callout.weight(.medium)).padding(.horizontal,10).frame(height:40).background(EditorTheme.gold.opacity(0.07))
        }.buttonStyle(.plain).accessibilityLabel("\(name), \(count) presets, \(expanded.contains(id) ? "expanded":"collapsed")")
    }
    private func presetRow(_ preset:PresetSlot,in folder:Int)->some View {
        Button {Task {if await monitor.load(preset) {error=nil}}} label:{
            HStack(spacing:6) {Image(systemName:"doc").font(.caption).opacity(0.6);Text(preset.label).font(.callout.monospacedDigit().weight(.semibold)).frame(width:34,alignment:.leading);Text(preset.name).font(.callout).lineLimit(1);Spacer(minLength:0)}.padding(.leading,folder>0 ? 26:12).padding(.trailing,8).frame(height:44).background(monitor.snapshot?.presetID==preset.contentID ? EditorTheme.gold.opacity(0.24):.clear).overlay(alignment:.bottom){Rectangle().fill(EditorTheme.gold.opacity(0.12)).frame(height:0.5)}
        }.buttonStyle(.plain).id("\(folder)-\(preset.contentID ?? 0)").disabled(monitor.busy || !monitor.connected)
    }
}
