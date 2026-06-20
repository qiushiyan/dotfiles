import argparse
import os
import shlex
import signal
import subprocess
import sys
import tempfile
import typing
import unicodedata
from contextlib import contextmanager
from dataclasses import dataclass


def parse_args() -> None:
    arg_parser = argparse.ArgumentParser()
    arg_parser.add_argument("--smart-case")
    arg_parser.add_argument("--label-chars")
    arg_parser.add_argument("--label-attrs")
    arg_parser.add_argument("--text-attrs")
    arg_parser.add_argument("--match-attrs")
    arg_parser.add_argument("--current-attrs")
    arg_parser.add_argument("--autojump")
    arg_parser.add_argument("--regions")
    arg_parser.add_argument("--auto-begin-selection")

    class Args(argparse.Namespace):
        def __init__(self) -> None:
            self.smart_case = ""
            self.label_chars = ""
            self.label_attrs = ""
            self.text_attrs = ""
            self.match_attrs = ""
            self.current_attrs = ""
            self.autojump = ""
            self.regions = ""
            self.auto_begin_selection = ""

    args = arg_parser.parse_args(sys.argv[1:], namespace=Args())

    global SMART_CASE, LABEL_CHARS, LABEL_ATTRS, TEXT_ATTRS, MATCH_ATTRS, CURRENT_ATTRS, AUTOJUMP, REGIONS, AUTO_BEGIN_SELECTION
    SMART_CASE = (args.smart_case.lower() or "on") == "on"
    LABEL_CHARS = args.label_chars or "fjdkslaghrueiwoqptyvncmxzb1234567890"
    # flash.nvim-style palette, theme-independent (explicit fg+bg so it reads on
    # both the light and dark terminal themes). Backdrop = calm grey; match =
    # light-on-grey; current (the Enter target) = dark-on-cyan; label = bold
    # dark-on-orange. Tune these four to taste.
    LABEL_ATTRS = args.label_attrs or "\033[1m\033[38;5;16m\033[48;5;208m"
    TEXT_ATTRS = args.text_attrs or "\033[0m\033[38;5;244m"
    MATCH_ATTRS = args.match_attrs or "\033[0m\033[38;5;231m\033[48;5;238m"
    CURRENT_ATTRS = args.current_attrs or "\033[0m\033[1m\033[38;5;16m\033[48;5;39m"
    AUTOJUMP = (args.autojump.lower() or "on") == "on"
    REGIONS = tuple(
        map(lambda x: int(x), [] if args.regions == "" else args.regions.split(","))
    )
    AUTO_BEGIN_SELECTION = (args.auto_begin_selection.lower() or "on") == "on"


parse_args()


class _Selection:
    x1: int
    y1: int
    x2: int
    y2: int
    is_rectangle: bool

    def __init__(
        self,
        x1: int,
        y1: int,
        x2: int,
        y2: int,
        is_rectangle: bool,
    ) -> None:
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
        self.is_rectangle = is_rectangle


class _CopyMode:
    scroll_position: int
    cursor_x: int
    cursor_y: int
    selection: typing.Optional[_Selection]

    def __init__(
        self,
        scroll_position: int,
        cursor_x: int,
        cursor_y: int,
        selection: typing.Optional[_Selection],
    ) -> None:
        self.scroll_position = scroll_position
        self.cursor_x = cursor_x
        self.cursor_y = cursor_y
        self.selection = selection


