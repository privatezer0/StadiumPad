import SwiftUI
import StadiumProtocol

struct BlockStyle {
    let title:String;let color:Color;let symbol:String
    @MainActor static func forBlock(_ block:SignalBlock,monitor:StadiumMonitor)->BlockStyle {
        let category=monitor.catalog[String(block.model)]?.category?.lowercased() ?? ""
        switch category {
        case "amp","preamp":return .init(title:"Amp",color:Color(red:0.96,green:0.16,blue:0.23),symbol:"hifispeaker.fill")
        case "cab","cab_ir_interp","ir":return .init(title:"Cab",color:.pink,symbol:"speaker.wave.2")
        case "distortion":return .init(title:"Distortion",color:.orange,symbol:"waveform.path")
        case "delay":return .init(title:"Delay",color:.green,symbol:"circle.lefthalf.filled")
        case "reverb":return .init(title:"Reverb",color:Color(red:1,green:0.35,blue:0.08),symbol:"cube")
        case "modulation":return .init(title:"Modulation",color:.cyan,symbol:"waveform")
        case "dynamics":return .init(title:"Dynamics",color:.yellow,symbol:"line.diagonal")
        case "eq":return .init(title:"EQ",color:.yellow,symbol:"slider.horizontal.3")
        case "pitch","synth","pitch_synth","pitch/synth","pitch/synths":return .init(title:"Pitch / Synth",color:EditorTheme.violet,symbol:"pianokeys")
        case "wah","filter","wah_filter","wah/filter":return .init(title:"Wah / Filter",color:EditorTheme.violet,symbol:"pedalboard")
        case "volume","volume_pan","volume/pan":return .init(title:"Volume / Pan",color:.mint,symbol:"dial.low")
        default:
            if block.position==0 || block.position==14 {return .init(title:"Input",color:.gray,symbol:"cable.connector")}
            if block.position==13 || block.position==27 {return .init(title:"Output",color:.gray,symbol:"arrow.right.circle")}
            if monitor.blockName(block)=="Y" {return .init(title:"Split",color:.gray,symbol:"arrow.triangle.branch")}
            return .init(title:"Effect",color:EditorTheme.violet,symbol:"waveform.path")
        }
    }
}
enum EditorTheme {
    static func categoryColor(_ name:String)->Color {
        switch name {
        case "Amp","Preamp":return .red
        case "Cab / IR":return .pink
        case "Distortion","Reverb":return .orange
        case "Delay":return .green
        case "Modulation":return .cyan
        case "Dynamics","EQ":return .yellow
        case "Pitch / Synth","Wah / Filter":return violet
        case "Volume / Pan","FX Loop":return .mint
        case "Clones":return .red
        default:return .gray
        }
    }
    static let violet=Color(red:0.61,green:0.31,blue:0.92)
    static let gold=Color(red:0.79,green:0.70,blue:0.30)
    static let panel=Color(white:0.055)
    static let border=Color(white:0.20)
    static let header=LinearGradient(colors:[Color(red:0.11,green:0.08,blue:0.17),Color(red:0.13,green:0.10,blue:0.08)],startPoint:.leading,endPoint:.trailing)
}
struct PageButtons:View {
    @Binding var page:Int
    let count:Int
    var body:some View {
        HStack(spacing:4) {
            Button {page=max(0,page-1)} label:{Image(systemName:"chevron.left").frame(width:36,height:36)}.disabled(page==0)
            Text("\(page+1) / \(max(1,count))").font(.caption.monospacedDigit()).frame(minWidth:44)
            Button {page=min(count-1,page+1)} label:{Image(systemName:"chevron.right").frame(width:36,height:36)}.disabled(page>=count-1)
        }.buttonStyle(.plain)
    }
}
