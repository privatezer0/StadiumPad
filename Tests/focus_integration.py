"""Synthetic multi-parameter Focus transactions; no physical devices or presets."""
import copy,json,os,struct,subprocess,tempfile,threading,unittest
from pathlib import Path
import msgpack
from integration_peer import Peer,exact,receive,ready,frame,osc,message
BINARY=Path(os.environ['STADIUM_EDIT_CHECK'])
class FocusPeer(Peer):
 def __init__(self,mode):
  self.active=11;self.dirty=False;self.live={1:struct.unpack('>f',struct.pack('>f',0.4))[0],2:False,3:1};self.stored={11:dict(self.live),12:dict(self.live)};self.reads=0
  super().__init__(mode)
 def reference(self,cid):return {'cid_':cid,'ccid':-2,'posi':267 if cid==11 else 268,'name':'iPad Edit Test 1117' if cid==11 else 'iPad Reload Check 1117','type':2}
 def edit(self,v):return {'sfg_':{'flow':[{'blks':[7,{'id__':3,'enbl':1,'mdls':[{'id__':99 if self.mode=='stale' and self.reads>=2 else 42,'parm':[{'pid_':p,'valu':n} for p,n in v.items()]}]}]}]}}
 def serve(self,listener,index):
  try:
   c,_=listener.accept();self.sockets.append(c);c.settimeout(8);c.sendall(exact(c,64));receive(c);c.sendall(ready('PUB' if index==0 else 'ROUTER'))
   if index==0:
    receive(c)
    while not self.closed:
     try:c.sendall(frame(struct.pack('>Q',2**40),1)+frame(osc('/heartbeat',[1,2,3])))
     except OSError:break
     threading.Event().wait(.1)
    return
   while not self.closed:
    _,data=receive(c);address,v=message(data);self.sent.append((address,v));cid=v[0];reply=address
    if address=='/ProductInfoGet':reply='/getProductInfo';args=[cid,msgpack.packb({})]
    elif address=='/PropertyValueGet':reply='/getPropertyValue';args=[cid,0,b'lavppgsm'+msgpack.packb({'val_':self.dirty if v[1]=='volatile.preset.edited' else self.active})]
    elif address=='/ActiveSnapshotIndexGet':reply='/getActiveSnapshotIndex';args=[cid,0]
    elif address=='/EditBufferStateGet':self.reads+=1;reply='/getEditBufferState';args=[cid,0,b'_sbepgsm'+msgpack.packb(self.edit(self.live))]
    elif address=='/GetContentRef':args=[cid,msgpack.packb(self.reference(v[1]))]
    elif address=='/GetContentData':args=[cid,b'_sbepgsm'+msgpack.packb(self.edit(self.stored[v[1]]))]
    elif address=='/ParamValueSet':
     assert v[1:4]==[0,7,0],v
     if self.mode=='timeout':threading.Event().wait(6);return
     reject=self.mode=='rejected' or (self.mode=='reject-second' and sum(a=='/ParamValueSet' for a,_ in self.sent)==2)
     reply='/status';args=[cid,-1 if reject else 0,1]
     if not reject and self.mode!='wrong':self.live[v[4]]=v[5];self.dirty=True
     if self.mode=='switch':self.active=999
    elif address=='/SavePresetWithCID':assert v[1:]==[11,-1,-1];self.stored[11]=dict(self.live);self.dirty=False;reply='/status';args=[cid,0,1]
    elif address=='/LoadPresetWithCID':assert not self.dirty;self.active=v[1];self.live=dict(self.stored[self.active]);reply='/status';args=[cid,0,1]
    else:raise AssertionError(address)
    c.sendall(frame(osc(reply,args)))
  except (EOFError,OSError):pass
  except BaseException as e:self.errors.append(repr(e))
class FocusIntegration(unittest.TestCase):
 def run_check(self,mode):
  peer=FocusPeer(mode)
  try:
   with tempfile.TemporaryDirectory(dir=os.environ.get('STADIUM_TEST_ROOT')) as td:
    root=Path(td)
    def spare(cid):return {'preset':{'contentID':cid,'container':-2,'position':267 if cid==11 else 268,'name':peer.reference(cid)['name'],'type':2},'sourceID':9,'sourceSnapshot':0,'sourceHash':'synthetic'}
    (root/'plan.json').write_text(json.dumps({'first':spare(11),'second':spare(12)}))
    params=[dict(id=i,key=str(i),name=str(i),type=t,minimum=0,maximum=m,unit='',harness=False) for i,t,m in [(1,'f',1),(2,'b',1),(3,'i',3)]]
    (root/'catalog.json').write_text(json.dumps({'42':dict(id=42,name='Synthetic Focus',parameters=params)}))
    r=subprocess.run([str(BINARY),'--host','127.0.0.1','--port',str(peer.port),'--plan',str(root/'plan.json'),'--catalog',str(root/'catalog.json'),'--backups',str(root/'backups'),'--focus-check'],capture_output=True,text=True,timeout=25)
   return r,peer.sent,peer.errors,peer.stored
  finally:peer.close()
 def test_batch_save_reload_restore_discrete_before_float(self):
  r,s,e,stored=self.run_check('normal');self.assertEqual(e,[]);self.assertEqual(r.returncode,0,r.stderr);self.assertIn('PASS Focus',r.stdout)
  self.assertEqual([v[4] for a,v in s if a=='/ParamValueSet'],[2,3,1,2,3,1]);self.assertAlmostEqual(stored[11][1],0.4,places=6);self.assertEqual(stored[11][2],False);self.assertEqual(stored[11][3],1)
 def test_stale_model_sends_no_writes(self):self.failure('stale',0)
 def test_rejected_batch_stops_without_save(self):self.failure('rejected',1)
 def test_changed_preset_stops_before_next_parameter(self):self.failure('switch',1)
 def test_partial_rejection_stops_without_saving(self):self.failure('reject-second',2)
 def test_timeout_never_retries(self):self.failure('timeout',1)
 def test_ack_without_values_never_saves(self):self.failure('wrong',3)
 def failure(self,mode,writes):
  r,s,e,_=self.run_check(mode);self.assertEqual(e,[]);self.assertNotEqual(r.returncode,0);self.assertEqual(sum(a=='/ParamValueSet' for a,_ in s),writes);self.assertFalse(any(a=='/SavePresetWithCID' for a,_ in s))
if __name__=='__main__':unittest.main()
