#!/bin/bash

CURDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # works in sourced files, only works for bash

export SCRIPT_BASE="$CURDIR"

. $SCRIPT_BASE/from-curie/script/install-native-dep
. $SCRIPT_BASE/from-curie/script/start-xvfb
. $SCRIPT_BASE/from-curie/script/get-aux-repo
. $SCRIPT_BASE/from-curie/script/install-and-test-dist
. $SCRIPT_BASE/from-curie/script/run-coverage-xform
