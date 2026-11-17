import os, pty,fcntl,termios,struct,subprocess,time,select,pathlib,json,shutil,signal
R=pathlib.Path.cwd(); H=R/'.live-test/pig-home'; U=R/'.live-test/pig-user'; E=pathlib.Path('/Users/kayisrahman/.no-mistakes/evidence/01M7KH6C5G1XVHFRXS8H8NQ0BQ/pig-readiness.txt'); log=[]; p=None
try:
 subprocess.run(['bin/fm-lab-home.sh','create',str(H)],check=True,stdout=subprocess.PIPE); U.mkdir()
 env=os.environ.copy()
 for k in ['FM_ROOT_OVERRIDE','FM_STATE_OVERRIDE','FM_DATA_OVERRIDE','FM_CONFIG_OVERRIDE','FM_PROJECTS_OVERRIDE','PI_CODING_AGENT','FM_PI_HARNESS']:env.pop(k,None)
 env.update(HOME=str(U),XDG_CONFIG_HOME=str(U/'.config'),XDG_DATA_HOME=str(U/'.local/share'),FM_HOME=str(H),TERM='xterm-256color',FM_SUPERVISION_MODEL='extension')
 m,s=pty.openpty();fcntl.ioctl(s,termios.TIOCSWINSZ,struct.pack('HHHH',40,120,0,0))
 p=subprocess.Popen(['pig','--no-context-files'],env=env,stdin=s,stdout=s,stderr=s,start_new_session=True);os.close(s)
 end=time.time()+10;screen=b''
 while time.time()<end:
  if select.select([m],[],[],0.2)[0]:
   try:screen+=os.read(m,65536)
   except OSError:break
  if p.poll() is not None:break
 log.append('Actual CLI: pig --no-context-files; PTY 40x120; isolated HOME; no credentials supplied.\n'+screen.decode(errors='replace'))
 assert p.poll() is None,'PiG exited before readiness inspection'
 (H/'state/.lock').write_text(str(p.pid)+'\n')
 proc=subprocess.run(['bin/fm-inbox.sh','ready'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True);log.append('$ FM_SUPERVISION_MODEL=extension bin/fm-inbox.sh ready\n'+proc.stdout)
 obj=json.loads(proc.stdout);assert obj['wake_consumer']['state']=='unknown' and obj['wake_consumer']['reason']=='supervision-unverified',obj
 log.append('ASSERTION: real live PiG lock owner remains unverified despite extension override.\n')
finally:
 if p is not None and p.poll() is None:
  os.killpg(p.pid,signal.SIGTERM)
  try:p.wait(timeout=5)
  except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait()
 E.write_text('\n'.join(log));shutil.rmtree(H,ignore_errors=True);shutil.rmtree(U,ignore_errors=True)
