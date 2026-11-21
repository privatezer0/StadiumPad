"""Global EQ hardware transactions against a synthetic local peer, never a pedal."""
import copy,os,struct,subprocess,tempfile,threading,unittest
from pathlib import Path
import msgpack
from integration_peer import Peer,exact,receive,ready,frame,osc,message
BINARY=Path(os.environ.get('STADIUM_EDIT_CHECK',str(Path(__file__).resolve().parents[1]/'.build/debug/stadium-edit-check')))
def norm(value):
 if isinstance(value,dict):return {(k.to_bytes(4,'big').decode() if isinstance(k,int) else k):norm(v) for k,v in value.items()}
 if isinstance(value,list):return list(map(norm,value))
 return value
def initial():
 root={'anyl':0,'post':0}
 for key,index in [('_qtr',0),('_xlr',1),('_pho',2)]:
  bands=[]
  for band,f in enumerate([20.,80.,150.,2000.,5000.,8000.,20000.]):
   params=[{'parm':1,'valu':True},{'parm':2,'valu':f}]
   params += [{'parm':5,'valu':1}] if band in [0,6] else [{'parm':3,'valu':0.}]
   if band in [2,3,4]:params.append({'parm':4,'valu':0.7070000171661377})
   bands.append({'band':band,'para':params})
  root[key]={'out_':index,'enab':False,'drty':False,'eqbs':bands,'olvl':{'parm':3,'valu':0.}}
 return root
class EQPeer(Peer):
 def __init__(self,mode):self.eq=initial();self.eq_reads=0;self.live=False;super().__init__(mode)
 def serve(self,listener,index):
  try:
   c,_=listener.accept();self.sockets.append(c);c.settimeout(8);greeting=exact(c,64);c.sendall(greeting);receive(c);c.sendall(ready('PUB' if index==0 else 'ROUTER'))
   if index==0:
    receive(c)
    if self.mode=='follow':
     change={'key_':'dsp.globaleq.qtr.mid.gain','type':'v','val_':{'parm':3,'valu':.125}}
     c.sendall(frame(struct.pack('>Q',2**40),1)+frame(osc('/setPropertyValue',[1,2,b'lavppgsm'+msgpack.packb(change)])))
    while not self.closed:
     try:c.sendall(frame(struct.pack('>Q',2**40),1)+frame(osc('/heartbeat',[1,2,3])))
     except OSError:break
     threading.Event().wait(.1)
    return
   while not self.closed:
    _,data=receive(c);address,v=message(data);self.sent.append((address,v));rid=v[0];reply=address
    if address=='/ProductInfoGet':reply='/getProductInfo';args=[rid,msgpack.packb({'host':{'vers':{'majo':1,'mino':4,'patc':2}}})]
    elif address=='/PropertyValueGet':
     reply='/getPropertyValue'
     if v[1]=='global.eq.sync':
      self.eq_reads+=1
      if self.mode=='stale' and self.eq_reads==2:self.eq['_xlr']['enab']=True
      if self.mode=='concurrent-output' and self.live:self.eq['_pho']['enab']=True
      value=copy.deepcopy(self.eq)
      if self.mode=='unknown':value['new_']=1
     else:value=False if v[1]=='volatile.preset.edited' else 50
     args=[rid,v[1],b'lavppgsm'+msgpack.packb({'key_':v[1],'type':'v' if v[1]=='global.eq.sync' else 'i','val_':value}),0]
    elif address=='/EditBufferStateGet':reply='/getEditBufferState';args=[rid,0,b'_sbepgsm'+msgpack.packb({'sfg_':{'flow':[]},'cg__':{'asnp':0}})]
    elif address=='/GetContentRef':args=[rid,msgpack.packb({'cid_':50,'name':'Synthetic EQ'})]
    elif address=='/ActiveSnapshotIndexGet':reply='/getActiveSnapshotIndex';args=[rid,0]
    elif address=='/PropertyValueSet':
     property=norm(msgpack.unpackb(v[2][8:],strict_map_key=False));assert property['type']=='v'
     key=property['key_'];value=property['val_']
     if key=='dsp.globaleq.qtr.mid.gain':
      assert value=={'parm':3,'valu':.125}
      self.live=True
      if self.mode=='timeout':threading.Event().wait(6);return
     elif key=='globals.eq':
      assert self.live,'Native commit before live acknowledgement'
      assert value['_xlr']==self.eq['_xlr'] and value['_pho']==self.eq['_pho'],'Other output overwritten'
      if self.mode!='readback-mismatch':self.eq=value
     else:raise AssertionError('Unsupported write '+key)
     reply='/status';args=[rid,-1 if self.mode=='bad-ack' or (self.mode=='bad-native-commit' and key=='globals.eq') else 0,0]
    else:raise AssertionError('Unexpected request '+address)
    c.sendall(frame(osc(reply,args)))
  except (EOFError,OSError):pass
  except Exception as e:self.errors.append(str(e))
