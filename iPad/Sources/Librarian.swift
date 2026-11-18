import SwiftUI
import StadiumProtocol

enum EditorSection:String,CaseIterable {case home="Home",librarian="Librarian",commands="Command Center",eq="Global EQ",songs="Songs"
    var icon:String {switch self {case .home:return "house";case .librarian:return "archivebox";case .commands:return "antenna.radiowaves.left.and.right";case .eq:return "slider.horizontal.3";case .songs:return "music.note"}}
}
enum LibraryCategory:String,CaseIterable {
    case presets="Presets",irs="Cab IRs",favorites="Favorites",templates="Templates",songs="Songs",clones="Clones"
    var icon:String {switch self {case .presets:return "doc";case .irs:return "waveform";case .favorites:return "star";case .templates:return "doc.badge.gearshape";case .songs:return "music.note";case .clones:return "cpu"}}
    var color:Color {switch self {case .irs:return .pink;case .favorites:return .gray;case .songs:return .teal;case .clones:return .red;default:return EditorTheme.gold}}
    var container:Int {switch self {case .presets:return -2;case .irs:return -3;case .favorites:return -8;case .templates:return -4;case .songs:return -7;case .clones:return 0}}
}
struct LibrarianView:View {
    @EnvironmentObject var monitor:StadiumMonitor
    var openEditor:()->Void = {}
    @State private var category:LibraryCategory = .presets
    @State private var folderID = -2
    @State private var search=""
    @State private var selectedID:Int?
    @State private var cloneCategory="Amp"
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
                }.padding(6).frame(width:rail).background(EditorTheme.panel)
                if category == .presets {presetLibrary(width:max(210,min(300,(geometry.size.width-rail)*0.30)))}
                else if category == .clones {clones}
                else {LibraryRows(title:category.rawValue,entries:monitor.libraryEntries[category.container] ?? [],canOpen:false).tint(category.color)}
            }.buttonStyle(.plain)
        }.task {if monitor.connected {do {try await monitor.refreshInventory()}catch is CancellationError {}catch {if !Task.isCancelled {monitor.errorText=error.localizedDescription}}}}
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
    private var clones:some View {
        VStack(spacing:0) {
            HStack(spacing:8) {tool("New Folder","folder.badge.plus");tool("Delete","trash");tool("Rename","pencil");Divider().frame(height:40);tool("Export","square.and.arrow.up");tool("Import","square.and.arrow.down");Spacer()}.padding(10)
            HStack(spacing:1) {
                VStack(spacing:0) {ForEach(["Amp","Amp+Cab","Distortion","Preamp"],id: \.self) {name in Button {cloneCategory=name} label:{HStack{Image(systemName:"folder");Text(name);Spacer();Image(systemName:"chevron.right").font(.caption)}.padding(12).background(cloneCategory==name ? Color.red.opacity(0.16):.clear)}};Spacer()}.frame(maxWidth:.infinity)
                VStack(alignment:.leading,spacing:12) {Text(cloneCategory).font(.title2);Text("Clone file transfers require an authenticated file connection.").foregroundStyle(.secondary);Text("The Stadium editing connection does not provide the desktop file browser. Transfer setup is being implemented.").font(.callout).foregroundStyle(.secondary);Spacer()}.padding(18).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
            }
            HStack{Label("User Clones",systemImage:"folder");Image(systemName:"chevron.right");Text(cloneCategory);Spacer()}.font(.caption).padding(12)
        }.foregroundStyle(.red).background(.red.opacity(0.055))
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
