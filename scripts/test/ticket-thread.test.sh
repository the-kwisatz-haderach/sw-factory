#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
thread="$here/../ticket-thread"

json='{"number": 23, "title": "Add x", "body": "Do x.", "comments": [{"author": {"login": "owner"}, "createdAt": "2026-01-02T00:00:00Z", "body": "Use y."}]}'
want="$(printf '# #23: Add x\n\nDo x.\n\n---\n\n**owner** commented on 2026-01-02T00:00:00Z:\n\nUse y.')"
expect_output "renders the title, body and every comment" "$want" sh -c "echo '$json' | '$thread'"
expect_output "a ticket without a body still renders" "# #4: Bare" sh -c "echo '{\"number\":4,\"title\":\"Bare\",\"body\":null,\"comments\":[]}' | '$thread'"

finish
