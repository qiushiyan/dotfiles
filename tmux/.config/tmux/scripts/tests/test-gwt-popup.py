#!/usr/bin/env python3
"""Real fzf/tmux creation on a private socket and temporary HOME/roots.

Requires gwt, tmux, fzf on PATH. Optional first argument: alternate popup script.
"""
import os, pathlib, shutil, subprocess, tempfile, time, shlex, json, sys
D = pathlib.Path(__file__).resolve().parents[5]
B = shutil.which('gwt')
if not B:
    raise SystemExit('Install gwt on PATH before running the popup test.')
popup = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else D/'tmux/.config/tmux/scripts/tmux-worktree.sh'
with tempfile.TemporaryDirectory(prefix='gwt-smoke-') as td:
    td = str(pathlib.Path(td).resolve())
    home = pathlib.Path(td)
    env = os.environ.copy()
    env.update(HOME=td, XDG_CONFIG_HOME=td+'/config', GIT_CONFIG_GLOBAL='/dev/null', GIT_CONFIG_NOSYSTEM='1', TERM='xterm-256color')
    for key in ('TMUX','GIT_DIR','GIT_WORK_TREE','GIT_INDEX_FILE','GIT_COMMON_DIR','GWT_CONFIG'):
        env.pop(key, None)
    def run(args, cwd=None, check=True, **kw):
        return subprocess.run(args, cwd=cwd, env=env, check=check, text=True, capture_output=True, timeout=20, **kw)
    root = home/"custom trees' root"
    config = home/'config/gwt/config.toml'
    config.parent.mkdir(parents=True)
    config.write_text('base = "HEAD"\nworktree_root = '+json.dumps(str(root))+'\ncopy_globs = [".env*"]\nfetch.max_age = "90s"\n')
    repo = home/'repo with spaces' 
    run(['git','init','-q','-b','main',str(repo)])
    (repo/'.gitignore').write_text('.env*\n')
    run(['git','add','.'], repo)
    run(['git','-c','user.name=Test','-c','user.email=test@example.invalid','commit','-qm','initial'], repo)
    (repo/'.env').write_text('smoke-secret')
    bindir = home/'.local/bin'; bindir.mkdir(parents=True)
    shutil.copy2(B, bindir/'gwt')
    env['PATH'] = str(bindir)+':'+env['PATH']
    run(['git','checkout','-qb','caller-topic'], repo)
    run(['git','-c','user.name=Test','-c','user.email=test@example.invalid','commit','--allow-empty','-qm','caller HEAD differs from main'], repo)
    caller_sha = run(['git','rev-parse','HEAD'],repo).stdout.strip()
    sock = str(home/'tmux.sock')
    tmux=['tmux','-S',sock]
    try:
        run(tmux+['-f','/dev/null','new-session','-d','-s','smoke','-c',str(repo),'/bin/bash --noprofile --norc'])
        run(tmux+['set-option','-g','default-shell','/bin/bash'])
        run(tmux+['set-option','-g','default-command','/bin/bash --noprofile --norc'])
        run(tmux+['set-option','-g','@worktree_auto_install','off'])
        run(tmux+['set-option','-g','@worktree_post_create_cmd','test -f .env && echo POST_CREATE_OK'])
        pane=run(tmux+['display-message','-p','-t','smoke:0','#{pane_id}']).stdout.strip()
        command='/bin/bash '+shlex.quote(str(popup))
        run(tmux+['send-keys','-t',pane,'-l',command]); run(tmux+['send-keys','-t',pane,'Enter'])
        deadline=time.monotonic()+8
        while time.monotonic()<deadline:
            cap=run(tmux+['capture-pane','-pt',pane]).stdout
            if 'enter switch/create' in cap: break
            time.sleep(.1)
        else: raise AssertionError('picker not ready: '+cap)
        run(tmux+['send-keys','-t',pane,'-l','feat/popup'])
        run(tmux+['send-keys','-t',pane,'C-n'])
        deadline=time.monotonic()+8
        while time.monotonic()<deadline:
            rows=run(tmux+['list-panes','-a','-F','#{pane_id}\t#{pane_current_path}']).stdout.splitlines()
            matches=[row.split('\t')[0] for row in rows if row.endswith('/feat/popup')]
            if matches:
                cap=run(tmux+['capture-pane','-pt',matches[0]]).stdout
                if '\nPOST_CREATE_OK\n' in cap: break
            time.sleep(.1)
        else: raise AssertionError('no seeded destination window: '+str(rows)+'\n'+cap)
        assert (root/repo.name/'feat/popup/.env').read_text() == 'smoke-secret'
        assert run(['git','rev-parse','feat/popup'], repo).stdout.strip() == caller_sha
        print('PASS: actual popup uses caller HEAD and custom quoted root, seeds files, opens window, delivers post-create')
    finally:
        run(tmux+['kill-server'],check=False)
