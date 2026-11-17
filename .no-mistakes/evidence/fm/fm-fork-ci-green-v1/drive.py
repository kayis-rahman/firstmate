import os, pathlib, subprocess, hashlib, json, shutil
R=pathlib.Path.cwd(); root=R/'.live-test/manual'; root.mkdir(); E=pathlib.Path('/Users/kayisrahman/.no-mistakes/evidence/01M7KH6C5G1XVHFRXS8H8NQ0BQ')
log=[]
def call(args,env=None,ok=0):
 e=os.environ.copy()
 for k in ['FM_ROOT_OVERRIDE','FM_STATE_OVERRIDE','FM_DATA_OVERRIDE','FM_CONFIG_OVERRIDE','FM_PROJECTS_OVERRIDE']: e.pop(k,None)
 e.update(FM_HOME=str(root),TMPDIR=str(R/'.live-test/tmp'))
 if env:e.update(env)
 p=subprocess.run(args,env=e,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 log.append('$ '+' '.join(args)+'\n'+p.stdout+f'[exit={p.returncode}]\n')
 if ok is not None: assert p.returncode==ok,p.stdout
 return p.stdout
try:
 call(['bin/fm-lab-home.sh','create',str(root)])
 s=root/'state'; c=root/'config'; d=root/'data'
 gen=call(['bin/fm-busy-event.sh','arm',str(s),'probe']).strip()
 call(['bin/fm-busy-event.sh','apply',str(s),'probe','busy','--gen','stale-incarnation','--source','pi-ext','--event','agent-start'],ok=1)
 record=s/'probe.busy-event-last-error'; assert 'stale busy-state gen' in record.read_text(); assert record.stat().st_mode&0o777==0o600
 out=call(['bin/fm-bootstrap.sh'],{'FM_BOOTSTRAP_DETECT_ONLY':'1','FM_BOOTSTRAP_NETWORK':'skip'}); assert 'HOOK_LAST_ERROR: task probe' in out
 call(['bin/fm-busy-event.sh','arm',str(s),'probe']); assert not record.exists()
 call(['bin/fm-busy-event.sh','apply',str(s),'probe','busy','--gen',gen,'--source','pi-ext','--event','agent-start'],ok=1)
 call(['bin/fm-busy-event.sh','retire',str(s),'probe','--current-gen']); assert not record.exists()
 copy=root/'copy'; copy.mkdir()
 for name in ['a','b']: (s/f'{name}.meta').write_text(f'kind=ship\nharness=claude\nworktree={copy}\nproject={copy}\n')
 before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in s.glob('*.meta')}
 out=call(['bin/fm-bootstrap.sh'],{'FM_BOOTSTRAP_DETECT_ONLY':'1','FM_BOOTSTRAP_NETWORK':'skip'}); assert 'COLLISION:' in out and 'a/worktree' in out and 'b/worktree' in out
 assert before=={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in s.glob('*.meta')}
 (s/'b.meta').unlink(); out=call(['bin/fm-bootstrap.sh'],{'FM_BOOTSTRAP_DETECT_ONLY':'1','FM_BOOTSTRAP_NETWORK':'skip'}); assert 'COLLISION:' not in out
 (s/'done.status').write_text('state: done\n'); (d/'done'/'selectedfoo').mkdir(parents=True)
 big=d/'done'/'big.png'; big.write_bytes(bytes(256000)); small=d/'done'/'small.png'; small.write_bytes(b'keep'); selected=d/'done'/'selectedfoo'/'keep.png'; selected.write_bytes(bytes(256000))
 out=call(['bin/fm-hygiene.sh','sweep','--treehouse-root',str(root/'treehouse')]); assert big.exists() and 'would remove media' in out
 out=call(['bin/fm-hygiene.sh','sweep','--yes','--treehouse-root',str(root/'treehouse')]); assert not big.exists() and small.exists() and selected.exists()
 out=call(['bin/fm-inbox.sh','ready']); assert json.loads(out)['wake_consumer']['state']=='unknown'
 call(['bin/fm-model-preflight.sh',''],{'FM_FREE_MODEL_AXI':''})
 log.append('ASSERTIONS: stale generation refused; private error surfaced and cleared on arm/retire; collision reported without editing metadata; sole claim silent; dry-run preserved media; sweep removed only oversized unselected media; readiness without a lock honest unknown; absent advisor tolerated.\n')
finally:
 (E/'live-cli-transcript.txt').write_text('\n'.join(log)); shutil.rmtree(root)