class Screen:
    _id: str
    _tty: str
    _width: int
    _height: int
    _cursor_pos: typing.List[typing.Tuple[int, int]]
    _history_size: int
    _in_copy_mode: bool
    _copy_mode: typing.Optional[_CopyMode]
    _alternate_on: bool
    _alternate_allowed: bool
    _lines: typing.List["Line"]
    _snapshot: str
    _raw: typing.Optional[str]

    def __init__(self) -> None:
        self._fill_info()
        self._lines = self._get_lines()
        self._raw = None
        if not self._alternate_allowed:
            self._snapshot = self._get_snapshot()

    def _fill_info(self) -> None:
        tmux_vars = _get_tmux_vars(
            "pane_id",
            "pane_tty",
            "pane_width",
            "pane_height",
            "cursor_x",
            "cursor_y",
            "history_size",
            "scroll_position",
            "selection_present",
            "copy_cursor_x",
            "copy_cursor_y",
            "selection_start_x",
            "selection_start_y",
            "selection_end_x",
            "selection_end_y",
            "alternate_on",
            "rectangle_toggle",
        )
        self._id = tmux_vars["pane_id"]
        self._tty = tmux_vars["pane_tty"]
        self._width = int(tmux_vars["pane_width"])
        self._height = int(tmux_vars["pane_height"])
        cursor_x = int(tmux_vars["cursor_x"])
        cursor_y = int(tmux_vars["cursor_y"])
        self._cursor_pos = [(cursor_x, cursor_y)]
        self._history_size = int(tmux_vars["history_size"])
        self._in_copy_mode = tmux_vars["scroll_position"] != ""
        if self._in_copy_mode:
            scroll_position = int(tmux_vars["scroll_position"])
            copy_cursor_x = int(tmux_vars["copy_cursor_x"])
            copy_cursor_y = int(tmux_vars["copy_cursor_y"])
            selection_present = tmux_vars["selection_present"] == "1"
            if selection_present:
                selection_start_x = int(tmux_vars["selection_start_x"])
                selection_start_y = int(tmux_vars["selection_start_y"])
                selection_start_y -= self._history_size - scroll_position  # tmux bug?
                selection_end_x = int(tmux_vars["selection_end_x"])
                selection_end_y = int(tmux_vars["selection_end_y"])
                selection_end_y -= self._history_size - scroll_position  # tmux bug?
                if (selection_start_x, selection_start_y) == (
                    copy_cursor_x,
                    copy_cursor_y,
                ):  # tmux bug?
                    selection_start_x, selection_start_y = (
                        selection_end_x,
                        selection_end_y,
                    )
                is_rectangle = tmux_vars["rectangle_toggle"] == "1"
                selection = _Selection(
                    selection_start_x,
                    selection_start_y,
                    selection_end_x,
                    selection_end_y,
                    is_rectangle,
                )
            else:
                selection = None
            self._copy_mode = _CopyMode(
                scroll_position, copy_cursor_x, copy_cursor_y, selection
            )
            self._cursor_pos.append((copy_cursor_x, copy_cursor_y))
        else:
            self._copy_mode = None
        self._alternate_on = tmux_vars["alternate_on"] == "1"
        if self._alternate_on:
            self._alternate_allowed = False
        else:
            result = _run_tmux_command("show-option", "-gv", "alternate-screen")
            self._alternate_allowed = result == "on"

    def _get_lines(self) -> typing.List["Line"]:
        args = ["capture-pane", "-t", self._id]
        if self._copy_mode is not None:
            start_line_number = -self._copy_mode.scroll_position
            end_line_number = start_line_number + self._height - 1
            args += ["-S", str(start_line_number), "-E", str(end_line_number)]
        args += ["-p"]
        chars_list = _run_tmux_command(*args).split("\n")
        lines: typing.List[Line] = []
        for i, chars in enumerate(chars_list):
            display_width = _calculate_display_width(chars)
            if i == len(chars_list) - 1:
                trailing_whitespaces = " " * (self._width - display_width)
            else:
                trailing_whitespaces = " " * (self._width - display_width) + "\r\n"
            line = Line(chars, trailing_whitespaces)
            lines.append(line)
        return lines

    def _get_snapshot(self) -> str:
        snapshot = _run_tmux_command(
            "capture-pane", "-t", self._id, "-e", "-p"
        ).replace("\n", "\r\n")
        return snapshot

    @contextmanager
    def overlay(self) -> typing.Generator[None, None, None]:
        # Set up the jump overlay once; the caller repaints inside its loop via
        # draw() on every keystroke (flash-style incremental search). The
        # alternate screen (tmux default) lets us repaint freely and restore on
        # exit. In the rare non-alternate path we restore the captured snapshot
        # and compensate copy-mode scroll once per logical draw (the overlay and
        # the snapshot) — independent of how many times the loop repainted, which
        # matches upstream's single-draw accounting.
        self._exit_copy_mode()
        if self._alternate_allowed:
            self._enter_alternate()
        try:
            yield
        finally:
            if self._alternate_allowed:
                self._leave_alternate()
            else:
                if self._copy_mode is not None and not self._alternate_on:
                    self._copy_mode.scroll_position += self._height
                self._update(self._snapshot)
                if self._copy_mode is not None and not self._alternate_on:
                    self._copy_mode.scroll_position += self._height
            if self._copy_mode is not None:
                self._enter_copy_mode(True)

    def draw(self, raw: str) -> None:
        self._update(raw)

    def render(
        self,
        query: str,
        positions: typing.List["Position"],
        labels: typing.List[str],
        current_idx: int,
    ) -> str:
        # Build the full-screen repaint: a calm grey backdrop, the matched
        # substring highlighted, the nearest match (the Enter target) in a
        # distinct colour, and a jump label overlaid on the start of each
        # labelled match. An empty query renders the whole screen as backdrop,
        # which signals "jump mode is armed".
        raw = self.raw
        qlen = len(query)
        offset = 0
        segments: typing.List[str] = []
        for i, position in enumerate(positions):
            if position.offset < offset:
                continue  # overlapped by a previous label; skip
            if offset < position.offset:
                segments.append(TEXT_ATTRS + raw[offset : position.offset])
            match_attrs = CURRENT_ATTRS if i == current_idx else MATCH_ATTRS
            match_end = position.offset + qlen
            label = labels[i] if i < len(labels) else ""
            if label != "":
                segments.append(LABEL_ATTRS + label)
                label_end = position.offset + len(label)
                if label_end < match_end:
                    segments.append(match_attrs + raw[label_end:match_end])
                offset = max(label_end, match_end)
            else:
                segments.append(match_attrs + raw[position.offset : match_end])
                offset = match_end
        if offset < len(raw):
            segments.append(TEXT_ATTRS + raw[offset:])
        return "".join(segments)

    def _enter_alternate(self) -> None:
        with open(self._tty, "w") as f:
            f.write("\033[?1049h")
        self._alternate_on = True

    def _update(self, raw: str) -> None:
        # Pure repaint: clear, write the rendered screen, park the cursor. The
        # copy-mode scroll-position compensation lives in overlay()'s teardown so
        # the per-keystroke redraws don't compound it.
        with open(self._tty, "w") as f:
            f.write("\033[2J\033[H\033[0m")
            f.write(raw)
            cursor_x, cursor_y = self._cursor_pos[-1]
            f.write("\033[{};{}H".format(cursor_y + 1, cursor_x + 1))

    def _leave_alternate(self) -> None:
        with open(self._tty, "w") as f:
            f.write("\033[?1049l")
        self._alternate_on = False

    def jump_to_pos(self, x: int, y: int) -> None:
        ok = self._enter_copy_mode(False)
        if not ok:
            return
        if self._copy_mode is not None and self._copy_mode.selection is not None:
            selection_start_x, selection_start_y = (
                self._copy_mode.selection.x1,
                self._copy_mode.selection.y1,
            )
            if (y, x) > (selection_start_y, selection_start_x):
                x += 1
        tmux_command = []
        self._xcopy_jump_to_pos(x, y, tmux_command)
        if (
            self._copy_mode is None or self._copy_mode.selection is None
        ) and AUTO_BEGIN_SELECTION:
            tmux_command += (
                "send-keys",
                "-t",
                self._id,
                "-X",
                "begin-selection",
                ";",
            )
        _run_tmux_command(*tmux_command)

    def _xcopy_jump_to_pos(
        self, x: int, y: int, tmux_command: typing.List[str]
    ) -> None:
        cursor_x, cursor_y = self._cursor_pos[-1]
        if (x, y) == (cursor_x, cursor_y):
            return
        dy = y - cursor_y
        if dy != 0:
            tmux_command += (
                "send-keys",
                "-t",
                self._id,
                "-X",
                "-N",
                str(dy if dy > 0 else -dy),
                "cursor-down" if dy > 0 else "cursor-up",
                ";",
            )
        tmux_command += ("send-keys", "-t", self._id, "-X", "start-of-line", ";")
        char_index = _calculate_char_index(self._lines[y].chars, x)
        if char_index >= 1:
            tmux_command += (
                "send-keys",
                "-t",
                self._id,
                "-X",
                "-N",
                str(char_index),
                "cursor-right",
                ";",
            )
        self._cursor_pos[-1] = (x, y)

    @property
    def cursor_pos(self) -> typing.Tuple[int, int]:
        return self._cursor_pos[-1]

    @property
    def lines(self) -> typing.List["Line"]:
        return self._lines

    @property
    def raw(self) -> str:
        # The whole visible pane as one string; offsets line up with
        # Position.offset. Immutable for the session, so build it once.
        if self._raw is None:
            temp: typing.List[str] = []
            for line in self._lines:
                temp.append(line.chars)
                temp.append(line.trailing_whitespaces)
            self._raw = "".join(temp)
        return self._raw

    def _exit_copy_mode(self) -> None:
        if not self._in_copy_mode:
            return
        _run_tmux_command("send-keys", "-t", self._id, "-X", "cancel")
        self._cursor_pos.pop()
        self._in_copy_mode = False

    def _enter_copy_mode(self, restore_copy_cursor: bool) -> bool:
        if self._in_copy_mode:
            return True
        _run_tmux_command("copy-mode", "-t", self._id)
        self._cursor_pos.append(self._cursor_pos[-1])
        if self._copy_mode is not None:
            history_size = self._get_history_size()
            if history_size % 2 != self._history_size % 2:
                # adapt to bug of tmux
                self._copy_mode.scroll_position -= 1
            self._history_size = history_size
            if self._copy_mode.scroll_position > self._history_size:
                return False
            tmux_command = [
                "send-keys",
                "-t",
                self._id,
                "-X",
                "goto-line",
                str(self._copy_mode.scroll_position),
                ";",
            ]
            selection = self._copy_mode.selection
            if selection is not None:
                self._xcopy_jump_to_pos(selection.x1, selection.y1, tmux_command)
                tmux_command += ("send-keys", "-t", self._id, "-X")
                if selection.is_rectangle:
                    tmux_command += (
                        "begin-selection",
                        ";",
                        "send-keys",
                        "-t",
                        self._id,
                        "-X",
                        "rectangle-on",
                        ";",
                    )
                else:
                    if self._selection_is_linewise(selection):
                        tmux_command += ("select-line", ";")
                    else:
                        tmux_command += ("begin-selection", ";")
            if restore_copy_cursor:
                self._xcopy_jump_to_pos(
                    self._copy_mode.cursor_x, self._copy_mode.cursor_y, tmux_command
                )
            _run_tmux_command(*tmux_command)
        self._in_copy_mode = True
        return True

    def _get_history_size(self) -> int:
        history_size = int(
            _run_tmux_command(
                "display-message", "-t", self._id, "-p", "#{history_size}"
            )
        )
        return history_size

    def _selection_is_linewise(
        self,
        selection: _Selection,
    ) -> bool:
        if selection.x1 != 0:
            return False
        line = self._lines[selection.y2].chars
        return _calculate_char_index(line, selection.x2) == len(line)


