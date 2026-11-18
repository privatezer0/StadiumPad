# Prepared beta information

Template for App Store Connect. The beta description, feedback address and
owner-approved private Apple review contact are saved there. Contact details are
intentionally omitted here. Version 0.6.3/build 13 has been uploaded, validated, and submitted for external Beta App Review. As of November 17, 2026, App Store Connect showed Waiting for Review. No public invitation is live; verify current status in App Store Connect before announcing availability.

## Beta description

StadiumPad is an unofficial open-source tablet companion for Line 6 Helix Stadium.
Connect your iPad and Stadium to the same local network, enable Remote Access,
and allow Local Network access in the app. Browse preset folders, select signal
blocks/models, edit supported parameters and save a new copy or User preset.
Focus View offers named tones/X/Y blending, cabinet placement and EQ control
positions while keeping presets and normal controls visible. Scene view offers eight snapshot buttons; Footswitch view controls validated
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
- Drag effects within a row, save/reload and confirm order/settings/assignments.
- Check Hype centered between the model name and ACTIVE on every parameter page.
- Select another preset to discard unsaved edits; no automatic Save occurs.
- Open Focus with the aperture icon, tap named tones/drag and restore starting tone.
- Check Focus responsiveness, cabinet placement and EQ handles on physical tablets.
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
Privacy information: https://github.com/privatezer0/StadiumPad/blob/main/PRIVACY.md

## Maintainer release status

The App Store Connect app record, beta description, feedback/review contact,
export-compliance information and What to Test were saved for the build 10 Focus submission.
Automatic tester notifications are disabled and no testers were invited at the
recorded submission time. Apple external beta approval and enabling a verified
public invitation remain pending as of November 17, 2026. Confirm live status
in App Store Connect before updating this document. Do not publish private
reviewer/contact details in this repository.
