"""Exercise the real local library agent against an isolated synthetic Stadium."""
import hashlib,json,os,subprocess,threading,unittest
from pathlib import Path
import msgpack
from integration_peer import Peer,exact,receive,ready,frame,osc,message
BINARY=Path(os.environ.get('STADIUM_LIBRARY',Path(__file__).resolve().parents[1]/'.build/debug/stadium-library'))
DEVICE=hashlib.sha256(b'synthetic-stadium').hexdigest()
UUID='11111111-1111-4111-8111-111111111111'
class ClonePeer(Peer):
 def __init__(self,mode):
  self.row={'cid_':20,'ccid':-23,'cctp':1002,'ownr':1,'type':11,'posi':0,'cluid':UUID,'name':'Before','unknown':b'preserved'}
  self.folder={'cid_':30,'ccid':-23,'ownr':1,'type':1002,'posi':1,'name':'Folder'}
  super().__init__(mode)
 def serve(self,listener,index):
  try:
   c,_=listener.accept();self.sockets.append(c);c.settimeout(8);greeting=exact(c,64);c.sendall(greeting);receive(c);c.sendall(ready('PUB' if index==0 else 'ROUTER'))
   if index==0:
    receive(c)
    while not self.closed:threading.Event().wait(.02)
    return
   while not self.closed:
    _,data=receive(c);address,values=message(data);self.sent.append((address,values));cmd=values[0]
    if address=='/ProductInfoGet':reply='/getProductInfo';args=[cmd,msgpack.packb({'host':{'snum':'synthetic-stadium'}})]
    elif address=='/GetContainerContents':
     cid=values[1]
     if cid==-14:rows=[{'cid_':-23,'ccid':-14,'ownr':1,'type':1002,'name':'Amp'}]
     elif cid==-23:rows=[self.folder]+([self.row] if self.row['ccid']==-23 else [])
     elif cid==30:rows=([self.row] if self.row['ccid']==30 else [])+([self.folder] if self.mode=='cycle' else [])
     else:rows=[]
     reply=address;args=[cmd,msgpack.packb(rows)]
    elif address=='/GetContentRef':reply=address;args=[cmd,msgpack.packb(self.row if values[1]==20 else self.folder)]
    elif address=='/SetContentAttrs':
     self.row=msgpack.unpackb(values[2],raw=False)
     if self.mode=='wrong-readback':self.row['name']='Concurrent change'
     reply='/status';args=[cmd,0,0]
    elif address=='/AddContentsToContainer':
     if values[-2:]!=[0,1]:raise AssertionError('Move flags changed to copy')
     if self.mode!='copy-instead-of-move':self.row=dict(self.row,ccid=values[1],posi=values[3])
     reply='/status';args=[cmd,0,0]
    else:raise AssertionError('Unexpected library request '+address)
    c.sendall(frame(osc(reply,args)))
  except (OSError,EOFError):pass
  except Exception as error:self.errors.append(str(error))
class CloneLibraryIntegration(unittest.TestCase):
 def run_agent(self,mode,request):
  peer=ClonePeer(mode)
  try:
   payload=dict(request,host='127.0.0.1',port=peer.port)
   result=subprocess.run([str(BINARY)],input=json.dumps(payload),capture_output=True,text=True,timeout=12)
   self.assertEqual(peer.errors,[])
   self.assertFalse(any(a in ('/SavePresetWithCID','/LoadPresetWithCID','/ParamValueSet','/ModelSet') for a,_ in peer.sent))
   return result,peer.sent
  finally:peer.close()
 def rename(self):return {'op':'rename','deviceID':DEVICE,'id':20,'parent':-23,'uuid':UUID,'expectedName':'Before','name':'After'}
 def test_read_walks_real_folder_ids_without_writes(self):
  r,sent=self.run_agent('normal',{});self.assertEqual(r.returncode,0,r.stdout);self.assertEqual(len(json.loads(r.stdout)['entries']),3);self.assertLessEqual({a for a,_ in sent},{'/ProductInfoGet','/GetContainerContents'})
 def test_wrong_device_is_rejected_before_mutation(self):
  q=self.rename();q['deviceID']='0'*64;r,sent=self.run_agent('normal',q);self.assertNotEqual(r.returncode,0);self.assertFalse(any(a=='/SetContentAttrs' for a,_ in sent))
 def test_stale_clone_uuid_is_rejected_before_mutation(self):
  q=self.rename();q['uuid']='22222222-2222-4222-8222-222222222222';r,sent=self.run_agent('normal',q);self.assertNotEqual(r.returncode,0);self.assertFalse(any(a=='/SetContentAttrs' for a,_ in sent))
 def test_rename_requires_exact_readback_and_preserves_unknown_fields(self):
  r,sent=self.run_agent('normal',self.rename());self.assertEqual(r.returncode,0,r.stdout);self.assertEqual(json.loads(r.stdout)['changed']['name'],'After');writes=[v for a,v in sent if a=='/SetContentAttrs'];self.assertEqual(len(writes),1);self.assertEqual(msgpack.unpackb(writes[0][2],raw=False)['unknown'],b'preserved')
 def test_failed_rename_readback_is_not_retried(self):
  r,sent=self.run_agent('wrong-readback',self.rename());self.assertNotEqual(r.returncode,0);self.assertEqual(sum(a=='/SetContentAttrs' for a,_ in sent),1)
 def test_copy_cannot_satisfy_move_confirmation(self):
  q={'op':'move','deviceID':DEVICE,'id':20,'parent':-23,'uuid':UUID,'expectedName':'Before','destination':30}
  r,sent=self.run_agent('copy-instead-of-move',q);self.assertNotEqual(r.returncode,0);self.assertEqual(sum(a=='/AddContentsToContainer' for a,_ in sent),1);self.assertFalse(any(a=='/RemoveContent' for a,_ in sent))
 def test_move_preserves_actual_clone_identity(self):
  q={'op':'move','deviceID':DEVICE,'id':20,'parent':-23,'uuid':UUID,'expectedName':'Before','destination':30}
  r,sent=self.run_agent('normal',q);self.assertEqual(r.returncode,0,r.stdout);self.assertEqual(json.loads(r.stdout)['changed']['cid_'],20);self.assertEqual(json.loads(r.stdout)['changed']['cluid'],UUID)
 def test_cyclic_folders_fail_without_writes(self):
  r,sent=self.run_agent('cycle',{});self.assertNotEqual(r.returncode,0);self.assertLessEqual({a for a,_ in sent},{'/ProductInfoGet','/GetContainerContents'})
if __name__=='__main__':unittest.main()
