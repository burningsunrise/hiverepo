#!/usr/bin/env bash

# default repository url. May be overriden by /hive-config/repo-sync.url
REPOURL=https://download.hiveos.farm/repo/binary/

# default repository path
REPOPATH=/var/www/html/repomirror

# for all the programs running from within the script, make sure they run in the "UTC" time zone
# (or whatever is set on the remote repo server as the timezone for timestamps of the files in the repo)
export TZ=UTC
WGET="/usr/bin/wget -t 0 -T 20 -nv -e robots=off"
[[ -t 1 && "$1" == "-v" ]] && WGET+=" -v"


function mydate() {
	date --rfc-3339=seconds
}


function check_md5() {
	# check md5 using InRelease
	local file="$1"
	local md5=`md5sum "$REPOPATH/repo/binary/$file" 2>/dev/null | awk '{ printf $1 }'`
	local exp
	exp=`grep -A 3 -m 1 "MD5Sum:" $REPOPATH/repo/binary/InRelease | grep "$file$" | awk '{ printf $1 }'` &&
		[[ "$exp" == "$md5" ]] && return 0
	[[ -z "$md5" ]] &&
		echo "Error: $file - not exists" ||
		echo "Error: $file - bad MD5 $md5 (expected $exp)"
	return 1
}

[[ -z $repourl ]] &&
	repourl="$REPOURL"

# should end in a / for successful sync, add trailing slash if missing
[[ "${repourl}" != */ ]] && repourl="${repourl}/"

# This does not work as rig will fetch from itself
#repourl=`cat /etc/apt/sources.list.d/hiverepo.list | grep '^deb http' | tail -n 1 | awk '{print $2}'`
echo "Repo URL: $repourl"

domain=`echo "$repourl" | sed -e 's|^[^/]*//||' -e 's|/.*$||'`
echo "Domain: $domain"

cd /var/www/html

echo "Working under $(pwd)"

# wget will download to domain directory, so link it appropriately
[[ ! -e /var/www/html/$domain ]] &&
	ln -sf $REPOPATH /var/www/html/$domain

need_update=1

# check RepoVer
repover=`${WGET} -O - "${repourl}RepoVer"`
exitcode=$?
[[ $exitcode -ne 0 ]] && echo "Error: Unable to get RepoVer (exitcode=$exitcode), exiting" && exit 1
echo "RepoVer: $repover"

# check for repo update
if [[ -e $REPOPATH/repo/binary/InRelease ]]; then
	echo "$(mydate): Checking repo update"
	release=`${WGET} -O - "${repourl}InRelease"`
	exitcode=$?
	[[ $exitcode -ne 0 ]] && echo "Error: Unable to get InRelease file (exitcode=$exitcode), exiting" && exit 2

	if [[ ! -z "$release" && "$release" == "$(< $REPOPATH/repo/binary/InRelease )" ]]; then
		echo "Repo is up to date!"
		need_update=0
	fi
fi

# check md5 using InRelease
if [[ $need_update -eq 0 ]]; then
	check_md5 Packages || need_update=1
	check_md5 Packages.gz || need_update=1
fi

if [[ $need_update -ne 0 ]]; then
	# remove files like RepoVer and other files which are not actual packages
	if [[ -e $REPOPATH/repo/binary ]]; then
		for file in `ls $REPOPATH/repo/binary/ | grep -v deb`
		do
			rm -f $file
		done
	fi

	# Request re-sync of everything except DEB files with conditional if-modified-since requests from the remote repo server,
	# overwriting local files with ones from the remote server. Using Packages for download DEB files later
	# Because -c and -N do not seem to work too nicely in GNU wget (only larger-than-original new files get synced upon update),
	# just use -N instead of  trying to save bandwidth upon incomplete downloads

	echo "$(mydate): Updating repo packages"
	${WGET} -r --no-parent --level=1 --reject=deb -N "$repourl" || echo "Error: Syncing failed (exitcode=$exitcode)"

	# Remove index files so directory contents will be generated via nginx
	# this may cause a certain amount of trash-talk from wget complaining about unavailable last-modified timestamps.
	rm -f repomirror/repo/index.html
	rm -f repomirror/repo/binary/index.html
fi

cd $REPOPATH/repo/binary

[[ ! -e InRelease ]] && echo "Error: No InRelease file, exiting" && exit 3

updated=`grep -oP "Date: \K.*" InRelease` && echo "Repo update time: $updated"

[[ ! -e Packages ]] && echo "Error: No Packages listing, exiting" && exit 4

# check md5 again using InRelease
if [[ $need_update -ne 0 ]]; then
	check_md5 Packages
	[[ $? -ne 0 ]] && echo "Exiting" && exit 5
fi

# Check for md5 mismatches vs Packages file, if we have one from a successful download.
# Insane Packages file will cause massive deletion of .deb files, but c'est la vie
echo "$(mydate): Checking and downloading missed/damaged/incomplete files using fresh Packages listing"
cnt=0
while IFS="|:" read -a arr; do
	declare -A info=( ["${arr[0]}"]="${arr[1]}" ["${arr[2]}"]="${arr[3]}" ["${arr[4]}"]="${arr[5]}" )
	(( ++cnt % 100 == 0 )) && [[ -t 1 ]] && echo "Files processed: $cnt"
	#echo "${info[Filename]} ${info[Size]} ${info[MD5sum]}"
	file="${info[Filename]/.\/}"
	[[ -z "$file" ]] && continue;
	if [[ -e "${info[Filename]}" ]]; then
		size=$(stat --format=%s "${info[Filename]}" 2>/dev/null) || size=0
		if [[ ! -z "${info[Size]}" && "${info[Size]}" -gt $size ]]; then
			echo "Error: $file - incomplete download ($size/${info[Size]}), resuming"
			${WGET} -c ${repourl}$file
		fi
		[[ -z "${info[MD5sum]}" || $(md5sum "${info[Filename]}" | awk '{printf $1}') == "${info[MD5sum]}" ]] && continue
			echo "Error: $file - bad MD5 sum, deleting"
			unlink "${info[Filename]}"
	fi
	echo "Downloading ${repourl}$file"
	${WGET} ${repourl}$file
	# we can check again but repo may be updated during checking
done < <( cat -s Packages | grep -E "^$|^Filename|^MD5sum|^Size" | tr '\n' '|' | sed  's/||/\n/g' | tr -d ' ' )
echo "Files processed: $cnt"

echo "$(mydate): Done."

exit 0
