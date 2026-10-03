#!/usr/bin/env python3
"""The session board (prefix S) on a private tmux socket and a temporary HOME.

Drives the real fzf and the real claude-steps against transcripts written
here. Requires claude-steps, tmux and fzf on PATH. Optional first argument:
an alternate board script.

What it holds:
  S1  the board lists every Claude pane and starts on the pane the key was
      pressed in
  S2  ctrl-n writes the note to the session ON THE ROW, even when that pane
      has moved to another session since the board was drawn
  S3  the list reloads with the note and keeps its cursor
  S4  Enter switches the client to the row's pane
  S5  nothing reached the real notes directory
  S6  prefix S, bound as tmux.conf binds it, opens the board in a popup on
      the client that pressed it
"""
import json, os, pathlib, pty, re, shlex, shutil, subprocess, sys, tempfile, threading, time

D = pathlib.Path(__file__).resolve().parents[5]
STEPS = shutil.which('claude-steps')
if not STEPS:
    raise SystemExit('Install claude-steps on PATH before running the board test (make install in ~/dev/claude-steps).')
script = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else D/'tmux/.config/tmux/scripts/tmux-steps.sh'

ALPHA = 'aaaaaaaa-1111-4111-8111-111111111111'
BETA = 'bbbbbbbb-2222-4222-8222-222222222222'
GAMMA = 'cccccccc-3333-4333-8333-333333333333'

real_notes = pathlib.Path.home()/'.local/state/claude-steps/notes'
def fingerprint(d):
    return sorted((p.name, p.stat().st_size, p.stat().st_mtime_ns) for p in d.iterdir()) if d.is_dir() else None
real_before = fingerprint(real_notes)

