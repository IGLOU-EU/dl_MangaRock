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
    echo "usage : dlmr.sh [OPTION]... --url \"<mangarock url>\" --out <path>
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

    mkdir -p "$outPut/epub" "$outPut/tmp"
}

build_output()
{
    echo '';
}

get_datas()
{
    local _manga
    local _buffer
    local _jsonFile

    _manga="${mrUrl#*manga/}"
    _manga="${_manga%%/*}"

    _jsonFile="$outPut/$_manga.json"

    curl   'https://api.mangarockhd.com/query/web401/manga_detail' \
        -H 'Content-Type: application/json' \
        -d '{"oids":{"'"$_manga"'":0},"sections":["basic_info","chapters"]}' \
        -o "$_jsonFile"

    # check curl

    jsonRequest=(
        ['title']=".data.\"${_manga}\".basic_info.name"
        ['author']=".data.\"${_manga}\".basic_info.author"
        ['completed']=".data.\"${_manga}\".basic_info.completed"
        ['description']=".data.\"${_manga}\".basic_info.description"
        ['last_updated']=".data.\"${_manga}\".default.last_updated"
        ['total_chapters']=".data.\"${_manga}\".basic_info.total_chapters"
        ['chapters']=".data.\"${_manga}\".chapters.chapters"
    )

    mangaInfo=(
        ['oid']="$_manga"
        ['title']="$(jq -r "${jsonRequest['title']}" "$_jsonFile")"
        ['author']="$(jq -r "${jsonRequest['author']}" "$_jsonFile")"
        ['completed']="$(jq -r "${jsonRequest['completed']}" "$_jsonFile")"
        ['description']="$(jq -r "${jsonRequest['description']}" "$_jsonFile")"
        ['last_updated']="$(jq -r "${jsonRequest['last_updated']}" "$_jsonFile")"
        ['total_chapters']="$(jq -r "${jsonRequest['total_chapters']}" "$_jsonFile")"
        ['chapters']="$(jq -r "${jsonRequest['chapters']}" "$_jsonFile")"
    )

    while read -r oid; do
        _buffer="$(curl "https://api.mangarockhd.com/query/web401/pagesv2?oid=$oid" | jq -r '.data' | jq -r '.[].url')"

        proceed_pages \
            "$oid" \
            "$(echo "${mangaInfo['chapters']}" | jq -r ".[] | select(.oid==\"$oid\")" | jq -r '.name')" \
            "$_buffer"

        exit
    done < <(echo "${mangaInfo['chapters']}" | jq -r '.[].oid')

}

proceed_pages()
{
    echo "$1"
    echo "$2"
    echo "$3"
    echo "$PWD"
}

clean_output()
{
    echo '';
}

# VARS
declare -A mangaInfo
declare -A jsonRequest
PWD=${0%/*}
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
