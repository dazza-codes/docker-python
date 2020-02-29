#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s nullglob

# https://www.python.org/downloads/23Introduction (under "OpenPGP Public Keys")
declare -A gpgKeys=(
	# gpg: key 18ADD4FF: public key "Benjamin Peterson <benjamin@python.org>" imported
	[2.7]='C01E1CAD5EA2C4F0B8E3571504C367C218ADD4FF'
	# https://www.python.org/dev/peps/pep-0373/#release-manager-and-crew

	# gpg: key F73C700D: public key "Larry Hastings <larry@hastings.org>" imported
	[3.5]='97FC712E4C024BBEA48A61ED3A5CA953F73C700D'
	# https://www.python.org/dev/peps/pep-0478/#release-manager-and-crew

	# gpg: key AA65421D: public key "Ned Deily (Python release signing key) <nad@acm.org>" imported
	[3.6]='0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D'
	# https://www.python.org/dev/peps/pep-0494/#release-manager-and-crew

	# gpg: key AA65421D: public key "Ned Deily (Python release signing key) <nad@acm.org>" imported
	[3.7]='0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D'
	# https://www.python.org/dev/peps/pep-0537/#release-manager-and-crew

	# gpg: key B26995E310250568: public key "\xc5\x81ukasz Langa (GPG langa.pl) <lukasz@langa.pl>" imported
	[3.8]='E3FF2839C048B25C084DEBE9B26995E310250568'
	# https://www.python.org/dev/peps/pep-0569/#release-manager-and-crew

	# gpg: key B26995E310250568: public key "\xc5\x81ukasz Langa (GPG langa.pl) <lukasz@langa.pl>" imported
	[3.9]='E3FF2839C048B25C084DEBE9B26995E310250568'
	# https://www.python.org/dev/peps/pep-0596/#release-manager-and-crew
)

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

pipVersion="$(curl -fsSL 'https://pypi.org/pypi/pip/json' | jq -r .info.version)"
getPipCommit="$(curl -fsSL 'https://github.com/pypa/get-pip/commits/master/get-pip.py.atom' | tac|tac | awk -F '[[:space:]]*[<>/]+' '$2 == "id" && $3 ~ /Commit/ { print $4; exit }')"
getPipUrl="https://github.com/pypa/get-pip/raw/$getPipCommit/get-pip.py"
getPipSha256="$(curl -fsSL "$getPipUrl" | sha256sum | cut -d' ' -f1)"

generated_warning() {
	cat <<-EOH
		#
		# NOTE: THIS DOCKERFILE IS GENERATED VIA "update.sh"
		#
		# PLEASE DO NOT EDIT IT DIRECTLY.
		#

	EOH
}

