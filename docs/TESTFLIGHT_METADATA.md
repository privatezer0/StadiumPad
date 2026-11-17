# Prepared beta information

Draft for App Store Connect; not evidence of an uploaded or approved build.
The maintainer must supply the actual feedback email and Apple review contact.

## Beta description

StadiumPad is an unofficial open-source tablet companion for Line 6 Helix Stadium.
Connect your iPad and Stadium to the same local network, enable Remote Access,
and allow Local Network access in the app. Browse preset folders, select signal
blocks/models, edit supported parameters and save a new copy or User preset.
Scene view offers eight snapshot buttons; Footswitch view controls validated
assigned latched effects. Tuner mode opens/closes the device tuner; live pitch
readings remain on the Stadium display. Designed for iPadOS18+ tablets.

This is an early proof of concept. Command Center editing, Global EQ, song/Showcase
editing/transport, IR/clone import/assignment and general block/routing editing are
unfinished. Offline editing/sync and Android are planned. No phone interface.

## What to test

- Find and connect to your own Stadium on the local network.
- Browse User preset folders and Factory presets; use Save Copy before experimenting.
- Select blocks on the iPad/pedal and check model/category/control synchronization.
- Edit a parameter on a spare preset, save, switch away and reload.
- Switch existing scenes; create only an empty scene slot when requested.
- Toggle standard assigned effects in Footswitch mode; report unsupported assignments.
- Enter/leave Tuner mode and check the pedal tuner opens/closes. No iPad pitch meter.
- Check Pro/regular landscape and portrait layouts with the preset sidebar visible.

Include app/firmware versions, steps, expected/actual results in feedback. Redact
personal preset/device data. Keep original saved presets safe when testing.

## Review notes

This companion app requires a physical Helix Stadium on the same LAN to exercise
hardware controls. No cloud login/account or payment is required in the app.
Remote Access must be enabled on the device; Local Network permission is required.
The app discovers the device through Bonjour or accepts a manually entered address.
There is no simulated offline editing mode in this build. Please contact the
maintainer for any additional hardware/testing resources needed for review.

The app is independent and not affiliated with Line 6, Yamaha, Neural DSP or Fender.
No firmware update or access-control bypass is implemented. Changes are live;
preset testing should use new copies. Source and acknowledgments are public.

Source/support: https://github.com/privatezer0/StadiumPad
Installation: https://github.com/privatezer0/StadiumPad/blob/main/INSTALL.md
Privacy information: https://github.com/privatezer0/StadiumPad/blob/main/SECURITY.md

## Maintainer fields still required

Feedback email; review contact name, phone and email; App Store Connect app record;
any required review testing resources; actual export-compliance answers. Do not
invent these fields or commit personal contact details without authorization.