with tempfile.TemporaryDirectory(prefix='steps-board-') as td:
    td = str(pathlib.Path(td).resolve())
    home = pathlib.Path(td)
    env = os.environ.copy()
    env.update(HOME=td, TERM='xterm-256color')
    for key in ('TMUX', 'TMUX_PANE', 'XDG_CONFIG_HOME', 'XDG_STATE_HOME', 'CLAUDE_STEPS_BIN'):
        env.pop(key, None)

    def run(args, check=True):
        return subprocess.run(args, env=env, check=check, text=True, capture_output=True, timeout=20)

    def transcript(sid, title, prompt):
        rows = [
            {'type': 'ai-title', 'aiTitle': title, 'sessionId': sid},
            {'type': 'user', 'uuid': 'u1', 'timestamp': '2026-10-01T09:00:00.000Z', 'isSidechain': False, 'cwd': td, 'promptId': 'p1',
             'origin': {'kind': 'human'}, 'promptSource': 'typed', 'message': {'role': 'user', 'content': prompt}},
        ]
        path = home/'.claude/projects/-work'/(sid+'.jsonl')
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(''.join(json.dumps(r)+'\n' for r in rows))

    transcript(ALPHA, 'Alpha session', 'start the alpha work')
    transcript(BETA, 'Beta session', 'start the beta work')
    transcript(GAMMA, 'Gamma session', 'a later session in the same pane')
    notes = home/'.local/state/claude-steps/notes'

    sock = str(home/'tmux.sock')
    tmux = ['tmux', '-S', sock]
    shell = '/bin/bash --noprofile --norc'
    client = None
    try:
        run(tmux+['-f', '/dev/null', 'new-session', '-d', '-s', 'one', '-x', '200', '-y', '50', '-c', td, shell])
        run(tmux+['set-option', '-g', 'default-command', shell])
        run(tmux+['new-session', '-d', '-s', 'two', '-x', '200', '-y', '50', '-c', td])
        pane_a = run(tmux+['display-message', '-p', '-t', 'one:0', '#{pane_id}']).stdout.strip()
        pane_b = run(tmux+['display-message', '-p', '-t', 'two:0', '#{pane_id}']).stdout.strip()
        board = run(tmux+['new-window', '-d', '-P', '-F', '#{pane_id}', '-t', 'one:', '-n', 'board']).stdout.strip()
        run(tmux+['set-option', '-p', '-t', pane_a, '@claude_ctx_sid', ALPHA])
        run(tmux+['set-option', '-p', '-t', pane_b, '@claude_ctx_sid', BETA])
        run(tmux+['select-window', '-t', 'one:board'])

        # Enter switches a CLIENT, so the server needs a real one: tmux attached
        # to session one on a pty this test owns.
        master, slave = pty.openpty()
        client = subprocess.Popen(tmux+['attach-session', '-t', 'one'], stdin=slave, stdout=slave, stderr=slave, env=env, close_fds=True)
        os.close(slave)
        # What the client's terminal received, which is the only place a popup
        # can be seen: it is no pane, so capture-pane does not reach it.
        stream, stream_lock = bytearray(), threading.Lock()
        def drain():
            try:
                while chunk := os.read(master, 65536):
                    with stream_lock:
                        stream.extend(chunk)
            except OSError:
                pass
        threading.Thread(target=drain, daemon=True).start()

        def screen():
            return run(tmux+['capture-pane', '-pt', board]).stdout
        def wait(what, ready, seconds=8):
            deadline = time.monotonic()+seconds
            while time.monotonic() < deadline:
                cap = screen()
                if ready(cap):
                    return cap
                time.sleep(.1)
            raise AssertionError(what+':\n'+screen())
        def keys(*args):
            run(tmux+['send-keys', '-t', board]+list(args))
        def session_of_client():
            return run(tmux+['list-clients', '-F', '#{client_session}']).stdout.strip()

        wait('no client attached', lambda _: session_of_client() == 'one')

        # The key was pressed in the beta pane.
        keys('-l', 'clear; /bin/bash '+shlex.quote(str(script))+' pick '+shlex.quote(pane_b))
        keys('Enter')
        cap = wait('the board never drew', lambda c: 'ctrl-n note' in c and 'Beta session   bbbbbbbb' in c)
        assert 'Alpha session' in cap and 'one:0.0' in cap and 'two:0.0' in cap, 'both Claude panes are listed:\n'+cap
        assert 'Gamma session' not in cap, 'a session in no pane is not on the board:\n'+cap
        assert 'Alpha session   aaaaaaaa' not in cap, 'the preview is the origin pane\'s session, not the first row\'s:\n'+cap
        print('PASS S1: the board lists every Claude pane and starts on the pane the key was pressed in')

        # The beta pane moves to another session while the board is open. The
        # note still belongs to the session the row showed.
        run(tmux+['set-option', '-p', '-t', pane_b, '@claude_ctx_sid', GAMMA])
        keys('C-n')
        wait('the note field never opened', lambda c: 'note >' in c and 'for session bbbbbbbb' in c)
        keys('-l', '--', '-- skip verify, the spike covered it')  # a note may start with a dash
        keys('Enter')
        wait('the list did not come back after the note', lambda c: 'ctrl-n note' in c and 'note >' not in c)
        written = {p.name: [json.loads(l)['text'] for l in p.read_text().splitlines()] for p in notes.iterdir()}
        assert written == {BETA+'.jsonl': ['-- skip verify, the spike covered it']}, written
        print('PASS S2: ctrl-n writes the note to the session on the row, not to the pane\'s session of the moment')

        # After the reload the pane shows its new session. Then a note from
        # another row: the list comes back with the note on that row and the
        # cursor still there, not thrown back to the pane the board opened on.
        wait('the reload did not show the pane\'s new session', lambda c: 'Gamma session   cccccccc' in c)
        keys('Up')
        wait('the cursor did not move to the alpha row', lambda c: 'Alpha session   aaaaaaaa' in c)
        keys('C-n'); wait('note field', lambda c: 'note >' in c and 'for session aaaaaaaa' in c)
        keys('-l', 'alpha is waiting on the migration'); keys('Enter')
        cap = wait('the list did not reload with the note', lambda c: 'ctrl-n note' in c and c.count('alpha is waiting on the migration') >= 2)
        assert 'Alpha session   aaaaaaaa' in cap and 'Gamma session   cccccccc' not in cap, 'the cursor left its row after the reload:\n'+cap
        keys('Down')
        wait('the cursor did not move back', lambda c: 'Gamma session   cccccccc' in c)
        print('PASS S3: the list reloads with the note and keeps its cursor')

        # An empty note and a cancelled one write nothing.
        keys('C-n'); wait('note field', lambda c: 'note >' in c); keys('Enter')
        wait('list after an empty note', lambda c: 'ctrl-n note' in c)
        keys('C-n'); wait('note field', lambda c: 'note >' in c); keys('-l', 'never saved'); keys('Escape')
        wait('list after a cancelled note', lambda c: 'ctrl-n note' in c)
        assert sorted(p.name for p in notes.iterdir()) == [ALPHA+'.jsonl', BETA+'.jsonl'] and all(len(p.read_text().splitlines()) == 1 for p in notes.iterdir()), 'an empty or cancelled note was written'

        keys('Enter')
        wait('Enter did not switch the client', lambda _: session_of_client() == 'two')
        active = run(tmux+['display-message', '-p', '-t', 'two:', '#{pane_id}']).stdout.strip()
        assert active == pane_b, active
        print('PASS S4: Enter switches the client to the row\'s pane')

        assert fingerprint(real_notes) == real_before, 'the real notes directory changed'
        for p in notes.iterdir():
            assert str(p.resolve()).startswith(td+'/'), p
        print('PASS S5: nothing reached the real notes directory')

        # The binding line itself, sourced into this server. Its command finds
        # the script under ~/.config, which is this HOME.
        line = next(l for l in (D/'tmux/.config/tmux/tmux.conf').read_text().splitlines() if l.startswith('bind-key S '))
        (home/'.config/tmux').mkdir(parents=True, exist_ok=True)
        (home/'.config/tmux/scripts').symlink_to(script.parent)
        (home/'bind.conf').write_text(line+'\n')
        run(tmux+['source-file', str(home/'bind.conf')])
        def terminal():
            with stream_lock:
                raw = bytes(stream)
            return re.sub(rb'\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b[()][0-9A-Za-z]|\x1b[=>78]|[\x00-\x08\x0e-\x1f]', b'', raw).decode('utf-8', 'replace')
        def wait_terminal(what, ready, seconds=8):
            deadline = time.monotonic()+seconds
            while time.monotonic() < deadline:
                if ready(terminal()):
                    return
                time.sleep(.1)
            raise AssertionError(what+':\n'+terminal()[-2000:])
        with stream_lock:
            stream.clear()
        os.write(master, b'\x02S')  # the default prefix, C-b, then S
        # The client shows session two, whose pane now runs the gamma session.
        wait_terminal('prefix S opened no board on the client', lambda t: 'ctrl-n note' in t and 'Gamma session   cccccccc' in t)
        os.write(master, b'\x1b')
        print('PASS S6: prefix S as tmux.conf binds it opens the board on the client that pressed it')
    finally:
        subprocess.run(tmux+['kill-server'], env=env, capture_output=True)
        if client is not None:
            try:
                client.wait(timeout=5)
            except subprocess.TimeoutExpired:
                client.kill()
