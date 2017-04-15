#!/bin/bash

CURDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # works in sourced files, only works for bash

export RENARD_SCRIPT_BASE="$CURDIR"

. $RENARD_SCRIPT_BASE/from-curie/script/install-native-dep
. $RENARD_SCRIPT_BASE/from-curie/script/start-xvfb
. $RENARD_SCRIPT_BASE/from-curie/script/get-aux-repo
. $RENARD_SCRIPT_BASE/from-curie/script/install-and-test-dist
. $RENARD_SCRIPT_BASE/general/run-coverage-deparse
