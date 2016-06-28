#!/bin/bash

CURDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # works in sourced files, only works for bash

unset OPENSSL_CONF
export OPENSSL_PREFIX="/c/msys64/mingw64"
#echo PATH=$PATH
#set
#pkg-config --libs --cflags  openssl

export PERL5OPT="-I$CURDIR -MEUMMnosearch"
echo PERL5OPT=$PERL5OPT;
