# Reuse an open Arc tab from a terminal link — deferred idea

**Status:** Potential future improvement. No automation or configuration change is planned now.

## Desired behavior

When a link is clicked in the terminal, focus an existing Arc tab whose current
URL matches the link. Open a new Arc tab only when there is no match. Preserve
the normal foreground or background behavior of the click gesture where
possible.

## What is available

- Arc for macOS has an AppleScript API for querying windows, spaces, and tabs.
  The installed `/Applications/Arc.app` scripting dictionary exposes each
  tab's `URL` and a `select` command. This could make lookup local and avoid
  scanning Arc's sidebar through UI automation. Arc's
  [release notes](https://resources.arc.net/hc/en-us/articles/20498377604887-Arc-for-macOS-2023-Release-Notes)
  confirm the tab-query API.
- Ghostty currently opens clicked URLs through the macOS system opener. Its
  [configuration reference](https://ghostty.org/docs/config/reference#link-url)
  describes that behavior, while a
  [custom URL handler](https://github.com/ghostty-org/ghostty/discussions/9546)
  is still a feature request. A local Arc lookup helper therefore has no
  straightforward hook into the existing click gesture.

## Revisit when

Ghostty supports a custom link-opening command, or another lightweight hook
can intercept terminal link clicks without changing the system's default
browser. Then prototype an AppleScript lookup and measure click-to-focus
latency. Define URL matching across fragments, redirects, spaces, and profiles
before making it the default path. An agent-driven UI check for every click is
too slow for this use case.
