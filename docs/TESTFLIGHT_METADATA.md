# TestFlight beta information

Updated November 22, 2026: **1.0.0 (49) uploaded, processed, external group assigned, Waiting for Review.** Earlier 0.9.6 (24) is Approved; it is not today's build. Automatic tester notifications stayed off. No invitations were sent; owner-approved review contacts stay in App Store Connect only. Public download of 49 is pending approval/release.

## Beta description

StadiumPad is an unofficial, open-source iPad companion for Line 6 Helix Stadium. Connect your iPad and Stadium to the same local network, enable Remote Access on Stadium, and allow Local Network access in StadiumPad.

Browse preset folders and Factory/User presets, select signal blocks and models, edit supported controls, and save a copy or User preset. Focus View offers supported named tones and X/Y control; Hype stays beside the selected amp/model name. Scene view provides eight snapshot buttons, and Footswitch view controls supported assigned latched effects. Tuner mode opens/closes the pedal tuner; live note/cents remain on Stadium.

The Matrix Mixer popup provides supported direct-USB level, pan, mute/solo and output selection controls with expandable Home/Song strips. Persistent toolbar icons open editor/performance modes; tuner activates on entry and exits with navigation. Global EQ includes seven colored bands, independent 1/4-inch/XLR/Phones outputs, level/bypass and Copy/Paste/Reset. Command Center edits supported controller assignments, labels and colors. Librarian offers full-width browsing; optional clone file transfers and library backups use a configured Mac companion. Normal preset, EQ and controller editing connects directly to Stadium without a Mac.

Designed for iPadOS 18+ tablets. This is a community proof of concept with incomplete desktop parity: no phone interface, offline editing/sync, Songs/Showcase editing/transport, general routing, IR upload/assignment or clone-to-block assignment. No cloud login or payment is required. Changes are live; use spare presets and Save Copy before experimenting.

Independent software, not affiliated with Line 6 or Yamaha. Thanks to Line 6 for Helix Stadium and to Dwayne Charrington (Vheissu/helix-stadium-tools) for protocol research/reference work. Source, acknowledgments, supported features and installation instructions: https://github.com/privatezer0/StadiumPad

## What to test in 0.9.6 (build 24)

StadiumPad 0.9.6 (24) adds the latest iPad Global EQ, Command Center and Librarian work.

Global EQ: open Global EQ, select 1/4-inch, XLR or Phones, then drag a colored band or adjust its controls. Check responsive iPad/pedal follow, including starting a new drag while a previous change settles. The final device confirmation runs in the background; delayed replies must not rewind newer values or show a false change warning. Test band enable, frequency/gain/Q, cut slope, output level/bypass, Copy/Paste and Reset. EQ changes are global and live, separate from preset Save. Record your starting settings and restore them after testing.

Command Center: use a spare preset to check Stomp A/B, instant/expression sources, supported command types, parameter choices, copy/paste, labels and colors. Assignments remain unsaved until Save Preset; assigned commands may affect connected equipment when triggered.

Librarian: check full-width preset/setlist and clone folder browsing/search. Optional clone import/export and User clone/IR library backup require a configured StadiumPad Mac companion; ordinary preset/EQ editing connects directly to Stadium.

Also test network discovery/reconnection, preset folders, two-way selected-block/model/control follow, Focus View, the pinned Hype control, within-row effect dragging, Save Copy and save/reload, eight scenes and supported latched footswitches. Switching presets discards unsaved edits after a local backup. Tuner entry/exit controls the pedal tuner; note/cents remain on the pedal.

Requires your physical Helix Stadium with Remote Access enabled on the same LAN, Local Network permission, and iPadOS 18+. Tablet UI; no phone layout or offline editing/sync. Songs/Showcase transport, general routing, IR upload/assignment and clone-to-block assignment remain unfinished. Use spare presets. Report app/firmware versions, steps and expected/actual behavior; redact private preset/device data.

## Review notes

A physical Line 6 Helix Stadium on the same LAN is required for hardware controls.
Enable Remote Access and allow Local Network permission. No cloud login,
subscription or payment is required. Normal preset/EQ/controller editing connects
directly to Stadium; optional clone transfers and library backup require a configured
Mac companion. Review contact details already approved by the owner are retained
in App Store Connect and are intentionally omitted here.

Changes are live. Use spare preset copies; record and restore starting global EQ
settings. There is no simulated offline editing mode. The app is independent and
not affiliated with Line 6/Yamaha. Contact the maintainer for hardware/testing needs.

Source/support: https://github.com/privatezer0/StadiumPad
Installation: https://github.com/privatezer0/StadiumPad/blob/main/INSTALL.md
Privacy: https://github.com/privatezer0/StadiumPad/blob/main/PRIVACY.md
