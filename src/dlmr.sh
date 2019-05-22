#!/bin/bash
trap "quit" 2 3

# FUNCTIONS
err()
{
    echo "FATAL ERROR: ${1}"
    exit 1
}

quit()
{
    echo "Program Termination"
    exit 0
}

help()
{
    echo "usage : dlmr.sh [OPTION]... --url <mangarock url> --out <path>
    "
}

function parsing_args()
{
    [ $# -lt 1 ] && err "no args given use -h OR --help"

    while [ $# -ne 0 ]; do
        case "$1" in
            "--url")
                shift
                mrUrl="$1"
                ;;
            "--out")
                shift
                outPut="$1"
                ;;
            "--fork")
                shift
                fork="$4"
                ;;
            "--only-vol")
                shift
                onlyVol="$1"
                ;;
            "--from-vol")
                shift
                fromVol="$1"
                ;;
            "-h" | "--help")
                help
                quit
                ;;
            *)
                echo "Unknown option -- $1"
                help
                exit 1
                ;;
        esac

        shift
    done
}

config_check()
{
    for soft in $dep_soft; do
        if [[ -z $(type -p "$soft") ]]; then
            err "\"$soft\" not found, please install all dep for this script \"$dep_soft\""
        fi
    done

    [[ -z $mrUrl ]] && err "no mangarock url given (use -h for help)"
    [[ -z $outPut ]] && err "no outPut given (use -h for help)"

    [[ -e $outPut ]] && err "\"$outPut\" already exist (use -h for help)"
    mkdir -p "$outPut" || err "mkdir fail to create \"$outPut\""
}

build_output()
{
    echo '';
}

get_datas()
{
    echo '';
}

clean_output()
{
    echo '';
}

# VARS
dep_soft="7z curl jq rm mkdir"

fork=4
mrUrl=""
outPut=""
onlyVol=""
fromVol=""

# MAIN
parsing_args "$@"
config_check

get_datas
build_output
clean_output

quit