for version in "${versions[@]}"; do
	rcVersion="${version%-rc}"
	rcGrepV='-v'
	if [ "$rcVersion" != "$version" ]; then
		rcGrepV=
	fi

	possibles=( $(
		{
			git ls-remote --tags https://github.com/python/cpython.git "refs/tags/v${rcVersion}.*" \
				| sed -r 's!^.*refs/tags/v([0-9a-z.]+).*$!\1!' \
				| grep $rcGrepV -E -- '[a-zA-Z]+' \
				|| :

			# this page has a very aggressive varnish cache in front of it, which is why we also scrape tags from GitHub
			curl -fsSL 'https://www.python.org/ftp/python/' \
				| grep '<a href="'"$rcVersion." \
				| sed -r 's!.*<a href="([^"/]+)/?".*!\1!' \
				| grep $rcGrepV -E -- '[a-zA-Z]+' \
				|| :
		} | sort -ruV
	) )
	fullVersion=
	declare -A impossible=()
	for possible in "${possibles[@]}"; do
		rcPossible="${possible%%[a-z]*}"

		# varnish is great until it isn't
		if wget -q -O /dev/null -o /dev/null --spider "https://www.python.org/ftp/python/$rcPossible/Python-$possible.tar.xz"; then
			fullVersion="$possible"
			break
		fi

		if [ -n "${impossible[$rcPossible]:-}" ]; then
			continue
		fi
		impossible[$rcPossible]=1
		possibleVersions=( $(
			wget -qO- -o /dev/null "https://www.python.org/ftp/python/$rcPossible/" \
				| grep '<a href="Python-'"$rcVersion"'.*\.tar\.xz"' \
				| sed -r 's!.*<a href="Python-([^"/]+)\.tar\.xz".*!\1!' \
				| grep $rcGrepV -E -- '[a-zA-Z]+' \
				| sort -rV \
				|| true
		) )
		if [ "${#possibleVersions[@]}" -gt 0 ]; then
			fullVersion="${possibleVersions[0]}"
			break
		fi
	done

	if [ -z "$fullVersion" ]; then
		{
			echo
			echo
			echo "  error: cannot find $version (alpha/beta/rc?)"
			echo
			echo
		} >&2
		exit 1
	fi

	echo "$version: $fullVersion"

	for v in \
		docker19.03 \
	; do
		dir="$version/$v"
		variant="$(basename "$v")"

		echo "Checking $dir"
		[ -d "$dir" ] || continue

		case "$variant" in
			docker*) template='docker'; tag="${variant#docker}" ;;
		esac
		if [[ "$version" == 2.* ]]; then
			# skip any python 2.x
			continue
		fi
		template="Dockerfile-${template}.template"
		echo "Updating: $dir/Dockerfile using $template"

		{ generated_warning; cat "$template"; } > "$dir/Dockerfile"

		sed -ri \
			-e 's/^(ENV GPG_KEY) .*/\1 '"${gpgKeys[$version]:-${gpgKeys[$rcVersion]}}"'/' \
			-e 's/^(ENV PYTHON_VERSION) .*/\1 '"$fullVersion"'/' \
			-e 's/^(ENV PYTHON_RELEASE) .*/\1 '"${fullVersion%%[a-z]*}"'/' \
			-e 's/^(ENV PYTHON_PIP_VERSION) .*/\1 '"$pipVersion"'/' \
			-e 's!^(ENV PYTHON_GET_PIP_URL) .*!\1 '"$getPipUrl"'!' \
			-e 's!^(ENV PYTHON_GET_PIP_SHA256) .*!\1 '"$getPipSha256"'!' \
			-e 's/^(FROM python):.*/\1:'"$version-$tag"'/' \
			-e 's!^(FROM docker):.*!\1:'"$tag"'!' \
			"$dir/Dockerfile"

		case "$rcVersion/$v" in
			# Libraries to build the nis module only available in Alpine 3.7+.
			# Also require this patch https://bugs.python.org/issue32521 only available in Python 2.7, 3.6+.
			3.5/docker*)
				sed -ri -e '/libnsl-dev/d' -e '/libtirpc-dev/d' "$dir/Dockerfile"
				;;& # (3.5*/alpine* needs to match the next blocks too)

			# https://bugs.python.org/issue11063, https://bugs.python.org/issue20519 (Python 3.7.0+)
			# A new native _uuid module improves uuid import time and avoids using ctypes.
			# This requires the development libuuid headers.
			3.[5-6]/docker*)
				sed -ri -e '/util-linux-dev/d' "$dir/Dockerfile"
				;;
			3.[5-6]/*)
				sed -ri -e '/uuid-dev/d' "$dir/Dockerfile"
				;;
		esac

		major="${rcVersion%%.*}"
		minor="${rcVersion#$major.}"
		minor="${minor%%.*}"
		if [ "$major" -gt 3 ] || { [ "$major" -eq 3 ] && [ "$minor" -ge 8 ]; }; then
			# PROFILE_TASK has a reasonable default starting in 3.8+; see:
			#   https://bugs.python.org/issue36044
			#   https://github.com/python/cpython/pull/14702
			#   https://github.com/python/cpython/pull/14910
			perl -0 -i -p -e "s![^\n]+PROFILE_TASK(='[^']+?')?[^\n]+\n!!gs" "$dir/Dockerfile"
		fi
	done
done
