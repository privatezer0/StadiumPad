"""User-requested discard semantics; synthetic loopback presets only."""
import json,os,subprocess,tempfile,unittest
from pathlib import Path
from editing_integration import EditorPeer,BINARY
class DiscardIntegration(unittest.TestCase):
 def run_check(self,mode,strict=False):
  peer=EditorPeer(mode)
  try:
   with tempfile.TemporaryDirectory(dir=os.environ.get('STADIUM_TEST_ROOT')) as td:
    root=Path(td)
    def spare(cid):return {'preset':{'contentID':cid,'container':-2,'position':267 if cid==11 else 268,'name':peer.reference(cid)['name'],'type':2},'sourceID':9,'sourceSnapshot':0,'sourceHash':'synthetic'}
    (root/'plan.json').write_text(json.dumps({'first':spare(11),'second':spare(12)}))
    r=subprocess.run([str(BINARY),'--host','127.0.0.1','--port',str(peer.port),'--plan',str(root/'plan.json'),'--backups',str(root/'backups'),'--strict-load-check' if strict else '--discard-check'],capture_output=True,text=True,timeout=20)
    backups=[p.read_bytes() for p in (root/'backups').glob('*.bin')]
   return r,peer.sent,peer.errors,peer.stored,backups
  finally:peer.close()
 def test_dirty_selection_discards_with_live_and_saved_backups_no_save(self):
  r,s,e,stored,backups=self.run_check('discard-normal');self.assertEqual(e,[]);self.assertEqual(r.returncode,0,r.stderr);self.assertIn('PASS discard',r.stdout)
  self.assertEqual(sum(a=='/LoadPresetWithCID' for a,_ in s),2);self.assertFalse(any(a in ['/ParamValueSet','/SavePresetWithCID','/SetContentData','/CreateContent'] for a,_ in s));self.assertEqual(stored,{11:0.4,12:0.4});self.assertGreaterEqual(len(set(backups)),2)
 def test_internal_strict_load_still_refuses_unsaved_data(self):
  r,s,e,_,_=self.run_check('discard-normal',strict=True);self.assertEqual(e,[]);self.assertNotEqual(r.returncode,0);self.assertFalse(any(a=='/LoadPresetWithCID' for a,_ in s))
 def test_backup_failure_prevents_discard(self):self.failure('discard-backup-failure')
 def test_source_changes_during_backup_prevent_discard(self):self.failure('discard-switch')
 def failure(self,mode):
  r,s,e,_,_=self.run_check(mode);self.assertEqual(e,[]);self.assertNotEqual(r.returncode,0);self.assertFalse(any(a in ['/LoadPresetWithCID','/SavePresetWithCID'] for a,_ in s))
if __name__=='__main__':unittest.main()
