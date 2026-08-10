# tmux 3.7b plus a backported fix for popups being overwritten by background
# pane updates when status-position is top (overlay checks used window
# coordinates while drawing used tty coordinates, so the popup's protected
# region landed `status lines` rows too low). Fixes screen_redraw_draw_pane,
# screen_redraw_draw_pane_status, screen_redraw_draw_borders_cell and the
# scrollbar drawer. Drop this formula and return to stock `tmux` once an
# upstream release includes the fix (check the tmux CHANGES for popup overlay
# fixes after 3.7b).
#
# Managed from the dotfiles repo: see docs/tmux-popup-patch.md there.
class TmuxPopupfix < Formula
  desc "Terminal multiplexer (3.7b + popup overlay fix for status-position top)"
  homepage "https://tmux.github.io/"
  url "https://github.com/tmux/tmux/releases/download/3.7b/tmux-3.7b.tar.gz"
  sha256 "87f2e99e3b685973f2ca002ffd6ed7e51a5744f7009daae5a15670b6d532db96"
  license "ISC"
  version "3.7b"

  depends_on "pkgconf" => :build
  depends_on "libevent"
  depends_on "ncurses"
  depends_on "utf8proc"

  conflicts_with "tmux", because: "both install a tmux binary"

  patch :p1, :DATA

  def install
    args = %W[
      --enable-utf8proc
      --sysconfdir=#{etc}
    ]
    system "./configure", *std_configure_args, *args
    system "make", "install"
  end

  test do
    system bin/"tmux", "-V"
  end
end

__END__
--- a/screen-redraw.c
+++ b/screen-redraw.c
@@ -672,7 +672,7 @@
 	struct visible_ranges	*r;
 	struct visible_range	*ri;
 	u_int			 i, l, x, width, size;
-	int			 xoff, yoff;
+	int			 xoff, yoff, ty;

 	log_debug("%s: %s @%u", __func__, c->name, w->id);

@@ -716,10 +716,17 @@
 			width = size - x;
 		}

-		r = tty_check_overlay_range(tty, x, yoff, width);
-		r = screen_redraw_get_visible_ranges(wp, x, yoff, width, r);
+		/*
+		 * The overlay check needs tty coordinates (the popup is
+		 * registered in tty space), but the visible ranges need
+		 * window coordinates: the tty y includes the status offset.
+		 */
+		ty = yoff;
 		if (ctx->statustop)
-			yoff += ctx->statuslines;
+			ty += ctx->statuslines;
+		r = tty_check_overlay_range(tty, x, ty - ctx->oy, width);
+		r = screen_redraw_get_visible_ranges(wp, x, yoff, width, r);
+		yoff = ty;
 		for (i = 0; i < r->used; i++) {
 			ri = &r->ranges[i];
 			if (ri->nx == 0)
@@ -992,12 +999,20 @@
 	struct window_pane	*wp, *active = server_client_get_pane(c);
 	struct grid_cell	 gc;
 	u_int			 cell_type;
-	u_int			 x = ctx->ox + i, y = ctx->oy + j;
+	u_int			 x = ctx->ox + i, y = ctx->oy + j, ty;
 	int			 isolates;
 	struct visible_ranges	*r;

+	/*
+	 * The overlay check needs tty coordinates (the cell is drawn at the
+	 * tty cursor position below), not window coordinates.
+	 */
 	if (c->overlay_check != NULL) {
-		r = c->overlay_check(c, c->overlay_data, x, y, 1);
+		if (ctx->statustop)
+			ty = ctx->statuslines + j;
+		else
+			ty = j;
+		r = c->overlay_check(c, c->overlay_data, i, ty, 1);
 		if (server_client_ranges_is_empty(r))
 			return;
 	}
@@ -1366,8 +1381,12 @@
 			width = ctx->sx - wx;
 		}

-		/* Get visible ranges of line before we draw it. */
-		r = tty_check_overlay_range(tty, wx, wy, width);
+		/*
+		 * Get visible ranges of line before we draw it. The overlay
+		 * check needs the tty y (py) since overlays are registered in
+		 * tty coordinates; the visible ranges need the window y (wy).
+		 */
+		r = tty_check_overlay_range(tty, wx, py, width);
 		r = screen_redraw_get_visible_ranges(wp, wx, wy, width, r);
 		tty_default_colours(&defaults, wp);
 		for (k = 0; k < r->used; k++) {
@@ -1542,7 +1561,7 @@
 	for (j = jmin; j < jmax; j++) {
 		wy = sb_wy + j; /* window y coordinate */
 		py = sb_tty_y + j; /* tty y coordinate */
-		r = tty_check_overlay_range(tty, sb_x, wy, imax);
+		r = tty_check_overlay_range(tty, sb_x, py, imax);
 		r = screen_redraw_get_visible_ranges(wp, sb_x, wy, imax, r);
 		for (i = imin; i < imax; i++) {
 			px = sb_x + ox + i; /* tty x coordinate */
