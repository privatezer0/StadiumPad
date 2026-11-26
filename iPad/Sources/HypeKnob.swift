import SwiftUI
import StadiumProtocol

/// A pinned control, independent of the paged parameter grid.
struct HypeKnob:View {
    let definition:ParameterDefinition
    let value:Value
    let enabled:Bool
    var working=false
    let color:Color
    let submit:(Value,Value)->Void
    @State private var draft=0.0
    @State private var anchor:Double?
    @State private var expected:Value?
    @State private var lastPoint:CGPoint?
    @State private var pending:Value?
    @GestureState private var dragging=false
    private var number:Double {(pending ?? value).numeric ?? definition.minimum}
    private var fraction:Double {max(0,min(1,((dragging ? draft:number)-definition.minimum)/(definition.maximum-definition.minimum)))}
    var body:some View {
        HStack(spacing:6) {
            ZStack {
                Circle().fill(LinearGradient(colors:[Color(white:0.48),Color(white:0.12),Color(white:0.27)],startPoint:.topLeading,endPoint:.bottomTrailing))
                Circle().trim(from:0,to:0.78).stroke(.black.opacity(0.8),style:StrokeStyle(lineWidth:3,lineCap:.round)).padding(2).rotationEffect(.degrees(130))
                Circle().trim(from:0,to:0.78*fraction).stroke(color,style:StrokeStyle(lineWidth:3,lineCap:.round)).padding(2).rotationEffect(.degrees(130))
                Capsule().fill(.white).frame(width:2,height:11).offset(y:-8).rotationEffect(.degrees(-140+280*fraction))
            }.frame(width:36,height:36)
            VStack(alignment:.leading,spacing:1) {
                Text("HYPE").font(.system(size:10,weight:.bold)).tracking(0.6).foregroundStyle(color)
                Text(definition.display(dragging ? .number(draft):(pending ?? value))).font(.system(size:12,weight:.medium)).monospacedDigit().foregroundStyle(.white)
            }
        }.frame(minWidth:80,minHeight:44).fixedSize(horizontal:true,vertical:false).contentShape(Rectangle()).opacity(enabled ? 1:0.5)
        .gesture(DragGesture(minimumDistance:0)
            .updating($dragging){_,active,_ in active=true}
            .onChanged {v in
                guard enabled else{return}
                if lastPoint==nil {anchor=number;expected=value}
                draft=adjusted(v.translation);lastPoint=v.location
            }
            .onEnded {v in
                guard enabled,let old=expected,anchor != nil else{return}
                let desired=adjusted(v.translation);anchor=nil;expected=nil;lastPoint=nil
                guard !sameParameterValue(old,.number(desired)) else{return}
                pending = .number(desired);submit(.number(desired),old)
            })
        // Gesture reset clears only presentation state. onEnded still needs
        // the captured expected value even when reset arrives first.
        .onChange(of:dragging){_,active in if !active {lastPoint=nil}}
        .onChange(of:working){_,active in if !active {pending=nil}}
        .accessibilityElement(children:.ignore).accessibilityLabel("Hype")
        .accessibilityValue(definition.display(value))
        .accessibilityAdjustableAction {direction in
            guard enabled else{return}
            let step=(definition.maximum-definition.minimum)/100
            submit(.number(max(definition.minimum,min(definition.maximum,number+(direction == .increment ? step:-step)))),value)
        }
    }
    private func adjusted(_ translation:CGSize)->Double {
        let delta=(-translation.height/140+translation.width/280)*(definition.maximum-definition.minimum)
        return max(definition.minimum,min(definition.maximum,(anchor ?? number)+delta))
    }
}
