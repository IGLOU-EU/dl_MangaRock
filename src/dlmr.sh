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

    --url   mangarock url, give serie url (ex: https://mangarock.com/manga/mrs-serie-183717)

    --out   output directory, can exist or not

    --fork  number of forking (parallelised rendering)
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
                fork="$1"
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

    mkdir -p "$outPut" || err "mkdir fail to create \"$outPut\""
    mkdir -p "$outPut/cbx" "$outPut/tmp"
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

    curl -s -S --retry 5 --retry-delay 10   'https://api.mangarockhd.com/query/web401/manga_detail' \
        -H 'Content-Type: application/json' \
        -d '{"oids":{"'"$_manga"'":0},"sections":["basic_info","chapters"]}' \
        -o "$_jsonFile" || err "can't get datas from https://api.mangarockhd.com"

    jq '' "$_jsonFile" > "/dev/null" || err "Cant't parsing json file \"$_jsonFile\""
    echo "OK - Json data get to \"$_jsonFile\""

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
        _buffer="$(curl -s -S --retry 5 --retry-delay 10 "https://api.mangarockhd.com/query/web401/pagesv2?oid=$oid" \
        | jq -r '.data' | jq -r '.[].url')" || { echo "Error: Can't get \"$oid\" json file, abort this chapter"; continue; }
        echo "OK - Json for chapter \"$oid\" successfully recovered"

        proceed_pages \
            "$oid" \
            "$(echo "${mangaInfo['chapters']}" | jq -r ".[] | select(.oid==\"$oid\")" | jq -r '.name')" \
            "$_buffer" &

        pids[$i]="$!"
        ((it++))

        [[ $it -ge $fork ]] && wait_fork
    done < <(echo "${mangaInfo['chapters']}" | jq -r '.[].oid')

}

proceed_pages()
{
    local _i
    local _cbz
    local _out
    local _pout
    local _cover

    _out="$outPut/tmp/$1"
    mkdir -p "$_out"

    _cbz="$outPut/cbx/${mangaInfo['title']}"
    mkdir -p "$_cbz"
    _cbz="$_cbz/${mangaInfo['title']} ${2}.cbz"

    sleep 5

    for page in $3; do
        ((i++))
        _pout="$_out/$(printf "%04d\n" ${i})_${2// /_}"
        [[ -z $_cover ]] && _cover="$(printf "%04d\n" ${i})_${2// /_}"

        curl -s -S --retry 5 --retry-delay 10 "$page" -o "$_pout.mri"
        [[ -e "$_pout.mri" ]] || { echo "Error: can't get \"$_pout.mri\" from \"${mangaInfo['title']} ${1}\", abort this chapter"; return; }

        $mri_convert "$_pout.mri" "$_pout.png"
        rm "$_pout.mri"
    done

    build_xml "$2" "$_i" "$_cover" "$_out"
    7z -bd a -tzip "$_cbz" "$_out/*" -mx0 > "/dev/null"

    rm -rf "$_out"
    echo "OK - Builded at \"$_cbz\""
}

build_xml()
{
    echo "
        <?xml version=\"1.1\" encoding=\"UTF-8\"?>
        <comet
          xmlns:comet=\"http://www.denvog.com/comet/\"
          xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"
          xsi:schemaLocation=\"http://www.denvog.com http://www.denvog.com/comet/comet.xsd\">
            <title>${mangaInfo['title']} ${1}</title>
            <description>${mangaInfo['description']}</description>
            <series>${mangaInfo['title']}</series>
            <language>en</language>
            <pages>${2}</pages>
            <creator>${mangaInfo['author']}</creator>
            <coverImage>${3}</coverImage>
        </comet>
    " > "${4}/CoMet.xml"

    echo "
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <ComicInfo
          xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"
          xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">
            <Title>${mangaInfo['title']} ${1}</Title>
            <Summary>${mangaInfo['description']}</Summary>
            <Series>${mangaInfo['title']}</Series>
            <LanguageISO>en</LanguageISO>
            <PageCount>${2}</PageCount>
            <Writer>${mangaInfo['author']}</Writer>
        </ComicInfo>
    " > "${4}/ComicInfo.xml"

    echo "
        <?xml version='1.0' encoding='utf-8'?>
        <package xmlns=\"http://www.idpf.org/2007/opf\" unique-identifier=\"uuid_id\" version=\"2.0\">
            <metadata xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:opf=\"http://www.idpf.org/2007/opf\">
                <dc:title>${mangaInfo['title']} ${1}</dc:title>
                <dc:creator opf:file-as=\"${mangaInfo['author']}\" opf:role=\"aut\">${mangaInfo['author']}</dc:creator>
                <dc:description>${mangaInfo['description']}</dc:description>
                <dc:language>en</dc:language>
                <meta content=\"${mangaInfo['title']}\" name=\"calibre:series\"/>
                <meta content=\"${mangaInfo['title']} ${1}\" name=\"calibre:title_sort\"/>
            </metadata>
            <guide>
                <reference href=\"${3}\" title=\"Couverture\" type=\"cover\"/>
            </guide>
        </package>
    " > "${4}/metadata.opf"
}

wait_fork () {
    for pid in "${pids[@]}"; do
        wait $pid
    done

    it=0
}

# VARS
declare -A mangaInfo
declare -A jsonRequest

it=0
pids=()
PWD=${0%/*}
dep_soft="7z curl jq rm mkdir"
mri_convert="$PWD/mri_convert.bin"

fork=1
mrUrl=""
outPut=""
onlyVol=""
fromVol=""

# MAIN
parsing_args "$@"
config_check

get_datas
build_output

quit
