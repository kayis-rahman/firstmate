import pathlib,subprocess,os,shutil
root=pathlib.Path.cwd();home=root/'.test-phase/hygiene-home';log=open('/Users/kayisrahman/.no-mistakes/evidence/01M7KH6C5G1XVHFRXS8H8NQ0BQ/live-hygiene.log','w');env=os.environ.copy()
for k in list(env):
 if k.startswith('FM_'):env.pop(k,None)
env.update(FM_HOME=str(home),HOME=str(home),TREEHOUSE_ROOT=str(home/'pool'))
try:
 for d in ['config','state','data/done-task/selected-images','data/active-task','pool']:(home/d).mkdir(parents=True,exist_ok=True)
 (home/'state/done-task.status').write_text('done\n')
 (home/'state/active-task.status').write_text('working: preserving this task\n')
 files={'data/done-task/large.png':204801,'data/done-task/boundary.png':204800,'data/done-task/selected-images/large.png':204801,'data/active-task/large.png':204801}
 for name,size in files.items():(home/name).write_bytes(b'x'*size)
 for execute in [False,True]:
  args=[str(root/'bin/fm-hygiene.sh'),'sweep','--treehouse-root',str(home/'pool')]+(['--yes'] if execute else [])
  p=subprocess.run(args,cwd=home,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=45)
  log.write('$ '+' '.join(args)+'\n'+p.stdout+f'[exit {p.returncode}]\n');log.flush();assert p.returncode==0,p.stdout
  assert '200.0KB' in p.stdout
  for name in files:assert (home/name).exists()==(not(execute and name=='data/done-task/large.png')),name
 log.write('Dry run preserved every file. Execute removed only the completed-task media above 204800 bytes; exact-boundary, selected, and active-task media survived.\n')
finally:shutil.rmtree(home,ignore_errors=True);log.close()
