#!/bin/sh

# exit on failures
set -e

TESTDIR="$(dirname $0)"
UNBOUND_TESTCONF="unbound.conf"
UNBOUND_SYSCONFDIR_SUFFIX="unbound"
QUERYNAME="google.com."
INSTALL_PKGS="bind-tools"

apk add -U "${INSTALL_PKGS}"

# set additional vars based on cmd output
UNBOUND_CONFPATH="$(unbound -V | tr -s ' ' '\n'|fgrep -- '--sysconfdir='|sed 's/.*=//')/${UNBOUND_SYSCONFDIR_SUFFIX}"
UNBOUND_BINPATH="/$(dirname $(apk info -L unbound|egrep 'unbound$'))"
UNBOUNDD_CMD="${UNBOUND_BINPATH}/unbound -d"
UNBOUNDCK_CMD="${UNBOUND_BINPATH}/unbound-checkconf"

cp "${TESTDIR}/${UNBOUND_TESTCONF}" "${UNBOUND_CONFPATH}"

QUERY_ADDR=$(${UNBOUNDCK_CMD} -o interface)

# start up the server in background
${UNBOUNDD_CMD} &
# assume host is in path, and return/exit code indicates query success/failure
host "${QUERYNAME}" "${QUERY_ADDR}"
