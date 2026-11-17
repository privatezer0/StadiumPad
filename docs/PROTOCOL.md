# Observed Stadium connection

Research date: November17,2026. Hardware firmware1.4.2/build1345; installed Mac
editor1.4.0.20. This is an observational interoperability record, not an official API.
Private traces, device identifiers, addresses and preset content stay outside Git.

## Discovery and transport

Bonjour advertises `_stadiumserver._tcp` with update port2001. Command connection
uses the adjacent port2002. The independent Swift reader uses two TCP connections,
64-byte ZMTP3 NULL greetings, READY metadata and data-frame subscription `[01]`.

**New local verification:** firmware1.4.2 identifies the update peer as **PUB**, not
ROUTER as the community overview describes. The command peer identifies as ROUTER.
Accept only supported roles; do not assume every firmware matches the overview.
Both short and long frames are observed/handled. Publisher sequence watermarks are
separate multipart frames; they are not a fixed12-byte OSC header. The parser
preserves frame boundaries across fragmented/combined TCP receives and rejects
frames over16MiB. Each network operation has a bounded timeout and closed-peer path.

## Read-only application messages

| Request | Expected reply | Data |
| --- | --- | --- |
| `/ProductInfoGet` | `/getProductInfo` | MessagePack device info |
| `/EditBufferStateGet` | `/getEditBufferState` | edit-buffer MessagePack |
| `/PropertyValueGet` for `server.active.preset.id` | `/getPropertyValue` | active content reference |
| `/GetContentRef` | `/GetContentRef` | preset name/reference |
| `/ActiveSnapshotIndexGet` | `/getActiveSnapshotIndex` | zero-based snapshot index |

Every request is correlated by command ID. Stale replies cannot satisfy a new read.
Snapshot assembly checks preset and snapshot before/after a full read, retrying
when they change, instead of combining a new preset label with an old signal graph.
Parameter edits within a read are live observations, not an atomic hardware lock.

Observed blobs use either bare MessagePack, `lavppgsm` (property envelope), `slvppgsm` (property-list envelope), or
`_sbepgsm` (edit-buffer envelope). The decoder recognizes only those envelopes:
trying arbitrary byte offsets can mistakenly accept a truncated message's tail.
Integer four-character keys are normalized to text. Arrays/maps, signed numbers,
booleans, binary fields, strings and floating-point values are bounded/validated.

## Updates and confirmation

The native reader received real `/heartbeat` messages on port2001. The owner's
manual parameter change was independently confirmed in a subsequent full state
read (8 to5). We did not capture that particular edit's push event at its instant;
that must not be described as a verified parameter-push test. The iPad refreshes
full state every750milliseconds and separately verifies the publisher connection.

## Limits

No passive tcpdump/Wireshark capture of the official application yet: BPF requires
administrator access not available noninteractively. Byte transcripts represent
only our own client's exchange. We did not change macOS capture permissions.
No PIN-required handshake, firmware writes, transport control,
proprietary model extraction redistribution or unsupported hardware limits tested.

References: [community technical details](https://github.com/Vheissu/helix-stadium-tools/blob/dad97d3a2011290f7f6630d04cc1a819cc58752b/docs/TECHNICAL_DETAILS.md),
[ZMTP specification](https://rfc.zeromq.org/spec/23/),
[OSC specification](https://opensoundcontrol.stanford.edu/spec-1_0.html),
[MessagePack specification](https://github.com/msgpack/msgpack/blob/master/spec.md).

## Editing and saving (0.2.0)

Observed on firmware 1.4.2 using two newly allocated User spares only:

- Parameter addressing is **flow + visible position + model slot**. Internal
  `id__` differs and is retained only as an additional stale-context check.
  Sending internal IDs failed; do not substitute them for visible positions.
- `/ParamValueSet`: `[cmd, flow, position, slot, parameter, value, -1]`.
  Floats use OSC `f`, enumerated integers `i`, booleans `T`/`F`.
  The older reference Python wrapper's boolean-as-integer path did not work here.
- `/HarnessParamValueSet`: `[cmd, flow, position, parameter, value, -1]`;
  harness/model numeric IDs can overlap and must remain distinct.
- Whole-preset save is `/SavePresetWithCID ,iiii [cmd, contentID, -1, -1]`.
  The older reference Python wrapper omits selectors; do not copy that shape.
- `/LoadPresetWithCID [cmd, contentID]` requires acknowledgement and active-ID
  readback. The app blocks ordinary loading when the current preset is dirty.
- `/CreateContent [cmd, -2, emptyPosition, 2, attributesBlob]` allocates a User
  preset. Its `/status [cmd, allocatedID, result]` differs from ordinary
  `/status [cmd, 0, result]`. Verify the allocated reference before storing.
- `/SetContentData [cmd, newID, rawPresetBytes]` is limited by this client to a
  just-allocated ID. Copy the exact `_sbepgsm` body and verify byte equality;
  decoding/re-encoding normalized FourCC keys would alter the native body.

Transactions serialize polling and edits. Writes check fresh identities and old
values, retain backups and send once. Save checks clean state and all model/harness
parameters in stored content. These checks cannot lock out concurrent physical
controls; stop other editing while saving. Errors never produce a saved message.


## Performance and folder observations (0.5.0)

`/setSelectedBlock` has four integer fields; its final two are zero-based flow and
visible block position. Coalesced refresh obtains matching state before publishing
focus. The update stream triggers refresh; 750ms polling provides a fallback.

`/ModelSet [cmd, flow, position, slot, modelID]` is backed up and read back. Output
changes are limited to output blocks; path-2 self-routing destinations are refused.
`/activateSnapshot [cmd, index, 0]` is send-only and confirmed by actual active index.
`/CopySnapshot [cmd, source, emptyTarget]` needs ACK and defined-scene readback.

`/ControllerValueSet [cmd, controllerID, Float32(0 or 1)]` drives validated actual
controller targets. Sources/controllers/targets come from cg__.entt. Bypass
endpoints invert native bypass values into enabled-state values. Timing fields may
be integer or floating zero; do not reject Float32 zero as a timed assignment.
Do not infer MIDI/command behavior from a changed effect's bypass.

Container -5 lists setlists (type1003); each positive setlist container contains
reference records (type1) with rcid pointing to the actual preset. Resolve rcid
for recall. The reference's cid_ is not itself a type2 preset and is never a Save
destination. Main libraries use -1 Factory and -2 User; other read-only inventories
are documented in the code.

Tuner events use `/PropertyValueSet [cmd, 0, propertyBlob]`. The blob is lavppgsm
plus a MessagePack map with numeric FourCC key_,type,val_ keys. Known open event:
volatile.held.taptempo, type i, value11; exit: volatile.press.exittuner, type i,
value11. These event ACKs do not expose an active-state or note/cents meter. Known
global.tuner.* properties contain settings, not live pitch readings.
