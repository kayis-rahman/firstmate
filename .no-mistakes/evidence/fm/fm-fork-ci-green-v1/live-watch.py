import os,pathlib,subprocess,shutil
root=pathlib.Path.cwd();home=root/'.test-phase/watch-home';sock=root/'.s'
f=open('/Users/kayisrahman/.no-mistakes/evidence/01M7KH6C5G1XVHFRXS8H8NQ0BQ/live-watch.log','w')
env=os.environ.copy()
for k in ['FM_ROOT_OVERRIDE','FM_STATE_OVERRIDE','FM_DATA_OVERRIDE','FM_CONFIG_OVERRIDE','FM_PROJECTS_OVERRIDE','TMUX','TMUX_PANE','HERDR_SESSION','HERDR_ENV','HERDR_SOCKET_PATH']:env.pop(k,None)
env.update(FM_HOME=str(home),FM_BACKEND='tmux',FM_POLL='1',FM_SIGNAL_GRACE='0',FM_CHECK_INTERVAL='999999',FM_HEARTBEAT='999999',FM_SECONDMATE_LIVENESS_SECS='99999999',FM_FREE_MODEL_AXI='')
def run(args):
 p=subprocess.run(args,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60)
 f.write('$ '+' '.join(map(str,args))+'\n'+p.stdout+f'[exit {p.returncode}]\n');f.flush();assert p.returncode==0,p.stdout;return p.stdout
p=None
try:
 run(['bin/fm-lab-home.sh','create',str(home)])
 run(['tmux','-S',str(sock),'new-session','-d','-s','fm-lab-watch','-x','120','-y','40','-c',str(root),'/bin/bash'])
 run(['tmux','-S',str(sock),'new-window','-d','-t','fm-lab-watch','-n','fm-vanished','sleep 300'])
 server=run(['tmux','-S',str(sock),'display-message','-p','-t','fm-lab-watch','#{pid}']).strip()
 env['TMUX']=str(sock)+','+server+',0'
 (home/'state/vanished.meta').write_text('window=fm-lab-watch:fm-vanished\nkind=ship\nbackend=tmux\nharness=claude\n')
 (home/'state/vanished.status').write_text('working: compiling\n')
 run(['bash','-c','. bin/fm-wake-lib.sh; fm_wake_status_mark_current "$FM_HOME/state" "$FM_HOME/state/vanished.status"'])
 run(['tmux','-S',str(sock),'kill-window','-t','fm-lab-watch:fm-vanished'])
 p=subprocess.Popen(['bin/fm-watch.sh'],env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 output=p.communicate(timeout=30)[0];f.write('$ bin/fm-watch.sh\n'+output+f'[exit {p.returncode}]\n');f.flush()
 assert p.returncode==0 and output.count('endpoint disappeared')==1,output
 queue=(home/'state/.wake-queue').read_text();f.write('Persisted wake queue:\n'+queue);assert queue.count('endpoint disappeared')==1
 f.write('Live tmux worker disappearance was surfaced and queued exactly once.\n')
finally:
 if p and p.poll() is None:p.terminate();p.wait(timeout=10)
 if sock.exists():run(['tmux','-S',str(sock),'kill-server'])
 shutil.rmtree(home,ignore_errors=True)
 f.write('Private tmux server stopped; disposable home removed.\n');f.close()
