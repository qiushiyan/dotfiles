#!/usr/bin/env python3
"""The session board (prefix S) on a private tmux socket and a temporary HOME.

Drives the real fzf and the real claude-steps against transcripts written
here. Requires claude-steps, tmux and fzf on PATH. Optional first argument:
an alternate board script.

What it holds:
  S1  the list holds every Claude pane and starts on the pane the key was
      pressed in
  S2  ctrl-n writes the note to the session ON THE ROW, even when that pane
      has moved to another session since the board was drawn
  S3  the list reloads with the note and keeps its cursor
  S4  Enter switches the client to the row's pane
  S5  nothing reached the real notes directory
  S6  prefix S, bound as tmux.conf binds it, opens the board in a popup on
      the client that pressed it
  S7  the main panel opens at its top, on the newest steps, however long the
      session is, and the status beside it holds the session's labels
  S8  Tab flips the main panel to the whole history and back
  S9  the binary's colours reach the popup, and a row is cut to the side
      column's width by the binary, not by fzf
  S10 a popup too small for the side column stacks, and its first line is
      still the newest step
  S11 the status box keeps its height as the cursor moves, so the list stays
      put, and never takes the rows the list needs: a status taller than
      that squeezes the list only while it is shown
  S12 the status is drawn in the terminal's own colour, not fzf's muted
      header colour, and the key hints in the muted one
"""
import fcntl, json, os, pathlib, pty, re, shlex, shutil, struct, subprocess, sys, tempfile, termios, threading, time

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

    def transcript(sid, title, *prompts, compacted=False, prs=0):
        rows = [{'type': 'ai-title', 'aiTitle': title, 'sessionId': sid}]
        stamp = lambda n: f'2026-10-01T{9 + n // 60:02d}:{n % 60:02d}:00.000Z'
        for n, prompt in enumerate(prompts):
            rows.append({'type': 'user', 'uuid': f'u{n}', 'timestamp': stamp(n), 'isSidechain': False, 'cwd': td, 'promptId': f'p{n}',
                         'origin': {'kind': 'human'}, 'promptSource': 'typed', 'message': {'role': 'user', 'content': prompt}})
        # A compaction is a row of the history and never a step.
        if compacted:
            rows.append({'type': 'system', 'subtype': 'compact_boundary', 'isSidechain': False, 'timestamp': stamp(len(prompts)),
                         'compactMetadata': {'trigger': 'manual', 'preTokens': 500000}})
        # Each pull request is a line of the status.
        rows += [{'type': 'pr-link', 'prNumber': n, 'prUrl': f'https://github.com/acme/app/pull/{n}', 'prRepository': 'acme/app'} for n in range(1, prs+1)]
        path = home/'.claude/projects/-work'/(sid+'.jsonl')
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(''.join(json.dumps(r)+'\n' for r in rows))

    # Eight labels, as many as the author's own, and a beta session with more
    # steps under one of them than the main panel has rows: a prompt that
    # names the label's skill is a step. The alpha session's title is wider
    # than the side column.
    (home/'.config/claude-steps').mkdir(parents=True)
    (home/'.config/claude-steps/config.toml').write_text('[[label]]\nname = "verify"\nskills = ["pl-loopy-verify"]\n' + ''.join(
        f'[[label]]\nname = "{name}"\nskills = ["{name}-skill"]\n' for name in ('consult', 'spec', 'review', 'docs', 'pr-review', 'prompts', 'closeout')))
    transcript(ALPHA, 'Alpha session, whose title runs well past the side column of the popup', 'start the alpha work')
    transcript(BETA, 'Beta session', 'start the beta work', *(f'check {n:02d}: run pl-loopy-verify again' for n in range(1, 81)), compacted=True)
    transcript(GAMMA, 'Gamma session', 'a later session in the same pane')
    notes = home/'.local/state/claude-steps/notes'

    sock = str(home/'tmux.sock')
    tmux = ['tmux', '-S', sock]
    shell = '/bin/bash --noprofile --norc'
    client = None
    try:
        run(tmux+['-f', '/dev/null', 'new-session', '-d', '-s', 'one', '-x', '200', '-y', '50', '-c', td, shell])
        run(tmux+['set-option', '-g', 'default-command', shell])
        # A theme, so the popup's fzf takes its colours from the palette.
        for option, value in {'@thm_mauve': '#cba6f7', '@thm_overlay_2': '#828bb8', '@thm_overlay_0': '#545c7e',
                              '@thm_surface_0': '#2f334d', '@thm_green': '#a6e3a1', '@thm_red': '#f38ba8'}.items():
            run(tmux+['set-option', '-g', option, value])
        run(tmux+['new-session', '-d', '-s', 'two', '-x', '200', '-y', '50', '-c', td])
        pane_a = run(tmux+['display-message', '-p', '-t', 'one:0', '#{pane_id}']).stdout.strip()
        pane_b = run(tmux+['display-message', '-p', '-t', 'two:0', '#{pane_id}']).stdout.strip()
        board = run(tmux+['new-window', '-d', '-P', '-F', '#{pane_id}', '-t', 'one:', '-n', 'board']).stdout.strip()
        run(tmux+['set-option', '-p', '-t', pane_a, '@claude_ctx_sid', ALPHA])
        run(tmux+['set-option', '-p', '-t', pane_b, '@claude_ctx_sid', BETA])
        run(tmux+['select-window', '-t', 'one:board'])

        # Enter switches a CLIENT, so the server needs a real one: tmux attached
        # to session one on a pty this test owns, as wide as a popup that
        # takes the side layout.
        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 50, 200, 0, 0))
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
        assert 'Gamma session' not in cap, 'a session in no pane is not on the list:\n'+cap
        assert 'aaaaaaaa   one:0.0' not in cap, 'the status is the origin pane\'s session, not the first row\'s:\n'+cap
        print('PASS S1: the list holds every Claude pane and starts on the pane the key was pressed in')

        # The main panel's first line is the newest step: the steps are the
        # top of the view, and the oldest are below. The status beside it is
        # the session's label with its latest event.
        label = r'verify +\d+\w+ +you: "check 80'
        assert 'check 80' in cap.splitlines()[1] and 'check 79' in cap and 'check 01' not in cap, 'the main panel did not open on the newest steps:\n'+cap
        assert re.search(label, cap) and 'no collect seen' in cap, 'the status does not hold the label row:\n'+cap
        print('PASS S7: the main panel opens on the newest steps, and the status beside it holds the labels')

        # The compaction is the newest row of the history and no step.
        assert 'compaction (manual)' not in cap, 'a compaction is among the steps:\n'+cap
        keys('Tab')
        cap = wait('Tab did not show the history', lambda c: '─ history ─' in c and 'compaction (manual)' in c.splitlines()[1])
        assert re.search(label, cap), 'the status went with the steps:\n'+cap
        keys('Tab')
        wait('Tab did not go back to the steps', lambda c: '─ steps ─' in c and 'compaction (manual)' not in c)
        print('PASS S8: Tab flips the main panel to the whole history and back')

        # The label's name is in its hue in the status and in the steps: the
        # binary writes through a pipe here and paints anyway.
        painted = screen(colour=True)
        assert painted.count('\x1b[34mverify') >= 2, 'the label is not painted in the status and the steps:\n'+repr(painted)
        muted = '\x1b[38;2;130;139;184m'
        assert 'Beta session' in painted and muted+'Beta session' not in painted, 'the status is drawn in the muted header colour:\n'+repr(painted)
        assert muted+'enter switch' in painted, 'the key hints lost the muted colour:\n'+repr(painted)
        print('PASS S12: the status is in the terminal\'s colour, the key hints in the muted one')

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

        # After the reload the pane shows its new session, in the list and in
        # the status. Then a note from another row: the status and the steps
        # come back with the note, and the cursor stays on that row, not
        # thrown back to the pane the view opened on.
        cap = wait('the reload did not show the pane\'s new session', lambda c: 'Gamma session   cccccccc' in c and 'Beta session' not in c)
        listed = lambda c: next(i for i, l in enumerate(c.splitlines()) if '─ sessions ─' in l)
        before = listed(cap)
        keys('Up')
        cap = wait('the cursor did not move to the alpha row', lambda c: 'aaaaaaaa   one:0.0' in c)
        # The alpha status is a line taller (its title takes two), and the box
        # grows to it once; back on the gamma row the box keeps that height.
        keys('Down'); cap = wait('the cursor did not move back to gamma', lambda c: 'Gamma session   cccccccc' in c)
        assert listed(cap) == before+1, f'the list moved: its box starts on line {listed(cap)}, not {before+1}:\n'+cap
        keys('Up'); cap = wait('the cursor did not move to the alpha row', lambda c: 'aaaaaaaa   one:0.0' in c)
        assert listed(cap) == before+1, 'the list moved with the alpha status:\n'+cap
        keys('C-n'); wait('note field', lambda c: 'note >' in c and 'for session aaaaaaaa' in c)
        keys('-l', 'alpha is waiting on the migration, which the platform team runs on Thursday afternoon'); keys('Enter')
        cap = wait('the status and the steps did not come back with the note', lambda c: 'ctrl-n note' in c and c.count('alpha is waiting on the migration') >= 2)
        assert 'Thursday afternoon' in cap, 'the status cut the note instead of folding it:\n'+cap
        assert 'aaaaaaaa   one:0.0' in cap and 'Gamma session   cccccccc' not in cap, 'the cursor left its row after the reload:\n'+cap

        # The alpha title is wider than the side column, so the binary cut its
        # row to the width the column shows. A row fzf cuts itself ends in "··".
        width = int(run(tmux+['display-message', '-p', '-t', board, '#{pane_width}']).stdout)
        side = min(max(width*36//100, 50), 72) - 6
        row = next(l for l in cap.splitlines() if 'Alpha session' in l and 'one:0.0' in l)
        item = re.search(r'one:0\.0 .*?…', row)
        assert width >= 120, f'the pane is {width} columns: too narrow for the side layout'
        assert '··' not in cap and item and len(item.group(0)) == side, f'the row was not fitted to the {side} columns of the side column:\n'+cap
        print('PASS S9: the binary\'s colours reach the popup, and a row is cut to the side column by the binary')
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

        # A popup the size of a plain terminal is too small for the side
        # column. The main panel opens on the newest step, eight labels or
        # not, the status follows the steps in it, and the list is under it.
        run(tmux+['resize-window', '-t', 'one:board', '-x', '80', '-y', '24'])
        run(tmux+['select-window', '-t', 'one:board'])
        keys('-l', 'clear; /bin/bash '+shlex.quote(str(script))+' pick '+shlex.quote(pane_a))
        keys('Enter')
        cap = wait('the stacked view never drew', lambda c: 'ctrl-n note' in c and 'one:0.0' in c)
        lines = cap.splitlines()
        at = lambda text: next(i for i, l in enumerate(lines) if text in l)
        assert '─ steps ─' in lines[0] and 'alpha is waiting' in lines[1], 'the stacked view does not open on the newest step:\n'+cap
        assert '─ status ─' not in cap and at('alpha is waiting') < at('─ sessions ─') < at('▌ one:0.0'), 'the view is not stacked over the list:\n'+cap
        keys('C-d')
        wait('the status does not follow the steps', lambda c: 'aaaaaaaa   one:0.0' in c and 'closeout' in c)
        keys('Escape')
        wait('the stacked view did not close', lambda c: 'ctrl-n note' not in c)
        print('PASS S10: a popup too small for the side column stacks, and opens on the newest step')

        # A popup just tall enough for the side column, and an alpha session
        # whose pull requests make its status taller than the room left once
        # the list has its rows. Shown, it squeezes the list; the gamma status
        # after it does not inherit that height.
        transcript(ALPHA, 'Alpha session, whose title runs well past the side column of the popup', 'start the alpha work', prs=12)
        run(tmux+['resize-window', '-t', 'one:board', '-x', '200', '-y', '34'])
        keys('-l', 'clear; /bin/bash '+shlex.quote(str(script))+' pick '+shlex.quote(pane_a))
        keys('Enter')
        wait('the side layout never drew', lambda c: '─ status ─' in c and 'PR #12 linked' in c)
        keys('Down')
        cap = wait('the cursor did not move to gamma', lambda c: 'Gamma session   cccccccc' in c)
        rows = [l for l in cap.splitlines()[listed(cap):] if '▌' in l]
        assert any('one:0.0' in l for l in rows) and any('two:0.0' in l for l in rows), 'the gamma status kept the alpha status\'s height and squeezed the list:\n'+cap
        keys('Escape')
        print('PASS S11: the status keeps its height as the cursor moves and leaves the list its rows')
    finally:
        subprocess.run(tmux+['kill-server'], env=env, capture_output=True)
        if client is not None:
            try:
                client.wait(timeout=5)
            except subprocess.TimeoutExpired:
                client.kill()
