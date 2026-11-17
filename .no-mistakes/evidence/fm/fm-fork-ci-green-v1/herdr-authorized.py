import os,pathlib,subprocess,shutil,time,json,shlex
root=pathlib.Path.cwd();lab=pathlib.Path(subprocess.check_output(['mktemp','-d','/tmp/fmv.XXXXXX'],text=True).strip()).resolve();home=lab/'home';helper=str(root/'bin/fm-herdr-lab.sh');session='fm-lab-proof-'+str(os.getpid())
f=open('/Users/kayisrahman/.no-mistakes/evidence/01M7KH6C5G1XVHFRXS8H8NQ0BQ/herdr-authorized.log','w')
env=os.environ.copy()
for k in list(env):
 if k.startswith(('FM_','HERDR_')) or k in ['TMUX','TMUX_PANE','NO_MISTAKES_GATE']:env.pop(k,None)
env.update(TMPDIR=str(lab),FM_HOME=str(home),HOME=str(lab/'user'),XDG_CONFIG_HOME=str(lab/'xdg'),FM_HERDR_LAB_STATE_DIR=str(lab/'guard'),HERDR_SESSION=session,TREEHOUSE_ROOT=str(lab/'pool'),FM_BACKEND='herdr',FM_FREE_MODEL_AXI='',FM_SPAWN_NO_GUARD='1',FM_POLL='1',FM_SIGNAL_GRACE='0',FM_CHECK_INTERVAL='999999',FM_HEARTBEAT='999999')
def run(args,check=True,timeout=90):
 p=subprocess.run(args,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
 f.write('$ '+json.dumps(args)+'\n'+p.stdout+f'[exit {p.returncode}]\n');f.flush()
 if check:assert p.returncode==0,p.stdout
 return p.stdout

def herdr(*args):return run([helper,'run',session,*args])
provisioned=False
try:
 (lab/'xdg/herdr').mkdir(parents=True);(lab/'user').mkdir()
 # Reference the genuine running fleet socket ONLY for the helper's read-only tripwire.
 (lab/'xdg/herdr/herdr.sock').symlink_to('/Users/kayisrahman/.config/herdr/herdr.sock')
 run(['bin/fm-lab-home.sh','create',str(home)]);(home/'config/herdr-presentation-spaces').write_text('off\n')
 run([helper,'prepare',session]);run([helper,'provision',session]);provisioned=True
 proj=lab/'project';proj.mkdir();run(['git','init','-q','-b','main',str(proj)]);(proj/'sample').write_text('disposable\n');run(['git','-C',str(proj),'add','.']);run(['git','-C',str(proj),'-c','user.name=Test','-c','user.email=test@example.invalid','commit','-qm','initial']);run(['git','clone','--bare',str(proj),str(lab/'origin.git')]);run(['git','-C',str(proj),'remote','add','origin',str(lab/'origin.git')])
 ws=json.loads(herdr('workspace','create','--cwd',str(proj),'--label','lab-launcher','--no-focus'))['result'];paneid=ws['root_pane']['pane_id'];wid=ws['workspace']['workspace_id']
 sessions=json.loads(herdr('session','list','--json'))['sessions']; socket=next(s['socket_path'] for s in sessions if s['name']==session)
 env.update(HERDR_ENV='1',HERDR_PANE_ID=paneid,HERDR_SOCKET_PATH=socket)
 task='proof';d=home/'data'/task;d.mkdir();(d/'brief.md').write_text('# Task\n## Captain\'s intent\nVerify isolated worker placement.\n## Firstmate spec\nRecord cwd then wait.\n');result=lab/'worker.result';cmd="pwd > "+shlex.quote(str(result))+"; sleep 300"
 run(['bin/fm-spawn.sh',task,str(proj),cmd,'--mode','local-only','--yolo','off','--backend','herdr'],timeout=150)
 for _ in range(100):
  if result.exists():break
  time.sleep(.2)
 assert result.exists(),'worker did not execute'
 meta=dict(line.split('=',1) for line in (home/'state/proof.meta').read_text().splitlines() if '=' in line)
 f.write('Persisted task metadata: '+json.dumps(meta)+'\nActual worker cwd: '+result.read_text());f.flush();assert result.read_text().strip()==meta['worktree']
 target=meta['window'];f.write('Target: '+target+'\n');f.flush()
 # Backend's public target encodes session:tab:pane; use persisted exact pane identity.
 worker_pane=meta['herdr_pane_id']
 got=json.loads(herdr('pane','get',worker_pane))['result']['pane'];assert got['workspace_id']==wid,(got,wid)
 herdr('pane','read',worker_pane,'--format','text')
 (home/'state/proof.status').write_text('working: disposable endpoint loss check\n')
 run(['bash','-c','. bin/fm-wake-lib.sh; fm_wake_status_mark_current "$FM_HOME/state" "$FM_HOME/state/proof.status"'])
 herdr('pane','close',worker_pane)
 for k in ['HERDR_ENV','HERDR_PANE_ID']:env.pop(k,None)
 out=run(['bin/fm-watch.sh'],timeout=40);assert out.count('endpoint disappeared')==1,out
 queue=(home/'state/.wake-queue').read_text();f.write('Actual wake queue:\n'+queue);f.flush();assert queue.count('endpoint disappeared')==1
 f.write('PASS: real Herdr worker ran in its recorded worktree and launcher workspace; destroyed endpoint generated one durable disappearance wake.\n')
finally:
 if provisioned:run([helper,'teardown',session],check=True)
 for p in lab.rglob('*'):
  if p.is_dir() and not p.is_symlink():p.chmod(p.stat().st_mode|0o700)
 shutil.rmtree(lab);f.write('Guarded teardown completed; only disposable lab removed.\n');f.close()
