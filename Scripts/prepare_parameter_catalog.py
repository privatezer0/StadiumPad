"""Normalize personal-use parameter metadata; generated catalogue is never committed."""
from pathlib import Path
import argparse,json,math,re
p=argparse.ArgumentParser();p.add_argument('--blocks',type=Path,required=True);p.add_argument('--io',type=Path,required=True);p.add_argument('--controls',type=Path,default=Path('/Applications/Line6/Helix Stadium.app/Contents/Resources/P35Controls.json'));p.add_argument('--uidefs',type=Path,default=Path('/Applications/Line6/Helix Stadium.app/Contents/Resources/P35ModelUIDefs.json'));p.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]/'iPad/Resources/ParameterCatalog.json');a=p.parse_args()
controls=json.loads(a.controls.read_text()) if a.controls.is_file() else {}
uidefs=json.loads(a.uidefs.read_text()) if a.uidefs.is_file() else {}
result={}
def number(value):return float(value) if isinstance(value,(int,float)) and math.isfinite(value) else None
for source in [a.blocks,a.io]:
 for group_key,group in json.loads(source.read_text()).items():
  for model in group.get('models',[]):
   if not isinstance(model.get('id'),int):continue
   params=[]
   for item in model.get('params',[]):
    if not isinstance(item.get('id'),int) or item.get('faux'):continue
    lo,hi=number(item.get('min')),number(item.get('max'))
    if lo is None or hi is None or lo>hi or item.get('type') not in ['f','i','b']:continue
    options=item.get('options')
    if options is not None and not all(isinstance(x,str) for x in options):options=None
    tag=item.get('display_tag')
    if not tag:
     ui=uidefs.get(model.get('key'),{})
     tag=next((p.get('display_tag') for p in ui.get('params',[]) if p.get('id')==item.get('key') and bool(p.get('harness'))==bool(item.get('harness'))),None)
    control=controls.get(tag,{}) if isinstance(tag,str) else {}
    scale=number(control.get('dspToDisplayScale'))
    display_lo=number(item.get('display_min'));display_hi=number(item.get('display_max'))
    if display_lo is None:display_lo=lo*(scale if scale is not None else 1)
    if display_hi is None:display_hi=hi*(scale if scale is not None else 1)
    unit=item.get('unit')
    # Seconds-based controls may select ms only for their sub-second format.
    # Our display range stays in seconds, so the constant unit must be seconds.
    if isinstance(tag,str) and tag.startswith('time_sec'):unit='sec'
    if not unit:
     forms=control.get('formatUnits') or control.get('format',[])
     forms=[forms] if isinstance(forms,str) else [x.get('formatUnits','') for x in forms if isinstance(x,dict)] if isinstance(forms,list) else []
     units=[re.sub(r'%[-+0-9.#]*[a-zA-Z]','',f.replace('%%','%')).strip() for f in forms]
     unit='ms' if 'ms' in units else '%' if '%' in units else next((u for u in units if u),'unitless')
    formats=[]
    raw_formats=control.get('format')
    if isinstance(raw_formats,list):
     for rule in raw_formats:
      if not isinstance(rule,dict):continue
      fmt=rule.get('formatUnits') or rule.get('format')
      if isinstance(fmt,str):formats.append(dict(lowerBound=number(rule.get('lowerBound')),upperBound=number(rule.get('upperBound')),multiplier=number(rule.get('unitsMultiplier')) or 1,format=fmt))
    else:
     fmt=control.get('formatUnits') or raw_formats
     if isinstance(fmt,str):formats.append(dict(lowerBound=None,upperBound=None,multiplier=1,format=fmt))
    params.append(dict(id=item['id'],key=item.get('key',''),name=item.get('name') or item.get('key') or 'Parameter',type=item['type'],minimum=lo,maximum=hi,displayMinimum=display_lo,displayMaximum=display_hi,unit=unit,displayFormats=formats or None,options=options,harness=bool(item.get('harness'))))
   # Duplicate numeric IDs are valid across harness/model spaces, but never within one.
   seen=set();unique=[]
   for item in params:
    key=(item['harness'],item['id'])
    if key in seen:continue
    seen.add(key);unique.append(item)
   result[str(model['id'])]=dict(id=model['id'],name=model.get('name','Effect'),category=model.get('category'),modelKey=model.get('key'),basedOn=model.get('based_on'),ioRole=group_key if source==a.io else None,parameters=unique)
out=a.output;out.write_text(json.dumps(result,sort_keys=True))
print('Prepared parameter catalogue for',len(result),'models; generated data excluded from Git.')
