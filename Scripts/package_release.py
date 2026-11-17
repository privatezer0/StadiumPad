"""Package a locally signed iPad build; installers must stay outside Git."""
import argparse,datetime,hashlib,plistlib,subprocess,tempfile,zipfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--app',type=Path,required=True);p.add_argument('--output-dir',type=Path,required=True);a=p.parse_args()
app=a.app.resolve();out=a.output_dir.resolve();out.mkdir(parents=True,exist_ok=True)
info=plistlib.loads((app/'Info.plist').read_bytes());assert info['DTPlatformName']=='iphoneos'
subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
profile=plistlib.loads(subprocess.check_output(['security','cms','-D','-i',str(app/'embedded.mobileprovision')],stderr=subprocess.DEVNULL))
assert profile['ExpirationDate']>datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
version=info['CFBundleShortVersionString'];ipa=out/f'StadiumPad-iPad-{version}.ipa'
with tempfile.TemporaryDirectory(dir=out) as td:
 payload=Path(td)/'Payload';payload.mkdir();subprocess.run(['ditto',str(app),str(payload/app.name)],check=True)
 subprocess.run(['ditto','-c','-k','--norsrc','--keepParent',str(payload),str(ipa)],check=True)
def sha(path):
 with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
with zipfile.ZipFile(ipa) as archive:
 assert archive.testzip() is None
 for item in app.rglob('*'):
  if item.is_file():assert hashlib.sha256(archive.read('Payload/'+app.name+'/'+item.relative_to(app).as_posix())).hexdigest()==sha(item)
print(ipa.name,sha(ipa))
