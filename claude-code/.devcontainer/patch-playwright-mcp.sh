#!/bin/sh
# No-op. The image now configures Playwright MCP through PLAYWRIGHT_MCP_* env vars,
# so plugin .mcp.json files are no longer rewritten. Kept so projects whose
# postStartCommand or init-plugins.sh still call it don't fail.
# Transitional: delete this file and its COPY after 2027-01-31.
exit 0
