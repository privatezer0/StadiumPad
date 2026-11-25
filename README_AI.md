# StadiumPad — AI / LLM contributor handoff

Give this file and README.md to your coding model. Read AGENTS.md and the actual
source before changing behavior. This guide grants no hardware or publishing access.

## Architecture

- Sources/StadiumProtocol: bounded ZMTP framing, OSC, MessagePack, typed read/edit
  commands, metadata validation, DeviceSnapshot projection, StompAssignment planning.
- Sources/StadiumNetwork: Network.framework sockets, request correlation, FIFO
  transactions, backups, edit/readback/save/copy and scene/controller operations.
- iPad/Sources: SwiftUI editor, connection monitor, discovery, scrolling folder
  browser, category/model selection, parameter controls and performance/tuner views.
- Android/app/src/main/java/com/privatezero/stadiumpad: native Java protocol, FIFO
  session/monitor, original Canvas tablet editor, Android NSD and guarded workflows.
  Build scripts use external Android SDK/JDK/build/signing paths; bundled catalogues
  are copied locally from the same generated iPad resources. No WebView or bridge
  Mac is needed for editing. File transfers use the optional companion. Shared synthetic Focus vectors verify arithmetic parity.
- Sources/StadiumProbe: explicitly invoked read-only research CLI.
- Sources/StadiumEditCheck: explicitly invoked spare-only edit harness.
- Tests: synthetic data and loopback peers. Hardware data is never a test fixture.

## Critical invariants

Use typed operations, never an arbitrary OSC/property-write UI. Parameter/model
contexts include connection origin, preset/snapshot, path, **visible position**,
internal block ID, model ID and model slot. Never substitute block ID for position.
Reject stale values/contexts instead of replaying them. Session snapshots are
coherent across preset/snapshot reads. Serialize whole transactions, not just frames.

Retain raw `_sbepgsm` preset bytes for preservation. Normalized FourCC maps are for
inspection; re-encoding them can corrupt native graphs. Save Copy allocates only an
empty User slot, verifies it again, records allocated identity, stores exact raw
bytes only to that allocation, and independently verifies before opening it.
Do not overwrite occupied slots. Owner-directed UI preset selection means discard
unsaved edits after backing up saved/live bytes; it does not save or create a copy.
Internal load helpers remain strict by default. Never opt copy/recovery code into
discard merely to bypass a failed preservation guard.

ACK is necessary but insufficient for parameter/model/save claims. Check actual
readback, clean state and stored content. No automatic retry after an uncertain
write. Back up saved and live state before edits. Never auto-save performance edits.

Footswitch plans resolve actual source/controller/target assignments. Preserve
inverse ranges and multi-target behavior. Commands, MIDI, timed/momentary behavior
and ambiguous targets are not supported; do not execute a partial approximation.
Tuner uses only the two known open/exit events; no live note/cents feed is established.
Do not fabricate a note meter or claim an ACK proves a pitch reading.

Disconnect/switch must invalidate old contexts, pending dialogs, inventories and
selection. Never restart a connection by recreating its owning root View with an
ID changed inside connect(): that creates a reconnect/cancellation loop. Routine
Task cancellation must not be shown as a connection error.

Native block reordering uses a bounded adjacent-swap `/doAgenda` batch within one
row, not delete/recreate. Agenda ACK's changed flag may be 0 or 1; it differs from
ordinary zero-status ACKs. Confirm the entire expected rotated layout, every model/
harness value and controller assignment configuration. Native entity/set ordering
and runtime byps/togl flags are not configuration edits. Preserve unknown fields;
never ignore actual assignment ranges or block enabled/parameter values. Reject
cross-row/path moves, IO/routing-node moves and uncertain branch boundaries.

Focus uses locally generated complete maps, float32 triangle interpolation and
strongest-point discrete choices, credited to helix-stadium-tools. Never drop a
missing non-excluded parameter and publish a partial tone. Supplemental native
controls are marked focusOnly and hidden from ordinary parameter browsing.

Batch edits validate every initial expected value before sending, retain native
backups, apply switches/integers before floats, check identity while running, and
confirm all final values. No retry/save on error. The view coalesces newer gestures
and stops queued work on close/target changes. A running batch finishes validation;
close does not abandon an uncertain write mid-response. Opening the view sends no
parameter writes. Keep start-tone restoration separate from desktop user defaults.

