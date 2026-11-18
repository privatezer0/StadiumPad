"""Correlated selection echo uses the broadcast stream, never a /status or Save."""
import os,subprocess,tempfile,unittest
from pathlib import Path
from editing_integration import EditorPeer,BINARY
class SelectionIntegration(unittest.TestCase):
 def run_selection(self,mode):
  peer=EditorPeer(mode)
  try:
   with tempfile.TemporaryDirectory(dir=os.environ.get('STADIUM_TEST_ROOT')) as tmp:
    result=subprocess.run([str(BINARY),'--host','127.0.0.1','--port',str(peer.port),'--plan',tmp+'/unused.json','--backups',tmp+'/backups','--selection-check'],capture_output=True,text=True,timeout=15)
   self.assertEqual(peer.errors,[])
   self.assertEqual(sum(a=='/SelectedBlockSet' for a,_ in peer.sent),1)
   self.assertFalse(any(a in ['/SavePresetWithCID','/ParamValueSet','/LoadPresetWithCID','/ModelSet'] for a,_ in peer.sent))
   return result
  finally:peer.close()
 def test_echo_confirms_selection_without_preset_edits(self):
  r=self.run_selection('selection');self.assertEqual(r.returncode,0,r.stderr);self.assertIn('PASS selection echo correlated',r.stdout)
 def test_missing_echo_is_not_retried(self):
  r=self.run_selection('selection-missing');self.assertNotEqual(r.returncode,0);self.assertIn('not confirmed',r.stderr)
 def test_other_command_id_cannot_confirm_selection(self):
  r=self.run_selection('selection-wrong-id');self.assertNotEqual(r.returncode,0);self.assertIn('not confirmed',r.stderr)
@unittest.skipUnless(os.environ.get('STADIUM_JAVA_SELECTION_CLASSES'),'Run Android/scripts/test-selection.sh for Java socket tests')
class JavaSelectionIntegration(SelectionIntegration):
 def run_selection(self,mode):
  peer=EditorPeer(mode)
  try:
   with tempfile.TemporaryDirectory(dir=os.environ.get('STADIUM_TEST_ROOT')) as tmp:
    result=subprocess.run([str(Path(os.environ['JAVA_HOME'])/'bin/java'),'-cp',os.environ['STADIUM_JAVA_SELECTION_CLASSES'],'com.privatezero.stadiumpad.SelectionSessionTests',str(peer.port),tmp],capture_output=True,text=True,timeout=15)
   self.assertEqual(peer.errors,[])
   self.assertEqual(sum(a=='/SelectedBlockSet' for a,_ in peer.sent),1)
   self.assertFalse(any(a in ['/SavePresetWithCID','/ParamValueSet','/LoadPresetWithCID','/ModelSet'] for a,_ in peer.sent))
   return result
  finally:peer.close()
if __name__=='__main__':unittest.main()
