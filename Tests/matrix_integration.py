"""Matrix MIDI transaction confirmation against a loopback peer, never hardware."""
import copy,os,struct,subprocess,tempfile,threading,time,unittest
from pathlib import Path
import msgpack
from integration_peer import Peer,exact,receive,ready,frame,osc,message
BINARY=Path(os.environ.get('STADIUM_EDIT_CHECK',str(Path(__file__).resolve().parents[1]/'.build/debug/stadium-edit-check')))
class MatrixPeer(Peer):
 def __init__(self,mode):
  self.reads=0;self.midi_reads=0;self.broadcasts=[];self.broadcast_lock=threading.Lock()
  self.matrix={'lom_':0,'atto':3,'lyrs':[{'out_':{'dst_':i,'vol_':-20.},'home':{'mix_':{'src_':5,'vol_':0.},'chan':[{'src_':1,'vol_':0.} ]},'song':{'vol_':-6.}} for i in [1,2,3]]}
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
     if self.midi_reads==2 and self.mode not in ['no-change','stale','shared','linked']:
      with self.broadcast_lock:self.broadcasts.append((time.monotonic()+.06,frame(struct.pack('>Q',2**40),1)+frame(osc('/syncMixChannelVolume',[8,-1,3 if self.mode=='wrong-output' else 1,5,-.5]))))
     reply='/getMatchingPropertyValues';rows=[{'key_':'global.midi.'+k,'val_':x} for k,x in [('channel',1),('bcchannel',2),('over.usb.c',1),('matrix.ch.qtr',3),('matrix.ch.xlr',4),('matrix.ch.phones',4 if self.mode=='shared' else 5)]]
     values=[rid,v[1],b'lavppgsm'+msgpack.packb({'vals':rows})]
    elif a=='/PropertyValueGet':
     reply='/getPropertyValue';key=v[1]
     if key=='server.mixer.state':
      self.reads+=1
      if self.mode=='stale' and self.reads==2:self.matrix['lyrs'][0]['home']['mix_']['vol_']=-2.
      if self.mode=='linked':self.matrix['lom_']=3
      if self.reads>=3 and self.mode not in ['no-change','stale','shared','linked']:
       if self.mode=='unrelated':self.matrix['lyrs'][1]['song']['vol_']=-12.
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
if __name__=='__main__':unittest.main()