## Validation and delivery

Run `swift test` and Python loopback tests as documented in README. Add meaningful
regressions for behavior changed. Use native SwiftUI viewport rendering for Pro,
regular landscape and portrait when changing layout. DEBUG verification harnesses
must be explicitly invoked; Release must never auto-edit for a test.

Hardware writes require the user's explicit authorization and newly allocated spare
copies, preserving existing saved contents and unsaved source edits. Persist intent
and each allocation so interrupted tests cannot blindly allocate/retry. Audit stored
original hashes afterward. Never use production presets as write destinations.

## Public-source hygiene

Never commit credentials, signing identities/profiles, private addresses/device IDs,
traces, captures, presets, generated vendor metadata, build caches or installers.
Use configurable paths and local environment variables for signing/builds. Keep the
MIT upstream notice. Credit research accurately, including controller interpretation.

Current gaps are listed in README. Offline mode remains planned. Android tablet source is implemented; its current
qualification and remaining limits are recorded in Android/README.md. Do not
confuse a view render, an injected gesture and human physical acceptance. No cloud synchronization exists. A future
sync design needs device identities, conflict handling, explicit destinations,
backups and preservation of unknown native data before it can safely write.

## Live selection (0.6.5)

`/SelectedBlockSet ,iii [commandID, zeroBasedFlow, visiblePosition]` changes the
pedal's transient selection. It emits `/setSelectedBlock ,iiii
[source, commandID, flow, position]` on the subscription stream, with no ordinary
`/status` ACK. Keep the event reader running while the FIFO transaction waits for
the matching command ID and location, then revalidate context. A missing/wrong echo
fails without retry, Save, parameter writes or a disconnect. Do not send the incoming
`/setSelectedBlock` notification as a command. A block may contain multiple model
slots; the event has no slot field, so retain the current slot at the same location.
Never echo externally applied selection back onto the network. Incoming events apply
immediately and reconcile against the refreshed snapshot; external model changes
also select the changed visible slot. Ordinary polling must preserve category browsing.

Startup selection remains unresolved: firmware1.4.2 rejected both SelectedBlockGet
and GetSelectedBlock. Fresh connection/snapshot replies and enumerated properties
provided no verified current-block field. A private, loopback-only trace of the
installed desktop editor's startup also showed no selection query/event; its initial
selection did not match the last independently observed pedal selection. These
observations do not prove no other getter exists. Do not simulate a read by sending
SelectedBlockSet or present cached focus as guaranteed current hardware state.

## Remembered selection (0.6.6)

Each client stores a local preference under a hashed device serial (endpoint/port
fallback) plus the actual active preset content ID. Never key by display name,
list position, prior app preset or transient connection UUID. Restoring is entirely
local: it must not send SelectedBlockSet, LoadPreset or Save. Use the fresh active
preset's own record; no history means ordinary valid-block fallback. Resolve stored
flow/internal block ID/model slot against fresh blocks, allowing within-flow moves;
removed, ambiguous, invalid or missing slots cannot reuse a stale edit context.

Remember explicit tablet choices and accepted external selections. Persist external
focus after coherent refresh so a pending preset transition cannot overwrite the
previous preset's preference. Initial fallback/preview renders do not overwrite
history. Preserve live-event precedence and reject stale focus after a newer local
selection. iPad and Android have independent local histories; this is not cloud sync
or a verified read of the pedal selection while the tablet was disconnected.

## Librarian and Mac file companion (0.7.0)

Librarian uses the full workspace, with no Home preset sidebar or preset mode bar.
The native category rail and independently scrolling folder/content panes exist on
both platforms. Containers: Templates -3, Favorites -8, Factory/User IRs -10/-11,
Factory/User Clones -13/-14. User clone category folders -22...-25 are real negative
IDs; retain type1002 and owner validation. GetCloneHierarchy may be empty despite
real clones. Enumerate actual GetContainerContents folders instead.

Companion/ is the optional macOS14+ HTTPS/SFTP file service. It requires the user's
installed supported official editor; no vendor identity is bundled or persisted.
The local runtime decoder is credited to former upstream MIT research. New editor
hashes fail closed: do not relax the fingerprint check or distribute extracted keys.
The tablet stores only its own pairing token/certificate pin in Keychain/Android
Keystore-encrypted preferences. No arbitrary command/path/host proxy API exists.

Sources/StadiumLibrary is a bounded local JSON agent with a typed whitelist, using
existing serialized StadiumSession transactions. Require exact device serial hash,
CID/UUID/name/owner/category and independently confirmed readback for mutations.
AddContentsToContainer's last flags 0,1 mean verified move; 0,0 copies and cannot
confirm a move. New folders require ownr1. Exports wait for cloneArchiveExportReady,
not an ordinary status ACK. GetContentPath replies include trailing zero status.

Clone uploads use exclusive unique staging, byte readback and one atomic rename
into the native ingest folder followed by a non-truncating close-write notification. Refuse logical AND physical UUID collisions before
commit. Journal intent first; never replay uncertain jobs. Preserve opaque/encrypted
clone members exactly. Never decrypt/rewrite protected DSP assets or overwrite an
existing identity. Delete/rename retains a Mac archive backup; built-ins and protected
content are refused. Do not test deletion on valued user content.

Download Library is read-only apart from native export-cache generation. ZIP entries
contain original User clone archives, User IR WAV files, and Library.json with
metadata/checksums. Validate actual IR paths and normalized symlinks remain in the
IR subtree, WAV headers, size bounds and before/after library consistency. Clients
verify the entire ZIP hash before retaining a durable backup; do not expose partial
success. IR upload/assignment, clone-to-model assignment, other Librarian writes and
complete desktop parity remain unimplemented. The Mac must be open for file
operations, not routine editing. The current Mac owner build is development-signed,
not a notarized public release.

Explicit DEBUG/instrumentation harnesses are not normal startup behavior. Strip
pairing links from private test plans after use. Keep all real archives/IRs, device
IDs, tokens, host keys, captures and installers out of source and test fixtures.

## iPad Command Center (0.8.0)

`CommandCenter.swift` defines source descriptors, category restrictions, validated
parameters, exact command contexts and clipboard values. `CommandCenterView` uses
original vector controls; do not copy vendor artwork/XML. Generate the ignored
functional `CommandCatalog.json` with `Scripts/prepare_command_catalog.py` from an
installed official editor. Missing metadata disables controls instead of guessing.

`attachCommandWithType` replies with the new command ID twice, not a source ID.
Stored XY sources have local=-1 even though attach uses local=0; Instant local=0,
context=instant index. Onboard EXP2 uses local42/context1; EXP1 context0. Physical
switch contexts are bank1/2. Never equate a command/source ID to its visual index.
`func` is the continuous flag, not the visible Command subtype: switches use pvlb,
Instants pvla. Snapshot removal is lowercase `/removeSnapshotCommandParam`.
Only Action and MIDI Command exclude snapshot control. Continuous runtime Value
is excluded from clipboard data. Clipboard All rejects unrecognized sources rather
than copying a partial layout. Clear All removes commands, retaining effect controllers.

Setlist destinations are indices (Factory0, User1, custom folder position+2),
preset destinations are positions within that list, never content IDs. Selecting a
setlist also resets its preset position to0 using separately checked FIFO writes.
The two onboard expression selector colors choose separate assignment contexts.
If Command1 uses Toggle, Command2 Action is displayed/disabled as Toggle like the
desktop editor. Appearance writes allow only the selected stomp's label/color keys;
labels max24 characters, colors0...11. Preset/Snapshot labels are automatic.

Assignments use backup, exact context revalidation and independent graph readback.
An uncertain write is not retried. Editing assignments does not execute them, but
Instant commands can execute on preset recall: remove transport-affecting Instants
before Save/reload tests. Physical tests allocate/preserve spares and journal intent
before writes. Never remove a test intent marker to replay an uncertain batch.
Android still has its previous Command Center placeholder; do not claim parity.


## iPad Global EQ (0.9.6)

`GlobalEQState` validates the entire seven-band/three-output schema. Unknown keys,
missing/duplicate band or parameter IDs, invalid values and wrong output IDs refuse
writes. Native values include boolean enables, float32 controls and integer slopes.
Numeric native FourCC keys use the exact unsigned32 MessagePack tag observed in the
desktop. Do not use this settings encoder to rewrite native presets.

`GlobalEQOperation.liveUpdates` emits the native individual band/control properties
for gestures, output enable and level. Native whole-output Paste/Reset messages are
separate operations. Session serializes fresh-state comparison, original native and
effective live backups, each live command/ACK, allowed partial-echo and other-output
checks, the native `globals.eq` commit/ACK, then device-owned `global.eq.sync` readback.
Never publish the sync mirror to manufacture successful readback. Compare the raw
stored reply after commit, not the shadow containing live-event echoes.
Native commit ACK precedes updated readable settings: hardware measurements found
stale replies beyond1.85seconds and a restoration settling at3.07seconds. Poll reads
at150ms intervals for up to5seconds, never repeat live/commit writes. `stageGlobalEQ`
serializes and backs up live DSP updates without waiting for that delayed readback;
its returned state is optimistic after ACKs, not storage proof. The view coalesces
updates at40ms and requests a single commit after150ms idle. `commitGlobalEQ` serializes
its guard/commit and each read individually, releasing the FIFO while sleeping.
A newer live-write revision supersedes the old confirmation. Monitor cancels its
old confirmation task and rejects background refreshes started before a newer edit.
Retain at most32 known committed roots so delayed snapshots cannot rewind newer
live state. Unknown external state still invalidates guarded writes.

Native own write echoes can arrive seconds late (observed2.63seconds after a newer
read). Track at most256 exact DSP request-ID/blob receipts, pin the correlated echo
source, and suppress only matching own receipts; other clients’ events still apply,
even with the same request ID/payload. Reset receipt/history/revision state on disconnect.
If readback still mismatches, say the change was sent and confirmation is incomplete;
never imply nothing changed after a successful live write.
No uncertain write is automatically retried. Do not save/recall presets for EQ.
Copy includes source bypass; Reset preserves destination bypass.

Important validation correction: owner reported 0.9.0's iPad graph changes did not
appear on the Stadium's own EQ screen. Earlier41hardware/17native API checks proved
command ACKs, stored sync-property values and preservation, not actual front-panel
or audio-engine changes. Never equate sync-mirror readback with independent DSP
verification.0.9.0 used whole-output messages for gestures and omitted the native
`globals.eq` commit in favor of a readable sync property. That substitution was
not justified by `globals.eq` being absent from property lookup: a command-style
property can be consumed without a registered readable value.0.9.1 restores the
observed native commit. The owner reported that 0.9.1 still did not update the
pedal. An isolated three-channel desktop trace then confirmed automatic stored-state
updates with no direct mirror write; the owner confirmed the native level change
on the pedal. Version 0.9.2 removes mirror writes. The owner subsequently confirmed
Level control and build20 graph Frequency/Gain follow on the pedal, but20's immediate
stored check falsely failed. Version0.9.3 waited for device readback; owner confirmed no warnings but reported lag.
Version0.9.4 separated streaming/verification; owner confirmed better response but
saw a false external-change warning from delayed own echoes. Version0.9.5 adds
receipt matching and refresh guards. The owner’s earlier warning reply was later
clarified as possibly an older test. A fresh clean build24 native check and human
touch test confirmed responsive pedal follow without warnings. Physical observations do not establish audio response;
no resolved-pedal-update or acoustic/power-cycle persistence claim until verified.

Desktop DSP broadcasts can precede an unchanged/stale sync-property read. The
connection-scoped EQ shadow applies validated live broadcasts; changed full sync
reads replace it. Coalesce pending typed properties and preserve newer events across
older in-flight reads. Reset on disconnect. Gestures coalesce and refuse stale or
disconnected edits. Leaving the view discards unsent changes; sent transactions
finish/read back. `EQResponse` is our visual approximation, not vendor DSP.
Android EQ is not implemented here. Debug-only STADIUM_TRACE_GLOBAL_EQ=1 records a
private owner-side wire trace capped at8MiB for diagnostics. A single atomically
replaced `global-eq-last-edit.json` records the last requested edit and its stored
readback/error result even after that cap; `global-eq-last-failure.json` separately
retains the last failure so later success cannot erase it; it is diagnostic evidence, not a
physical-DSP confirmation. Never publish captures/preset data.


Build24 includes a one-shot DEBUG `--verify-global-eq-stream` harness. It requires
an explicit new `global-eq-stream-intent.json` authorization and refuses an existing
started marker, a different spare preset, or an enabled quarter-output EQ. It drives
the real Monitor staging/idle-commit path, supersedes a settling commit, verifies
the final stored state, restores the captured complete original output, and checks
preset/edit-buffer/snapshot preservation. On native Pro,13checks passed; maximum
individual live transaction latency was0.4223seconds. This is business-logic/network
qualification, not a substitute for human touch testing. The owner subsequently
confirmed the fresh build24 graph was responsive, followed on the pedal and showed
no warning. Final Release24 was installed/cold-launched; no new TestFlight upload.
Do not replay a partial run or expose its real native data. Debug records now carry build
and diagnostic schema; write failures retain a separate small diagnostic text file.

## USB transport and Matrix guitar volume candidate (0.10.0 / 46)

Read docs/USB_MATRIX.md before continuing this work. Carry the discovered NWInterface
into both editor sockets; a wired interface type alone did not qualify. USB mode
must never silently use Wi-Fi. CoreMIDI volume is direct from iPad, not a Mac bridge.
Keep USB/network device identity binding explicit and invalidate availability on
MIDI detach. Read actual MIDI channel settings and refuse linked/conflicting outputs.
The popup exposes only typed documented per-channel controls; there is no arbitrary MIDI sender UI.

Bulk server.mixer.state can lag a device Home-level event. Use the bounded,
connection-scoped live overlay and a new output receipt to confirm MIDI changes;
never overwrite a mirror or use an estimated MIDI inverse to skip restoration.
Preserve queue coalescing and current MIDI thumb position. Initial position mapping
remains approximate. Live notifications do not prove acoustic/pedal-screen behavior.
Native Phones/Home Solo and pan qualification passed; broader device coverage,
unplug/replug and USB EQ stored confirmation remain open;
never convert the candidate into a claimed release based only on synthetic tests.

## Matrix popup (development candidate 0.10.0 build 45)

A single Matrix Mixer header button opens MatrixMixerView. Its output selector uses
three accessible icon buttons; selection is remembered locally. Opening never sends MIDI. Close reads attached output and uses the closing plan
(distinct output, original output, original output) before dismissing locally.
Missing USB still permits local Close; errors dismiss locally with no retry or
claim of confirmed pedal visibility. Swipe is disabled to prevent bypassing Close.
Do not send from onDisappear. Explicit popup output taps use MatrixPanelCommand's distinct-output
then target plan. Home0 is NOT an established absolute panel close: owner42testing
showed same-output toggling despite it. Do not restore Home0/output batching.
StadiumSession.navigateMatrixPanel serializes the two stages, checks fresh global routing,
requires a new matching syncMixAttachedOut receipt per stage and allows the first UI
transition to settle. MainActor USB identity/generation is checked adjacent to each
send. No uncertain stage retries or advances. Selecting output affects screen/knob
target only, not levels or presets. No writes from onDisappear, output observers or header entry. WiFi-only/preview remains local. No verified panel-visible getter/event
exists; attached-output alone must not auto-open a closed iPad popup. The one-shot
DEBUG icon check tests repeated targets and preserves preset/mixer settings; its
success does not constitute visual pedal-screen proof.
MatrixConsoleState strictly parses the nineteen documented sources per output;
source IDs differ from CC order (Home=source5/CC11, Song=source14/CC16).
MatrixConsoleCommand exposes only typed channel fields, never arbitrary MIDI CCs.
Mute/solo CCs are toggles: require the opposite live state. Solo currently sends
127 then0 as a press/release pair, verified on/off for Phones/Home. Never
retry uncertain toggles. Coalesce level/pan gestures, but never toggle commands.
Every transaction requires a new matching output/source/field live receipt and
preserves unrelated known and unknown data. Bulk properties can stay stale after
MIDI writes. Retain bounded live overlays per connection for all four channel fields.
Disconnect/close/output switching clears pending gestures; in-flight transactions
finish confirmation. MainActor connection identity is checked adjacent to USB send.
No meters, main-knob writes, output linking or all-channel Reset are implemented;
do not fake these or claim full pedal parity. Initial level thumb remains estimated;
actual dB readouts are live, and calibration requires independent hardware evidence.

Clear Solos is a separate absolute CC103 operation for one output, not a loop of
unconfirmed Solo toggles. Its menu remains usable after an uncertain toggle, with
fresh connection/USB identity/channel/link guards. Require new off receipts for
all previously active known strips and preserve every non-solo mixer field and all
other outputs. Do not retry an uncertain clear. The guarded DEBUG Solo qualification
uses a reviewed UUID, starts only with all Phones solos off, preserves saved/live
preset bytes, tests Home on/off once, and uses one absolute clear as recovery only.
Do not replay marked runs or enable these tests on normal launch.

## Matrix gesture queue and modal rendering

MatrixGestureQueue owns coalescing, in-flight tickets and visual thumb positions.
Show the newest continuous request immediately; an older receipt cannot rewind it.
Toggle flags always use actual device state and are never coalesced or shown as
confirmed optimistically. Reset invalidates old tickets; canceling queued gestures
does not abandon an already-sent transaction. dB labels remain actual readback.
MatrixPan uses the observed1.4 mapping clamp((MIDI−64)/63,−1,1), with float tolerance.

Matrix operations participate in the busy guard without publishing a redraw of the
hidden editor behind the modal. Ordinary editor operations still publish busy;
closing the modal or disconnecting releases the Matrix exclusion correctly.
--show-matrix opens only the popup. Layout rendering requires the separate
--capture-matrix-layout or --verify-layout flag; don't run heavy preview captures
concurrently with gesture measurements. The opt-in DEBUG gesture test exercises the
presented production model/queue, samples CADisplayLink main-thread frame pacing,
uses small Phones/Home pan requests, restores Center and checks saved/live bytes.
It requires its own exclusive UUID marker. Combined qualification runs Solo then pan
sequentially, never concurrently. The on-device matrix-tests-gate.json disarms debug
helpers after testing; malformed existing gates fail closed. The delivered gate is
disarmed. Equivalent pan endpoints may skip a send only with a prior fresh matching
receipt; estimated volume mappings never authorize a no-op.

## Matrix expansion and scroll gestures (build 45)

Home/Song insert child strips into the same horizontal ScrollView. The HStack keeps
its full intrinsic horizontal width; never squeeze expanded controls into the viewport.
MatrixFaderTouchSurface bridges a clear UIKit view over the existing SwiftUI fader
artwork. Its UIPanGestureRecognizer delegate rejects horizontal velocity before
recognition begins, so the enclosing ScrollView can claim that swipe. Vertical
pan/tap callbacks update the existing binding and release on end/cancellation.
VoiceOver adjustment remains on the SwiftUI element. An initial simultaneous
SwiftUI DragGesture passed vertical edits but failed the far-end swipe test; do
not restore that workaround or a minimumDistance0 exclusive drag.

MatrixScrollHarness is DEBUG-only, synthetic and has no monitor/session/MIDI sender.
The optional STADIUMPAD_UI_TESTS=1 project-generation flag adds StadiumPadScrolling
with iPad/UITests/MatrixScrollingUITests.swift. Its launch argument bypasses the
normal connected editor. Native UI tests check expansion, far-end reachability,
unchanged values during horizontal swipes, collapse and vertical adjustment after
a sideways gesture. Release does not include the harness. Distinguish simulator
passes from physical automation; the first physical run timed out enabling automation.

## Song strip display labels (build 46)

MatrixStrip.displayName maps only sourceIDs6–10 whose native name is the matching
case-insensitive trimmed Track1–5 default to Drums/Bass/Guitar/Vocals/Other. Prefer
all specific native labels. Other IDs/names are unchanged. UI footer, Pan title
and accessibility names use displayName; raw name, property bytes, IDs, routing,
state equality and write receipts must remain native. These are the documented
standard stem labels, not a claim to have fetched active-song custom metadata.
The observed remote Matrix data still returns Track1–8 while the pedal shows stem
names. Do not hard-code names into raw properties or reorder sources to match them.

### iPad top navigation (build 47)

The five EditorSection buttons stay centered on screen. Matrix Mixer sits directly
to their left and EditorMode directly to their right, with dividers and 10-point
gaps. The grouped header compensates for the unequal flank widths to preserve
the core center; connection/status remains separate at the left edge. Modes are always visible labeled icons, separated from
Songs by a divider. A mode tap sets section to Home then selects the mode; the
existing mode/section observers retain tuner exit behavior. Do not restore the
preset-bar-only segmented picker. Header buttons share navigationButton styling.

Build 47 validation: physical iPad Pro build/install/launch and native renders at
Pro landscape, regular iPad landscape/portrait and library/other section sizes.
98 Swift unit tests and 30 Matrix loopback tests pass. This presentation change
does not send Matrix writes or change source routing; no pedal settings were
changed during validation. FootPressIcon is original SwiftUI vector artwork.

### Tuner navigation (build 48)

TunerBoard has an exit callback: Turn Tuner Off selects Home/Preset, which sends
the exit command through the existing mode observer. Main toolbar sections use
selectSection, explicitly clearing Tuner even when Home is already selected.
Modes use selectMode; entering Tuner sends open automatically, and an explicit
repeat tap reopens it. MatrixVolumeBar calls beforeOpen to leave tuning too.
setTuner must not guard on editor busy or own that shared busy flag: the session
FIFO transaction lock serializes tuner commands behind pending work. Otherwise a
busy editor silently drops automatic entry/exit. No live pitch support is implied.

Build 48 qualification: 98 Swift tests and 30 Matrix loopback tests pass. An
explicit DEBUG-only --verify-tuner-navigation check on the connected iPad executes
the actual view navigation callbacks and observes session acknowledgments: entry
while editor busy, Off/Home return, entry from Librarian, exit through each of the
five main sections, final Home/Preset with tuner off (13 checks, 12 acknowledged
tuner commands). This verifies command acceptance and local navigation, not pedal
screen pixels or live pitch. Native Tuner layout inspected. Final app relaunched
without verification flags; no preset or mixer settings changed.


## PedalBridge — 2026-11-24 development1.1.0(50)

Owner changed architecture: tablet Wi-Fi → Mac/Pi helper → Stadium USB network + MIDI, with helper Wi-Fi-only fallback and Matrix unavailable without matching USB. Quad Cortex deferred. Separate privatezer0/PedalBridge development repo. Preserve direct Wi-Fi/USB modes.

PedalBridgePair validates private URL fields and redacts description. PedalBridgeConnection obtains target identity/generation then shares a random lease across pinned-TLS updates/commands; WireSocket authenticates before ZMTP, never traces the token, and preserves bytes buffered beyond the JSON newline. Native session transactions/backups/readback remain unchanged. Monitor requires bridge snapshot identity to match preflight. Keychain settings and startup routing are centralized to avoid the previous competing auto-connect task losing the pair. DEBUG private-file import is explicit, removes the file, and is not a production secret persistence path.

Matrix callbacks use the bridge only for a bridge route, retain adjacent MainActor connection/token checks, and never fall back silently to local tablet MIDI. Helper validates actual MIDI settings, its editor lease and physical USB identity; send success is not pedal readback. Direct callbacks stay intact. Wi-Fi-only helper has no Matrix. Upstream/USB changes revoke streams; uncertain writes never replay. Android uses the equivalent TLS preface and encrypted app-only Keystore pairing; direct USB/Ethernet uses per-socket Android Network binding, not process-wide routing. Android original feature gaps remain.

Validation here:101Swift tests; existing Matrix loopback suite;10helper TLS/auth/lease/Matrix-mapping tests; repeated native Swift read-only sessions through real helper; physical Pro read-only snapshot/live events plus Matrix ready with local USB MIDI false; native Android emulator read-only snapshot and3Matrixoutputs through same Mac app. No physical writes, preset/save/firmware/audio changes. No new TestFlight submission. Physical Android/native USB and bridged Matrix writes pending. See helper README/ARCHITECTURE for Pi plan, helper lifecycle and current limits.
