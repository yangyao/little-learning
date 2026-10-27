#!/usr/bin/env python3
"""Generate Java fixtures from the same exported bank the APK uses."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
c=json.loads((root/'app/src/main/assets/content.json').read_text())
def s(x):return json.dumps(x,ensure_ascii=False)
def point(p):return 'new Point(%d,%d)'%tuple(p)
lines=['package com.family.littlelearning;','import java.util.*;','import static com.family.littlelearning.GameModel.*;','final class ContentFixtures {','static List<Question> questions(){return Arrays.asList(']
qs=[q for g in c['arithmetic'] for q in g['questions']]
lines += [',\n'.join(f'new Question({q["start"]},{q["change"]},{s(q["id"])})' for q in qs)+');}']
lines += ['static List<Route> routes(){return Arrays.asList(']
rs=[]
for r in c['routes']:
 blocks='new HashSet<>(Arrays.asList('+','.join(map(point,r['obstacles']))+'))'
 commands='Arrays.asList('+','.join(map(s,r['solution']))+')'
 rs.append('new Route(%d,%d,%s,%s,%s,%s,%s,%s)'%(r['index'],r['size'],point(r['start']),point(r['goal']),point(r['pickup']) if 'pickup'in r else 'null',blocks,commands,s(r['id'])))
lines += [',\n'.join(rs)+');}','}']
(root/'build/tests').mkdir(parents=True,exist_ok=True)
(root/'build/tests/ContentFixtures.java').write_text('\n'.join(lines))
