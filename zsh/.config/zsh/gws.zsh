# Workaround for gws keychain encryption bug (https://github.com/googleworkspace/cli/issues/361)
# Injects a fresh gcloud application-default access token on every gws invocation.
# Auth with: gcloud auth application-default login --scopes=<all scopes>
gws() {
  GOOGLE_WORKSPACE_CLI_TOKEN=$(gcloud auth application-default print-access-token 2>/dev/null) command gws "$@"
}
