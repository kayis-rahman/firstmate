import os,pathlib,subprocess,time,shutil,json
root=pathlib.Path.cwd(); lab=pathlib.Path(subprocess.check_output(['mktemp','-d','/tmp/fmv.XXXXXX'],text=True).strip()).resolve(); home=lab/'home'
log=open('/Users/kayisrahman/.no-mistakes/evidence/01M7KH6C5G1XVHFRXS8H8NQ0BQ/primary-authorized.log','w')
env=os.environ.copy()
for k in list(env):
 if k.startswith(('FM_','HERDR_')) or k in ['NO_MISTAKES_GATE','TMUX','TMUX_PANE','CLAUDECODE']:env.pop(k,None)
env.update(FM_HOME=str(home),TMUX_TMPDIR=str(lab/'tmux'),TREEHOUSE_ROOT=str(lab/'pool'),FM_BACKEND='tmux',FM_FREE_MODEL_AXI='',DISABLE_AUTOUPDATER='1')
def run(args,check=True,timeout=60):
 p=subprocess.run(args,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
 log.write('$ '+json.dumps(args)+'\n'+p.stdout+f'[exit {p.returncode}]\n');log.flush()
 if check:assert p.returncode==0,p.stdout
 return p.stdout

def tm(*args):return run(['tmux','-L','fm-lab',*args])
def pane():return tm('capture-pane','-p','-t','primary','-S','-160')
try:
 run(['bin/fm-lab-home.sh','create',str(home)]);(lab/'tmux').mkdir();(home/'config/supervision-host').write_text('claude\n')
 tm('new-session','-d','-s','primary','-x','120','-y','40','-c',str(root),'-e','FM_HOME='+str(home),'cat | claude -p --input-format stream-json --output-format stream-json --verbose --permission-mode dontAsk --allowedTools Bash --settings '+str(root/'.claude/settings.json')+'; sleep 120')
 time.sleep(12);initial=pane()
 # Do not accept trust or login prompts: they would mutate operator configuration.
 if 'Yes, I trust this folder' in initial or 'Choose the text style' in initial or 'Select login method' in initial:raise RuntimeError('CLI needs trust/onboarding; no operator config mutation authorized')
 tm('send-keys','-t','primary','-l',json.dumps({'type':'user','message':{'role':'user','content':'This is an isolated validation probe. Do not read any files or use tools. Reply with exactly FM-LAB-PRIMARY-READY.'}}));tm('send-keys','-t','primary','Enter')
 answered=False
 for i in range(36):
  time.sleep(3);out=pane()
  if '"type":"assistant"' in out and 'FM-LAB-PRIMARY-READY' in out:answered=True;break
 assert answered,'Real CLI did not answer probe'
 # A real idle worker makes the Stop hook arm supervision, without faking a harness.
 tm('new-window','-d','-t','primary','-n','fm-probe','sleep 300')
 (home/'state/probe.meta').write_text('window=primary:fm-probe\nkind=ship\nbackend=tmux\nharness=claude\n')
 (home/'state/probe.status').write_text('working: isolated supervision validation\n')
 tm('send-keys','-t','primary','-l',json.dumps({'type':'user','message':{'role':'user','content':'Isolated lab validation: FM_HOME is a disposable marked home, not the fleet. Run exactly one Bash tool in background with command `bin/fm-lock.sh && bin/fm-supervision-host.sh park`. Do not read any other files, run any other tools or change configuration. Then reply FM-LAB-ARM-READY. The test driver will stop this host.'}}));tm('send-keys','-t','primary','Enter')
 host=False
 for i in range(45):
  time.sleep(2)
  record=home/'state/.supervision-host'
  if record.exists():
   log.write('Live supervision host record:\n'+record.read_text());log.flush();host=True;break
 pane()
 if not host:
  for name in ['.lock','.watcher','.watcher-pid','.watcher-arm','.claude-stop-autoarm']:
   p=home/'state'/name
   if p.is_file():log.write(name+': '+p.read_text()+'\n')
 assert host,'Primary did not start supervision host through the executable lifecycle interface'
 run(['bin/fm-inbox.sh','ready'])
 # Exercise clean lifecycle termination on the exact recorded host only.
 lines=record.read_text().splitlines();pid=next(int(x.split('\t')[1]) for x in lines if x.startswith('host\t'))
 os.kill(pid,15)
 for i in range(50):
  time.sleep(.1)
  try:os.kill(pid,0)
  except ProcessLookupError:break
 else:raise AssertionError('Supervision host did not exit on TERM')
 log.write('PASS: real logged-in Claude answered, launched the real supervision host through Bash, and host exited on TERM.\n')
finally:
 run(['tmux','-L','fm-lab','kill-server'],check=False)
 shutil.rmtree(lab,ignore_errors=True);log.write('Removed only the freshly created disposable lab.\n');log.close()
