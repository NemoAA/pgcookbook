#!/bin/bash

# describe_postgres.sh - provides details about a PostgreSQL instance.
#
# Collects and prints out:
#
# - version
# - tablespaces
# - custom settings
#
# Copyright (c) 2015 Sergey Konoplev
#
# Sergey Konoplev <gray.ru@gmail.com>

source $(dirname $0)/config.sh
source $(dirname $0)/utils.sh

# version information

(
    src=$($PSQL -XAtc 'SELECT version()' 2>&1) ||
        die "$(declare -pA a=(
            ['1/message']='Can not get a version data'
            ['2m/detail']=$src))"

    regex='^\S+ (.+) on (\S+),'

    [[ $src =~ $regex ]] ||
        die "$(declare -pA a=(
            ['1/message']='Can not match the version data'
            ['2m/data']=$src))"

    version=${BASH_REMATCH[1]}
    arch=${BASH_REMATCH[2]}

    info "$(declare -pA a=(
        ['1/message']='Version'
        ['2/version']=$version
        ['3/arch']=$arch))"
)

# tablespaces

(
    src_list=$($PSQL -XAtc '\db' -F ' ' 2>&1) ||
        die "$(declare -pA a=(
            ['1/message']='Can not get a tablespaces data'
            ['2m/detail']=$src_list))"

    while read src; do
        (
            regex='^(\S+) (\S+)( (\S+))?'

            [[ $src =~ $regex ]] ||
                die "$(declare -pA a=(
                    ['1/message']='Can not match the tablespaces data'
                    ['2m/data']=$src))"

            name=${BASH_REMATCH[1]}
            owner=${BASH_REMATCH[2]}
            location=${BASH_REMATCH[4]:-null}

            info "$(declare -pA a=(
                ['1/message']='Tablespace'
                ['2/name']=$name
                ['3/owner']=$owner
                ['4/location']=$location))"
        )
    done <<< "$src_list"
)

# custom settings

sql=$(cat <<EOF
SELECT name, setting
FROM pg_settings
WHERE source NOT IN ('default', 'client');
EOF
)

(
    result=$(
        ($PSQL -XAt -c "$sql" \
            | cut -d '|' -f 1,2 | grep -E "$settings_regex") 2>&1) ||
        die "$(declare -pA a=(
            ['1/message']='Can not get a settings data'
            ['2m/detail']=$result))"

    declare -A a=(
        ['1/message']='Custom settings')

    count=2
    while read l; do
        a["$count/${l%%|*}"]="${l#*|}"
        (( count++ ))
    done <<< "$result"

    info "$(declare -p a)"
)