@dataclass
class Line:
    chars: str
    trailing_whitespaces: str


@dataclass
class Position:
    line_number: int
    column_number: int
    offset: int


def read_key(message: str) -> str:
    # Read a single keypress as a tmux key NAME (command-prompt -k), so we can
    # tell "Enter"/"Escape"/"BSpace"/"Space" apart from a literal character.
    return _get_char(message, key_name=True)


def key_to_char(key: str) -> typing.Optional[str]:
    # Map a tmux key name to the character it contributes to the search, or None
    # if it is not a searchable character (arrows, Tab, function keys, C-x, ...).
    if key == "Space":
        return " "
    if len(key) == 1:
        return key
    return None


def continuation_chars(
    raw: str, positions: typing.List["Position"], query_len: int
) -> typing.Set[str]:
    # The flash.nvim rule: a label must never be a character that could continue
    # the search. Collect the character immediately after each match (via the
    # precomputed raw buffer, since Position.offset indexes straight into it);
    # excluding those from the label alphabet makes every keypress unambiguous —
    # it is either "extend the search" or "pick a label", never both.
    result: typing.Set[str] = set()
    for position in positions:
        i = position.offset + query_len
        if i < len(raw):
            c = raw[i]
            if c not in (" ", "\r", "\n"):  # match was at end of line: no follower
                result.add(c.lower())
    return result