class EQIntegration(unittest.TestCase):
 def run_peer(self,mode):
  peer=EQPeer(mode)
  try:
   with tempfile.TemporaryDirectory() as directory:
    r=subprocess.run([str(BINARY),'--host','127.0.0.1','--port',str(peer.port),'--plan',directory+'/unused','--backups',directory+'/backups','--global-eq-follow-check' if mode=='follow' else '--global-eq-transaction-check'],capture_output=True,text=True,timeout=18)
    writes=[norm(msgpack.unpackb(v[2][8:],strict_map_key=False))['key_'] for a,v in peer.sent if a=='/PropertyValueSet']
    return r,writes,peer.errors
  finally:peer.close()
 def test_desktop_dsp_broadcast_is_visible_despite_stale_global_property(self):
  r,w,e=self.run_peer('follow');self.assertEqual(e,[]);self.assertEqual(r.returncode,0,r.stderr);self.assertEqual(w,[])
 def test_live_then_native_commit_then_device_readback_without_mirror_write(self):
  r,w,e=self.run_peer('normal');self.assertEqual(e,[]);self.assertEqual(r.returncode,0,r.stderr);self.assertEqual(w,['dsp.globaleq.qtr.mid.gain','globals.eq'])
 def test_stale_state_prevents_any_write(self):
  r,w,e=self.run_peer('stale');self.assertEqual(e,[]);self.assertNotEqual(r.returncode,0);self.assertEqual(w,[])
 def test_concurrent_other_output_is_not_overwritten(self):
  r,w,e=self.run_peer('concurrent-output');self.assertEqual(e,[]);self.assertNotEqual(r.returncode,0);self.assertEqual(w,['dsp.globaleq.qtr.mid.gain'])
 def test_unknown_fields_prevent_any_write(self):
  r,w,e=self.run_peer('unknown');self.assertEqual(e,[]);self.assertNotEqual(r.returncode,0);self.assertEqual(w,[])
 def test_negative_ack_never_persists_or_retries(self):
  r,w,e=self.run_peer('bad-ack');self.assertEqual(e,[]);self.assertNotEqual(r.returncode,0);self.assertEqual(w,['dsp.globaleq.qtr.mid.gain'])
 def test_native_commit_failure_stops_before_readback(self):
  r,w,e=self.run_peer('bad-native-commit');self.assertEqual(e,[]);self.assertNotEqual(r.returncode,0);self.assertEqual(w,['dsp.globaleq.qtr.mid.gain','globals.eq'])
 def test_uncertain_live_write_never_persists_or_retries(self):
  r,w,e=self.run_peer('timeout');self.assertEqual(e,[]);self.assertNotEqual(r.returncode,0);self.assertEqual(w,['dsp.globaleq.qtr.mid.gain'])
 def test_ack_alone_cannot_confirm_eq_settings(self):
  r,w,e=self.run_peer('readback-mismatch');self.assertEqual(e,[]);self.assertNotEqual(r.returncode,0);self.assertEqual(w,['dsp.globaleq.qtr.mid.gain','globals.eq'])
if __name__=='__main__':unittest.main()
