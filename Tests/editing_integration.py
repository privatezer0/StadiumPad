"""Synthetic editor/device integration. Every socket is bound to loopback."""
import copy,json,os,socket,struct,subprocess,tempfile,threading,unittest
from pathlib import Path
import msgpack
from integration_peer import Peer,exact,receive,ready,frame,osc,message
BINARY=Path(os.environ.get('STADIUM_EDIT_CHECK',str(Path(__file__).resolve().parents[1]/'.build/debug/stadium-edit-check')))
CATALOG={'42':{'id':42,'name':'Dynamic Room','parameters':[{'id':1,'key':'Decay','name':'Decay','type':'f','minimum':0,'maximum':1,'displayMinimum':0,'displayMaximum':10,'unit':'s','harness':False}]}}
class EditorPeer(Peer):
 def __init__(self,mode):
  self.active=11;self.dirty=False;self.live=0.4;self.stored={11:0.4,12:0.4};self.edits=0;self.edit_reads=0;self.selection_echo=None
  super().__init__(mode)
  if mode.startswith('discard'):self.dirty=True;self.live=0.65
 def reference(self,cid):return {'cid_':cid,'ccid':-2,'posi':267 if cid==11 else 268,'name':'iPad Edit Test 1117' if cid==11 else 'iPad Reload Check 1117','type':2}
 def edit(self,value,model=42):return {'sfg_':{'flow':[{'blks':[7,{'id__':3,'enbl':1,'mdls':[{'id__':model,'parm':[{'pid_':1,'valu':value}]}]}]}]}}
 def serve(self,listener,index):
  try:
   c,_=listener.accept();self.sockets.append(c);c.settimeout(8);greeting=exact(c,64);c.sendall(greeting);receive(c);c.sendall(ready('PUB' if index==0 else 'ROUTER'))
   if index==0:
    receive(c)
    while not self.closed:
     try:
      echo=self.selection_echo
      if echo is not None:
       self.selection_echo=None
       c.sendall(frame(osc('/setSelectedBlock',echo)))
      c.sendall(frame(struct.pack('>Q',2**40),1)+frame(osc('/heartbeat',[1,2,3])))
     except OSError:break
     threading.Event().wait(.1)
    return
   while not self.closed:
    _,data=receive(c);address,values=message(data);self.sent.append((address,values));cid=values[0];reply=address;args=None
    if address=='/ProductInfoGet':reply='/getProductInfo';args=[cid,msgpack.packb({'host':{'vers':{'majo':1,'mino':4,'patc':2}}})]
    elif address=='/PropertyValueGet':reply='/getPropertyValue';args=[cid,0,b'lavppgsm'+msgpack.packb({'val_':self.dirty if values[1]=='volatile.preset.edited' else self.active})]
    elif address=='/EditBufferStateGet':
     self.edit_reads+=1;model=99 if self.mode=='stale-block' and self.edit_reads>=3 else 42
     reply='/getEditBufferState';args=[cid,0,b'_sbepgsm'+msgpack.packb(self.edit(self.live,model))]
    elif address=='/GetContentRef':args=[cid,msgpack.packb(self.reference(values[1]))]
    elif address=='/ActiveSnapshotIndexGet':reply='/getActiveSnapshotIndex';args=[cid,0]
    elif address=='/GetContentData':
     args=[cid,b'' if self.mode=='discard-backup-failure' else b'_sbepgsm'+msgpack.packb(self.edit(self.stored[values[1]]))]
     if self.mode=='discard-switch' and sum(a=='/GetContentData' for a,_ in self.sent)>=2:self.active=999
    elif address=='/SelectedBlockSet':
     assert values[1:]==[0,7],values
     if self.mode!='selection-missing':self.selection_echo=[5,cid+(1 if self.mode=='selection-wrong-id' else 0),0,7]
     continue
    elif address=='/ParamValueSet':
     assert values[1:5]==[0,7,0,1],values
     if self.mode=='edit-rejected':args=[cid,-1,1]
     else:self.live=values[5];self.dirty=True;self.edits+=1;args=[cid,0,1]
     reply='/status'
    elif address=='/SavePresetWithCID':
     assert values[1:]==[11,-1,-1],values
     if self.mode=='save-timeout':threading.Event().wait(6);return
     if self.mode!='stored-mismatch':self.stored[11]=self.live
     self.dirty=False;reply='/status';args=[cid,0,1]
     if self.mode=='save-switch':self.active=999
    elif address=='/LoadPresetWithCID':
     assert not self.dirty or self.mode.startswith('discard')
     assert values[1] in [11,12]
     self.active=values[1];self.live=self.stored[self.active];self.dirty=False;reply='/status';args=[cid,0,0]
    else:raise AssertionError('Unexpected command '+address)
    c.sendall(frame(osc(reply,args)))
  except (EOFError,OSError):pass
  except Exception as error:self.errors.append(str(error))
