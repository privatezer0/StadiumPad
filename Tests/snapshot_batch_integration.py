"""Read-only snapshots: out-of-order replies and before/after identity guards."""
import os,select,struct,subprocess,threading,unittest
import msgpack
from integration_peer import Peer,exact,receive,ready,frame,osc,message,BINARY
class BatchPeer(Peer):
 def __init__(self,mode):self.active=7;self.groups=[];self.switched=False;super().__init__(mode)
 def reply(self,address,v):
  rid=v[0]
  if address=='/ProductInfoGet':return '/getProductInfo',[rid,msgpack.packb({'host':{'vers':{'majo':1,'mino':4,'patc':2}}})]
  if address=='/PropertyValueGet':return '/getPropertyValue',[rid,0,b'lavppgsm'+msgpack.packb({'val_':False if v[1]=='volatile.preset.edited' else self.active})]
  if address=='/ActiveSnapshotIndexGet':return '/getActiveSnapshotIndex',[rid,0]
  if address=='/GetContentRef':return '/GetContentRef',[rid,msgpack.packb({'cid_':v[1],'name':'Synthetic'})]
  if address=='/EditBufferStateGet':return '/getEditBufferState',[rid,0,b'_sbepgsm'+msgpack.packb({'sfg_':{'flow':[]}})]
  raise AssertionError('Unexpected or mutating request')
 def serve(self,listener,index):
  try:
   c,_=listener.accept();self.sockets.append(c);c.settimeout(8)
   greeting=exact(c,64);c.sendall(greeting);receive(c);c.sendall(ready('PUB' if index==0 else 'ROUTER'))
   if index==0:
    receive(c)
    while not self.closed:threading.Event().wait(.02)
    return
   while not self.closed:
    group=[message(receive(c)[1])]
    while select.select([c],[],[],.01)[0]:group.append(message(receive(c)[1]))
    self.groups.append(len(group));self.sent.extend(a for a,v in group)
    replies=[self.reply(a,v) for a,v in group]
    if self.mode=='switch' and len(group)>1 and any(a=='/EditBufferStateGet' for a,v in group) and not self.switched:self.active=8;self.switched=True
    if self.mode=='missing' and len(group)>1:replies=replies[:1]
    # Valid replies are reversed, preceded by stale IDs. Only exact correlation
    # can reconstruct the state; the read order must not control association.
    wire=b''
    for address,args in reversed(replies):
     wire+=frame(osc(address,[args[0]+1000,*args[1:]]))+frame(osc(address,args))
    c.sendall(wire)
  except (EOFError,OSError):pass
  except Exception as error:self.errors.append(str(error))
class BatchedSnapshotTests(unittest.TestCase):
 def run_peer(self,mode):
  peer=BatchPeer(mode)
  try:
   result=subprocess.run([str(BINARY),'--host','127.0.0.1','--port',str(peer.port),'--benchmark-state-reads'],capture_output=True,text=True,timeout=15)
   self.assertEqual(peer.errors,[])
   self.assertTrue(any(n>=(2 if mode=='missing' else 3) for n in peer.groups))
   self.assertLessEqual(set(peer.sent),{'/ProductInfoGet','/PropertyValueGet','/ActiveSnapshotIndexGet','/EditBufferStateGet','/GetContentRef'})
   return result
  finally:peer.close()
 def test_reversed_and_stale_replies_keep_read_identity(self):
  result=self.run_peer('normal');self.assertEqual(result.returncode,0,result.stderr);self.assertIn('batchedMilliseconds',result.stdout)
 def test_preset_change_cannot_pass_as_same_snapshot(self):
  result=self.run_peer('switch');self.assertNotEqual(result.returncode,0);self.assertIn('changed',result.stderr)
 def test_missing_batch_reply_is_not_filled_by_stale_id(self):
  result=self.run_peer('missing');self.assertNotEqual(result.returncode,0);self.assertIn('respond in time',result.stderr)
if __name__=='__main__':unittest.main()
