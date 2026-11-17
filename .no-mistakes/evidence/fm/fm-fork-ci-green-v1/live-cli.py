import os,subprocess,pathlib,hashlib,json,shutil
root=pathlib.Path.cwd(); home=root/'.test-phase/live-home'; copy=root/'.test-phase/shared-copy'
evidence=pathlib.Path('/Users/kayisrahman/.no-mistakes/evidence/01M7KH6C5G1XVHFRXS8H8NQ0BQ/live-cli.log')
env=os.environ.copy()
for k in ['FM_ROOT_OVERRIDE','FM_STATE_OVERRIDE','FM_DATA_OVERRIDE','FM_CONFIG_OVERRIDE','FM_PROJECTS_OVERRIDE','FM_TEST_HARNESS','CLAUDECODE','PI_CODING_AGENT','FM_PI_HARNESS','FM_SUPERVISION_PRIMARY_HARNESS']:env.pop(k,None)
env.update(FM_HOME=str(home),HOME=str(home),FM_BOOTSTRAP_DETECT_ONLY='1',FM_BOOTSTRAP_NETWORK='skip',FM_FREE_MODEL_AXI='',AI_AGENT='pig')
f=evidence.open('w')
def run(args,expect=0):
 p=subprocess.run(args,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=90)
 f.write('$ '+' '.join(args)+'\n'+p.stdout+f'[exit {p.returncode}]\n');f.flush()
 assert p.returncode==expect,(args,p.stdout,p.returncode)
 return p.stdout
try:
 run(['bin/fm-lab-home.sh','create',str(home)])
 copy.mkdir()
 for task in ['alpha','beta']:(home/f'state/{task}.meta').write_text(f'project={copy}\nworktree={copy}\nharness=pi\nkind=ship\n')
 before={p.name:p.read_bytes() for p in (home/'state').iterdir() if p.is_file()}
 output=run(['bin/fm-bootstrap.sh']);assert 'COLLISION:' in output and 'alpha/worktree' in output and 'beta/worktree' in output
 assert all((home/'state'/n).read_bytes()==b for n,b in before.items())
 (home/'state/beta.meta').unlink()
 output=run(['bin/fm-bootstrap.sh']);assert 'COLLISION:' not in output
 run(['bin/fm-busy-event.sh','apply',str(home/'state'),'alpha','busy','--current-gen','--source','pi-ext','--event','agent-start'],1)
 record=home/'state/alpha.busy-event-last-error'; assert record.exists();f.write('Persisted hook failure: '+record.read_text())
 assert record.stat().st_mode & 0o777==0o600
 output=run(['bin/fm-bootstrap.sh']);assert 'HOOK_LAST_ERROR: task alpha' in output
 gen=run(['bin/fm-busy-event.sh','arm',str(home/'state'),'alpha']).strip();assert not record.exists()
 run(['bin/fm-busy-event.sh','apply',str(home/'state'),'alpha','idle','--gen','stale-generation','--source','pi-ext','--event','agent-end'],1)
 assert gen in (home/'state/alpha.busy-gen').read_text()
 run(['bin/fm-busy-event.sh','retire',str(home/'state'),'alpha','--current-gen']); assert not record.exists()
 output=run(['bin/fm-bootstrap.sh']);assert 'HOOK_LAST_ERROR:' not in output
 env['FM_SUPERVISION_PRIMARY_HARNESS']='pig'
 env['FM_SUPERVISION_ACTOR']='branch'
 output=run(['bin/fm-afk-launch.sh','enter','--words','Disposable verification only.']);assert (home/'state/.afk-contract').exists()
 output=run(['bin/fm-afk-launch.sh','start'],1);assert 'no longer launched on pig' in output
 output=run(['bin/fm-afk-launch.sh','stop']);assert not (home/'state/.afk-contract').exists()
 env['FM_SUPERVISION_MODEL']='unverified'
 output=run(['bin/fm-inbox.sh','ready']);j=json.loads(output);assert j['wake_consumer']['state']=='unknown' and j['wake_consumer']['reason']=='supervision-unverified' and j['can_receive']==False;f.write('Parsed ready output: '+json.dumps(j)+'\n')
 f.write('All live CLI assertions passed. Disposable home and shared copy removed in finally.\n')
finally:
 shutil.rmtree(home,ignore_errors=True);shutil.rmtree(copy,ignore_errors=True);f.close()
