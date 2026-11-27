#!/bin/sh
# Sourced, not run: the image installs it in /etc/profile.d and sources it from
# ~/.zshrc and ~/.bashrc, so VS Code's userEnvProbe (a login-interactive shell)
# carries the export into the extension host and every terminal.
#
# The github@claude-plugins-official MCP server sends
# `Authorization: Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}` with no OAuth fallback, so
# unset means a bare "Bearer " and HTTP 400. The gh login's OAuth token is accepted
# there, so no PAT has to be created (#118). A token already in the environment wins:
# an empty `${localEnv:...}` counts as unset.
if [ -z "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
    if [ -n "${GH_TOKEN:-}" ]; then
        export GITHUB_PERSONAL_ACCESS_TOKEN="$GH_TOKEN"
    elif [ -n "${GITHUB_TOKEN:-}" ]; then
        export GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_TOKEN"
    elif command -v gh >/dev/null 2>&1; then
        # Not signed in: export nothing rather than an empty token.
        _gh_mcp_token=$(gh auth token 2>/dev/null) && [ -n "$_gh_mcp_token" ] \
            && export GITHUB_PERSONAL_ACCESS_TOKEN="$_gh_mcp_token"
        unset _gh_mcp_token
    fi
fi
