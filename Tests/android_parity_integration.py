"""Run the actual Android Java transaction engines against existing synthetic peers."""
import os,subprocess,tempfile,unittest
from global_eq_integration import EQPeer
from command_center_integration import CommandPeer
from matrix_integration import MatrixPeer
JAVA=os.environ.get('STADIUM_JAVA','java');CLASSES=os.environ.get('STADIUM_ANDROID_CLASSES','')
@unittest.skipUnless(CLASSES,'Set STADIUM_ANDROID_CLASSES to compiled Android classes plus SDK jar')
class AndroidParity(unittest.TestCase):
 def run_case(self,peer,kind,success):
  try:
   with tempfile.TemporaryDirectory() as directory:r=subprocess.run([JAVA,'-cp',CLASSES,'com.privatezero.stadiumpad.ParitySessionTests',str(peer.port),directory,kind],capture_output=True,text=True,timeout=15)
   self.assertEqual(peer.errors,[],r.stdout+r.stderr)
   self.assertEqual(r.returncode==0,success,r.stdout+r.stderr)
   sent=[a if isinstance(a,str) else a[0] for a in peer.sent]
   self.assertNotIn('/SavePresetWithCID',sent);self.assertNotIn('/LoadPresetWithCID',sent)
   return peer.sent
  finally:peer.close()
 def test_eq_live_commit_delayed_readback(self):
  for mode in ['normal','delayed-commit']:
   with self.subTest(mode=mode):
    sent=self.run_case(EQPeer(mode),'eq',True);self.assertEqual(sum(a=='/PropertyValueSet' for a,_ in sent),2)
 def test_eq_preserves_native_integer_enable_representation(self):
  peer=EQPeer("native-flags")
  for key in ["_qtr","_xlr","_pho"]:peer.eq[key]["enab"]=0
  self.run_case(peer,"eq",True)
 def test_eq_faults_never_retry(self):
  for mode in ['stale','concurrent-output','unknown','bad-ack','bad-native-commit','readback-mismatch']:
   with self.subTest(mode=mode):
    sent=self.run_case(EQPeer(mode),'eq',False);self.assertLessEqual(sum(a=='/PropertyValueSet' for a,_ in sent),2)
 def test_eq_late_own_echo_and_foreign_source(self):
  self.run_case(EQPeer("stream"),"eq-stream",True)
  self.run_case(EQPeer("stream-external"),"eq-stream",False)
 def test_command_allocation_and_parameter(self):self.run_case(CommandPeer('normal'),'command',True)
 def test_command_faults_never_retry(self):
  for mode in ['stale','wrong-echo','missing-readback','timeout']:
   with self.subTest(mode=mode):
    sent=self.run_case(CommandPeer(mode),'command',False);self.assertLessEqual(sum(a=='/attachCommandWithType' for a,_ in sent),1);self.assertNotIn('/setCommandParamVal',[a for a,_ in sent])
 def test_matrix_live_controls(self):
  for console,kind in [('mute','matrix-mute'),(True,'matrix-pan'),('clear','matrix-clear')]:
   with self.subTest(kind=kind):self.run_case(MatrixPeer('normal',console),'matrix-clear' if console=='clear' else kind,True)
 def test_matrix_guards_and_missing_receipts(self):
  for mode in ['no-change','stale','shared','linked','wrong-output','unrelated']:
   with self.subTest(mode=mode):self.run_case(MatrixPeer(mode,'mute'),'matrix-mute',False)
if __name__=='__main__':unittest.main()
