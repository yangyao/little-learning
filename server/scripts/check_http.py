#!/usr/bin/env python3
"""Exercise real HTTP, migration, concurrent spending, restart and backup in an isolated DB."""
import concurrent.futures, json, pathlib, secrets, socket, subprocess, sys, tempfile, time, urllib.request, urllib.error, uuid
urllib.request.install_opener(urllib.request.build_opener(urllib.request.ProxyHandler({})))
binary=str(pathlib.Path(sys.argv[1]).resolve())
history=pathlib.Path(sys.argv[2]).resolve() if len(sys.argv)>2 else None
with tempfile.TemporaryDirectory(prefix='learning-http-') as folder:
 root=pathlib.Path(folder)
 with socket.socket() as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
 token=secrets.token_hex(32);config=root/'config.json';config.write_text(json.dumps(dict(listen=f'127.0.0.1:{port}',database=str(root/'family.db'),token=token)))
 args=[binary,'-config',str(config)]
 if history is None:
  history=root/'synthetic-history.json'
  def award(child,i):
   return dict(id=str(uuid.uuid5(uuid.NAMESPACE_URL,f'learning-test:{child}:{i}')),date=1700000000000,kind='award',reference=f'numberLine:{i}:1',title='Synthetic test award',amount=1)
  history.write_text(json.dumps(dict(device='synthetic-migration-test',children=dict(qianyi=[award('qianyi',i) for i in range(10)],zhenyi=[award('zhenyi',i) for i in range(3)]))))
 source=json.loads(history.read_text());expected={c:sum(e['amount'] for e in entries) for c,entries in source['children'].items()}
 cost=expected['qianyi'];assert cost>0
 imported=json.loads(subprocess.check_output(args+['-import',str(history)]));assert imported==expected
 process=None
 def start():
  global process
  process=subprocess.Popen(args,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
  for _ in range(100):
   try:
    with urllib.request.urlopen(f'http://127.0.0.1:{port}/healthz',timeout=.2) as r:assert json.load(r)==dict(status='ok');return
   except OSError:time.sleep(.05)
  raise RuntimeError('Service did not start')
 def exchange(payload,authorized=True):
  req=urllib.request.Request(f'http://127.0.0.1:{port}/v1/sync',data=json.dumps(payload).encode(),headers={'Content-Type':'application/json','Authorization':'Bearer '+(token if authorized else 'incorrect')})
  try:
   with urllib.request.urlopen(req,timeout=5) as r:return r.status,json.load(r)
  except urllib.error.HTTPError as e:return e.code,json.load(e)
 def request(device='http-test',operation=None):
  r=dict(device=device,children=dict(qianyi=[],zhenyi=[]))
  if operation:r['operation']=operation
  return r
 try:
  start();assert exchange(request(),False)[0]==401
  status,result=exchange(request());assert status==200 and result['balances']==imported
  # All historical entries may be resent: no balance increase and no new expense.
  historical=json.loads(history.read_text());status,result=exchange(historical);assert status==200 and result['balances']==imported
  operations=[]
  for i in range(2):operations.append(request(f'device-{i}',dict(id=str(uuid.uuid4()),child='qianyi',kind='redemption',title='并发测试',points=cost,reference='')))
  with concurrent.futures.ThreadPoolExecutor(2) as pool:results=list(pool.map(exchange,operations))
  assert sorted(r[0] for r in results)==[200,409]
  winner=next(i for i,r in enumerate(results) if r[0]==200)
  status,result=exchange(operations[winner]);assert status==200 and result['balances']['qianyi']==0
  original=operations[winner]['operation']['id']
  refund=dict(id=str(uuid.uuid4()),child='qianyi',kind='refund',title='',points=0,reference=original)
  status,result=exchange(request('refund-device',refund));assert status==200 and result['balances']['qianyi']==cost
  refund['id']=str(uuid.uuid4());status,result=exchange(request('refund-device',refund));assert status==200 and result['balances']['qianyi']==cost
  backup=root/'backup.db';subprocess.check_call(args+['-backup',str(backup)]);assert backup.stat().st_size>0
  process.terminate();process.wait(timeout=5);start()
  status,result=exchange(request());assert status==200 and result['balances']==imported
  print('PASS: authenticated HTTP, real history import/resend, concurrent spending, lost-response retry, refund deduplication, live SQLite backup and process restart persistence')
 finally:
  if process and process.poll() is None:process.terminate();process.wait(timeout=5)
