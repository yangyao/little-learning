#!/usr/bin/env python3
"""Normalize backed-up native ledgers. Never add device balances together."""
import argparse, hashlib, json, uuid
from pathlib import Path

def stable(text):
    return str(uuid.UUID(bytes=hashlib.md5(text.encode()).digest(), version=3)).upper()

def normalize(root):
    children={c:[] for c in ('qianyi','zhenyi')}
    report={}
    for path in sorted(root.glob('iphone-*/collection-v1.family-v1.json')):
        source=json.loads(path.read_text())
        for child,state in source['children'].items():
            events=state['rewards']['entries']
            report[f'{path.parent.name}/{child}']={'entries':len(events),'balance':sum(e['amount'] for e in events)}
            for original in events:
                e=dict(original);e['id']=e['id'].upper();e['date']=round((e['date']+978307200)*1000)
                if e['kind']=='refund':e['reference']=e['reference'].upper()
                children[child].append(e)
    tv=json.loads((root/'tv/family-tv-v1.json').read_text())
    for child,state in zip(children,tv['children']):
        events=[]
        for r in state['awards']:
            events.append(dict(id=stable(child+':'+r['id']),date=r['at'],kind='award',reference=r['id'],title=r['title'],amount=r['points']))
        for r in state['redemptions']:
            play=r['id'].startswith('playtime:');identifier=r['id'].removeprefix('playtime:').upper()
            events.append(dict(id=identifier,date=r['at'],kind='playTime' if play else 'redemption',reference='play-time:5-minutes' if play else 'manual',title=r['title'],amount=-r['points']))
            if r['undone']:
                events.append(dict(id=stable('refund:'+child+':'+identifier),date=r['at'],kind='refund',reference=identifier,title='撤销 · '+r['title'],amount=r['points']))
        report[f'tv/{child}']={'entries':len(events),'balance':sum(e['amount'] for e in events)}
        children[child]+=events
    merged={}
    for child,events in children.items():
        ids={};semantic={};result=[]
        for e in events:
            key=(e['kind'],e['reference']) if e['kind'] in ('award','refund') else ('id',e['id'])
            if e['id'] in ids:
                old=ids[e['id']]
                assert all(old[k]==e[k] for k in ('kind','reference','amount')),f'Conflicting UUID {e["id"]}'
            if key in semantic:
                assert semantic[key]['amount']==e['amount'],f'Conflicting event {key}'
                continue
            ids[e['id']]=e;semantic[key]=e;result.append(e)
        children[child]=result
        merged[child]={'entries':len(result),'awards':sum(e['kind']=='award' for e in result),'balance':sum(e['amount'] for e in result)}
        assert merged[child]['balance']>=0
    return dict(device='historical-migration',children=children),dict(sources=report,merged=merged)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('backup',type=Path);p.add_argument('output',type=Path);a=p.parse_args()
    request,report=normalize(a.backup);a.output.write_text(json.dumps(request,ensure_ascii=False,indent=2));a.output.with_suffix('.report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps(report,ensure_ascii=False,indent=2))
    manifest={str(f.relative_to(a.backup)):hashlib.sha256(f.read_bytes()).hexdigest() for f in a.backup.rglob('*') if f.is_file() and f.name!='manifest.json'}
    (a.backup/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