class EditIntegration(unittest.TestCase):
 def run_check(self,mode):
  peer=EditorPeer(mode)
  try:
   with tempfile.TemporaryDirectory() as directory:
    root=Path(directory);catalog=root/'catalog.json';catalog.write_text(json.dumps(CATALOG))
    def saved(cid,source=1):return {'preset':peer.reference(cid)|{'contentID':cid,'container':-2,'position':267 if cid==11 else 268,'backingID':None},'sourceID':source,'sourceSnapshot':0,'sourceHash':'unused'}
    plan=root/'plan.json';plan.write_text(json.dumps({'first':saved(11),'second':saved(12)}))
    args=[str(BINARY),'--host','127.0.0.1','--port',str(peer.port),'--plan',str(plan),'--backups',str(root/'backups'),'--exercise','--catalog',str(catalog)]
    if mode=='normal':args.append('--concurrent-reads')
    result=subprocess.run(args,capture_output=True,text=True,timeout=20)
    backups=list((root/'backups').glob('*.bin')) if (root/'backups').exists() else []
    return result,peer.sent,peer.errors,peer.stored,len(backups)
  finally:peer.close()
 def test_edit_save_reload_restore_and_concurrent_polling(self):
  result,sent,errors,stored,backups=self.run_check('normal');self.assertEqual(errors,[]);self.assertEqual(result.returncode,0,result.stderr);self.assertIn('COMPLETE PASS',result.stdout);self.assertAlmostEqual(stored[11],0.4,places=6);self.assertEqual(stored[12],0.4);self.assertGreater(backups,0)
  writes=[values for address,values in sent if address=='/SavePresetWithCID'];self.assertEqual(len(writes),2);self.assertTrue(all(v[1]==11 for v in writes))
 def test_rejected_edit_never_saves(self):
  result,sent,errors,_,_=self.run_check('edit-rejected');self.assertEqual(errors,[]);self.assertNotEqual(result.returncode,0);self.assertFalse(any(a=='/SavePresetWithCID' for a,_ in sent))
 def test_stale_model_never_sends_parameter_write(self):
  result,sent,errors,_,_=self.run_check('stale-block');self.assertEqual(errors,[]);self.assertNotEqual(result.returncode,0);self.assertFalse(any(a=='/ParamValueSet' for a,_ in sent))
 def test_missing_save_ack_is_not_retried_or_claimed(self):
  result,sent,errors,_,_=self.run_check('save-timeout');self.assertEqual(errors,[]);self.assertNotEqual(result.returncode,0);self.assertEqual(sum(a=='/SavePresetWithCID' for a,_ in sent),1);self.assertFalse(any(a=='/LoadPresetWithCID' for a,_ in sent))
 def test_switch_during_save_cannot_confirm_other_clean_preset(self):
  result,sent,errors,_,_=self.run_check('save-switch');self.assertEqual(errors,[]);self.assertNotEqual(result.returncode,0);self.assertFalse(any(a=='/LoadPresetWithCID' for a,_ in sent))
 def test_clean_flag_without_stored_value_does_not_confirm_save(self):
  result,sent,errors,_,_=self.run_check('stored-mismatch');self.assertEqual(errors,[]);self.assertNotEqual(result.returncode,0);self.assertFalse(any(a=='/LoadPresetWithCID' for a,_ in sent))
if __name__=='__main__':unittest.main()
