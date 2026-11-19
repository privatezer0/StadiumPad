# Installing StadiumPad on an iPad

## Simple installation for testers — TestFlight

A public TestFlight invitation is being prepared. **There is no live TestFlight
link yet.** Version 0.6.3/build13 is submitted to Apple and is **Waiting for Review**
(as of November 17, 2026). The GitHub repository is source code, not a one-tap iPad installer.
Do not download an arbitrary IPA and expect it to install on any iPad.

Once the invitation is published:

1. On the iPad, install **TestFlight by Apple** from the App Store.
2. Open StadiumPad's public TestFlight invitation link on that iPad.
3. Tap **Accept**, then **Install**; open StadiumPad.
4. Allow **Local Network** access when requested.
5. Put the iPad and Stadium on the same Wi-Fi/LAN. Enable Remote Access on Stadium.
6. In StadiumPad, tap **Connect → Search Network**, then select your Stadium.
   If discovery is unavailable, enter the hostname/IP shown for your Stadium.
7. Try **Save Copy** before experimenting with a valued preset. Changes are live;
   choose **Save** when you want to keep them.

Testers do **not** need a Mac, Xcode, an Apple Developer membership, USB connection
or Developer Mode for a TestFlight build. They need a compatible iPad (iPadOS18+),
TestFlight and their own Stadium on the local network. Preset editing works directly
with the pedal after installation. Optional file transfers require the Mac companion. TestFlight builds expire after 90 days; install
replacement beta builds through TestFlight when available.

Apple documents [TestFlight](https://developer.apple.com/testflight/) and
[public external tester invitations](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers).

## Android tablets

The native Android tablet build uses a signed APK, not TestFlight. There is no
Google Play listing or public APK release asset yet; the public repository contains
source. Once you have the maintainer's verified APK:

1. Download/copy StadiumPad's APK to the tablet and open it in Files.
2. If Android asks, allow that Files app to install this APK, then tap Install.
3. Open StadiumPad, put tablet and Stadium on the same Wi-Fi/LAN, and enable
   Remote Access on the pedal.
4. Tap Connect → Search Network and choose your Stadium, or enter its address.
5. Updates must use the same signing identity; install over the existing app to
   retain local backups/settings. Do not uninstall just to update.

Requires Android8/API26 or newer; physically tested on an Android16 tablet. Tablet
landscape retains the model browser; compact portrait opens Change Model in a
dialog while keeping presets, chain and controls visible. No phone layout.
[Developer build instructions](Android/README.md).

## Build it yourself — developers only

This route is available from source now. Nontechnical testers should wait for the
TestFlight invitation rather than following these development steps.

You need a Mac compatible with Xcode's iOS18+ SDK, Xcode installed/opened once,
Python3, an Apple Account added to Xcode, a USB data cable for initial pairing,
and an iPad on iPadOS18 or later. Install the official Helix Stadium editor on the
Mac so the local functional model metadata can be prepared. Apple's Personal Team
can sign personal-device development builds, subject to its provisioning limits;
that is separate from public TestFlight distribution.

1. In Terminal, select a workspace with room for Xcode builds:

   ```sh
   git clone https://github.com/privatezer0/StadiumPad.git
   cd StadiumPad
   git clone https://github.com/Vheissu/helix-stadium-tools.git ../helix-stadium-tools
   git -C ../helix-stadium-tools checkout dad97d3a2011290f7f6630d04cc1a819cc58752b
   python3 ../helix-stadium-tools/scripts/generate_mobile_block_types_json.py --output ../stadium-blocks.json
   python3 ../helix-stadium-tools/scripts/generate_io_models_json.py --output ../stadium-io.json
   python3 Scripts/prepare_parameter_catalog.py --blocks ../stadium-blocks.json --io ../stadium-io.json
   python3 Scripts/prepare_command_catalog.py
   python3 Scripts/generate_project.py
   open StadiumPad.xcodeproj
   ```

   The extraction scripts use the default installed editor location. For another
   location/version, supply their documented resource options. Generated data is
   private/local and ignored by Git; don't upload it. Without it, the app builds
   with generic labels but won't offer guessed model/parameter controls.

2. In Xcode, open **Settings → Apple Accounts** (Accounts on older versions), add
   your Apple Account and accept any required Apple agreements yourself.
3. Select the blue **StadiumPad** project, then the **StadiumPad** app target.
   Under **Signing & Capabilities**, enable **Automatically manage signing**,
   choose your Team, and change the bundle identifier from `com.example.stadiumpad`
   to something unique, such as `com.yourname.stadiumpad`. Don't use the author's ID.
4. Connect and unlock your iPad, tap **Trust** if asked, and select the physical
   iPad as Xcode's run destination. Finish any device-preparation prompts.
5. If prompted, enable **Settings → Privacy & Security → Developer Mode** on the
   iPad, restart and confirm. Follow Apple's developer-profile trust prompt if shown.
6. Click Xcode's **Run** triangle. Xcode builds, signs and installs your own copy.
7. Allow Local Network access, then follow connection steps 5–7 above.

A Personal Team build may need periodic rebuilding/re-signing. Never remove the
installed app just to update it if you want to preserve its local backups/settings;
use the same signing identity/bundle ID and install an update.

Apple references: [account/Personal Team](https://developer.apple.com/help/account/basics/about-your-developer-account/),
[run on a device](https://developer.apple.com/documentation/xcode/building-and-running-an-app),
[Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device).

## Copying User Clones and IRs to your tablet

1. Open StadiumPad Companion on a Mac with the supported official Helix Stadium
   editor installed. Keep Mac, tablet and Stadium on the same LAN.
2. Search/select your Stadium and connect. Verify the file-connection identity on
   first use. Allow the Mac's Local Network request when prompted.
3. Scan the pairing QR with the tablet camera, open its StadiumPad link, then
   confirm Pair in Librarian; alternatively paste Copy Pairing Link there.
4. In StadiumPad Librarian, choose **Download Library** and wait for completion.
5. **Open Tablet Backup** shares/saves the ZIP, including Clones, IRs and Library.json.
   The verified copy remains on the tablet after disconnecting. The Stadium originals
   remain intact. Keep the Mac companion open for transfers.

This does not install Stadium amp/effect processing on the tablet. Library files
are backups; offline preset editing/synchronization remains planned. See
[Mac companion requirements and developer build](Companion/README.md). The current
Mac owner build is development-signed, not yet notarized for general distribution.
