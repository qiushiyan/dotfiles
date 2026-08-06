# Reaching a dev server from the phone

Satellite of `docs/mobile-terminal-access.md`. That doc gets you a **terminal**
on the laptop; this one gets your phone's **browser** to a dev server running
there. The two are independent channels over the same tailnet — Moshi is not
involved in this path at all.

## Why `localhost` can't work

`pnpm dev` and friends bind to `127.0.0.1`. On the phone, `http://localhost:3000`
is **always** the phone itself — `localhost` means "this device," no matter what
is running in your SSH session. So the server has to become reachable over the
network, and you visit it at the laptop's Tailscale hostname.

Two approaches. Pick on whether the app needs HTTPS.

## Option A — bind to all interfaces (simplest, HTTP only)

Most dev servers take a flag to bind `0.0.0.0` instead of `127.0.0.1` — for
Vite-family tools that is `--host`; Next.js wants `--hostname 0.0.0.0`. Check
your own tool's flag rather than trusting a list here.

Then browse to `http://qiushi-mac:3000` on the phone: MagicDNS resolves the
hostname to the tailnet IP, the server accepts because it is now listening on
all interfaces, and HMR works normally.

**Caveat:** this also exposes the dev server to your home LAN, not just the
tailnet. Usually fine at home; use Option B when it isn't.

## Option B — Tailscale Serve (real HTTPS)

For service workers, WebAuthn, camera/mic APIs, or `SharedArrayBuffer`:

```sh
# Laptop, while the dev server runs on localhost:3000
tailscale serve --bg https / http://localhost:3000
# Phone browser: https://qiushi-mac.<your-tailnet>.ts.net
```

Tailscale runs an HTTPS proxy on the tailnet interface, terminates TLS with a
real ACME-issued cert for the `*.ts.net` subdomain, and forwards to
`localhost:3000` — so the dev server can stay bound to `127.0.0.1` and only
Tailscale talks to it. Strictly tailnet-only, never LAN.

Tear down with `tailscale serve --bg off`, or `tailscale serve reset` for
everything.

**One-time prerequisite:** enable HTTPS certs for the tailnet in the Tailscale
admin console → DNS → HTTPS Certificates. Single toggle, free.

## Which to use

Start with Option A — it is one flag on a command you already run. Move to
Option B only when a specific browser API rejects the insecure origin, which the
console will tell you.