def _get_char(message: str, key_name: bool = False) -> str:
    temp_dir_name = tempfile.mkdtemp()
    try:
        temp_file_name = os.path.join(temp_dir_name, "fifo")
        try:
            return _do_get_char(message, temp_file_name, key_name)
        finally:
            os.unlink(temp_file_name)
    finally:
        os.rmdir(temp_dir_name)


def _do_get_char(message: str, temp_file_name: str, key_name: bool = False) -> str:
    os.mkfifo(temp_file_name)
    _run_tmux_command(
        "command-prompt",
        "-k" if key_name else "-1",
        "-p",
        message,
        'run-shell -b "tee >> {} << EOF\\n%%%\\nEOF"'.format(
            shlex.quote(temp_file_name)
        ),
    )

    def handler(signum, frame) -> None:
        raise TimeoutError()

    signal.signal(signal.SIGALRM, handler)
    signal.alarm(30)
    try:
        with open(temp_file_name, "r") as f:
            char = f.readline()[:-1]
    except TimeoutError:
        char = ""  # idle too long; treated as cancel by the caller
    finally:
        signal.alarm(0)
        signal.signal(signal.SIGALRM, signal.SIG_DFL)
    return char  # "" == empty/aborted prompt; the caller treats it as cancel


def search_for_key(lines: typing.List[Line], key: str) -> typing.List[Position]:
    lower_key = key.lower()
    line_offset = 0
    positions: typing.List[Position] = []
    for line_index, line in enumerate(lines):
        lower_line_chars = line.chars.lower()
        char_index = -len(key)
        while True:
            char_index = lower_line_chars.find(lower_key, char_index + len(key))
            if char_index < 0:
                break
            potential_key = line.chars[char_index : char_index + len(key)]
            if not _test_potential_key(potential_key, key):
                continue
            column_index = _calculate_display_width(line.chars[:char_index])
            if not _point_is_in_region(column_index + 1, line_index + 1):
                continue
            offset = line_offset + char_index
            position = Position(line_index + 1, column_index + 1, offset)
            positions.append(position)
        line_offset += len(line.chars) + len(line.trailing_whitespaces)
    return positions


