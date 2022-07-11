#!/usr/bin/env bash

DOWNLOAD_URL=https://download.hiveos.farm/latest/
TIMEOUT=20
OS_BRAND="hiveos"
OS_REGEX="$OS_BRAND-[^\"]+\.(zip|xz)"
URL_MASK="^(http|ftp|https)://.*/${OS_REGEX}$"

NOCOLOR=$'\033[0m'
BLACK=$'\033[0;30m'
DGRAY=$'\033[1;30m'
RED=$'\033[0;31m'
BRED=$'\033[1;31m'
GREEN=$'\033[0;32m'
BGREEN=$'\033[1;32m'
YELLOW=$'\033[0;33m'
BYELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
BBLUE=$'\033[1;34m'
PURPLE=$'\033[0;35m'
BPURPLE=$'\033[1;35m'
CYAN=$'\033[0;36m'
BCYAN=$'\033[1;36m'
LGRAY=$'\033[0;37m'
WHITE=$'\033[1;37m'
GRAY=$'\033[2;37m'

export PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/sbin:/usr/local/bin:$PATH"

url=

function url_decode() {
	echo -e "${1//%/\\x}"
}

function get_image_from_url { # return $url
	local from_url=$( url_decode "$1" )
	local name=$2
	set -o pipefail
	url=`curl --connect-timeout $TIMEOUT --retry 2 -fskL --head -w '%{url_effective}' "$from_url" 2>/dev/null | tail -n 1`
	if [[ $? -eq 0 ]]; then
		[[ "$url" =~ $URL_MASK ]] && return 0
		echo -e "$RED> Got bad url for $name image - $url${NOCOLOR}"
		return 1
	fi
	echo -e "$RED> Unable to get url for $name image${NOCOLOR}"
	return 2
}

get_image_from_url $DOWNLOAD_URL "Stable" || exit

wget -t 0 -T $TIMEOUT -P /var/www/html/repo --no-check-certificate "$url"