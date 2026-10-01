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
    shutil.copy2(B, bindir/'gwt-real')
    # gwt on PATH is the real binary behind a switch: while $HOME/slow-list
    # exists, `gwt list` answers 3s late, which is how the first-paint case
    # holds the probed rows back. Each `gwt remove` first records every pane's
    # cwd on the test server, which shows whether the popup stopped the
    # checkout's writers before gwt read it.
    (bindir/'gwt').write_text('#!/bin/sh\n[ "$1" = list ] && [ -e "$HOME/slow-list" ] && sleep 3\n'
                              '[ "$1" = remove ] && tmux list-panes -a -F "#{pane_current_path}" >> "$HOME/panes-at-remove"\n'
                              'exec "$(dirname "$0")/gwt-real" "$@"\n')
    (bindir/'gwt').chmod(0o755)
    # ctrl-y resolves toclip through PATH; this stub keeps the real clipboard out
    # of reach and records the payload and the pane it was aimed at.
    clip = home/'clip.txt'
    (bindir/'toclip').write_text('#!/bin/sh\ncat > '+shlex.quote(str(clip))+'.tmp && printf %s "$TMUX_PANE" > '+shlex.quote(str(clip))+'.pane && mv '+shlex.quote(str(clip))+'.tmp '+shlex.quote(str(clip))+'\n')
    (bindir/'toclip').chmod(0o755)
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
        # gwt ran at the pane's terminal, so it copied the new path; clear that
        # so the ctrl-y checks below see only ctrl-y's own copies.
        assert clip.read_text() == str(root/repo.name/'feat/popup'), 'creation copies its path'
        clip.unlink()
        print('PASS: actual popup uses caller HEAD and custom quoted root, seeds files, opens window, delivers post-create, copies the path')

        # Copy: the probed rows replace the bare first paint (the dirty mark only
        # exists in them), ctrl-y copies the highlighted path and closes, and with
        # every row marked it copies them all, one per line.
        tree = root/repo.name/'feat/popup'
        (tree/'untracked.txt').write_text('dirty')
        def open_popup():
            run(tmux+['send-keys','-t',pane,'-l','clear; '+command]); run(tmux+['send-keys','-t',pane,'Enter'])
            deadline=time.monotonic()+8
            while time.monotonic()<deadline:
                cap=run(tmux+['capture-pane','-pt',pane]).stdout
                if '* feat/popup' in cap: return
                time.sleep(.1)
            raise AssertionError('probed rows never replaced the bare list: '+cap)
        def copied():
            deadline=time.monotonic()+8
            while time.monotonic()<deadline:
                if clip.exists():
                    cap=run(tmux+['capture-pane','-pt',pane]).stdout
                    if 'ctrl-y copy path' not in cap:
                        text=clip.read_text(); clip.unlink(); return text
                time.sleep(.1)
            raise AssertionError('ctrl-y did not copy and close: '+run(tmux+['capture-pane','-pt',pane]).stdout)
        open_popup()
        run(tmux+['send-keys','-t',pane,'-l','feat/popup']); time.sleep(.3)
        run(tmux+['send-keys','-t',pane,'C-y'])
        assert copied() == str(tree), 'single copy'
        # toclip reads only the pane's session (to find its client), and in this
        # detached session the active pane is the window ctrl-n just opened.
        aimed = (home/'clip.txt.pane').read_text()
        assert aimed and run(tmux+['display-message','-p','-t',aimed,'#{session_name}']).stdout.strip() == 'smoke', 'toclip aimed at the invoking session: '+aimed
        open_popup()
        run(tmux+['send-keys','-t',pane,'C-a']); time.sleep(.3)
        run(tmux+['send-keys','-t',pane,'C-y'])
        assert sorted(copied().split('\n')) == sorted([str(repo), str(tree)]), 'marked rows copy one path per line'
        print('PASS: probed rows replace the bare list; ctrl-y copies the highlighted or marked paths aimed at the invoking session, and closes')

        # Reap: gwt's verdict tags a worktree at the trunk (main) as merged, and
        # ctrl-g removes its checkout and, after gwt merged agrees, its branch.
        # The tag and the reap share one eligibility rule: feat/popup (forked
        # from caller-topic, which main does not contain) is clean here, so only
        # its unmerged verdict protects it; locked-me is merged but locked.
        # broken-me is merged but its status probe fails (unreadable .git), so
        # gwt calls its untracked work dirty: never tagged, never reaped, and
        # ctrl-x's --discard-dirty keeps it because it cannot be snapshotted.
        # reap-me-too is another window whose name starts with reap-me; reaping
        # reap-me must not kill it by name prefix.
        (tree/'untracked.txt').unlink()
        reaped = run(['gwt','create','-n','--no-copy','reap-me','main'], repo).stdout.strip()
        locked = run(['gwt','create','-n','--no-copy','locked-me','main'], repo).stdout.strip()
        run(['git','worktree','lock',locked], repo)
        broken = pathlib.Path(run(['gwt','create','-n','--no-copy','broken-me','main'], repo).stdout.strip())
        (broken/'precious.txt').write_text('only copy')
        (broken/'.git').chmod(0)
        run(tmux+['new-window','-d','-t','smoke:','-n','reap-me-too'])
        def wait_for(text):
            deadline=time.monotonic()+10
            while time.monotonic()<deadline:
                cap=run(tmux+['capture-pane','-pt',pane]).stdout
                if text in cap: return cap
                time.sleep(.1)
            raise AssertionError('never saw '+repr(text)+': '+cap)
        run(tmux+['send-keys','-t',pane,'-l','clear; '+command]); run(tmux+['send-keys','-t',pane,'Enter'])
        cap = wait_for('reap-me · merged')
        assert 'feat/popup · merged' not in cap and 'locked-me · merged' not in cap and 'locked-me' in cap, cap
        assert 'broken-me · merged' not in cap and 'broken-me' in cap, cap
        run(tmux+['send-keys','-t',pane,'C-g'])
        wait_for('proceed? [y/N]'); run(tmux+['send-keys','-t',pane,'y','Enter'])
        wait_for('merged branch(es)? [Y/n]'); run(tmux+['send-keys','-t',pane,'Enter'])
        wait_for('enter switch/create')
        assert not pathlib.Path(reaped).exists(), 'reaped checkout remains'
        assert run(['git','show-ref','--verify','--quiet','refs/heads/reap-me'], repo, check=False).returncode == 1, 'reaped branch remains'
        assert tree.exists() and run(['git','show-ref','--verify','--quiet','refs/heads/feat/popup'], repo, check=False).returncode == 0, 'unmerged worktree touched'
        assert pathlib.Path(locked).exists(), 'locked worktree reaped'
        assert (broken/'precious.txt').exists(), 'unprobed worktree reaped'
        windows = run(tmux+['list-windows','-t','smoke','-F','#W']).stdout.split()
        assert 'reap-me-too' in windows, 'reaping reap-me killed a window by name prefix: '+str(windows)
        run(tmux+['send-keys','-t',pane,'-l','broken-me']); time.sleep(.3)
        run(tmux+['send-keys','-t',pane,'C-x'])
        # fzf restores the main screen on exit, so the reap's prompts are still
        # on it: wait for text only this run prints.
        wait_for('broken-me  (dirty'); run(tmux+['send-keys','-t',pane,'y','Enter'])
        wait_for('also remove the 1 dirty one(s)?'); run(tmux+['send-keys','-t',pane,'y','Enter'])
        wait_for('could not remove broken-me: could not read')
        wait_for('enter switch/create')
        assert (broken/'precious.txt').read_text() == 'only copy', 'ctrl-x discarded the unprobed worktree'
        (broken/'.git').chmod(0o644)
        run(tmux+['send-keys','-t',pane,'Escape'])
        print('PASS: gwt tags the trunk-merged worktree; ctrl-g reaps its checkout and branch and leaves unmerged, locked, unprobed work and prefix-named windows; ctrl-x keeps an unprobed worktree it cannot snapshot')

        # ctrl-x on dirty work: declining keeps it; accepting removes it with a
        # printed recovery ref holding the untracked file. The window another
        # session has open on it dies too (ids collected before the move). An
        # unmerged branch goes only behind the force prompt, its tip kept.
        def git_ok(*args):
            return run(['git', *args], repo, check=False).returncode == 0
        dirty = pathlib.Path(run(['gwt','create','-n','--no-copy','dirty-me','main'], repo).stdout.strip())
        (dirty/'wip.txt').write_text('unsaved notes')
        unmerged = pathlib.Path(run(['gwt','create','-n','--no-copy','unmerged-me','main'], repo).stdout.strip())
        run(['git','-c','user.name=Test','-c','user.email=test@example.invalid','commit','--allow-empty','-qm','unmerged work'], unmerged)
        unmerged_tip = run(['git','rev-parse','HEAD'], unmerged).stdout.strip()
        run(tmux+['new-session','-d','-s','other','-c',str(dirty)])
        run(tmux+['send-keys','-t',pane,'-l','clear; '+command]); run(tmux+['send-keys','-t',pane,'Enter'])
        wait_for('* dirty-me')
        run(tmux+['send-keys','-t',pane,'-l',"'dirty-me"]); time.sleep(.3)
        run(tmux+['send-keys','-t',pane,'C-x'])
        wait_for('dirty-me  (dirty'); run(tmux+['send-keys','-t',pane,'y','Enter'])
        wait_for('also remove the 1 dirty one(s)?'); run(tmux+['send-keys','-t',pane,'n','Enter'])
        wait_for('nothing left to remove')
        wait_for('enter switch/create')
        assert (dirty/'wip.txt').exists(), 'declining removed dirty work'
        assert run(['git','for-each-ref','refs/wt-trash'], repo).stdout == '', 'declining kept a ref'
        run(tmux+['send-keys','-t',pane,'-l',"'dirty-me | 'unmerged-me"]); time.sleep(.3)
        run(tmux+['send-keys','-t',pane,'C-a']); time.sleep(.3)
        run(tmux+['send-keys','-t',pane,'C-x'])
        wait_for('remove 2 worktree(s):'); run(tmux+['send-keys','-t',pane,'y','Enter'])
        wait_for('also remove the 1 dirty one(s)?'); run(tmux+['send-keys','-t',pane,'y','Enter'])
        cap = wait_for('merged branch(es)? [Y/n]')
        assert 'kept refs/wt-trash/' in cap, 'snapshot ref not printed: '+cap
        run(tmux+['send-keys','-t',pane,'Enter'])
        wait_for('NOT merged'); wait_for('force-delete them?'); run(tmux+['send-keys','-t',pane,'y','Enter'])
        wait_for('enter switch/create')
        assert not dirty.exists() and not unmerged.exists(), 'checkouts remain'
        assert not git_ok('show-ref','--verify','--quiet','refs/heads/dirty-me'), 'merged branch remains'
        assert not git_ok('show-ref','--verify','--quiet','refs/heads/unmerged-me'), 'forced branch remains'
        refs = run(['git','for-each-ref','--format=%(refname) %(objectname)','refs/wt-trash'], repo).stdout.split('\n')
        snap = [r.split()[0] for r in refs if r.split() and run(['git','show',r.split()[0]+':wip.txt'], repo, check=False).stdout == 'unsaved notes']
        assert len(snap) == 1, 'no snapshot holds the untracked file: '+str(refs)
        assert any(r.endswith(' '+unmerged_tip) for r in refs), 'forced tip not kept: '+str(refs)
        panes = run(tmux+['list-panes','-a','-F','#{pane_current_path}']).stdout
        assert str(dirty) not in panes and run(tmux+['has-session','-t','other'], check=False).returncode != 0, 'other session kept a window on the removed worktree'
        at_remove = (home/'panes-at-remove').read_text()
        assert str(repo) in at_remove and str(dirty) not in at_remove.split('\n'), 'a window still worked in the checkout when gwt remove ran: '+at_remove
        run(tmux+['send-keys','-t',pane,'Escape'])
        print('PASS: ctrl-x keeps declined dirty work; accepted, another session loses its window before gwt runs, gwt snapshots the work to a printed ref, and a forced unmerged branch keeps its tip')

        # First paint: with gwt list held back, the bare rows are on screen at
        # once and take a query and a mark; the probed rows then replace them
        # (feat/popup gains its dirty mark) with the query and the mark intact.
        (tree/'untracked.txt').write_text('dirty')
        (home/'slow-list').touch()
        # Start from a settled shell: the previous popup gone, the screen clear.
        deadline=time.monotonic()+8
        while 'enter switch/create' in run(tmux+['capture-pane','-pt',pane]).stdout and time.monotonic()<deadline:
            time.sleep(.1)
        run(tmux+['send-keys','-t',pane,'-l','clear; echo settled']); run(tmux+['send-keys','-t',pane,'Enter'])
        deadline=time.monotonic()+8
        while 'settled' not in run(tmux+['capture-pane','-pt',pane]).stdout.splitlines() and time.monotonic()<deadline:
            time.sleep(.1)
        run(tmux+['send-keys','-t',pane,'-l',command]); run(tmux+['send-keys','-t',pane,'Enter'])
        started = time.monotonic()
        cap = wait_for('locked-me')
        elapsed = time.monotonic() - started
        assert elapsed < 2 and '* feat/popup' not in cap, 'bare rows waited on gwt list (%.2fs): %s' % (elapsed, cap)
        run(tmux+['send-keys','-t',pane,'-l','feat/pop']); time.sleep(.3)
        run(tmux+['send-keys','-t',pane,'Tab']); time.sleep(.3)
        cap = run(tmux+['capture-pane','-pt',pane]).stdout
        assert 'feat/pop' in cap and '✓' in cap and '* feat/popup' not in cap, 'typing or marking waited on the probes: '+cap
        cap = wait_for('* feat/popup')
        row = next(l for l in cap.splitlines() if '* feat/popup' in l)
        assert '✓' in row and 'locked-me' not in cap and 'feat/pop' in cap, 'query or mark lost across the swap: '+cap
        run(tmux+['send-keys','-t',pane,'Escape'])
        (home/'slow-list').unlink()
        print('PASS: bare rows paint before gwt list returns, take a query and a mark, and keep both across the swap')
    finally:
        run(tmux+['kill-server'],check=False)
        for gitfile in root.glob('*/broken-me/.git'):
            gitfile.chmod(0o644)
