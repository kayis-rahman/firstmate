import os, pathlib, subprocess, time, json, shutil
root = pathlib.Path.cwd()
ev = pathlib.Path('/Users/kayisrahman/.no-mistakes/evidence/01M7MEESXX8M7SXBFJ9PBF9C0A')
lab = root / '.test-tmp/live-home'
sock = str(root / '.test-tmp/s')
log = []
results = []
env = os.environ.copy()
for k in ['TMUX','FM_ROOT_OVERRIDE','FM_STATE_OVERRIDE','FM_DATA_OVERRIDE','FM_CONFIG_OVERRIDE','FM_PROJECTS_OVERRIDE','FM_BACKEND','HERDR_ENV','HERDR_SESSION','HERDR_SOCKET_PATH','HERDR_PANE_ID']:
    env.pop(k, None)
env.update(FM_HOME=str(lab), FM_SEND_SETTLE='0')
def run(args, **kw):
    return subprocess.run(args, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, **kw)
def tmux(*args):
    p = run(['tmux','-S',sock,*args])
    if p.returncode: raise RuntimeError(p.stderr)
    return p.stdout
baseline = root / 'bin/.fm-send-baseline-live.sh'
try:
    p = run(['bin/fm-lab-home.sh','create',str(lab)])
    assert p.returncode == 0, p.stderr
    tmux('new-session','-d','-s','idlecheck','-n','fm-t1','-x','120','-y','40','cat')
    server_pid = tmux('display-message','-p','-t','idlecheck:fm-t1','#{pid}').strip()
    env['TMUX'] = f'{sock},{server_pid},0'
    log += ['Real product: bin/fm-send.sh; real private tmux endpoint idlecheck:fm-t1 (cat recipient).',
            'Task metadata and clock-aged state are disposable fixtures; no model execution or authentication claimed.',
            'Private tmux grid: 120 columns x 40 rows. All paths stay in the gate worktree.']
    state = lab/'state'
    flag = lab/'config/idle-steer-guard'
    def case(name, harness, age, contents='', expected=0, limit=None, model=None, args=None, status_age=None, executable='bin/fm-send.sh'):
        for p in list(state.iterdir()):
            if p.is_dir(): shutil.rmtree(p)
            else: p.unlink()
        (state/'t1.meta').write_text(f'window=idlecheck:fm-t1\nbackend=tmux\nkind=ship\nharness={harness}\n' + (f'model={model}\n' if model else ''))
        if contents is None:
            flag.unlink(missing_ok=True)
        else:
            flag.write_text(contents)
        if age is not None:
            (state/'t1.turn-ended').touch()
            t = time.time() - age * 60
            os.utime(state/'t1.turn-ended',(t,t))
        if status_age is not None:
            (state/'t1.status').write_text('working: disposable progress\n')
            t = time.time() - status_age * 60
            os.utime(state/'t1.status',(t,t))
        message = f'Live idle guard check: {name}'
        cmd = [executable,'t1',*(args or []),message]
        p = run(cmd)
        records = list((state/'t1.inbox').glob('*.msg'))
        log.extend([f'\n=== {name} ===', f'harness={harness}, model={model}, idle_minutes={age}, status_age={status_age}, flag_contents={contents!r}',
                    '$ ' + ' '.join(cmd), f'exit={p.returncode}', p.stdout.rstrip(), p.stderr.rstrip(), f'durable_records={len(records)}'])
        assert (p.returncode == expected), f'{name}: exit {p.returncode} expected {expected}'
        assert len(records) == (1 if expected == 0 else 0), f'{name}: wrong durable state'
        if limit and expected != 0: assert f'limit {limit}' in p.stderr
        if records:
            body = run(['bash','-c','. "$1"; fm_task_inbox_body "$2"','_',str(root/'bin/fm-task-inbox-lib.sh'),str(records[0])])
            assert body.returncode == 0 and body.stdout.rstrip('\n') == message, (name, body.stdout, body.stderr)
            log.extend(['Persisted inbox body: ' + body.stdout.rstrip()])
        results.append({'name':name,'exit':p.returncode,'records':len(records),'pass':True})
    # Fixed boundaries, including the exact minute which is still allowed.
    for h,limit in [('claude',60),('codex',40)]:
        for age in [limit-1,limit,limit+1]:
            case(f'{h}-{age}m-empty-flag',h,age,expected=0 if age<=limit else 1,limit=limit)
    # Actively attempt both legacy override formats, in both directions.
    for h,limit in [('claude',60),('codex',40)]:
        for label,contents in [('bare-low','1'),('bare-high','999'),('family-low','claude=1\ncodex=1'),('family-high','claude=999\ncodex=999')]:
            for age in [limit-1,limit+1]:
                case(f'{h}-{label}-{age}m',h,age,contents,expected=0 if age<limit else 1,limit=limit)
    for h,m,limit in [('pi','openai-codex/gpt-5',40),('pi-signed','openai-codex/gpt-5',40),('pi','other/model',60),('other',None,60)]:
        case(f'{h}-{m}-50m',h,50,'999\nclaude=999\ncodex=999',expected=1 if limit==40 else 0,limit=limit,model=m)
    case('flag-absent-disables-guard','claude',500,None)
    case('missing-turn-end-does-not-block','codex',None,'1')
    case('fresh-status-keeps-worker-warm','codex',90,'1',status_age=1)
    for path in ['steer','relaunch','handoff']:
        case('explicit-confirmation-'+path,'codex',90,'999',args=['--idle-path',path])
    time.sleep(1)
    log += ['\n=== Real private tmux recipient capture ===', tmux('capture-pane','-p','-t','idlecheck:fm-t1')]
    # Before/after reproduction against the base's real executable in its own bin directory.
    source = run(['git','show','cda7e75253c8c0b83a2676aac441cda1ae116c85:bin/fm-send.sh'])
    assert source.returncode == 0
    baseline.write_text(source.stdout)
    baseline.chmod(0o755)
    case('BASELINE-reproduces-bare-999-bypass','codex',41,'999',expected=0,executable=str(baseline))
    case('BASELINE-reproduces-family-1-premature-refusal','claude',59,'claude=1',expected=1,limit=1,executable=str(baseline))
    log += ['\nAll live checks and before/after reproductions matched expected behavior.']
finally:
    if pathlib.Path(sock).exists():
        p=run(['tmux','-S',sock,'kill-server'])
        log += [f'\nPrivate tmux teardown exit={p.returncode}']
    baseline.unlink(missing_ok=True)
    shutil.rmtree(lab,ignore_errors=True)
    log += ['Disposable task home removed.']
    (ev/'idle-guard-live-transcript.txt').write_text('\n'.join(log)+'\n')
    (ev/'idle-guard-live-results.json').write_text(json.dumps(results,indent=2)+'\n')
print(f'Completed {len(results)} real CLI checks; transcript: {ev}/idle-guard-live-transcript.txt')
