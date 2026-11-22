# USB editing and persistent guitar volume — development candidate

Development version: **0.10.0 (33)**. This work is under physical-device qualification;
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

## Output buttons and the Matrix popup

The main header now has compact **¼-inch, XLR and Phones** buttons, with editor
navigation on the right. Tap an output to open a large dismissible Matrix mixer
modal over the current editor. Close returns to the same editor/preset. Opening,
changing the local output tab and closing send no MIDI messages or preset edits.

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
New bulk reads cannot rewind those live values. The UI labels use the received dB
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

- 84 Swift tests pass. Matrix-specific loopback tests: 21 pass, including
  invalidating an older no-op receipt before any new send. The full integration
  suite with TCP tuning completed 82 cases: 79 pass and 3 existing skips; the new
  receipt and recovery regressions then passed in the 21-case Matrix suite. The Matrix
  loopback tests deliberately keep the bulk property stale and deliver live events,
  and reject missing/wrong-output receipts, stale contexts, linked outputs, shared
  channels and unrelated changed fields.
- Native iPad Pro USB-only discovery/connection and product, preset, library,
  Matrix and Global EQ reads pass. The product matches the selected Stadium.
- Native USB Save Copy created two new empty User slots. Their contents independently
  match the original live bytes; the saved original, unsaved source buffer, current
  preset and snapshot stayed unchanged. Copies were not opened by that check.
- Pro, regular landscape and portrait editor layouts were rendered natively and inspected.
  The new popup was opened on the USB-connected Pro and read all 19 channels.
  Native Pro/regular/portrait and expanded-channel captures were visually inspected;
  the seven collapsed strips and Close fit without horizontal workspace scrolling.
  Preview faders are intentionally disabled and do not send MIDI.
- The owner confirmed the earlier live-event Phones level fader follows promptly
  without warnings. Independent updates confirm popup Phones/Home mute on/off and
  pan changes. A guarded native pan move/Center check passes and restores exact0.0.
  Fresh gesture-speed acceptance, Solo, other outputs and unplug/replug checks remain
  outstanding.
- USB-only Global EQ sent a change but did not pass its stored-snapshot confirmation;
  the existing Global EQ confirmation behavior needs further qualification over USB.
  This is not a claim that every editor control has passed a USB hardware test.

Release installers and TestFlight must not be updated based only on these candidate
builds. Keep raw captures, device identities, private addresses, presets and signing
material outside Git. DEBUG hardware checks require a fresh reviewed intent,
persist a marker before sending and never replay an interrupted run on restart.

## References

- [Line 6 MIDI manual](https://manuals.line6.com/en/helix-stadium/live/midi)
- [Line 6 Matrix Mixer manual](https://manuals.line6.com/en/helix-stadium/live/matrix-mixer)
- [Line 6 firmware 1.4 notes](https://kb.line6.com/helix-stadium-1-4-release-notes)
- [Vheissu protocol research](https://github.com/Vheissu/helix-stadium-tools)

See the project acknowledgments for the community research credit.

## Gesture latency and diagnostic checks

The pan popup retains a local draft while dragging. Matrix writes pause background
preset polling, while TCP noDelay and interactive connection scheduling reduce small
request/reply latency. Fresh routing/mixer checks remain intact. The mixer keeps the
screen awake while open and restores the app's prior idle-timer setting on Close;
preview rendering does not alter it.

In build30, a guarded native USB Phones/Home pan move followed by Center measured
101/106ms per transaction, compared with a prior 622ms sample. A separate listener
observed both pan updates and final exact0.0 Center. This establishes that bounded
check, not gesture smoothness on all devices. The opt-in DEBUG local status report
includes requested control, readiness/error and transaction duration.

Every new send clears its older MIDI/no-op receipt before calling the sender.
Even a send error or lost event cannot leave an old confirmation eligible to suppress
a separate restoration. The loopback regression verifies this failure path.

The DEBUG native pan check requires --verify-matrix-pan and a reviewed UUID intent,
persists its marker before sending, moves only Phones/Home pan to MIDI62, then
separately restores Center at MIDI64. It never writes level, mute, solo or preset
data and cannot replay the same run after restart. Raw state stays on-device.
It is excluded from Release and is not enabled by normal launch.

See [Apple TCP noDelay documentation](https://developer.apple.com/documentation/network/nwprotocoltcp/options/nodelay).

## Solo and UI follow-up under qualification

The owner reported build30 Solo enabled but a second tap timed out, leaving the
stale S indicator lit after Solo was cleared on the pedal. A new build sends Solo
as a high-value press followed by a low-value release in one MIDI event list. This
is a device-test candidate, not established firmware behavior or a verified fix.

While the mixer is presented, preset polling and deferred editor refreshes wait
until it closes; the live event reader and Matrix reads remain active. Heartbeat
receipt time no longer publishes a redraw of the whole editor. These changes aim
to reduce gesture stalls; isolated 100ms transactions did not prove smooth dragging
in the owner's earlier check. Fresh gesture and Solo acceptance remain required.

An opt-in DEBUG Matrix trace filters to the live-update socket, with a2MiB cap.
This avoids large preset-read responses exhausting the event trace before testing.
No source traces or native mixer data are included in Git.

## Absolute Solo recovery and autonomous qualification

Clear Solos sends only the selected output's documented CC103. It requires fresh
routing/identity checks and off receipts for all previously active strips; partial,
missing and other-output events cannot claim success. All non-solo fields and other
outputs are preserved. It does not loop through uncertain toggle commands.

A DEBUG --verify-matrix-solo check is prepared for unattended qualification. A fresh
reviewed intent and UUID marker are mandatory; it starts with Phones solos off,
records the Matrix baseline, runs only Home Solo on/off, then verifies saved preset
and live edit bytes stayed unchanged. If that toggle check becomes uncertain, it
attempts one separate absolute Clear Solos restoration. An uncertain clear is never
retried. Normal launch sends no test writes. Physical qualification of this recovery
path remains pending while the iPad cannot launch the check.
