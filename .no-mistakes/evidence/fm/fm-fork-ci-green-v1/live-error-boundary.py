import pathlib,subprocess,os,shutil,json
root=pathlib.Path.cwd();home=root/'.test-phase/error-home';log=open('/Users/kayisrahman/.no-mistakes/evidence/01M7KH6C5G1XVHFRXS8H8NQ0BQ/live-error-boundary.log','w');env=os.environ.copy()
for k in list(env):
 if k.startswith('FM_'):env.pop(k,None)
env.update(FM_HOME=str(home),HOME=str(home),FM_BOOTSTRAP_DETECT_ONLY='1',FM_BOOTSTRAP_NETWORK='skip')
results=[]
def run(args):
 p=subprocess.run(args,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=30)
 log.write('$ '+json.dumps(args)+'\n'+p.stdout+f'[exit {p.returncode}]\n');log.flush();return p
try:
 assert run(['bin/fm-lab-home.sh','create',str(home)]).returncode==0
 gen=run(['bin/fm-busy-event.sh','arm',str(home/'state'),'alpha']).stdout.strip()
 for source,event in [('pi-ext\nsecond-line','agent-start'),('pi-ext','agent-start\nsecond-line')]:
  p=run(['bin/fm-busy-event.sh','apply',str(home/'state'),'alpha','busy','--gen',gen,'--source',source,'--event',event]);assert p.returncode==1
  record=(home/'state/alpha.busy-event-last-error').read_text();log.write('Persisted last-error record (JSON-escaped): '+json.dumps(record)+'\n')
  output=run(['bin/fm-bootstrap.sh']).stdout
  result={'invalid_field':'source' if '\n' in source else 'event','record_lines':len(record.splitlines()),'bootstrap_names_error': 'error=invalid' in output,'generation_unchanged':(home/'state/alpha.busy-gen').read_text().strip()==gen}
  results.append(result);log.write('Observed boundary result: '+json.dumps(result)+'\n');log.flush()
 assert all(r['record_lines']==1 and r['bootstrap_names_error'] and r['generation_unchanged'] for r in results),results
finally:shutil.rmtree(home,ignore_errors=True);log.write('Disposable error home removed.\n');log.close()
