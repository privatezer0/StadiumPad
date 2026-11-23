# Maintainer TestFlight release

Status, November 22, 2026: **StadiumPad 1.0.0 (build 49) is uploaded, processed and Waiting for Review** in StadiumPad Public Beta. This is today's iPad editor with Matrix Mixer, the adjacent persistent toolbar, and automatic tuner entry/navigation exit, plus the earlier EQ fixes, Command Center, Librarian, Focus and performance views. Source was promoted from feature/usb-matrix-guitar-volume for this release.

The older **0.9.6 (24) is Approved**; that is the approval previously shown by Apple, not an approval of today's work. A 0.10.0 (48) upload had begun before the owner requested the 1.0 version label; it was not submitted or assigned to the external group. Build 49 is the new external-review candidate.

Public invitation: https://testflight.apple.com/join/bsmEWx8M (iPad, iPadOS 18+). This check verified review state, not a compatible-device public download. Do not claim build 49 is downloadable until Apple approval/release is verified. Automatic tester notifications remained OFF; no tester invitations or notification emails were sent. Existing approved builds were not expired.

Matrix controls require the supported direct USB route; Wi-Fi editor controls remain available. Live tuner note/cents, complete desktop parity and offline preset sync remain unimplemented. Clone/IR file transfers use the optional Mac companion. Version 1.0 is a release label, not a claim that all desktop features exist.

Users' simple installation steps are in INSTALL.md. A public repository does not
produce a TestFlight invitation automatically.

The maintainer needs an Apple Developer Program membership and App Store Connect
access. Create an iOS app record with the public StadiumPad bundle ID, name,
primary language and SKU. Use a separate public bundle ID from private owner builds.
Register/sign that bundle ID under the maintainer's team. Do not publish signing
keys, profiles, account data or App Store Connect credentials in Git.

Prepare local functional model metadata before archiving; testers must receive a
usable app and must not run extraction tools themselves. Confirm distribution
rights for everything bundled. No vendor artwork, model DSP binaries, user presets,
private traces or DEBUG verification data belongs in the app.

Generate the Xcode project with the public bundle ID/team. Select a Release archive
for an iOS device, then **Product → Archive → Organizer → Distribute App → App Store
Connect → Upload**. Do not choose TestFlight Internal Only for an external beta.
Use the next available build number and resolve upload validation errors.

In App Store Connect, complete export-compliance questions accurately; provide beta
description, what to test, feedback email, contact/review details and hardware setup
instructions. Explain that the app requires the user's Helix Stadium on the same LAN
and that unfinished sections are labeled. Provide Apple reviewers the testing
resources they require; do not claim access to hardware they do not have.

Create an internal tester group first, then an external group; add the processed
build and submit the first external build for TestFlight App Review. After approval,
enable a public invitation link and restrict eligible devices/OS to compatible iPads.
Publish the **verified** Apple invitation in INSTALL.md, README and the announcement.
Do not mark a link live while a build is still being processed/reviewed.

External testers install Apple's TestFlight app, open the invitation and tap Install.
No source build, Xcode or Developer Mode is needed. Beta builds expire after90days;
maintainers need replacement uploads. Source and Android plans remain on GitHub.

[Apple overview](https://developer.apple.com/testflight/) ·
[external testing/public links](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers)
