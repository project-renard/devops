set -e
set -o pipefail

ANSI_RED="\033[31;1m"
ANSI_GREEN="\033[32;1m"
ANSI_RESET="\033[0m"
ANSI_CLEAR="\033[0K"

simple_retry() {
	retry_cmd 3 "$@"
}

retry_cmd() {
	local result=0
	local count=1
	set +e

	retry_cnt=$1
	shift 1

	while [ $count -le ${retry_cnt} ]; do
		[ $result -ne 0 ] && {
			echo -e "\n${ANSI_RED}The command \"$@\" failed. Retrying, $count of ${retry_cnt}${ANSI_RESET}\n" >&2
		}
		"$@"
		result=$?
		[ $result -eq 0 ] && break
		count=$(($count + 1))
		sleep 1
	done

	[ $count -gt ${retry_cnt} ] && {
		echo -e "\n${ANSI_RED}The command \"$@\" failed ${retry_cnt} times.${ANSI_RESET}\n" >&2
	}

	set -e
	return $result
}
