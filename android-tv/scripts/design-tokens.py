#!/usr/bin/env python3
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
tokens=json.loads((root.parent/'design/tokens.json').read_text())
def resolve(path):
 v=tokens
 for key in path.split('.'):v=v[key]
 return resolve(v[1:-1]) if isinstance(v,str) and v.startswith('{') else v
keys={'BG':'semantic.color.canvas','INK':'semantic.color.textPrimary','MUTED':'semantic.color.textSecondary','WOOD':'semantic.color.actionPrimary','GREEN':'semantic.color.success','SURFACE':'semantic.color.tray'}
s='package com.family.littlelearning;\n/** Generated from games/design/tokens.json. Do not edit. */\nfinal class Design {\n'
for key,path in keys.items():s+=f' static final int {key}=0xff{resolve(path).lstrip("#")};\n'
s+=' private Design(){}\n}\n'
(root/'app/src/main/java/com/family/littlelearning/Design.java').write_text(s)
