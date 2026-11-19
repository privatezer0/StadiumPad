#if DEBUG
import SwiftUI
import UIKit
import StadiumProtocol

@MainActor func captureEditorLayouts(monitor:StadiumMonitor,discovery:StadiumDiscovery,selection:BlockSelection?) async {
    let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    if let window=UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).flatMap({$0.windows}).first(where:{$0.isKeyWindow}) {
        let image=UIGraphicsImageRenderer(bounds:window.bounds).image {_ in window.drawHierarchy(in:window.bounds,afterScreenUpdates:true)}
        try? image.pngData()?.write(to:folder.appendingPathComponent("layout-physical.png"),options:.atomic)
    }
    var cases:[(String,CGSize,BlockSelection?)]=[("pro-landscape",CGSize(width:1366,height:980),selection),("regular-landscape",CGSize(width:1024,height:724),selection),("regular-portrait",CGSize(width:768,height:980),selection)]
    if let state=monitor.snapshot {
        for (name,block) in [("regular-reverb",state.blocks.first(where:{monitor.catalog[String($0.model)]?.category=="reverb"})),("regular-dual-cab",state.blocks.first(where:{$0.slot==1}))] {
            if let block,let context=try? state.context(for:block) {cases.append((name,CGSize(width:1024,height:724),BlockSelection(block:block,context:context)))}
        }
    }
    func render(_ name:String,_ size:CGSize,_ currentSelection:BlockSelection?,_ section:EditorSection = .home,_ mode:EditorMode = .preset,_ focus:Bool=false,_ libraryCategory:LibraryCategory = .presets,_ renderMonitor:StadiumMonitor?=nil)async {
        let root=StadiumView(initialSelection:currentSelection,preview:true,initialSection:section,initialMode:mode,initialFocus:focus,initialLibraryCategory:libraryCategory).environmentObject(renderMonitor ?? monitor).environmentObject(discovery).preferredColorScheme(.dark)
        let host=UIHostingController(rootView:root);host.view.frame=CGRect(origin:.zero,size:size);host.view.backgroundColor = .black
        host.view.setNeedsLayout();host.view.layoutIfNeeded()
        try? await Task.sleep(for:.milliseconds(250))
        let image=UIGraphicsImageRenderer(size:size).image {_ in host.view.drawHierarchy(in:host.view.bounds,afterScreenUpdates:true)}
        try? image.pngData()?.write(to:folder.appendingPathComponent("layout-\(name).png"),options:.atomic)
    }
    for (name,size,currentSelection) in cases {await render(name,size,currentSelection)}
    for (name,size) in [("pro",CGSize(width:1366,height:980)),("regular",CGSize(width:1024,height:724)),("portrait",CGSize(width:768,height:980))] {await render("librarian-"+name,size,selection,.librarian)}
    for (name,size) in [("pro",CGSize(width:1366,height:980)),("regular",CGSize(width:1024,height:724)),("portrait",CGSize(width:768,height:980))] {await render("clones-"+name,size,selection,.librarian,.preset,false,.clones)}
    for (name,size) in [("pro",CGSize(width:1366,height:980)),("regular",CGSize(width:1024,height:724)),("portrait",CGSize(width:768,height:980))] {await render("commands-"+name,size,selection,.commands)}
    // Preview-only six-field MIDI variants; no synthetic values enter the live monitor.
    if let state=monitor.snapshot,let context=try? CommandContext(state:state,source:CommandSource(.stomp,number:1,bank:1),slot:0),let cid=context.commandID,context.family == .midi {
        for (name,subtype) in [("bank",0),("note",2)] {
            let copy=StadiumMonitor();copy.connected=true;copy.stompProperties=monitor.stompProperties;copy.commandProperties=monitor.commandProperties
            var buffer=state.editBuffer.object,graph=buffer["cg__"]!.object,entities=graph["entt"]!.object
            entities["cmnd"] = .array(entities["cmnd"]!.items.map{command in guard command["cid_"].integer==cid else{return command};var values=command.object;values["pvlb"] = .int(Int64(subtype));return .object(values)})
            graph["entt"] = .object(entities);buffer["cg__"] = .object(graph)
            copy.snapshot=DeviceSnapshot(product:state.product,editBuffer:.object(buffer),preset:state.preset,activeSnapshot:state.activeSnapshot,origin:state.origin)
            await render("commands-regular-"+name,CGSize(width:1024,height:724),selection,.commands,.preset,false,.presets,copy)
        }
    }
    for section in [EditorSection.librarian,.commands,.eq,.songs] {await render("section-"+section.rawValue,CGSize(width:1024,height:724),selection,section)}
    for mode in [EditorMode.scene,.footswitch,.tuner] {
        for (name,size) in [("pro",CGSize(width:1366,height:980)),("regular",CGSize(width:1024,height:724)),("portrait",CGSize(width:768,height:980))] {await render(mode.rawValue+"-"+name,size,selection,.home,mode)}
    }
    if let state=monitor.snapshot {
        for category in ["distortion","eq","cab_ir_interp"] {
            if let block=state.blocks.first(where:{monitor.catalog[String($0.model)]?.category==category}),let context=try? state.context(for:block) {
                for (name,size) in [("pro",CGSize(width:1366,height:980)),("regular",CGSize(width:1024,height:724)),("portrait",CGSize(width:768,height:980))] {await render("focus-"+category+"-"+name,size,BlockSelection(block:block,context:context),.home,.preset,true)}
            }
        }
    }
    if let state=monitor.snapshot,let block=state.blocks.first(where:{monitor.catalog[String($0.model)]?.hypeParameter != nil}),let context=try? state.context(for:block) {
        for (name,size) in [("pro",CGSize(width:1366,height:980)),("regular",CGSize(width:1024,height:724)),("portrait",CGSize(width:768,height:980))] {await render("hype-"+name,size,BlockSelection(block:block,context:context))}
    }
    let report:[String:Any] = ["capturedAt":Date().timeIntervalSince1970,"cases":cases.map{$0.0},"sections":["Librarian","Command Center","Global EQ","Songs"]]
    try? JSONSerialization.data(withJSONObject:report).write(to:folder.appendingPathComponent("layout-report.json"),options:.atomic)
}
#endif
