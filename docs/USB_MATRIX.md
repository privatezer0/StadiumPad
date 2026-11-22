# USB editing and persistent guitar volume — development candidate

Development version: **0.10.0 (41)**. This work is under physical-device qualification;
it has not replaced the validated 0.9.6 installer or been uploaded to TestFlight.

## Standalone iPad connection

Connect Stadium's USB-C port directly to the iPad with a data cable. No computer is
required for the normal editor connection. Enable Remote Access on Stadium and
allow Local Network permission on iPad. In StadiumPad's connection menu choose
**USB**, tap **Find USB Stadium**, then select the discovered device. The selected
USB preference is remembered; startup discovers the current cable interface again.

Stadium firmware 1.4 exposes a USB Ethernet interface. USB mode binds both editor
sockets to the actual interface returned by USB-scoped Bonjour discovery. A cached
hostname/IP and a generic wired-interface requirement were insufficient on the
physical iPad. USB mode does not silently fall back to Wi-Fi. Automatic and Wi-Fi
remain available in the same connection menu.

All existing direct editor operations use the selected session transport. The
optional Mac companion remains necessary for its existing clone file-transfer and
library-backup operations; USB support does not add standalone clone transfers,
offline editing, Songs/Showcase editing or other unfinished features.

## Matrix Mixer button and popup

A single **Matrix Mixer** button with a cyan fader icon sits centered beside Home,
Librarian, Command Center, Global EQ and Songs. It opens a dismissible mixer modal.
The modal header has three output icon buttons: ¼-inch connector, XLR connector
and headphones. Highlighting identifies the selected output; accessible labels
identify each icon. The last viewed output is remembered locally. Tapping the
selected icon keeps that output open; use Close or swipe to dismiss the popup.

Opening, selecting an output and closing are local view actions. They send no
pedal-screen commands and never change presets. Build 40's CC9/Home screen-link
behavior was removed after the owner reported the screens became out of sync.
There is no verified pedal panel-visible getter; do not restore that navigation
based on an assumed remote screen state. The working channel-edit transport and
receipt checks are unchanged. Wi-Fi-only opens the mixer for viewing; channel
editing still needs bound direct USB MIDI. Background interaction uses the normal
modal behavior, without the experimental header tap-through behavior.

The popup follows the pedal's channel-strip arrangement: Home, Song, Click, Count
In, USB In 1/2, Bluetooth and Aux. Expand Home to reveal Path 1A/1B/2A/2B; expand
Song to reveal its eight tracks. Expanded channels scroll horizontally, as on the
pedal. Each available strip has a vertical volume fader, pan popup with Center,
mute and solo. The top-left mixer menu includes Clear Solos for the selected output,
using the absolute CC103 operation. It stays available after an uncertain toggle;
controls pause while recovery runs. The Global EQ shortcut opens that output's EQ.
Count In is reserved by Line 6 and is visibly unavailable. Native channel enable
flags disable unavailable inputs/tracks.

The controls use direct iPad USB MIDI and Line 6's documented per-channel CCs,
with actual Matrix MIDI channels read from the device. No Mac bridge is used.
USB-C MIDI must be enabled. Shared MIDI channels or linked outputs prevent
independent editing; change those settings on Stadium. USB device notifications
and a pre-send identity check disable edits when the cable disappears. Reading
requires an editor connection (USB or Wi-Fi); writing requires direct USB MIDI.
Wi-Fi-only output buttons can open the mixer for viewing with its edits disabled.

USB and network serial fields differ; StadiumPad records a hashed association.
A verified USB editor session with one attached Stadium can establish it; a Wi-Fi
session requires confirmation that the attached USB device is the selected Stadium.
No MIDI values are sent by connection, association or restoring local view state.

### Remaining gaps from the pedal

This candidate does **not** yet provide live audio meters, remote output linking,
the physical master output knob or all-channel Reset. The verified MIDI table
provides channel level/pan/mute/solo, but no main-output-volume or link command.
The popup controls the signals feeding each output, not its hardware gain. There
are no simulated meters or inactive controls pretending to implement those gaps.
Exact MIDI-to-dB calibration and unity-reset support also remain unqualified; the
initial volume thumb estimate is approximate, while the label is actual received dB.
Do not describe this candidate as complete pedal parity.

## Live state and confirmation

The device can emit `/syncMixChannelVolume` with a newer channel level while
`server.mixer.state` still returns an older value. That bulk property must not be
used alone to confirm a MIDI edit or claim live-level restoration. The session
keeps a bounded overlay of device-originated level, pan, mute and solo events, scoped to the connection.
New bulk reads cannot rewind those live values. On a new connection, before a fresh
event arrives, an initial bulk read can still show an older stored value; no verified
query for a fresh full DSP snapshot is established. The UI labels use the received dB
value, and retain the confirmed MIDI thumb position after an adjustment.

MIDI edits run serially with coalesced newer drag positions. A new matching live
output/channel/control event is required; a send return code alone is insufficient. The session
rechecks output links/channels and preserves unrelated mixer fields. It never
writes a mirror or repeats an uncertain MIDI command to manufacture confirmation.
A no-op requires a previously confirmed exact MIDI value and corresponding level;
an approximate inverse dB estimate must not skip a restoration.

MIDI has 128 steps. The initial thumb estimate is approximate until a device value
is confirmed; its dB readout is not a calibrated MIDI-to-dB formula. A live event is
also not independent acoustic or pedal-screen qualification.

