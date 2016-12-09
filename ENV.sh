#!/usr/bin/env bash

main() {
	_check_if_being_sourced;
	_check_directory_with_all_repos;

	export RENARD_TEST_DATA_PATH=$(_repo_dir "test-data")
	export RENARD_SCRIPT_BASE=$(_repo_dir "devops")/script
}

_repo_dir () {
	DIR_NAME="$1"
	_check_directory_with_all_repos;
	_check_in_wrapper;
	if [ 1 == "$RENARD_IN_WRAPPER" ]; then
		echo "$RENARD_ALL_REPO_DIR/$DIR_NAME/$DIR_NAME"
	else
		echo "$RENARD_ALL_REPO_DIR/$DIR_NAME"
	fi
}

_check_source_env_script_dir () {
	# works in sourced files, only works for bash
	export RENARD_ENV_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
}

_check_in_wrapper () {
	if [ -n "$RENARD_IN_WRAPPER" ]; then
		# already calculated
		return
	fi

	_check_source_env_script_dir;
	LAST_PART_OF_PATH=$(basename $RENARD_ENV_SCRIPT_DIR)
	DIR_ABOVE_ENV_SCRIPT_DIR=$(cd $RENARD_ENV_SCRIPT_DIR/.. && pwd)
	if [ $(basename $DIR_ABOVE_ENV_SCRIPT_DIR) = $LAST_PART_OF_PATH ]; then
		export RENARD_IN_WRAPPER=1
	else
		export RENARD_IN_WRAPPER=0
	fi

}

_check_directory_with_all_repos () {
	if [ -n "$RENARD_ALL_REPO_DIR" ]; then
		# already calculated
		return
	fi

	_check_in_wrapper;
	if [ 1 == "$RENARD_IN_WRAPPER" ]; then
		# We are in the wrapper
		export RENARD_ALL_REPO_DIR=$( cd $RENARD_ENV_SCRIPT_DIR/../.. && pwd )
	else
		export RENARD_ALL_REPO_DIR=$( cd $RENARD_ENV_SCRIPT_DIR/.. && pwd )
	fi
}


_check_if_being_sourced () {
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
		echo "Sourcing ${BASH_SOURCE[0]}"
	else
		cat <<USAGE
You must source the script:

  . ${0}
USAGE
		exit 1
	fi
}


## renard_run_cover_on_branch
##
## Syntax
##
##   renard_run_cover_on_branch [branch] [command]
##
## Example
##
##   renard_run_cover_on_branch master
##
##   renard_run_cover_on_branch feat/foo
##
## Runs the tests using prove on a given branch
## (or the current branch if none is given).
##
## Requires: Devel::Cover
##
##     cpanm Devel::Cover
##
## Recommends: Pod::Coverage
##
##     cpanm Pod::Coverage
renard_run_cover_on_branch () {
	_check_in_wrapper;
	BRANCH="$1";
	if [ -z "$BRANCH" ]; then
		# set branch to the name of the current branch
		BRANCH=`git rev-parse --abbrev-ref HEAD`
	fi

	COVER_DIR="cover_db/$BRANCH"
	if [ 1 == "$RENARD_IN_WRAPPER" ]; then
		# move to directory above
		COVER_DIR="../$COVER_DIR"
	fi
	mkdir -p "$COVER_DIR"
	COVER_DIR=$(cd $COVER_DIR && pwd)

	if [ -z "$DEVEL_COVER_SILENT" ]; then
		DEVEL_COVER_SILENT=1
	fi
	(
		export HARNESS_PERL_SWITCHES="-MDevel::Cover=-db,$COVER_DIR,+ignore,^x?t/,-silent,$DEVEL_COVER_SILENT"
		git co $BRANCH
		cover $COVER_DIR -delete
		prove -lvr t # xt
		cover $COVER_DIR -report html #+ignore '^x?t/'
		cover $COVER_DIR -report vim  #+ignore '^x?t/'
		#see $COVER_DIR/coverage.html
	)
}

## renard_run_cover_on_branch_dzil
##
## The same as renard_run_cover_on_branch, except using `dzil test` to run
## the test harness.
renard_run_cover_on_branch_dzil () {
	_check_in_wrapper;
	BRANCH="$1";
	if [ -z "$BRANCH" ]; then
		# set branch to the name of the current branch
		BRANCH=`git rev-parse --abbrev-ref HEAD`
	fi

	COVER_DIR="cover_db/$BRANCH"
	if [ 1 == "$RENARD_IN_WRAPPER" ]; then
		# move to directory above
		COVER_DIR="../$COVER_DIR"
	fi
	mkdir -p "$COVER_DIR"
	COVER_DIR=$(cd $COVER_DIR && pwd)

	(
		export HARNESS_PERL_SWITCHES="-MDevel::Cover=-db,$COVER_DIR,+ignore,^x?t/"
		git co $BRANCH
		cover $COVER_DIR -delete
		dzil test --all --keep
		( cd .build/latest && cover $COVER_DIR )
		#see $COVER_DIR/coverage.html
	)
}


main;
