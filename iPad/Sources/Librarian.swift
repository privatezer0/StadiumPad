import SwiftUI
import StadiumProtocol
import UniformTypeIdentifiers

enum EditorSection:String,CaseIterable {case home="Home",librarian="Librarian",commands="Command Center",eq="Global EQ",songs="Songs"
    var icon:String {switch self {case .home:return "house";case .librarian:return "archivebox";case .commands:return "antenna.radiowaves.left.and.right";case .eq:return "slider.horizontal.3";case .songs:return "music.note"}}
}
enum LibraryCategory:String,CaseIterable {
    case presets="Presets",irs="Cab IRs",favorites="Favorites",templates="Templates",songs="Songs",clones="Clones"
    var icon:String {switch self {case .presets:return "doc";case .irs:return "waveform";case .favorites:return "star";case .templates:return "doc.badge.gearshape";case .songs:return "music.note";case .clones:return "cpu"}}
    var color:Color {switch self {case .irs:return .pink;case .favorites:return .gray;case .songs:return .teal;case .clones:return .red;default:return EditorTheme.gold}}
    var container:Int {switch self {case .presets:return -2;case .irs:return -11;case .favorites:return -8;case .templates:return -3;case .songs:return -7;case .clones:return 0}}
}
struct LibrarianView:View {
    @EnvironmentObject var monitor:StadiumMonitor
    var openEditor:()->Void = {}
    @State private var category:LibraryCategory = .presets
    @State private var folderID = -2
    @State private var search=""
    @State private var selectedID:Int?
    @State private var cloneFolderID = -23
    @State private var cloneTrail:[LibraryEntry]=[]
    @State private var cloneSelection:Int?
    @State private var cloneSearch=""
    @StateObject private var companion=FileCompanion()
    @State private var showPairing=false
    @State private var pairingLink=""
    @State private var showCloneImporter=false
    @State private var importDeviceID:String?
    @State private var importCloneFolder = -23
    @State private var exportFile:CloneShareFile?
    @State private var showCloneName=false
    @State private var showCloneDelete=false
    @State private var cloneOperation=""
    @State private var cloneDraftName=""
    @State private var cloneActionTarget:LibraryEntry?
    @State private var cloneActionParent=0
    @State private var cloneActionDeviceID:String?
    init(openEditor:@escaping ()->Void = {},pairingLink:String?=nil,initialCategory:LibraryCategory = .presets) {
        self.openEditor=openEditor
        _pairingLink=State(initialValue:pairingLink ?? "")
        _showPairing=State(initialValue:pairingLink != nil)
        _category=State(initialValue:pairingLink == nil ? initialCategory:.clones)
    }
    private var folders:[PresetFolder] {monitor.presetFolders}
    private var rows:[PresetSlot] {
        let slots:[PresetSlot]
        if let folder=folders.first(where:{$0.id==folderID}) {slots=folder.presets}
        else {slots=(monitor.libraryEntries[folderID] ?? []).filter{$0.type==2}.map{PresetSlot(.object(["cid_":.int(Int64($0.id)),"name":.string($0.name),"type":.int(2),"posi":.int(Int64($0.position))]))}}
        return slots.filter{search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.label.localizedCaseInsensitiveContains(search)}
    }
    var body:some View {
        GeometryReader {geometry in
            let rail=max(140,min(185,geometry.size.width*0.16))
            HStack(spacing:0) {
                VStack(spacing:2) {
                    ForEach(LibraryCategory.allCases,id: \.self) {item in
                        Button {category=item;selectedID=nil;search=""} label:{
                            HStack(spacing:10) {Image(systemName:item.icon).font(.system(size:26,weight:.ultraLight)).frame(width:30);Text(item.rawValue).font(.system(size:20,weight:.light)).lineLimit(1).minimumScaleFactor(0.6);Spacer(minLength:0)}.padding(.horizontal,12).frame(height:62).background(LinearGradient(colors:[item.color.opacity(category==item ? 0.4:0.12),.black],startPoint:.leading,endPoint:.trailing),in:RoundedRectangle(cornerRadius:8))
                        }.foregroundStyle(item.color)
                    };Spacer()
                    Button {if !companion.paired {showPairing=true}else if let expected=deviceID {Task {do {let _=try await companion.downloadLibrary(deviceID:expected)}catch {monitor.errorText=error.localizedDescription}}}} label:{Label("Download Library",systemImage:"arrow.down.doc").font(.caption).frame(maxWidth:.infinity).frame(height:42).background(EditorTheme.gold.opacity(0.13),in:RoundedRectangle(cornerRadius:6))}.disabled(companion.busy || deviceID==nil).foregroundStyle(EditorTheme.gold)
                    if let backup=companion.latestBackup {Button {exportFile=CloneShareFile(url:backup)} label:{Label("Open Tablet Backup",systemImage:"folder").font(.caption).frame(maxWidth:.infinity).frame(height:40)}.foregroundStyle(EditorTheme.gold)}
                    if companion.busy {ProgressView().controlSize(.small)}
                    Text(companion.status).font(.system(size:10)).foregroundStyle(.secondary).lineLimit(3).padding(.horizontal,4)

                }.padding(6).frame(width:rail).background(EditorTheme.panel)
                if category == .presets {presetLibrary(width:max(210,min(300,(geometry.size.width-rail)*0.30)))}
                else if category == .clones {clones}
                else {LibraryRows(title:category.rawValue,entries:monitor.libraryEntries[category.container] ?? [],canOpen:false).tint(category.color)}
            }.buttonStyle(.plain)
        }.task {if monitor.connected {do {try await monitor.refreshInventory()}catch is CancellationError {}catch {if !Task.isCancelled {monitor.errorText=error.localizedDescription}}}}
        .alert(cloneOperation=="mkdir" ? "New Clone Folder":"Rename Clone",isPresented:$showCloneName) {
            TextField("Name",text:$cloneDraftName)
            Button("Cancel",role:.cancel){}
            Button(cloneOperation=="mkdir" ? "Create":"Rename"){performCloneAction()}
        } message:{Text("Changes the connected Stadium's User Clone library. Presets are not saved or recalled.")}
        .confirmationDialog("Delete \(cloneActionTarget?.name ?? "selected clone")?",isPresented:$showCloneDelete,titleVisibility:.visible) {
            Button("Delete",role:.destructive){performCloneAction()}
        } message:{Text("The Mac retains a .clone backup before deleting a clone. Only empty custom folders can be deleted. Built-in folders stay protected.")}
        .sheet(isPresented:$showPairing) {pairingSheet}
        .sheet(item:$exportFile) {CloneShareView(url:$0.url)}
        .fileImporter(isPresented:$showCloneImporter,allowedContentTypes:[.item],allowsMultipleSelection:true) {result in
            Task {do {
                let urls=try result.get()
                guard let expected=importDeviceID,expected==deviceID else{throw ProtocolError.invalid("The connected Stadium changed. Choose the files again.")}
                try await companion.importFiles(urls,deviceID:expected,folder:importCloneFolder)
                try await monitor.refreshInventory();try await monitor.readLibraryFolder(cloneFolderID)
            } catch {monitor.errorText=error.localizedDescription}}
        }
        .task(id:"\(category)-\(cloneFolderID)-\(monitor.connectionID)") {
            guard category == .clones else{return}
            while !Task.isCancelled && monitor.connected {
                do {try await monitor.readLibraryFolder(-14);if cloneTrail.isEmpty,let root=cloneFolders.first(where:{$0.id==cloneFolderID}) {cloneTrail=[root]};try await monitor.readLibraryFolder(cloneFolderID);try await Task.sleep(for:.seconds(3))}
                catch is CancellationError {return}
                catch {if !Task.isCancelled {monitor.errorText=error.localizedDescription};return}
            }
        }
    }
    private func tool(_ label:String,_ icon:String,enabled:Bool=false,action:@escaping ()->Void = {})->some View {
        Button(action:action){VStack(spacing:5){Image(systemName:icon).font(.system(size:22,weight:.ultraLight));Text(label).font(.system(size:11)).lineLimit(2).minimumScaleFactor(0.65)}.frame(minWidth:28,maxWidth:74).frame(height:58).background(category.color.opacity(0.13),in:RoundedRectangle(cornerRadius:6))}.disabled(!enabled).opacity(enabled ? 1:0.35).accessibilityLabel(label)
    }
    private func presetLibrary(width:CGFloat)->some View {
        HStack(spacing:1) {
            VStack(spacing:0) {
                caption("Setlists")
                HStack(spacing:3) {tool("New","doc.badge.plus");tool("Delete","trash");tool("Duplicate","doc.on.doc");tool("Import","square.and.arrow.down");tool("Export","square.and.arrow.up")}.padding(6)
                HStack {Image(systemName:"magnifyingglass");TextField("Search Presets",text:$search).textInputAutocapitalization(.never).autocorrectionDisabled();if !search.isEmpty {Button{search=""}label:{Image(systemName:"xmark.circle.fill")}}}.padding(10).background(EditorTheme.gold.opacity(0.1),in:RoundedRectangle(cornerRadius:6)).padding(6)
                ScrollView {LazyVStack(spacing:0) {
                    folderRow("FACTORY PRESETS",id:-1,icon:"building.2",locked:true)
                    folderRow("USER PRESETS",id:-2,icon:"person.crop.square")
                    ForEach(Array(folders.enumerated()),id: \.element.id) {index,folder in folderRow("\(index+1)   \(folder.name)",id:folder.id,icon:"folder")}
                }}
            }.frame(width:width)
            VStack(spacing:0) {
                caption("Presets")
                HStack {tool("Delete","trash");tool("Create Setlist","folder.badge.plus");Spacer(minLength:0);tool("Import","square.and.arrow.down");tool("Export","square.and.arrow.up")}.padding(6)
                ScrollView {LazyVStack(spacing:0) {
                    ForEach(rows) {preset in
                        Button {selectedID=preset.contentID} label:{HStack(spacing:12){Image(systemName:"doc").foregroundStyle(EditorTheme.gold);Text(preset.label).font(.callout.monospacedDigit().bold()).frame(width:36,alignment:.leading);Text(preset.name).lineLimit(1);Spacer(minLength:0)}.padding(.horizontal,12).frame(height:44).background(selectedID==preset.contentID ? EditorTheme.gold.opacity(0.24):.clear).contentShape(Rectangle())}.simultaneousGesture(TapGesture(count:2).onEnded {Task {if await monitor.load(preset) {openEditor()}}})
                            .overlay(alignment:.bottom){Rectangle().fill(EditorTheme.gold.opacity(0.12)).frame(height:0.5)}
                    }
                }}
                HStack {Text("\(rows.count) presets").font(.caption);Spacer();Button("Open Preset"){if let preset=rows.first(where:{$0.contentID==selectedID}) {Task {if await monitor.load(preset) {openEditor()}}}}.disabled(!rows.contains(where:{$0.contentID==selectedID}) || monitor.busy || !monitor.connected)}.padding(10)
            }.frame(maxWidth:.infinity)
        }.foregroundStyle(EditorTheme.gold).background(EditorTheme.gold.opacity(0.055))
    }
    private func caption(_ text:String)->some View {Text(text).font(.caption).frame(maxWidth:.infinity,alignment:.leading).padding(8).background(.black.opacity(0.3))}
    private func folderRow(_ name:String,id:Int,icon:String,locked:Bool=false)->some View {
        Button {folderID=id;selectedID=nil} label:{HStack(spacing:8){Image(systemName:icon).font(.title3);Text(name).font(.callout).lineLimit(1);if locked {Image(systemName:"lock").font(.caption)};Spacer(minLength:0)}.padding(.horizontal,10).frame(height:44).background(folderID==id ? EditorTheme.gold.opacity(0.24):.clear)}
    }
    private var deviceID:String? {monitor.connected ? monitor.snapshot.flatMap{FileCompanion.deviceID($0.product)}:nil}
    private var cloneFolders:[LibraryEntry] {(monitor.libraryEntries[-14] ?? []).sorted{$0.name.localizedStandardCompare($1.name) == .orderedAscending}}
    private var cloneRows:[LibraryEntry] {(monitor.libraryEntries[cloneFolderID] ?? []).filter{cloneSearch.isEmpty || $0.name.localizedCaseInsensitiveContains(cloneSearch)}.sorted{$0.name.localizedStandardCompare($1.name) == .orderedAscending}}
    private var selectedManageEntry:LibraryEntry? {cloneRows.first{$0.id==cloneSelection && $0.id>0} ?? cloneTrail.last.flatMap{$0.id>0 ? $0:nil}}
    private func prepareCloneAction(_ operation:String) {
        guard companion.paired else{showPairing=true;return}
        guard let expected=deviceID else{return}
        cloneOperation=operation;cloneActionTarget=operation=="mkdir" ? nil:selectedManageEntry
        cloneActionParent=cloneActionTarget?.parent ?? cloneFolderID;cloneActionDeviceID=expected
        cloneDraftName=operation=="mkdir" ? "New Folder":cloneActionTarget?.name ?? ""
        if operation=="delete" {showCloneDelete=true}else{showCloneName=true}
    }
    private func performCloneAction() {
        guard let expected=cloneActionDeviceID,deviceID==expected else{monitor.errorText="The connected Stadium changed. Nothing was sent.";return}
        let operation=cloneOperation,target=cloneActionTarget,parent=cloneActionParent,name=cloneDraftName
        Task {do {
            try await companion.manage(operation,parent:parent,entry:target,name:operation=="delete" ? nil:name,deviceID:expected)
            guard deviceID==expected else{return}
            if operation=="delete",let target,target.type==1002,cloneFolderID==target.id {cloneTrail.removeAll{$0.id==target.id};cloneFolderID=parent}
            try await monitor.refreshInventory();try await monitor.readLibraryFolder(cloneFolderID)
        } catch {monitor.errorText=error.localizedDescription}}
    }
    private var selectedClone:LibraryEntry? {cloneRows.first{$0.id==cloneSelection && $0.type==11}}
    private var clones:some View {
        VStack(spacing:0) {
            HStack(spacing:8) {
                tool("New Folder","folder.badge.plus",enabled:deviceID != nil && !companion.busy){prepareCloneAction("mkdir")}
                tool("Delete","trash",enabled:selectedManageEntry != nil && deviceID != nil && !companion.busy){prepareCloneAction("delete")}
                tool("Rename","pencil",enabled:selectedManageEntry != nil && deviceID != nil && !companion.busy){prepareCloneAction("rename")}
                Divider().frame(height:40)
                tool("Export","square.and.arrow.up",enabled:selectedClone != nil && deviceID != nil && companion.paired && !companion.busy) {
                    guard let entry=selectedClone,let expected=deviceID else{return}
                    Task {do {let url=try await companion.exportClone(entry,deviceID:expected);guard deviceID==expected else{throw ProtocolError.invalid("The connected Stadium changed during export.")};exportFile=CloneShareFile(url:url)}catch {monitor.errorText=error.localizedDescription}}
                }
                tool("Import","square.and.arrow.down",enabled:deviceID != nil && !companion.busy) {
                    if companion.paired {importDeviceID=deviceID;importCloneFolder=cloneFolderID;showCloneImporter=true}else{showPairing=true}
                }
                Spacer(minLength:0)
                Button {showPairing=true} label:{Label(companion.paired ? "Mac Paired":"Pair Mac",systemImage:"desktopcomputer").font(.caption)}.disabled(companion.busy)
            }.padding(10)
            HStack {Image(systemName:"magnifyingglass");TextField("Search Clones",text:$cloneSearch).textInputAutocapitalization(.never).autocorrectionDisabled();if !cloneSearch.isEmpty {Button{cloneSearch=""}label:{Image(systemName:"xmark.circle.fill")}}}.padding(.horizontal,14).frame(height:40).background(.red.opacity(0.07))
            HStack(spacing:1) {
                ScrollView {LazyVStack(spacing:0) {
                    ForEach(cloneFolders) {entry in Button {cloneFolderID=entry.id;cloneTrail=[entry];cloneSelection=nil} label:{HStack{Image(systemName:"folder");Text(entry.name).lineLimit(1);Spacer(minLength:0);Image(systemName:"chevron.right").font(.caption)}.padding(12).background(cloneFolderID==entry.id || cloneTrail.first?.id==entry.id ? Color.red.opacity(0.16):.clear)}}
                }}.frame(maxWidth:.infinity)
                ScrollView {LazyVStack(spacing:0) {
                    if cloneTrail.count>1 {Button {cloneTrail.removeLast();cloneFolderID=cloneTrail.last?.id ?? -23;cloneSelection=nil} label:{Label("Back",systemImage:"chevron.left").frame(maxWidth:.infinity,alignment:.leading).padding(12)}}
                    ForEach(cloneRows) {entry in Button {
                        if entry.type==1002 {cloneTrail.append(entry);cloneFolderID=entry.id;cloneSelection=nil}else{cloneSelection=entry.id}
                    } label:{HStack(spacing:10){Image(systemName:entry.type==1002 ? "folder":"cpu");Text(entry.name).lineLimit(1);Spacer(minLength:0);if entry.type==1002 {Image(systemName:"chevron.right").font(.caption)}}.padding(.horizontal,12).frame(height:44).background(cloneSelection==entry.id ? Color.red.opacity(0.25):.clear)}}
                    if cloneRows.isEmpty {Text(monitor.connected ? "No clones in this folder":"Connect to Stadium to browse clones").font(.callout).foregroundStyle(.secondary).padding(18)}
                }}.frame(maxWidth:.infinity)
            }
            VStack(alignment:.leading,spacing:6) {
                HStack{Label("User Clones",systemImage:"folder");ForEach(cloneTrail) {entry in Image(systemName:"chevron.right");Text(entry.name).lineLimit(1)};Spacer(minLength:0);Text("\(cloneRows.count) items")}.font(.caption)
                if companion.busy {ProgressView(value:companion.progress).tint(.red)}
                HStack {Text(companion.status).lineLimit(2);Spacer(minLength:0);if companion.lastJob != nil,let expected=deviceID {Button("Check Last Transfer"){Task {do {try await companion.checkLast(deviceID:expected);try await monitor.readLibraryFolder(cloneFolderID)}catch {monitor.errorText=error.localizedDescription}}}.disabled(companion.busy)}}.font(.caption).foregroundStyle(.secondary)
            }.padding(12).background(.black.opacity(0.25))
        }.foregroundStyle(.red).background(.red.opacity(0.055))
    }
    private var pairingSheet:some View {
        NavigationStack {VStack(alignment:.leading,spacing:18) {
            Text("Open StadiumPad Companion on your Mac, connect it to this Stadium, then copy its pairing link here.").foregroundStyle(.secondary)
            Text("The Mac is needed for file imports and exports. Clone browsing and preset editing connect directly to Stadium.").font(.callout).foregroundStyle(.secondary)
            SecureField("Paste pairing link",text:$pairingLink).textContentType(.none).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
            Button("Pair Mac") {Task {do {try companion.configure(pairingLink);pairingLink="";guard let expected=deviceID else{throw ProtocolError.invalid("Connect to Stadium first.")};try await companion.check(deviceID:expected);showPairing=false}catch {monitor.errorText=error.localizedDescription}}}.buttonStyle(.borderedProminent).disabled(companion.busy || pairingLink.isEmpty)
            Spacer()
        }.padding(24).navigationTitle("Mac File Companion").toolbar {ToolbarItem(placement:.cancellationAction){Button("Close"){pairingLink="";showPairing=false}}}}
    }
}
struct LibraryRows:View {
    @EnvironmentObject var monitor:StadiumMonitor
    let title:String;let entries:[LibraryEntry];let canOpen:Bool
    @State private var search=""
    var body:some View {
        VStack(alignment:.leading,spacing:0) {
            HStack {Text(title).font(.title2);Spacer();Text("\(entries.count)").foregroundStyle(.secondary)}.padding(16)
            TextField("Search \(title)",text:$search).textFieldStyle(.roundedBorder).padding(.horizontal,16).padding(.bottom,10)
            ScrollView {LazyVStack(spacing:0) {
                ForEach(entries.filter{search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)}) {entry in
                    HStack {Image(systemName:entry.type==1003 ? "folder":"doc");Text(entry.name);Spacer();if canOpen && entry.type==2 {Button("Open") {Task {let row=PresetSlot(.object(["cid_":.int(Int64(entry.id)),"name":.string(entry.name),"type":.int(2)]));_ = await monitor.load(row)}}.disabled(monitor.busy || !monitor.connected)}}.padding(12).overlay(alignment:.bottom){Rectangle().fill(.white.opacity(0.08)).frame(height:0.5)}
                }
            }}
        }
    }
}
struct SectionStatusView:View {
    let section:EditorSection
    var body:some View {
        VStack(spacing:18) {Image(systemName:section.icon).font(.system(size:44,weight:.ultraLight));Text(section.rawValue).font(.largeTitle);Text("Not connected yet").foregroundStyle(.orange);Text(detail).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth:500)}.padding(24).frame(maxWidth:.infinity,maxHeight:.infinity)
    }
    private var detail:String {switch section {
    case .commands:return "Footswitch, instant-command, MIDI, utility and expression assignments are being mapped from the desktop editor."
    case .eq:return "The desktop's output-specific global EQ controls are being mapped. Your current global EQ settings are preserved."
    case .songs:return "Song arrangement, audio import, stem splitting and Showcase transport are being mapped from the desktop editor."
    default:return "This section is being connected."
    }}
}
