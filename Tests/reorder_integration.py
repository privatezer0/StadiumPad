"""Loopback-only block reorder, observed-move and persistence transaction tests."""
import hashlib,json,os,struct,subprocess,tempfile,threading,unittest
from pathlib import Path
import msgpack
from integration_peer import Peer,exact,receive,ready,frame,osc,message
BINARY=Path(os.environ.get('STADIUM_EDIT_CHECK',str(Path(__file__).resolve().parents[1]/'.build/debug/stadium-edit-check')))
class ReorderPeer(Peer):
 def __init__(self,mode):
  self.active=11;self.model=0;self.stored={11:0,12:0};self.snapshot_index=0;self.dirty=False;self.reads=0
  super().__init__(mode)
  if mode=='manual':self.model=1;self.dirty=True
 def state(self,model):
  def block(i,m,v):return {'id__':i,'enbl':1,'mdls':[{'id__':m,'parm':[{'pid_':1,'valu':v}]}]}
  return {'cg__':{'asnp':0,'entt':{'snps':[{'si__':0,'name':'Clean','vald':True}]}},'sfg_':{'flow':[{'blks':[7 if model==1 else 5,block(3,42 if model!=99 else 99,0.4),5 if model==1 else 6,block(4,43,0.2)]}]}}
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
    elif address=='/GetContentRef':args=[cid,msgpack.packb({'cid_':values[1],'ccid':-2,'type':2,'posi':267 if values[1]==11 else 268,'name':('StadiumPad Move Test' if values[1]==11 else 'StadiumPad Move Preserve') if self.mode=='manual' else ('iPad Edit Test 1117' if values[1]==11 else 'iPad Reload Check 1117')})]
    elif address=='/GetContentData':args=[cid,b'_sbepgsm'+msgpack.packb(self.state(self.stored[values[1]]))]
    elif address=='/ActiveSnapshotIndexGet':reply='/getActiveSnapshotIndex';args=[cid,self.snapshot_index]
    elif address=='/doAgenda':
     commands=msgpack.unpackb(values[1]);expected=[{'cmnd':0x73776170,'flow':0,'blk0':p,'blk1':p+(1 if self.model==0 else -1)} for p in ([5,6] if self.model==0 else [7,6])]
     assert commands==expected,(commands,expected)
     if self.mode=='timeout':threading.Event().wait(6);return
     reply='/status';args=[cid,-1 if self.mode=='rejected' else 1,1]
     if self.mode not in ['rejected','wrong-readback']:self.model=1-self.model;self.dirty=True
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
class ReorderTests(unittest.TestCase):
 def run_check(self,mode,bad_hash=False):
  peer=ReorderPeer(mode)
  with tempfile.TemporaryDirectory(dir=os.environ.get('STADIUM_TEST_ROOT')) as td:
   root=Path(td);plan=root/'plan.json';catalog=root/'catalog.json'
   def copy(cid,pos,name):return {'preset':{'contentID':cid,'container':-2,'position':pos,'name':name,'type':2},'sourceID':9,'sourceSnapshot':0,'sourceHash':'synthetic'}
   if mode=='manual':
    test=copy(11,267,'StadiumPad Move Test');test['sourceID']=12
    test['sourceHash']='wrong' if bad_hash else hashlib.sha256(b'_sbepgsm'+msgpack.packb(peer.state(0))).hexdigest()
    plan.write_text(json.dumps({'test':test,'preserved':copy(12,268,'StadiumPad Move Preserve')}))
   else:plan.write_text(json.dumps({'first':copy(11,267,'iPad Edit Test 1117'),'second':copy(12,268,'iPad Reload Check 1117')}))
   catalog.write_text(json.dumps({str(i):{'id':i,'name':n,'category':cat,'parameters':[]} for i,n,cat in [(42,'Original Room','reverb'),(43,'Simple Delay','delay')]}))
   result=subprocess.run([str(BINARY),'--host','127.0.0.1','--port',str(peer.port),'--plan',str(plan),'--catalog',str(catalog),'--backups',str(root/'backups'),*(['--reorder-resume','--source-position','5','--destination','7'] if mode=='manual' else ['--reorder-check'])],capture_output=True,text=True,timeout=20)
  peer.close();return result,peer.sent,peer.errors
 def test_observed_manual_drag_is_saved_without_replaying_forward_move(self):
  result,sent,errors=self.run_check('manual');self.assertEqual(errors,[]);self.assertEqual(result.returncode,0,result.stderr)
  self.assertIn('Confirmed previous move',result.stdout)
  self.assertEqual(sum(a=='/doAgenda' for a,_ in sent),1) # reverse only
 def test_manual_drag_with_unreviewed_saved_bytes_sends_no_writes(self):
  result,sent,errors=self.run_check('manual',bad_hash=True);self.assertEqual(errors,[]);self.assertNotEqual(result.returncode,0)
  self.assertFalse(any(a in ['/doAgenda','/SavePresetWithCID','/LoadPresetWithCID'] for a,_ in sent))
 def test_reorder_save_reload_restore(self):
  result,sent,errors=self.run_check('normal');self.assertEqual(errors,[]);self.assertEqual(result.returncode,0,result.stderr);self.assertIn('PASS reorder/save/reload/restore',result.stdout)
  self.assertEqual(sum(a=='/doAgenda' for a,_ in sent),2)
 def test_rejected_reorder_is_not_saved(self):self.check_failure('rejected',1)
 def test_timeout_reorder_is_not_retried_or_saved(self):self.check_failure('timeout',1)
 def test_stale_source_sends_no_reorder(self):self.check_failure('stale',0)
 def test_ack_without_reordered_blocks_is_not_saved(self):self.check_failure('wrong-readback',1)
 def check_failure(self,mode,writes):
  result,sent,errors=self.run_check(mode);self.assertEqual(errors,[]);self.assertNotEqual(result.returncode,0);self.assertEqual(sum(a=='/doAgenda' for a,_ in sent),writes);self.assertFalse(any(a=='/SavePresetWithCID' for a,_ in sent))
if __name__=='__main__':unittest.main()
