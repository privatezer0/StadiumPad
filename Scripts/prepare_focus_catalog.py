"""Prepare personal-use Focus metadata from a locally extracted reference map.
No factory maps or native model definitions belong in the public repository.
"""
import argparse,json,math
from pathlib import Path
import msgpack
p=argparse.ArgumentParser()
p.add_argument('--source',type=Path,required=True,help='Locally generated helix-stadium-tools focusModels.json')
p.add_argument('--modeldefs',type=Path,required=True,help='Installed editor modeldefs/p35md-*.bin')
p.add_argument('--catalog',type=Path,default=Path(__file__).resolve().parents[1]/'iPad/Resources/ParameterCatalog.json')
p.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]/'iPad/Resources/FocusCatalog.json')
a=p.parse_args()
with a.modeldefs.open('rb') as f:native=list(msgpack.Unpacker(f,raw=False))[-1]
catalog=json.loads(a.catalog.read_text());result={};added=0
for mid,focus in json.loads(a.source.read_text()).items():
 model=catalog.get(mid);definition=native.get(focus['key'],{})
 if not model or definition.get('id')!=model['id']:continue
 params=[];supplement=[]
 for spec in focus['params']:
  meta=definition.get('params',{}).get(spec['key'])
  if not meta or meta.get('id')!=spec['id'] or meta.get('type')!=spec['type']:break
  if spec['behavior'] not in ['interpolate','quantize'] or len(spec['values'])!=5:break
  low,high=float(meta['min']),float(meta['max']);values=[float(v) for v in spec['values']]
  if not all(math.isfinite(v) for v in [low,high,*values]) or low>high:break
  existing=next((p for p in model['parameters'] if p['id']==spec['id'] and not p['harness']),None)
  if existing and (existing['key']!=spec['key'] or existing['type']!=spec['type'] or existing['minimum']!=low or existing['maximum']!=high):break
  if not existing:supplement.append(dict(id=spec['id'],key=spec['key'],name=spec['key'],type=spec['type'],minimum=low,maximum=high,unit='',harness=False,focusOnly=True))
  params.append(dict(spec,min=low,max=high,values=values))
 else:
  if len(focus['names'])==5 and params:
   result[mid]=dict(focus,params=params);model['parameters'].extend(supplement);added+=len(supplement)
if not result:raise SystemExit('No complete, matching Focus definitions; outputs unchanged.')
a.catalog.write_text(json.dumps(catalog,sort_keys=True));a.output.write_text(json.dumps(result,sort_keys=True))
print('Prepared',len(result),'complete Focus maps;',added,'additional native Focus-only controls. Generated data stays local.')
