"""Typed Command Center transaction regressions; synthetic loopback only."""
import copy,os,struct,subprocess,tempfile,threading,unittest
from pathlib import Path
import msgpack
from integration_peer import Peer,exact,receive,ready,frame,osc,message
BINARY=Path(os.environ.get('STADIUM_EDIT_CHECK',str(Path(__file__).resolve().parents[1]/'.build/debug/stadium-edit-check')))
class CommandPeer(Peer):
 def __init__(self,mode):
  self.rows=[];self.commands=[];self.reads=0
  super().__init__(mode)
 def edit(self):return {'sfg_':{'flow':[]},'cg__':{'asnp':0,'entt':{'srcs':self.rows,'cmnd':self.commands,'ctrl':[],'trgs':[]}}}
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
    _,data=receive(c);address,v=message(data);self.sent.append((address,v));rid=v[0];reply=address
    if address=='/ProductInfoGet':reply='/getProductInfo';args=[rid,msgpack.packb({'host':{'vers':{'majo':1,'mino':4,'patc':2}}})]
    elif address=='/PropertyValueGet':reply='/getPropertyValue';args=[rid,0,b'lavppgsm'+msgpack.packb({'val_':False if v[1]=='volatile.preset.edited' else 50})]
    elif address=='/EditBufferStateGet':
     self.reads+=1;body=copy.deepcopy(self.edit())
     if self.mode=='stale' and self.reads>=2:body['cg__']['entt']['srcs']=[{'id__':9,'type':1,'locl':25,'ctxt':1,'cmds':[-1,-1]}]
     reply='/getEditBufferState';args=[rid,0,b'_sbepgsm'+msgpack.packb(body)]
    elif address=='/GetContentRef':args=[rid,msgpack.packb({'cid_':50,'ccid':-2,'posi':0,'type':2,'ownr':1,'name':'Synthetic Commands'})]
    elif address=='/ActiveSnapshotIndexGet':reply='/getActiveSnapshotIndex';args=[rid,0]
    elif address=='/GetContentData':args=[rid,b'_sbepgsm'+msgpack.packb(self.edit())]
    elif address=='/attachCommandWithType':
     assert v[1:7]==[1,25,1,0,6,0],v
     if self.mode=='timeout':threading.Event().wait(6);return
     if self.mode!='missing-readback':
      self.rows=[{'id__':9,'type':1,'locl':25,'ctxt':1,'cmds':[3,-1]}]
      self.commands=[{'cid_':3,'trig':9,'tid_':18,'type':6,'pvla':0,'pvlb':0}]
     args=[rid,3,4 if self.mode=='wrong-echo' else 3]
    elif address=='/setCommandParamVal':
     assert v[1:]==[3,1,1],v
     self.commands[0]['pvlb']=1;reply='/status';args=[rid,0,0]
    else:raise AssertionError('Unexpected command '+address)
    c.sendall(frame(osc(reply,args)))
  except (EOFError,OSError):pass
  except Exception as e:self.errors.append(str(e))
class CommandIntegration(unittest.TestCase):
 def run_peer(self,mode):
  peer=CommandPeer(mode)
  try:
   with tempfile.TemporaryDirectory() as directory:
    result=subprocess.run([str(BINARY),'--host','127.0.0.1','--port',str(peer.port),'--plan',directory+'/unused.json','--backups',directory+'/backups','--command-transaction-check'],capture_output=True,text=True,timeout=18)
    return result,peer.sent,peer.errors
  finally:peer.close()
 def test_allocation_echo_is_command_not_source_and_readback_confirms_edit(self):
  r,s,e=self.run_peer('normal');self.assertEqual(e,[]);self.assertEqual(r.returncode,0,r.stderr);self.assertIn('PASS command transaction',r.stdout)
 def test_stale_source_rejected_before_hardware_write(self):
  r,s,e=self.run_peer('stale');self.assertEqual(e,[]);self.assertNotEqual(r.returncode,0);self.assertFalse(any(a=='/attachCommandWithType' for a,_ in s))
 def test_wrong_allocation_echo_stops_without_retry_or_parameter_write(self):
  r,s,e=self.run_peer('wrong-echo');self.assertEqual(e,[]);self.assertNotEqual(r.returncode,0);self.assertEqual(sum(a=='/attachCommandWithType' for a,_ in s),1);self.assertFalse(any(a=='/setCommandParamVal' for a,_ in s))
 def test_ack_without_readback_does_not_confirm_assignment(self):
  r,s,e=self.run_peer('missing-readback');self.assertEqual(e,[]);self.assertNotEqual(r.returncode,0);self.assertFalse(any(a=='/setCommandParamVal' for a,_ in s))
 def test_uncertain_attach_is_never_replayed_or_saved(self):
  r,s,e=self.run_peer('timeout');self.assertEqual(e,[]);self.assertNotEqual(r.returncode,0);self.assertEqual(sum(a=='/attachCommandWithType' for a,_ in s),1);self.assertFalse(any(a=='/SavePresetWithCID' for a,_ in s))
if __name__=='__main__':unittest.main()
