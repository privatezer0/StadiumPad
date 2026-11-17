"""Loopback-only model replacement and snapshot transaction tests."""
import json,os,struct,subprocess,tempfile,threading,unittest
from pathlib import Path
import msgpack
from integration_peer import Peer,exact,receive,ready,frame,osc,message
BINARY=Path(os.environ.get('STADIUM_EDIT_CHECK',str(Path(__file__).resolve().parents[1]/'.build/debug/stadium-edit-check')))
class ModelPeer(Peer):
 def __init__(self,mode):
  self.active=11;self.model=42;self.stored={11:42,12:42};self.snapshot_index=0;self.dirty=False;self.reads=0
  super().__init__(mode)
 def state(self,model):return {'cg__':{'entt':{'snps':[{'si__':0,'name':'Clean','vald':True},{'si__':1,'name':'Lead','vald':True}]}},'sfg_':{'flow':[{'blks':[7,{'id__':3,'enbl':1,'mdls':[{'id__':model,'parm':[{'pid_':1,'valu':0.4}]}]}]}]}}
 def serve(self,listener,index):
  try:
   c,_=listener.accept();self.sockets.append(c);c.settimeout(8);greeting=exact(c,64);c.sendall(greeting);receive(c);c.sendall(ready('PUB' if index==0 else 'ROUTER'))
   if index==0:
    receive(c)
    while not self.closed:
     try:c.sendall(frame(struct.pack('>Q',2**40),1)+frame(osc('/heartbeat',[1,2,3])))
     except OSError:break
     threading.Event().wait(.1)
    return
   while not self.closed:
    _,data=receive(c);address,values=message(data);self.sent.append((address,values));cid=values[0];reply=address
    if address=='/ProductInfoGet':reply='/getProductInfo';args=[cid,msgpack.packb({'host':{'vers':{'majo':1,'mino':4,'patc':2}}})]
    elif address=='/PropertyValueGet':reply='/getPropertyValue';args=[cid,0,b'lavppgsm'+msgpack.packb({'val_':self.dirty if values[1]=='volatile.preset.edited' else self.active})]
    elif address=='/EditBufferStateGet':
     self.reads+=1;model=99 if self.mode=='stale' and self.reads>=2 else self.model
     reply='/getEditBufferState';args=[cid,0,b'_sbepgsm'+msgpack.packb(self.state(model))]
    elif address=='/GetContentRef':args=[cid,msgpack.packb({'cid_':values[1],'ccid':-2,'type':2,'posi':267 if values[1]==11 else 268,'name':'iPad Edit Test 1117' if values[1]==11 else 'iPad Reload Check 1117'})]
    elif address=='/GetContentData':args=[cid,b'_sbepgsm'+msgpack.packb(self.state(self.stored[values[1]]))]
    elif address=='/ActiveSnapshotIndexGet':reply='/getActiveSnapshotIndex';args=[cid,self.snapshot_index]
    elif address=='/ModelSet':
     assert values[1:]==[0,7,0,43],values
     if self.mode=='timeout':threading.Event().wait(6);return
     reply='/status';args=[cid,-1 if self.mode=='rejected' else 0,1]
     if self.mode not in ['rejected','wrong-readback']:self.model=43;self.dirty=True
    elif address=='/SavePresetWithCID':
     assert values[1:]==[11,-1,-1];self.stored[11]=self.model;self.dirty=False;reply='/status';args=[cid,0,1]
    elif address=='/LoadPresetWithCID':
     self.active=values[1];self.model=self.stored[self.active];self.dirty=False;reply='/status';args=[cid,0,1]
    elif address=='/activateSnapshot':
     assert values[2]==0 and values[1] in [0,1];self.snapshot_index=values[1];continue
    else:raise AssertionError(address)
    c.sendall(frame(osc(reply,args)))
  except (EOFError,OSError):pass
  except BaseException as error:self.errors.append(repr(error))
class ModelTests(unittest.TestCase):
 def run_check(self,mode):
  peer=ModelPeer(mode)
  with tempfile.TemporaryDirectory(dir=os.environ.get('STADIUM_TEST_ROOT')) as td:
   root=Path(td);plan=root/'plan.json';catalog=root/'catalog.json'
   def copy(cid,pos,name):return {'preset':{'contentID':cid,'container':-2,'position':pos,'name':name,'type':2},'sourceID':9,'sourceSnapshot':0,'sourceHash':'synthetic'}
   plan.write_text(json.dumps({'first':copy(11,267,'iPad Edit Test 1117'),'second':copy(12,268,'iPad Reload Check 1117')}))
   catalog.write_text(json.dumps({str(i):{'id':i,'name':n,'category':cat,'parameters':[]} for i,n,cat in [(42,'Original Room','reverb'),(43,'Simple Delay','delay')]}))
   result=subprocess.run([str(BINARY),'--host','127.0.0.1','--port',str(peer.port),'--plan',str(plan),'--catalog',str(catalog),'--backups',str(root/'backups'),'--replace-check'],capture_output=True,text=True,timeout=20)
  peer.close();return result,peer.sent,peer.errors
 def test_model_save_reload_and_snapshot_selection(self):
  result,sent,errors=self.run_check('normal');self.assertEqual(errors,[]);self.assertEqual(result.returncode,0,result.stderr);self.assertIn('PASS replacement',result.stdout)
  self.assertEqual([v[1] for a,v in sent if a=='/activateSnapshot'],[1,0])
 def test_rejected_model_is_not_saved(self):self.check_failure('rejected',1)
 def test_timeout_model_is_not_retried_or_saved(self):self.check_failure('timeout',1)
 def test_stale_model_sends_no_replacement(self):self.check_failure('stale',0)
 def test_ack_without_changed_model_is_not_saved(self):self.check_failure('wrong-readback',1)
 def check_failure(self,mode,writes):
  result,sent,errors=self.run_check(mode);self.assertEqual(errors,[]);self.assertNotEqual(result.returncode,0);self.assertEqual(sum(a=='/ModelSet' for a,_ in sent),writes);self.assertFalse(any(a=='/SavePresetWithCID' for a,_ in sent))
if __name__=='__main__':unittest.main()