def _calculate_char_index(line: str, x: int) -> int:
    display_width = 0
    for i, c in enumerate(line):
        if display_width >= x:
            return i
        if unicodedata.east_asian_width(c) == "W":
            display_width += 2
        else:
            display_width += 1
    return len(line)


def _calculate_display_width(s: str) -> int:
    display_width = 0
    for c in s:
        if unicodedata.east_asian_width(c) in ("W", "F"):
            display_width += 2
        else:
            display_width += 1
    return display_width


def _test_potential_key(potential_key: str, key: str) -> bool:
    if potential_key == key:
        return True
    if not SMART_CASE:
        return False
    for c in key:
        if c.isupper():
            return False
    return True


def _point_is_in_region(x: int, y: int) -> bool:
    n = len(REGIONS)
    if n == 0:
        return True
    for i in range(0, n, 4):
        region = REGIONS[i : i + 4]
        if x >= region[0] and y >= region[1] and x <= region[2] and y <= region[3]:
            return True
    return False


def generate_labels(
    label_chars: typing.List[str], number_of_positions: int
) -> typing.List[str]:
    # Single-character labels only, taken from the (continuation-filtered)
    # alphabet. If there are more matches than labels, the farther matches go
    # unlabelled — flash's philosophy is to narrow by typing rather than to grow
    # labels. Single-char labels also keep a keypress unambiguous and stop a
    # label from overdrawing an adjacent match in the renderer.
    return list(label_chars)[: max(0, number_of_positions)]


def rank_positions(
    positions: typing.List[Position],
    cursor_pos: typing.Tuple[int, int],
) -> typing.List[int]:
    # Position indices ordered nearest-to-cursor first (rank 0 is the Enter
    # target). Shared by label assignment and the "current match" highlight.
    def distance_to_cursor(position: Position) -> float:
        a = position.column_number - (cursor_pos[0] + 1)
        b = 2 * (position.line_number - (cursor_pos[1] + 1))
        return (a * a + b * b) ** 0.5

    ranked = list(range(len(positions)))
    ranked.sort(key=lambda i: distance_to_cursor(positions[i]))
    return ranked


