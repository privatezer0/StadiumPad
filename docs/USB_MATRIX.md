# USB editing and persistent guitar volume — development candidate

Development version: **0.10.0 (25)**. This work is under physical-device qualification;
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

## The three header faders

The header keeps **¼-inch, XLR and Phones** guitar faders visible across Home,
Librarian, Command Center, Global EQ and Songs. Navigation moves to the right. The
workspace still fits Pro and regular iPads; preset/model lists scroll as before.

The faders target Matrix **Home / All Paths**, rather than changing preset tone
controls or the physical output gain. They affect guitar paths routed through that
Matrix layer; Song, Click, Bluetooth, USB-monitor and Aux channels remain separate.
The hardware output volume supplies the overall ceiling.

The volume path is direct iPad USB MIDI, using Line 6's documented CC11 and the
actual Matrix MIDI channels read from the device. No Mac bridge is used. Default
channels are 3/4/5, but they are not hard-coded as the current device settings.
USB-C MIDI must be enabled. Linked outputs or conflicting MIDI channels prevent
independent operation and are reported in the connection sheet.

CoreMIDI notifications grey out the faders when the USB Stadium disappears. Every
send rechecks the unique attached USB Stadium. USB and network serial fields differ;
StadiumPad records a hashed association. A verified USB editor session with one
attached Stadium can establish this association; Wi-Fi-only sessions require the
user to confirm that the USB device is the same selected Stadium. No MIDI values
are sent merely by connecting or restoring local view state.

## Live state and confirmation

The device can emit `/syncMixChannelVolume` with a newer Home level while
`server.mixer.state` still returns an older value. That bulk property must not be
used alone to confirm a MIDI edit or claim live-level restoration. The session
keeps a bounded overlay of device-originated Home events, scoped to the connection.
New bulk reads cannot rewind those live values. The UI labels use the received dB
value, and retain the confirmed MIDI thumb position after an adjustment.

MIDI edits run serially with coalesced newer drag positions. A new matching live
output event is required; a send return code alone is insufficient. The session
rechecks output links/channels and preserves unrelated mixer fields. It never
writes a mirror or repeats an uncertain MIDI command to manufacture confirmation.
A no-op requires a previously confirmed exact MIDI value and corresponding level;
an approximate inverse dB estimate must not skip a restoration.

MIDI has 128 steps. The initial thumb estimate is approximate until a device value
is confirmed; its dB readout is not a calibrated MIDI-to-dB formula. A live event is
also not independent acoustic or pedal-screen qualification.

## Qualification as of November 21, 2026

- 79 Swift tests pass; 76 integration tests pass with 3 existing skips. The Matrix
  loopback tests deliberately keep the bulk property stale and deliver live events,
  and reject missing/wrong-output receipts, stale contexts, linked outputs, shared
  channels and unrelated changed fields.
- Native iPad Pro USB-only discovery/connection and product, preset, library,
  Matrix and Global EQ reads pass. The product matches the selected Stadium.
- Native USB Save Copy created two new empty User slots. Their contents independently
  match the original live bytes; the saved original, unsaved source buffer, current
  preset and snapshot stayed unchanged. Copies were not opened by that check.
- Pro, regular landscape and portrait layouts were rendered natively and inspected.
  Preview faders are intentionally disabled and do not send MIDI.
- An earlier polling implementation failed the owner's pedal-screen check and was
  sluggish. A later live-event implementation is installed, but a fresh physical
  screen/volume acceptance check and unplug/replug check remain outstanding.
- USB-only Global EQ sent a change but did not pass its stored-snapshot confirmation;
  the existing Global EQ confirmation behavior needs further qualification over USB.
  This is not a claim that every editor control has passed a USB hardware test.

Release installers and TestFlight must not be updated based only on these candidate
builds. Keep raw captures, device identities, private addresses, presets and signing
material outside Git. DEBUG inspections are read-only; hardware copy checks require
a fresh reviewed intent, persist an allocation marker and never replay on restart.

## References

- [Line 6 MIDI manual](https://manuals.line6.com/en/helix-stadium/live/midi)
- [Line 6 Matrix Mixer manual](https://manuals.line6.com/en/helix-stadium/live/matrix-mixer)
- [Line 6 firmware 1.4 notes](https://kb.line6.com/helix-stadium-1-4-release-notes)
- [Vheissu protocol research](https://github.com/Vheissu/helix-stadium-tools)

See the project acknowledgments for the community research credit.
