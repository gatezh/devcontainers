#!/bin/sh
# Sourced from ~/.zshrc and ~/.bashrc: the github@claude-plugins-official MCP server
# sends `Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}`, so give it the gh login's token (#118).
# gh prefers GH_TOKEN, then GITHUB_TOKEN. No login exports nothing: "Bearer " is a 400.
if [ -z "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
    _gh_mcp_token=$(gh auth token --hostname github.com 2>/dev/null) && [ -n "$_gh_mcp_token" ] \
        && export GITHUB_PERSONAL_ACCESS_TOKEN="$_gh_mcp_token"
    unset _gh_mcp_token
fi
