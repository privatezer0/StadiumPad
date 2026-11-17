import SwiftUI
import StadiumProtocol

enum EditorSection:String,CaseIterable {case home="Home",librarian="Librarian",commands="Command Center",eq="Global EQ",songs="Songs"
    var icon:String {switch self {case .home:return "house";case .librarian:return "archivebox";case .commands:return "antenna.radiowaves.left.and.right";case .eq:return "slider.horizontal.3";case .songs:return "music.note"}}
}
struct LibrarianView:View {
    @EnvironmentObject var monitor:StadiumMonitor
    @State private var section="Models"
    private let sections=["Models","Factory Presets","User Presets","Setlists","Cab IRs","Favorites","Templates","Clones"]
    var body:some View {
        HStack(spacing:0) {
            VStack(spacing:4) {ForEach(sections,id:\.self){name in Button {section=name} label:{Text(name).font(.callout).frame(maxWidth:.infinity,alignment:.leading).padding(12).background(section==name ? EditorTheme.gold.opacity(0.2):.clear)}};Spacer()}.buttonStyle(.plain).frame(width:160).foregroundStyle(EditorTheme.gold).background(EditorTheme.panel)
            if section=="Models" {ModelBrowser(selection:nil)}
            else if section=="Clones" {
                VStack(alignment:.leading,spacing:16) {
                    Text("Clone library").font(.title2)
                    ForEach(monitor.catalog.values.filter{[836,838,839,840].contains($0.id)}.sorted{$0.id<$1.id},id:\.id) {model in Label(model.name,systemImage:"folder").foregroundStyle(.red)}
                    if monitor.cloneHierarchy.items.isEmpty {Text("No clone files returned by the Stadium.").foregroundStyle(.secondary)}
                    Text("Clone file import and assignment are not connected yet.").font(.caption).foregroundStyle(.orange)
                    Spacer()
                }.padding(24).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
            } else {
                let container=section=="Factory Presets" ? -1:section=="User Presets" ? -2:section=="Setlists" ? -5:section=="Cab IRs" ? -3:section=="Favorites" ? -8:-4
                LibraryRows(title:section,entries:monitor.libraryEntries[container] ?? [],canOpen:container == -1 || container == -2)
            }
        }.task {do {try await monitor.refreshInventory()}catch {monitor.errorText=error.localizedDescription}}
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
                    HStack {Image(systemName:entry.type==1003 ? "folder":"doc");Text(entry.name);Spacer();if canOpen {Button("Open") {Task {let row=PresetSlot(.object(["cid_":.int(Int64(entry.id)),"name":.string(entry.name),"type":.int(2)]));_ = await monitor.load(row)}}.disabled(monitor.busy || !monitor.connected)}}.padding(12).overlay(alignment:.bottom){Rectangle().fill(.white.opacity(0.08)).frame(height:0.5)}
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
