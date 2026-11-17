import os,pathlib,subprocess,shutil,time,shlex
root=pathlib.Path.cwd();home=root/'.test-phase/spawn-home';sock=root/'.s';world=root/'.test-phase/spawn-world'
f=open('/Users/kayisrahman/.no-mistakes/evidence/01M7KH6C5G1XVHFRXS8H8NQ0BQ/live-spawn.log','w')
env=os.environ.copy()
for k in list(env):
 if k.startswith(('FM_','HERDR_','CLAUDE_')) or k in ['TMUX','TMUX_PANE','NO_MISTAKES_GATE']:env.pop(k,None)
env.update(FM_HOME=str(home),HOME=str(home/'user'),TREEHOUSE_ROOT=str(world/'pool'),FM_BACKEND='tmux',FM_FREE_MODEL_AXI='',FM_SPAWN_NO_GUARD='1',CHROME_DEVTOOLS_AXI_IDLE_TIMEOUT_MS='1',CLAUDE_CONFIG_DIR='')
def run(args,check=True,timeout=120,cwd=None):
 p=subprocess.run(args,env=env,cwd=cwd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
 f.write('$ '+' '.join(map(str,args))+'\n'+p.stdout+f'[exit {p.returncode}]\n');f.flush()
 if check:assert p.returncode==0,p.stdout
 return p.stdout
try:
 run(['bin/fm-lab-home.sh','create',str(home)]);(home/'user').mkdir();world.mkdir()
 proj=world/'project';proj.mkdir()
 run(['git','init','-q','-b','main',str(proj)])
 (proj/'sample.txt').write_text('Disposable source\n');run(['git','-C',str(proj),'add','.'])
 run(['git','-C',str(proj),'-c','user.name=Test','-c','user.email=test@example.invalid','commit','-qm','initial'])
 run(['git','clone','--bare',str(proj),str(world/'origin.git')]);run(['git','-C',str(proj),'remote','add','origin',str(world/'origin.git')])
 run(['tmux','-S',str(sock),'new-session','-d','-s','firstmate','-x','120','-y','40','-c',str(root),'/bin/bash'])
 server=run(['tmux','-S',str(sock),'display-message','-p','-t','firstmate','#{pid}']).strip();env['TMUX']=str(sock)+','+server+',0'
 for mode in ['absent','allowlist']:
  if mode=='allowlist':(home/'config/launch-env-allowlist').touch()
  task='env-'+mode;d=home/'data'/task;d.mkdir();(d/'brief.md').write_text('# Task\n## Captain\'s intent\nVerify the real custom-command worker environment.\n\n## Firstmate spec\nRecord cwd and browser timeout, then remain available for inspection.\n')
  result=world/(task+'.result')
  cmd="printf '%s\\n' \"$PWD\" \"$CHROME_DEVTOOLS_AXI_IDLE_TIMEOUT_MS\" > "+shlex.quote(str(result))+"; sleep 300"
  run(['bin/fm-spawn.sh',task,str(proj),cmd,'--mode','local-only','--yolo','off','--backend','tmux'],timeout=150)
  for _ in range(100):
   if result.exists():break
   time.sleep(.1)
  assert result.exists(),task+' worker never executed'
  lines=result.read_text().splitlines();f.write('Actual worker output '+task+':\n'+result.read_text());f.flush();assert lines[1]=='1800000',lines
  meta=(home/f'state/{task}.meta').read_text();f.write('Published task metadata:\n'+meta);f.flush()
  wt=[line[9:] for line in meta.splitlines() if line.startswith('worktree=')][0];assert lines[0]==wt and wt!=str(proj),(lines,wt)
  target=[line[7:] for line in meta.splitlines() if line.startswith('window=')][0]
  run(['tmux','-S',str(sock),'capture-pane','-p','-t',target])
 f.write('Both real custom-command launches received the fixed timeout and ran in their recorded isolated worktrees.\n')
finally:
 if sock.exists():run(['tmux','-S',str(sock),'kill-server'],check=False)
 for directory in [home,world]:
  if directory.exists():
   for p in directory.rglob('*'):
    if p.is_dir():p.chmod(p.stat().st_mode|0o700)
   shutil.rmtree(directory)
 f.write('Private tmux server stopped; disposable project, origin, home and pool removed.\n');f.close()
