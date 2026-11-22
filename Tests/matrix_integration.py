"""Matrix MIDI transaction confirmation against a loopback peer, never hardware."""
import copy,os,struct,subprocess,tempfile,threading,time,unittest
from pathlib import Path
import msgpack
from integration_peer import Peer,exact,receive,ready,frame,osc,message
BINARY=Path(os.environ.get('STADIUM_EDIT_CHECK',str(Path(__file__).resolve().parents[1]/'.build/debug/stadium-edit-check')))
class MatrixPeer(Peer):
 def __init__(self,mode,console=False):
  self.console=console
  self.reads=0;self.midi_reads=0;self.broadcasts=[];self.broadcast_lock=threading.Lock()
  self.matrix={'lom_':0,'atto':3,'lyrs':[{'out_':{'dst_':i,'vol_':-20.},'home':{'mix_':{'src_':5,'vol_':0.},'chan':[{'src_':1,'vol_':0.} ]},'song':{'vol_':-6.}} for i in [1,2,3]]}
  if console:
   def row(source):return {'src_':source,'name':f'Channel {source}','enbl':-1,'vol_':0.,'pan_':0.,'mute':False,'solo':False,'unknown':123}
   self.matrix={'lom_':0,'atto':3,'lyrs':[{'out_':{'dst_':i,'vol_':-20.},'home':{'mix_':row(5),'chan':[row(x) for x in range(1,5)]},'song':{'mix_':row(14),'chan':[row(x) for x in range(6,14)]},**{k:row(x) for k,x in [('clik',15),('cntn',16),('usbn',17),('bt__',18),('auxn',19)]}} for i in [1,2,3]]}
  if console=='clear':
   self.matrix['lyrs'][0]['home']['mix_']['solo']=True
   self.matrix['lyrs'][0]['song']['mix_']['solo']=True
  super().__init__(mode)
 def serve(self,listener,index):
  try:
   c,_=listener.accept();self.sockets.append(c);c.settimeout(8);greeting=exact(c,64);c.sendall(greeting);receive(c);c.sendall(ready('PUB' if index==0 else 'ROUTER'))
   if index==0:
    receive(c)
    while not self.closed:
     with self.broadcast_lock:
      now=time.monotonic();pending=[packet for at,packet in self.broadcasts if at<=now];self.broadcasts=[(at,packet) for at,packet in self.broadcasts if at>now]
     for packet in pending:c.sendall(packet)
     threading.Event().wait(.01)
    return
   while not self.closed:
    _,data=receive(c);a,v=message(data);self.sent.append(a);rid=v[0]
    if a=='/ProductInfoGet':reply='/getProductInfo';values=[rid,msgpack.packb({'host':{'vers':{'majo':1,'mino':4,'patc':2}}})]
    elif a=='/EditBufferStateGet':reply='/getEditBufferState';values=[rid,0,b'_sbepgsm'+msgpack.packb({'sfg_':{'flow':[]}})]
    elif a=='/GetContentRef':reply=a;values=[rid,msgpack.packb({'cid_':7,'name':'Synthetic'})]
    elif a=='/ActiveSnapshotIndexGet':reply='/getActiveSnapshotIndex';values=[rid,0]
    elif a=='/MatchingPropertyValuesGet':
     self.midi_reads+=1
     if self.console=='panel' and self.mode not in ['no-change','route-conflict']:
      output=2 if self.midi_reads==1 else 1
      if self.mode=='wrong-output':output=3
      with self.broadcast_lock:self.broadcasts.append((time.monotonic()+.06,frame(struct.pack('>Q',2**40),1)+frame(osc('/syncMixAttachedOut',[8,-1,output]))))
     if self.console!='panel' and self.midi_reads==2 and self.mode not in ['no-change','stale','shared','linked']:
      with self.broadcast_lock:
       if self.console=='clear':
        for source in ([5] if self.mode=='partial' else [5,14]):
         self.broadcasts.append((time.monotonic()+.06,frame(struct.pack('>Q',2**40),1)+frame(osc('/syncMixChannelSolo',[8,-1,3 if self.mode=='wrong-output' else 1,source,0]))))
       else:self.broadcasts.append((time.monotonic()+.06,frame(struct.pack('>Q',2**40),1)+frame(osc('/syncMixChannelMute' if self.console=='mute' else '/syncMixChannelPan' if self.console else '/syncMixChannelVolume',[8,-1,3 if self.mode=='wrong-output' else 1,14 if self.console else 5,1 if self.console=='mute' else -1 if self.console=='endpoints' else -32/63 if self.console else -.5]))))
     reply='/getMatchingPropertyValues';rows=[{'key_':'global.midi.'+k,'val_':x} for k,x in [('channel',3 if self.mode=='route-conflict' else 1),('bcchannel',2),('over.usb.c',1),('matrix.ch.qtr',3),('matrix.ch.xlr',4),('matrix.ch.phones',4 if self.mode=='shared' else 5)]]
     values=[rid,v[1],b'lavppgsm'+msgpack.packb({'vals':rows})]
    elif a=='/PropertyValueGet':
     reply='/getPropertyValue';key=v[1]
     if key=='server.mixer.state':
      self.reads+=1
      if self.mode=='stale' and self.reads==2:self.matrix['lyrs'][0]['home']['mix_']['vol_']=-2.
      if self.mode=='linked':self.matrix['lom_']=3
      if self.reads>=3 and self.mode not in ['no-change','stale','shared','linked']:
       if self.mode=='unrelated':self.matrix['lyrs'][1]['song']['unexpected']=True
      value=self.matrix
     else:value=False if key=='volatile.preset.edited' else 7
     values=[rid,key,b'lavppgsm'+msgpack.packb({'key_':key,'val_':copy.deepcopy(value)}),0]
    else:raise AssertionError('Unexpected wire write '+a)
    c.sendall(frame(osc(reply,values)))
  except (EOFError,OSError):pass
  except Exception as error:self.errors.append(str(error))
