"""Prepare local functional Command Center metadata; generated data stays out of Git."""
import argparse,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--resources',type=Path,default=Path('/Applications/Line6/Helix Stadium.app/Contents/Resources'));p.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]/'iPad/Resources/CommandCatalog.json');a=p.parse_args()
text=(a.resources/'commanddefs/P35EditCommandDefs.json').read_text();decoder=json.JSONDecoder();_,offset=decoder.raw_decode(text);definitions=json.loads(text[offset:].strip());controls=json.loads((a.resources/'P35Controls.json').read_text())
tags={'Action':'cc_action','Select':'cc_extamp_select','Message':'cc_midi_message','Keystroke':'key_keystroke','Modifier 1':'key_modifier_mac','Modifier 2':'key_modifier_mac','Modifier 3':'key_modifier_mac','Note':'midi_note'}
commands={'PresetSnapshot':'cc_presetsnapshot_command','Song':'cc_song_command','Looper':'cc_looper_command','Utility':'cc_utility_command','MIDI':'cc_midi_command'}
result={}
for key,definition in definitions.items():
 params=[];family=key.split('-')[0]
 for name,item in definition.get('params',{}).items():
  tag=commands.get(family) if name=='Command' else 'cc_drum_action' if name=='Action' and key.endswith('-Drum') else tags.get(name)
  options=controls.get(tag,{}).get('format')
  if not isinstance(options,list) or not all(isinstance(v,str) for v in options):options=None
  params.append(dict(id=item['id'],name=name,type=item['type'],minimum=item['min'],maximum=item['max'],defaultValue=item['def'],options=options))
 result[key]=sorted(params,key=lambda x:x['id'])
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,sort_keys=True));print('Prepared',len(result),'local command variants; generated data excluded from Git.')
