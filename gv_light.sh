#!/usr/bin/env bash
#===============================================================================
#
#          FILE: gv_light.sh
#         USAGE: ./gv_light.sh
#   DESCRIPTION: Script to control Govee lights
#       OPTIONS: -a, -b, -c, -i, and -p
#  REQUIREMENTS: curl jq
#          BUGS: probably
#         NOTES:
#        AUTHOR: Cesar Bodden (), cesar@poa.nyc
#  ORGANIZATION: pissedoffadmins.com
#       CREATED: 25-NOV-25
#      REVISION: 3
#===============================================================================

LC_ALL=C
LANG=C
set -e
set -o nounset
set -o pipefail
set -u

main()
{
    readonly API_ID_URL="https://developer-api.govee.com/v1/devices"
    readonly API_URL="https://openapi.api.govee.com"
    readonly CNT_TYPE="application/json"
    readonly DATE="$(date +%s)"
    readonly GV_DIR=$(readlink -m $(dirname $0))
    readonly GV_NAME=$(basename $0)

    ## check if conf file exists then source
    ## content : API_KEY="Govee-API-Key:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    if [[ -f "${GV_DIR}/.gv_light.conf" ]]
    then
        source ${GV_DIR}/.gv_light.conf
    else
        printf "%s\n" \
            ". . .CONF not found. . ."
        exit 1
    fi

    ## check if deps exist
    local _DEPS="curl jq"
    for ITER in ${_DEPS}
    do
        if [[ -z "$(which ${ITER} 2>/dev/null)" ]]
        then
            printf "%s\n" \
                ". . .${ITER} not found. . ."
            exit 1
        else
            readonly ${ITER^^}="$(which ${ITER})"
        fi
    done

    ## check if shlibs exist then source
    if [[ -z "$( ls -A "${GV_DIR}/shlib/" )" ]]
    then
        printf "%s\n" \
            ". . .shlibs not found. . ."
        exit 1
    else
        for ITER in ${GV_DIR}/shlib/*.shlib
        do
            source ${ITER}
        done
    fi

    ## tmp file for json output
    readonly CURL_JSON_CNT=$(mktemp -t curl_json_cnt.XXXXXX)
    readonly CURL_JSON_STT=$(mktemp -t curl_json_stt.XXXXXX)

    ## clean up left over files on exit
    trap "rm -f ${CURL_JSON_CNT} ${CURL_JSON_STT} " 0 1 2 15
}

## clearing for main options
clear
main

## option selection 
while getopts ":a:b:c:i:op" OPT
do
    case "${OPT}" in
        'a')
            if \
                [[ ${OPTARG} == "alert" ]] \
                || [[ ${OPTARG} == "clear" ]]
            then
                readonly BTT="${OPTARG}"
            else
                _USAGE \
                    less
                exit 1
            fi
            gv_Alert
            ;;
        'b')
            if \
                [[ ${OPTARG} == "inc" ]] \
                || [[ ${OPTARG} == "dec" ]] \
                || [[ ${OPTARG} == "reset" ]]
            then
                readonly BTT="${OPTARG}"
            else
                _USAGE \
                    less
                exit 1
            fi
            gv_Action bright
            ;;
        'c')
            if ! [[ ${OPTARG} =~ ^[0-9A-F]{6}$ ]]
            then
                readonly COLOR="${OPTARG}"
            else
                _USAGE \
                    less
                exit 1
            fi
            gv_Action color
            ;;
        'i')
            if \
                [[ ${OPTARG} == "detail" ]] \
                || [[ ${OPTARG} == "list" ]]
            then
                readonly BTT="${OPTARG}"
            else
                _USAGE \
                    less
                exit 1
            fi
            gv_Info ${BTT}
            ;;
        'p')
            gv_Action power
            ;;
        *)
            _USAGE \
                less
            exit 1
            ;;
    esac
done

if [[ ${OPTIND} -eq 1 ]]
then
    _USAGE \
        less
    exit 1
fi
shift $((OPTIND-1))
