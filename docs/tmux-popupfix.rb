# tmux 3.7c with jemalloc plus a fix for popups overwritten by background
# pane updates when status-position is top (overlay checks used window
# coordinates while drawing used tty coordinates, so the popup's protected
# region landed `status lines` rows too low). Fixes screen_redraw_draw_pane,
# screen_redraw_draw_pane_status, screen_redraw_draw_borders_cell and the
# scrollbar drawer.
#
# Also fixes the server spinning for seconds per redraw when a client smaller
# than the window draws pane-border-status: the "right not visible" branch of
# screen_redraw_draw_pane_status underflowed the width to ~2^32 cells
# (tmux/tmux#5664).
#
# Also, for diagnosis: a fatal (tmux's fatal/fatalx, or libevent's own fatal
# error) appends its reason, a backtrace and the image's load slide to
# ~/.local/state/tmux-exit/fatal.log ($TMUX_FATAL_LOG overrides) even with
# logging off, since stock tmux writes a fatal's reason only to its -v log;
# tmux-exit-watch joins those lines into its exit record (docs/recovery.md).
#
# Drop this formula and return to stock `tmux` once an upstream release
# includes both fixes (check the tmux CHANGES for popup overlay fixes after
# 3.7c; 3.8 rewrites the pane status drawing).
#
# Managed from the dotfiles repo: see docs/tmux-popup-patch.md there.
class TmuxPopupfix < Formula
  desc "Terminal multiplexer (3.7c + popup overlay fix for status-position top)"
  homepage "https://tmux.github.io/"
  url "https://github.com/tmux/tmux/releases/download/3.7c/tmux-3.7c.tar.gz"
  sha256 "7c60cae9a0e25288e2e24750aafc9e8800fc7fd4555e447e1b29ee4201cfb3bf"
  license "ISC"
  version "3.7c"
  revision 2

  depends_on "pkgconf" => :build
  depends_on "libevent"
  depends_on "ncurses"
  depends_on "utf8proc"
  depends_on "jemalloc"

  conflicts_with "tmux", because: "both install a tmux binary"

  patch :p1, :DATA

  def install
    args = %W[
      --enable-utf8proc
      --enable-jemalloc
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

@@ -713,13 +713,20 @@
 			/* Right not visible. */
 			l = 0;
 			x = xoff - ctx->ox;
-			width = size - x;
+			width = ctx->sx - x;
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
--- a/log.c
+++ b/log.c
@@ -19,9 +19,14 @@
 #include <sys/types.h>
 
 #include <errno.h>
+#include <execinfo.h>
+#include <fcntl.h>
+#include <limits.h>
+#include <mach-o/dyld.h>
 #include <stdio.h>
 #include <stdlib.h>
 #include <string.h>
+#include <time.h>
 #include <unistd.h>
 
 #include "tmux.h"
@@ -31,11 +36,22 @@
 
 /* Log callback for libevent. */
 static void
-log_event_cb(__unused int severity, const char *msg)
+log_fatal_write(const char *, const char *);
+static void
+log_event_cb(int severity, const char *msg)
 {
+	if (severity == EVENT_LOG_ERR)
+		log_fatal_write("libevent: ", msg);
 	log_debug("%s", msg);
 }
 
+/* Local build: record libevent's fatal errors with logging off too. */
+__attribute__((constructor)) static void
+log_event_init(void)
+{
+	event_set_log_callback(log_event_cb);
+}
+
 /* Increment log level. */
 void
 log_add_level(void)
@@ -93,7 +109,7 @@
 		fclose(log_file);
 	log_file = NULL;
 
-	event_set_log_callback(NULL);
+	event_set_log_callback(log_event_cb);
 }
 
 /* Write a log message. */
@@ -135,6 +151,64 @@
 	va_end(ap);
 }
 
+/*
+ * Local build: a fatal leaves its reason in a file even with logging off,
+ * with a backtrace and the image's load slide so `atos -o <tmux> -s <slide>
+ * <addr>...` names static functions. TMUX_FATAL_LOG overrides the path.
+ * libevent's own fatal errors (EVENT_LOG_ERR, then exit(1)) are recorded
+ * the same way. Only the stack and write(2): an allocation failure is one
+ * of the causes.
+ */
+static void
+log_fatal_write(const char *prefix, const char *text)
+{
+	char		 path[PATH_MAX], line[2048];
+	const char	*env, *home;
+	void		*frames[64];
+	int		 fd, n, len;
+
+	if ((env = getenv("TMUX_FATAL_LOG")) != NULL && *env != '\0')
+		len = snprintf(path, sizeof path, "%s", env);
+	else if ((home = getenv("HOME")) != NULL && *home != '\0')
+		len = snprintf(path, sizeof path,
+		    "%s/.local/state/tmux-exit/fatal.log", home);
+	else
+		return;
+	if (len < 0 || (size_t)len >= sizeof path)
+		return;
+	if ((fd = open(path, O_WRONLY|O_APPEND|O_CREAT, 0600)) == -1)
+		return;
+
+	len = snprintf(line, sizeof line,
+	    "%lld pid %ld tmux %s slide 0x%lx %s%s", (long long)time(NULL),
+	    (long)getpid(), getversion(),
+	    (unsigned long)_dyld_get_image_vmaddr_slide(0), prefix, text);
+	if (len < 0)
+		len = 0;
+	if ((size_t)len > sizeof line - 2)
+		len = sizeof line - 2;
+	line[len++] = '\n';
+	write(fd, line, len);
+
+	n = backtrace(frames, sizeof frames / sizeof frames[0]);
+	backtrace_symbols_fd(frames, n, fd);
+	write(fd, "\n", 1);
+	close(fd);
+}
+
+static void
+log_fatal_record(const char *prefix, const char *msg, va_list ap)
+{
+	char	text[1024];
+	va_list	aq;
+
+	va_copy(aq, ap);
+	if (vsnprintf(text, sizeof text, msg, aq) < 0)
+		text[0] = '\0';
+	va_end(aq);
+	log_fatal_write(prefix, text);
+}
+
 /* Log a critical error with error string and die. */
 __dead void
 fatal(const char *msg, ...)
@@ -146,6 +220,10 @@
 		exit(1);
 
 	va_start(ap, msg);
+	log_fatal_record(tmp, msg, ap);
+	va_end(ap);
+
+	va_start(ap, msg);
 	log_vwrite(msg, ap, tmp);
 	va_end(ap);
 
@@ -159,6 +237,10 @@
 	va_list	 ap;
 
 	va_start(ap, msg);
+	log_fatal_record("fatal: ", msg, ap);
+	va_end(ap);
+
+	va_start(ap, msg);
 	log_vwrite(msg, ap, "fatal: ");
 	va_end(ap);
 
