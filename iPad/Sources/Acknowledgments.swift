import SwiftUI

struct AcknowledgmentsView:View {
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:20) {
                    Text("StadiumPad").font(.largeTitle.bold())
                    Text("An independent, open-source tablet companion for Helix Stadium. A community proof of concept, with no affiliation with or endorsement from the manufacturers mentioned here.")
                    Text("Thank you, Line 6").font(.title2.bold())
                    Text("Helix exists because of the hard work of Line 6's designers, engineers and musicians. StadiumPad is intended as a quick, useful bridge while we wait and hope for an official iPad editor, with respect for that work. We hope an official editor makes this tool unnecessary one day; this is not a claim about Line 6's plans.")
                    Text("Community foundations").font(.title2.bold())
                    Text("A special shout-out to Dwayne Charrington (Vheissu) for helix-stadium-tools. Its MIT-licensed protocol research and implementation informed the transport, editing operations and controller-assignment interpretation used here. The upstream copyright and license are retained in the repository.")
                    Link("Vheissu / helix-stadium-tools",destination:URL(string:"https://github.com/Vheissu/helix-stadium-tools")!)
                    Text("Gig-view inspiration").font(.title2.bold())
                    Text("The Scene and Footswitch views draw workflow inspiration from the Quad Cortex editor and Fender Tone Master Pro: large scene buttons and an on-screen pedalboard that can be used instead of floor switches. The desktop Helix Stadium editor guides our preset/chain/control layout. StadiumPad uses its own SwiftUI implementation and original icon; no vendor artwork or interface source is included.")
                    Text("Built with help").font(.title2.bold())
                    Text("Apple Swift, SwiftUI, Network and Foundation; ZeroMQ ZMTP, Open Sound Control and MessagePack protocol specifications. Python msgpack supports development tests. AI assisted development and the original StadiumPad icon. See the repository for licenses, limitations and the AI contributor guide.")
                    Text("Current limits").font(.title2.bold())
                    Text("Command Center editing, Global EQ controls, song/Showcase editing and transport, IR/clone file importing and assignment, firmware updates and PIN authentication are not implemented. Virtual switches support validated latched effect/parameter assignments; timed, momentary and command/MIDI switches remain unavailable. Tuner mode sends open/exit commands; live pitch remains on the Stadium display. No phone layout or Android build yet.")
                    Link("Source, bugs & contributions",destination:URL(string:"https://github.com/privatezer0/StadiumPad")!)
                }.padding(28).frame(maxWidth:750,alignment:.leading).frame(maxWidth:.infinity)
            }.navigationTitle("About & Acknowledgments").toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){dismiss()}}}
        }.preferredColorScheme(.dark)
    }
}
