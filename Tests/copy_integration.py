"""Fault-injection for new spare copies. Original stored bytes must never change."""
import json,socket,struct,subprocess,tempfile,threading,unittest
from pathlib import Path
import msgpack
from integration_peer import Peer,exact,receive,ready,frame,osc,message
from editing_integration import BINARY
class CopyPeer(Peer):
 def __init__(self,mode):
  self.active=11;self.dirty=True;self.live=0.6;self.records={11:dict(cid_=11,ccid=-2,posi=267,name='Original',type=2)};self.saved={11:self.body(0.4)};self.containers=0;self.created=[]
  super().__init__(mode)
 def body(self,n):return b'_sbepgsm'+msgpack.packb({'sfg_':{'flow':[{'blks':[7,{'id__':3,'enbl':1,'mdls':[{'id__':42,'parm':[{'pid_':1,'valu':n}]}]}]}]}})
 def slots(self):
  occupied={r['posi']:r for r in self.records.values()};out=[]
  for n in range(512):out.append(occupied.get(n,dict(ccid=-2,posi=n,cid_=0)))
  if self.mode=='occupied' and self.containers>=2:out[0]=dict(ccid=-2,posi=0,cid_=99)
  return out
 def serve(self,listener,index):
  try:
   c,_=listener.accept();self.sockets.append(c);c.settimeout(8);g=exact(c,64);c.sendall(g);receive(c);c.sendall(ready('PUB' if index==0 else 'ROUTER'))
   if index==0:
    receive(c)
    while not self.closed:
     try:c.sendall(frame(struct.pack('>Q',1),1)+frame(osc('/heartbeat',[1,2,3])))
     except OSError:break
     threading.Event().wait(.1)
    return
   while not self.closed:
    _,data=receive(c);address,v=message(data);self.sent.append((address,v));cid=v[0];reply=address
    if address=='/ProductInfoGet':reply='/getProductInfo';values=[cid,msgpack.packb({'host':{'vers':{'majo':1,'mino':4,'patc':2}}})]
    elif address=='/PropertyValueGet':reply='/getPropertyValue';values=[cid,0,b'lavppgsm'+msgpack.packb({'val_':self.dirty if v[1]=='volatile.preset.edited' else self.active})]
    elif address=='/EditBufferStateGet':reply='/getEditBufferState';values=[cid,0,self.body(self.live)]
    elif address=='/GetContentRef':values=[cid,msgpack.packb(self.records[v[1]])]
    elif address=='/GetContentData':values=[cid,self.saved[v[1]]]
    elif address=='/ActiveSnapshotIndexGet':reply='/getActiveSnapshotIndex';values=[cid,0]
    elif address=='/GetContainerContents':self.containers+=1;values=[cid,msgpack.packb(self.slots())]
    elif address=='/CreateContent':
     assert v[1]==-2 and v[3]==2
     position=v[2];assert not any(r['posi']==position for r in self.records.values())
     attrs=msgpack.unpackb(v[4]);new=50+len(self.created);self.records[new]=dict(cid_=new,ccid=-2,posi=position,name=attrs['name'],type=2);self.created.append(new)
     if self.mode=='create-timeout':threading.Event().wait(6);return
     reply='/status';values=[cid,11 if self.mode=='wrong-id' else new,1]
    elif address=='/SetContentData':
     assert v[1] in self.created and v[1]!=11
     self.saved[v[1]]=self.body(0.61) if self.mode=='corrupt-copy' else v[2];reply='/status';values=[cid,0,1]
    elif address=='/LoadPresetWithCID':
     assert v[1] in self.created and self.saved[v[1]]==self.body(self.live)
     self.active=v[1];self.dirty=False;reply='/status';values=[cid,0,0]
    else:raise AssertionError('Unexpected '+address)
    c.sendall(frame(osc(reply,values)))
  except (OSError,EOFError):pass
  except Exception as e:self.errors.append(str(e))
class CopyIntegration(unittest.TestCase):
 def run_copy(self,mode):
  peer=CopyPeer(mode);before=peer.saved[11]
  try:
   with tempfile.TemporaryDirectory() as d:
    r=subprocess.run([str(BINARY),'--host','127.0.0.1','--port',str(peer.port),'--plan',str(Path(d)/'plan.json'),'--backups',str(Path(d)/'backup'),'--prepare'],capture_output=True,text=True,timeout=15)
    self.assertEqual(peer.saved[11],before);self.assertEqual(peer.errors,[])
    return r,peer.sent,peer.active,peer.created,peer.saved
  finally:peer.close()
 def test_unsaved_live_state_copied_to_two_empty_slots_and_original_untouched(self):
  r,sent,active,created,saved=self.run_copy('normal');self.assertEqual(r.returncode,0,r.stderr);self.assertEqual(len(created),2);self.assertEqual(active,created[0]);self.assertEqual(saved[created[0]],saved[created[1]])
  self.assertTrue(all(v[1] in created for a,v in sent if a=='/SetContentData'))
 def test_slot_becoming_occupied_blocks_allocation(self):
  r,sent,active,created,_=self.run_copy('occupied');self.assertNotEqual(r.returncode,0);self.assertEqual(created,[]);self.assertEqual(active,11)
 def test_create_timeout_never_retries_or_writes(self):
  r,sent,active,created,_=self.run_copy('create-timeout');self.assertNotEqual(r.returncode,0);self.assertEqual(len(created),1);self.assertFalse(any(a=='/SetContentData' for a,_ in sent));self.assertEqual(active,11)
 def test_existing_id_in_allocation_reply_is_rejected(self):
  r,sent,active,_,_=self.run_copy('wrong-id');self.assertNotEqual(r.returncode,0);self.assertFalse(any(a=='/SetContentData' for a,_ in sent));self.assertEqual(active,11)
 def test_copy_mismatch_does_not_load_or_discard_unsaved_source(self):
  r,sent,active,_,_=self.run_copy('corrupt-copy');self.assertNotEqual(r.returncode,0);self.assertFalse(any(a=='/LoadPresetWithCID' for a,_ in sent));self.assertEqual(active,11)
if __name__=='__main__':unittest.main()