def assign_labels(
    labels: typing.List[str],
    positions: typing.List[Position],
    ranked: typing.List[int],
    previous: typing.Dict[int, str],
) -> typing.List[str]:
    # Assign single-char labels nearest-first. Every match gets a label,
    # including the nearest one — like flash's label.current: a match you can see
    # always has a key to jump to it, and Enter is just a shortcut to the nearest
    # (which also carries the distinct "current" highlight). Reuse a match's
    # previous label when it's still available so labels stay put as the query
    # narrows instead of reshuffling under the user.
    assigned = [""] * len(positions)
    pool_set = set(labels)
    taken: typing.Set[str] = set()
    for idx in ranked:
        prev = previous.get(positions[idx].offset)
        if prev and prev in pool_set and prev not in taken:
            assigned[idx] = prev
            taken.add(prev)
    fresh = (label for label in labels if label not in taken)
    for idx in ranked:
        if assigned[idx] == "":
            label = next(fresh, "")
            if label == "":
                break
            assigned[idx] = label
    return assigned


def _run_tmux_command(*args: str) -> str:
    proc = subprocess.run(("tmux", *args), check=True, capture_output=True)
    result = proc.stdout.decode()[:-1]
    return result


def _get_tmux_vars(*tmux_var_names: str) -> typing.Dict[str, str]:
    result = _run_tmux_command(
        "display-message", "-p", "\n".join("#{%s}" % s for s in tmux_var_names)
    )
    tmux_var_values = result.split("\n")
    tmux_vars = dict(zip(tmux_var_names, tmux_var_values))
    return tmux_vars


def interactive(screen: Screen) -> typing.Optional[Position]:
    # flash.nvim-style loop: type characters to narrow; matches and labels
    # update live on every keystroke. A label key jumps to that match; Enter
    # jumps to the nearest (unlabelled) match; Escape or an empty keypress
    # cancels. With autojump on, a query that leaves exactly one match jumps
    # immediately (forward typing only — a backspace down to one match waits).
    # Returns the chosen position — the jump runs after the overlay is torn
    # down — or None to cancel.
    query = ""
    previous: typing.Dict[int, str] = {}  # offset -> label, for label stability
    just_deleted = False
    with screen.overlay():
        while True:
            positions = search_for_key(screen.lines, query) if query != "" else []
            ranked = rank_positions(positions, screen.cursor_pos)
            current_idx = ranked[0] if ranked else -1
            if AUTOJUMP and len(positions) == 1 and not just_deleted:
                return positions[0]
            if positions:
                excluded = continuation_chars(screen.raw, positions, len(query))
                alphabet = [c for c in LABEL_CHARS if c.lower() not in excluded]
                labels = generate_labels(alphabet, len(positions))
                assigned = assign_labels(labels, positions, ranked, previous)
            else:
                assigned = []
            previous = {
                positions[i].offset: assigned[i]
                for i in range(len(positions))
                if assigned[i] != ""
            }
            label_targets = {
                assigned[i]: positions[i]
                for i in range(len(positions))
                if assigned[i] != ""
            }
            screen.draw(screen.render(query, positions, assigned, current_idx))

            key = read_key("jump: {}".format(query))
            if key in ("", "Escape", "C-c", "C-g"):
                return None
            if key in ("Enter", "C-m"):
                return positions[current_idx] if current_idx >= 0 else None
            if key in ("BSpace", "C-h", "DC", "C-?"):
                query = query[:-1]
                just_deleted = True
                continue
            char = key_to_char(key)
            if char is None:
                continue  # ignore non-searchable keys (arrows, Tab, ...)
            if char in label_targets:  # single-char labels: a label key jumps now
                return label_targets[char]
            query += char
            just_deleted = False


def main() -> None:
    screen = Screen()
    position = interactive(screen)
    if position is not None:
        screen.jump_to_pos(position.column_number - 1, position.line_number - 1)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
