# ~/.config/zsh/proxy.zsh
# CLI proxy settings for Astrill OpenWeb on macOS.

: "${ASTRILL_PROXY_URL:=http://127.0.0.1:3213}"
: "${ASTRILL_PROXY_NO_PROXY:=localhost,127.0.0.1,::1,*.local}"

proxyon() {
  local proxy_url="${1:-$ASTRILL_PROXY_URL}"

  export HTTP_PROXY="$proxy_url"
  export HTTPS_PROXY="$proxy_url"
  export ALL_PROXY="$proxy_url"
  export http_proxy="$proxy_url"
  export https_proxy="$proxy_url"
  export all_proxy="$proxy_url"

  export NODE_USE_ENV_PROXY=1
  export NO_PROXY="$ASTRILL_PROXY_NO_PROXY"
  export no_proxy="$ASTRILL_PROXY_NO_PROXY"

  echo "CLI proxy enabled: $proxy_url"
}

proxyoff() {
  unset HTTP_PROXY HTTPS_PROXY ALL_PROXY
  unset http_proxy https_proxy all_proxy
  unset NODE_USE_ENV_PROXY
  unset NO_PROXY no_proxy

  echo "CLI proxy disabled"
}

proxystatus() {
  printf 'HTTP_PROXY=%s\n' "${HTTP_PROXY:-}"
  printf 'HTTPS_PROXY=%s\n' "${HTTPS_PROXY:-}"
  printf 'ALL_PROXY=%s\n' "${ALL_PROXY:-}"
  printf 'NODE_USE_ENV_PROXY=%s\n' "${NODE_USE_ENV_PROXY:-}"
  printf 'NO_PROXY=%s\n' "${NO_PROXY:-}"
}

# Astrill OpenWeb "Tunnel all apps" works as a tunnel, not always as a local
# HTTP proxy. Keep this opt-in so shells do not break when 127.0.0.1:3213 is
# not listening.
if [[ "${ASTRILL_PROXY_AUTO:-0}" == "1" ]]; then
  proxyon >/dev/null
fi
