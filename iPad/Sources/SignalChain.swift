import SwiftUI
import StadiumProtocol

private struct ChainLane:Identifiable {let path:Int;let row:Int;let blocks:[SignalBlock];var id:Int {path*2+row}}
struct SignalChainView:View {
    @EnvironmentObject var monitor:StadiumMonitor
    let state:DeviceSnapshot
    let selected:BlockSelection?
    let select:(SignalBlock)->Void
    private var lanes:[ChainLane] {
        (1...2).flatMap {path in (0...1).compactMap {row in
            let blocks=state.blocks.filter{$0.path==path && $0.position/14==row}
            guard row==0 || blocks.contains(where:{monitor.blockName($0) != "None"}) else{return nil}
            return ChainLane(path:path,row:row,blocks:blocks)
        }}
    }
    var body:some View {
        GeometryReader {geometry in
            let labelWidth:CGFloat=30
            let cell=(geometry.size.width-labelWidth-12)/14
            let rowHeight=geometry.size.height/CGFloat(max(1,lanes.count))
            ZStack(alignment:.topLeading) {
                Canvas {context,size in
                    for (index,lane) in lanes.enumerated() {
                        let y=CGFloat(index)*rowHeight+rowHeight*0.43
                        var start=0
                        if lane.row==1 {
                            let real=lane.blocks.filter{monitor.blockName($0) != "None"}.map{$0.position%14}
                            var inputs:[Int]=[]
                            for flow in state.editBuffer["sfg_"]["flow"].items {
                                let raw=flow["blks"].items
                                for offset in stride(from:0,to:max(0,raw.count-1),by:2) {if raw[offset+1]["bflw"].integer==lane.path-1,let target=raw[offset+1]["bblk"].integer,target/14==lane.row {inputs.append(target%14)}}
                            }
                            start=(real+inputs).min() ?? 0
                        }
                        var line=Path();line.move(to:CGPoint(x:labelWidth+(CGFloat(start)+0.5)*cell,y:y));line.addLine(to:CGPoint(x:labelWidth+13.5*cell,y:y))
                        context.stroke(line,with:.color(.gray.opacity(lane.row==0 ? 0.65:0.28)),lineWidth:2)
                    }
                    // Native split targets use visible positions and explicit flow IDs.
                    for (flowIndex,flow) in state.editBuffer["sfg_"]["flow"].items.enumerated() {
                        let raw=flow["blks"].items
                        for offset in stride(from:0,to:max(0,raw.count-1),by:2) {
                            guard let position=raw[offset].integer,let target=raw[offset+1]["bblk"].integer,let targetFlow=raw[offset+1]["bflw"].integer,
                                  let sourceRow=lanes.firstIndex(where:{$0.path==flowIndex+1 && $0.row==position/14}),let destRow=lanes.firstIndex(where:{$0.path==targetFlow+1 && $0.row==target/14}) else{continue}
                            let a=CGPoint(x:labelWidth+(CGFloat(position%14)+0.5)*cell,y:CGFloat(sourceRow)*rowHeight+rowHeight*0.43)
                            let b=CGPoint(x:labelWidth+(CGFloat(target%14)+0.5)*cell,y:CGFloat(destRow)*rowHeight+rowHeight*0.43)
                            var branch=Path();branch.move(to:a);branch.addLine(to:CGPoint(x:a.x,y:b.y));branch.addLine(to:b)
                            context.stroke(branch,with:.color(.gray.opacity(0.65)),lineWidth:2)
                        }
                    }
                }.allowsHitTesting(false)
                ForEach(Array(lanes.enumerated()),id:\.element.id) {index,lane in
                    Text("\(lane.path)\(lane.row==0 ? "A":"B")").font(.caption2.monospaced()).foregroundStyle(.gray).frame(width:labelWidth,height:rowHeight).position(x:labelWidth/2,y:CGFloat(index)*rowHeight+rowHeight/2)
                    ForEach(lane.blocks.filter{$0.slot==0}) {block in
                        let models=lane.blocks.filter{$0.position==block.position}
                        let style=BlockStyle.forBlock(block,monitor:monitor)
                        let active=selected?.context.presetID==state.presetID && selected?.context.snapshot==state.activeSnapshot && selected?.block.path==block.path && selected?.block.position==block.position
                        Button {select(block)} label:{
                            VStack(spacing:3) {
                                ZStack(alignment:.bottomTrailing) {
                                    RoundedRectangle(cornerRadius:5).fill(style.color.opacity(block.enabled ? 0.15:0.045))
                                    Image(systemName:style.symbol).font(.system(size:min(22,cell*0.42),weight:.light)).foregroundStyle(style.color.opacity(block.enabled ? 1:0.4)).frame(maxWidth:.infinity,maxHeight:.infinity)
                                    if models.count>1 {Text("2").font(.system(size:9,weight:.bold)).padding(2).background(.black).foregroundStyle(style.color)}
                                }.frame(width:min(43,cell-5),height:min(40,rowHeight-22)).overlay(RoundedRectangle(cornerRadius:5).stroke(active ? .white:style.color.opacity(0.5),lineWidth:active ? 2:1))
                                Text(shortName(monitor.blockName(block))).font(.system(size:max(8,min(10,cell*0.17)))).lineLimit(1).foregroundStyle(active ? .white:.gray)
                            }.frame(width:cell,height:rowHeight)
                        }.buttonStyle(.plain).accessibilityLabel("Path \(lane.path), \(monitor.blockName(block))\(models.count>1 ? ", dual model":"")")
                        .position(x:labelWidth+(CGFloat(block.position%14)+0.5)*cell,y:CGFloat(index)*rowHeight+rowHeight/2)
                    }
                }
            }
        }.padding(.horizontal,6).padding(.vertical,8).background(.black)
    }
    private func shortName(_ name:String)->String {name.replacingOccurrences(of:"Instrument ",with:"In ").replacingOccurrences(of:"Dynamic ",with:"").replacingOccurrences(of:"4x12 ",with:"")}
}
