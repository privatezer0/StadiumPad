# Acknowledgments

**Thank you to Line 6.** Helix Stadium exists because of the hard work of Line 6's
engineers, designers and musicians. StadiumPad is a small independent tool meant
to help tablet users while we wait and hope for an official iPad editor. It is in
no way intended to slight that work. We hope an official editor makes this tool
unnecessary one day; we do not claim knowledge of Line 6's roadmap. No affiliation
or endorsement by Line 6/Yamaha is implied.

**A special shout-out to Dwayne Charrington (Vheissu)** and
[helix-stadium-tools](https://github.com/Vheissu/helix-stadium-tools). This project's
Swift implementation builds on that project's MIT-licensed protocol research and
reference implementation, including transport behavior, property envelopes, edit
commands, model metadata extraction, stomp controller/target interpretation and
native adjacent-swap block-reorder planning, Focus factory-map extraction and
float32 triangle interpolation/discrete tie handling. Swift Focus arithmetic and
synthetic reference-vector tests are adapted from that MIT reference; its native
research remains credited to the original author.
Reference commit: `dad97d3a2011290f7f6630d04cc1a819cc58752b`.
The [upstream license](docs/REFERENCE_LICENSE.txt) is retained. Credit belongs to
the developers who did that foundation work; this is not a claim of discovering
the entire protocol independently.

**Gig-view inspiration:** the Quad Cortex editor and Fender Tone Master Pro showed
useful ways to present scenes and virtual footswitch/pedalboard controls. StadiumPad
adapts that workflow idea to a tablet, while its preset/sidebar/chain/control
arrangement takes the desktop Helix Stadium editor as a reference. No vendor UI
source, logos, artwork, DSP models or factory-preset payloads are included here.
Model/factory lists come from the connected device and locally prepared metadata.

**Technology:** Apple Swift/SwiftUI/Foundation/Network; the
[ZMTP specification](https://rfc.zeromq.org/spec/23/),
[OSC specification](https://opensoundcontrol.stanford.edu/spec-1_0.html), and
[MessagePack specification](https://github.com/msgpack/msgpack/blob/master/spec.md).
[Python msgpack](https://github.com/msgpack/msgpack-python) supports development
integration tests, not the Swift runtime. See [third-party notices](docs/THIRD_PARTY.md).

AI assisted implementation and the original app icon, with human direction and
spare-preset verification. [Icon generation notes](docs/ICON.md) record the brief.
Please contribute reproducible bug reports, improvements or fixes.