## Qualification as of November 21, 2026

Build 41 removes the unsuccessful screen-navigation feature and simplifies the UI.
It retains build 38's channel-control fixes. Hardware navigation qualification from
build 40 is superseded; attached-output readback never established panel visibility.
Build 41 passes 91 Swift tests, 22 Matrix loopback tests and native build/install/
launch. The physical Pro main screen and regular/portrait popup renders were
inspected. No new channel edits were sent for this navigation-only fix.

- 91 Swift tests and 22 Matrix loopback tests pass. These include stale bulk reads,
  missing/wrong-output receipts, receipt invalidation, linked/shared routing,
  unrelated-field preservation, gesture ordering and equivalent pan endpoints.
  The earlier full TCP integration run completed 82 cases: 79 pass, 3 existing skips.
- Native iPad Pro USB-only discovery/connection and product, preset, library,
  Matrix and Global EQ reads pass. Earlier Save Copy checks created two empty User
  slots and verified their contents without changing the source preset or edit buffer.
- The popup's Pro/regular/portrait and expanded-channel renders were inspected.
  Seven collapsed strips and Close fit without horizontal workspace scrolling;
  expanded channels scroll horizontally. Preview faders cannot send MIDI.
- Final build 38 tested Solo on/off through the actual presented production model:
  109.5/108.1 ms, final Solo off, with new device live receipts.
- Its 49-input pan burst had zero thumb rewinds, maximum input handling 5.1 ms,
  final queue drain 98.1 ms and 16.7 ms maximum/p95 main-thread frame gaps at 60 Hz.
  Full-left MIDI 0 followed by equivalent MIDI 1 also passed, then restored Center.
- The final native tests verified saved preset bytes, live edit bytes, active preset,
  snapshot and dirty state were unchanged. Close released the presentation lease,
  restored the prior idle timer and left the session connected and not busy.
- Earlier owner checks confirmed Phones level follows promptly and mute/pan events
  reached the device. Other output/controller combinations, acoustic behavior,
  detach/reconnect behavior and exact level calibration remain unqualified.
- USB Global EQ sent a change but did not pass its stored-snapshot confirmation;
  it still requires separate USB qualification. No claim of complete USB parity.

These are bounded automated production-model measurements, not human touch or
acoustic acceptance on every device. Release installers and TestFlight remain
0.9.6 (24); development build 38 has not replaced them.

## Gesture latency and state handling

The coalescing queue displays the newest level/pan thumb position immediately.
Explicit in-flight tickets prevent an older confirmation from rewinding it. Toggle
commands are neither coalesced nor optimistically displayed as confirmed; labels
remain device readback. Reset invalidates old tickets, while canceling pending input
allows an already-sent transaction to finish confirmation.

While the mixer is presented, periodic preset polling and deferred editor refreshes
wait until Close; live events and Matrix reads continue. Matrix writes retain the
editor exclusion guard without publishing a redraw of the hidden editor. This
reduced measured frame gaps from about 47 ms to 16.7 ms. TCP noDelay and interactive
connection scheduling reduce small request/reply latency. Fresh identity, routing
and confirmation checks remain mandatory.

Pan uses the observed firmware 1.4 conversion clamp((MIDI−64)/63,−1,1).
MIDI 0 and 1 share the full-left endpoint. An equivalent-pan no-op requires a prior
fresh exact receipt still matching current state, never just a stale bulk value.
An estimated inverse dB value never suppresses a level restoration. Each new send
invalidates its older receipt before calling the sender, including failure paths.

Solo sends a high-value press and low-value release in one MIDI event list. This
pairing passed the native on/off checks; the underlying firmware mechanism remains
an inference. Clear Solos is a separate absolute CC103 recovery, requiring off
receipts for previously active strips and preservation of unrelated fields. It is
never implemented by retrying uncertain toggles. Its recovery failure paths have
loopback coverage; physical absolute-clear recovery still needs qualification.

## Development diagnostics

Normal launch sends no test writes. DEBUG hardware checks require explicit flags,
a reviewed UUID intent and an exclusive persisted marker before sending; marked
runs cannot replay. Combined qualification runs Solo then pan sequentially, checking
saved/live preset preservation and restoring Solo off/pan Center. Missing or malformed
intent stops before writes. The on-device matrix-tests-gate.json can disarm these
helpers; malformed existing gates fail closed. The delivered iPad's gate is disarmed.

--show-matrix only opens the popup. Expensive preview capture requires the separate
--capture-matrix-layout or --verify-layout flag and must not run during timing tests.
The optional live-event trace has a 2 MiB cap. Keep raw captures, native state,
identities, addresses, presets and signing material outside Git.

See [Apple TCP noDelay documentation](https://developer.apple.com/documentation/network/nwprotocoltcp/options/nodelay).

## References

- [Line 6 MIDI manual](https://manuals.line6.com/en/helix-stadium/live/midi)
- [Line 6 Matrix Mixer manual](https://manuals.line6.com/en/helix-stadium/live/matrix-mixer)
- [Line 6 firmware 1.4 notes](https://kb.line6.com/helix-stadium-1-4-release-notes)
- [Vheissu protocol research](https://github.com/Vheissu/helix-stadium-tools)

See the project acknowledgments for the community research credit.
