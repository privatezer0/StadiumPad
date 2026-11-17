"""Prepare personal-use labels outside source control; no Line 6 artwork is copied."""
import argparse,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--catalog',type=Path,required=True);a=p.parse_args()
data=json.loads(a.catalog.read_text());names={str(m['id']):m['name'] for m in data['models'] if isinstance(m.get('id'),int) and m.get('name')}
out=Path(__file__).resolve().parents[1]/'iPad/Resources/ModelNames.json';out.parent.mkdir(exist_ok=True);out.write_text(json.dumps(names,sort_keys=True))
print('Prepared local model labels; generated data stays out of Git.')
