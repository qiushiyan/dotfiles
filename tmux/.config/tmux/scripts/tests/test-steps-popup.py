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
  S7  the preview opens at its top, on the session's labels and newest steps,
      however long the session is
  S8  Tab flips the preview to the whole history and back
  S9  the binary's colours reach the popup, and no row is wider than fzf
      shows
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

    def transcript(sid, title, *prompts):
        rows = [{'type': 'ai-title', 'aiTitle': title, 'sessionId': sid}]
        for n, prompt in enumerate(prompts):
            rows.append({'type': 'user', 'uuid': f'u{n}', 'timestamp': f'2026-10-01T09:{n:02d}:00.000Z', 'isSidechain': False, 'cwd': td, 'promptId': f'p{n}',
                         'origin': {'kind': 'human'}, 'promptSource': 'typed', 'message': {'role': 'user', 'content': prompt}})
        path = home/'.claude/projects/-work'/(sid+'.jsonl')
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(''.join(json.dumps(r)+'\n' for r in rows))

    # One label, and a beta session with more steps under it than the preview
    # has rows: a prompt that names the label's skill is a step.
    (home/'.config/claude-steps').mkdir(parents=True)
    (home/'.config/claude-steps/config.toml').write_text('[[label]]\nname = "verify"\nskills = ["pl-loopy-verify"]\n')
    transcript(ALPHA, 'Alpha session', 'start the alpha work')
    transcript(BETA, 'Beta session', 'start the beta work', *(f'check {n:02d}: run pl-loopy-verify again' for n in range(1, 41)))
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

        def screen(colour=False):
            return run(tmux+['capture-pane', '-p']+(['-e'] if colour else [])+['-t', board]).stdout
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

        # The first screen of the preview is the top of the session: its label
        # with the latest event, and the newest steps. The oldest are below.
        assert re.search(r'verify +\d+ \w+ ago +you: "check 40', cap) and 'no collect seen' in cap, 'the label row is not on the first screen:\n'+cap
        assert 'check 39' in cap and 'check 01' not in cap, 'the preview did not open at its top:\n'+cap
        print('PASS S7: the preview opens on the session\'s labels and newest steps')

        keys('Tab')
        cap = wait('Tab did not show the history', lambda c: '─ history ─' in c and re.search(r'^ *history *$', c, re.M))
        assert re.search(r'verify +\d+ \w+ ago +you: "check 40', cap), 'the history lost the labels above it:\n'+cap
        keys('Tab')
        wait('Tab did not go back to the steps', lambda c: '─ steps ─' in c and re.search(r'^ *steps *$', c, re.M))
        print('PASS S8: Tab flips the preview to the whole history and back')

        # The label's name is in its hue in the list's header and in the
        # preview: the binary writes through a pipe here and paints anyway.
        painted = screen(colour=True)
        assert painted.count('\x1b[34mverify') >= 2, 'the label is not painted in the list and the preview:\n'+repr(painted)

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
        keys('-l', 'alpha is waiting on the migration, which the platform team runs on Thursday afternoon'); keys('Enter')
        cap = wait('the list did not reload with the note', lambda c: 'ctrl-n note' in c and c.count('alpha is waiting on the migration') >= 2)
        assert 'Alpha session   aaaaaaaa' in cap and 'Gamma session   cccccccc' not in cap, 'the cursor left its row after the reload:\n'+cap

        # The row with the note is wider than the pane, so the binary cut it
        # to the width fzf gives a row. A row fzf cuts itself ends in "··" and
        # loses the note.
        width = int(run(tmux+['display-message', '-p', '-t', board, '#{pane_width}']).stdout)
        row = next(l for l in cap.splitlines() if 'Alpha session' in l and 'one:0.0' in l)
        assert width < 100, f'the pane is {width} columns: too wide for the note to need cutting'
        assert '··' not in cap and row.rstrip().endswith('…') and len(row.rstrip()) == width-1, f'the row was not fitted to {width} columns:\n'+cap
        print('PASS S9: the binary\'s colours reach the popup, and a row is cut to the width fzf shows')
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
