# USB editing and persistent guitar volume — development candidate

Development version: **0.10.0 (26)**. This work is under physical-device qualification;
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
mute and solo. Clear Solos turns off the currently enabled solos through individually
confirmed operations. The Global EQ shortcut opens the selected output's EQ.
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

- 82 Swift tests pass. Matrix-specific loopback tests: 13 pass. The full
  integration suite has 82 cases: 79 pass and 3 existing skips. Eight library cases
  were rerun successfully after correcting their external executable path. The Matrix
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
- An earlier polling implementation failed the owner's pedal-screen check and was
  sluggish. The owner subsequently confirmed the live-event Phones fader follows promptly
  with no warning. The new full-channel popup, other outputs, pan/mute/solo and
  unplug/replug checks remain outstanding.
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
