#!/usr/bin/env python3
"""Compare a known-broken tmux with a candidate using isolated nested servers."""
import argparse
import os
import pathlib
import shlex
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--stock', required=True, help='Known-broken stock 3.7b or 3.7c binary')
parser.add_argument('--candidate', required=True, help='Binary expected to preserve the popup')
args = parser.parse_args()
stock = str(pathlib.Path(args.stock).resolve(strict=True))
patched = str(pathlib.Path(args.candidate).resolve(strict=True))
env = dict(os.environ, SHELL='/bin/sh', TERM='tmux-256color')
env.pop('TMUX', None)
env.pop('TMUX_PANE', None)

with tempfile.TemporaryDirectory(prefix='tmux-popup-') as root:
    root = pathlib.Path(root)
    env['HOME'] = str(root)
    env['XDG_CONFIG_HOME'] = str(root / 'config')
    conf = root / 'tmux.conf'
    conf.write_text('set -g default-shell /bin/sh\nset -g status off\nset -g exit-empty off\n')
    for name, binary in [('stock', stock), ('patched', patched)]:
        inner, outer = str(root / (name + '-in')), str(root / (name + '-out'))
        def run(socket, *args, check=True):
            return subprocess.run([binary, '-S', socket, '-f', str(conf), *args], env=env, text=True,
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10, check=check).stdout
        popup = None
        try:
            run(inner, 'new-session', '-d', '-s', 'test', '-x', '100', '-y', '30', 'sleep 120')
            run(inner, 'set', '-g', 'status', '2')
            run(inner, 'set', '-g', 'status-position', 'top')
            run(inner, 'split-window', '-h', '-t', 'test:0', 'sleep 120')
            command = shlex.join([binary, '-S', inner, 'attach-session', '-t', 'test'])
            run(outer, 'new-session', '-d', '-s', 'view', '-x', '100', '-y', '30', command)
            time.sleep(.5)
            client = run(inner, 'list-clients', '-F', '#{client_name}').strip()
            assert client, 'nested client did not attach'
            popup = subprocess.Popen([binary, '-S', inner, 'display-popup', '-c', client, '-x', '20', '-y', '20', '-w', '60', '-h', '12', '-b', 'simple', '-T', 'POPUP', 'sleep 120'], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            time.sleep(.3)
            baseline = run(outer, 'capture-pane', '-p', '-t', 'view:0.0').splitlines()
            top = next(i for i, line in enumerate(baseline) if 'POPUP' in line)
            assert top >= 2, 'popup must overlap pane content, below the status bar'
            assert baseline[top].count('-') > 40, 'popup top border not drawn'
            # Busy applications redraw underneath the existing popup. Compare the
            # captured outer terminal, since inner capture-pane omits overlays.
            run(inner, 'respawn-pane', '-k', '-t', 'test:0.0', "while :; do printf '\\033[H'; seq 1 40; sleep 0.03; done")
            time.sleep(.5)
            snapshots = []
            for _ in range(8):
                run(inner, 'refresh-client', '-t', client)
                time.sleep(.05)
                snapshots.append(run(outer, 'capture-pane', '-p', '-t', 'view:0.0').splitlines())
                time.sleep(.08)
            # Compare the entire top edge at its observed coordinates.
            left = baseline[top].index('+')
            right = baseline[top].rindex('+') + 1
            intact = all(s[top][left:right] == baseline[top][left:right] for s in snapshots)
            divider_col = int(run(inner, 'display', '-p', '-t', 'test:0.0', '#{pane_width}').strip())
            below = top + 12
            divider = all(s[below][divider_col:divider_col+1] in ('│', '|') for s in snapshots)
            print(f'{name}: popup top intact={intact}, divider below popup intact={divider}', flush=True)
            if name == 'stock':
                assert not intact, 'negative control did not reproduce the popup defect'
            else:
                assert intact and divider, 'patched popup or divider corrupted'
                run(inner, 'display-popup', '-C', '-c', client)
                run(inner, 'copy-mode', '-t', 'test:0.0')
                assert run(inner, 'display', '-p', '-t', 'test:0.0', '#{pane_in_mode}').strip() == '1'
                run(inner, 'send-keys', '-t', 'test:0.0', '-X', 'cancel')
                assert run(inner, 'display', '-p', '-t', 'test:0.0', '#{pane_in_mode}').strip() == '0'
                print('patched: copy-mode enter/exit passed', flush=True)
        finally:
            run(outer, 'kill-server', check=False)
            run(inner, 'kill-server', check=False)
            if popup is not None:
                popup.communicate(timeout=10)
