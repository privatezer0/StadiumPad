# Maintainer TestFlight release

Status, November 17, 2026: StadiumPad0.6.0/build10 (Focus View) is uploaded,
validated and submitted for external Beta App Review. App Store Connect confirms
**Waiting for Review** for0.6.0/build10. Earlier0.5.2/build9 remains Waiting for
Review; build8 was withdrawn after its touchscreen-drag defect. No beta approval
or public invitation is live. Updated What to Test includes Focus gestures and
current limits. Automatic tester notification is disabled; no testers are invited.
Native iPad Focus transaction/save/reload/restoration checks pass. Physical pad
feel is requested separately; do not claim acceptance until observed or reported.
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
