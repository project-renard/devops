#!/bin/sh

CURDIR=`dirname "$0"`
#CURDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # works in sourced files, only works for bash

if `uname -a | grep -qi Linux` && `which apt-get > /dev/null`; then
	TARGET_SYSTEM="linux"
	HAS_APT_GET=1
fi

if `uname -a | grep -qi Darwin` && `which brew > /dev/null`; then
	TARGET_SYSTEM="osx"
	HAS_HOMEBREW=1
fi

if `uname -a | grep -qi Msys` && `which pacman > /dev/null`; then
	TARGET_SYSTEM="msys2"
	HAS_PACMAN=1
fi