class MatrixTransactions(unittest.TestCase):
 def run_mode(self,mode,success):
  peer=MatrixPeer(mode)
  try:
   with tempfile.TemporaryDirectory() as folder:
    r=subprocess.run([str(BINARY),'--host','127.0.0.1','--port',str(peer.port),'--plan',folder+'/plan','--backups',folder,'--matrix-transaction-check'],capture_output=True,text=True,timeout=10)
   self.assertEqual(peer.errors,[])
   self.assertEqual(r.returncode==0,success,r.stdout+r.stderr)
   self.assertFalse(any('Set' in a or a.startswith('/sync') for a in peer.sent))
   return r
  finally:peer.close()
 def test_confirmed_change_preserves_other_mix_settings(self):self.run_mode('normal',True)
 def test_unchanged_readback_is_not_success(self):self.run_mode('no-change',False)
 def test_stale_context_is_rejected(self):self.run_mode('stale',False)
 def test_shared_channels_refused(self):self.run_mode('shared',False)
 def test_linked_outputs_refused(self):self.run_mode('linked',False)
 def test_unrelated_changed_field_is_not_success(self):self.run_mode('unrelated',False)
 def test_other_output_event_cannot_confirm_our_command(self):self.run_mode('wrong-output',False)
class ConsoleTransactions(unittest.TestCase):
 def run_mode(self,mode,console,success):
  peer=MatrixPeer(mode,console=console)
  try:
   with tempfile.TemporaryDirectory() as folder:
    args=[str(BINARY),'--host','127.0.0.1','--port',str(peer.port),'--plan',folder+'/plan','--backups',folder,'--matrix-clear-check' if console=='clear' else '--matrix-console-check']
    if console=='mute':args+=['--console-mute']
    if console=='invalidated':args+=['--console-invalidated-noop']
    if console=='endpoints':args+=['--console-equivalent-pan']
    r=subprocess.run(args,capture_output=True,text=True,timeout=10)
   self.assertEqual(peer.errors,[]);self.assertEqual(r.returncode==0,success,r.stdout+r.stderr)
   self.assertFalse(any('Set' in a or a.startswith('/sync') for a in peer.sent))
  finally:peer.close()
 def test_confirmed_equivalent_pan_endpoint_does_not_require_a_new_echo(self):self.run_mode('normal','endpoints',True)
 def test_uncertain_send_invalidates_previous_noop_receipt(self):self.run_mode('normal','invalidated',True)
 def test_pan_confirmed_by_live_event_with_stale_bulk(self):self.run_mode('normal','pan',True)
 def test_mute_toggle_confirmed_by_live_event(self):self.run_mode('normal','mute',True)
 def test_missing_toggle_receipt_is_not_retried(self):self.run_mode('no-change','mute',False)
 def test_wrong_output_cannot_confirm(self):self.run_mode('wrong-output','pan',False)
 def test_unrelated_unknown_field_is_preserved(self):self.run_mode('unrelated','pan',False)
 def test_shared_channels_rejected(self):self.run_mode('shared','pan',False)
class ClearSoloTransactions(unittest.TestCase):
 run_mode=ConsoleTransactions.run_mode
 def test_clear_all_requires_live_off_for_each_active_strip(self):self.run_mode('normal','clear',True)
 def test_partial_clear_does_not_claim_success(self):self.run_mode('partial','clear',False)
 def test_clear_without_event_is_not_confirmed(self):self.run_mode('no-change','clear',False)
 def test_clear_other_output_is_rejected(self):self.run_mode('wrong-output','clear',False)
 def test_clear_preserves_unrelated_unknown_fields(self):self.run_mode('unrelated','clear',False)
 def test_clear_shared_channels_are_rejected(self):self.run_mode('shared','clear',False)
 def test_clear_linked_outputs_are_rejected(self):self.run_mode('linked','clear',False)
if __name__=='__main__':unittest.main()

class PanelNavigationTransactions(unittest.TestCase):
 def run_panel(self,mode,success,sends):
  peer=MatrixPeer(mode,console='panel')
  try:
   with tempfile.TemporaryDirectory() as folder:
    r=subprocess.run([str(BINARY),'--host','127.0.0.1','--port',str(peer.port),'--plan',folder+'/plan','--backups',folder,'--matrix-panel-check'],capture_output=True,text=True,timeout=10)
   self.assertEqual(peer.errors,[])
   self.assertEqual(r.returncode==0,success,r.stdout+r.stderr)
   self.assertEqual(r.stdout.count('PANEL SEND'),sends,r.stdout+r.stderr)
   self.assertFalse(any('Set' in a or a.startswith('/sync') for a in peer.sent))
  finally:peer.close()
 def test_both_distinct_outputs_require_fresh_receipts(self):self.run_panel('normal',True,2)
 def test_missing_first_receipt_stops_without_retry_or_second_send(self):self.run_panel('no-change',False,1)
 def test_other_output_receipt_does_not_allow_second_send(self):self.run_panel('wrong-output',False,1)
 def test_conflicting_global_channel_blocks_all_sends(self):self.run_panel('route-conflict',False,0)
