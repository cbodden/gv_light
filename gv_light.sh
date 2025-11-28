#!/usr/bin/env bash
#===============================================================================
#
#          FILE: gv_light.sh
#         USAGE: ./gv_light.sh
#   DESCRIPTION:
#       OPTIONS: -a, -b, -i, -o, and -p
#  REQUIREMENTS: curl jq
#          BUGS: probably
#         NOTES:
#        AUTHOR: Cesar Bodden (), cesar@poa.nyc
#  ORGANIZATION: pissedoffadmins.com
#       CREATED: 25-NOV-25
#      REVISION: 1
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

    ## tmp file for json output
    readonly CURL_JSON_CNT=$(mktemp -t curl_json_cnt.XXXXXX)
    readonly CURL_JSON_STT=$(mktemp -t curl_json_stt.XXXXXX)

    ## clean up left over files on exit
    trap "rm -f ${CURL_JSON_CNT} ${CURL_JSON_STT} " 0 1 2 15
}

gv_Count()
{
    ## count all devices and map ID's and model numbers
    ${CURL} \
        -H "${API_KEY}" \
        ${API_ID_URL} \
        >> ${CURL_JSON_CNT}
}

gv_State()
{
    ## pull state of specific id
    ${CURL} \
        -X POST \
        -H "Content-Type: ${CNT_TYPE}" \
        -H "${API_KEY}" \
        --data "$(generate_state_data)" \
        ${API_URL}/router/api/v1/device/state \
        >> ${CURL_JSON_STT}
}

gv_Action()
{
    ## action function
    local OPTION=${1}
    gv_Count
    DEV_ID_TTL=$(\
        ${JQ} \
            -r '.data.devices[] | (.device + "," + .model)' \
            ${CURL_JSON_CNT} \
    )

    for ITER in ${DEV_ID_TTL}
    do
        local DEV_ID=${ITER%%,*}
        local DEV_SKU=${ITER##*,}

        if [[ ${OPTION} == "power" ]]
        then
            readonly TYPE="devices.capabilities.on_off"
            readonly INSTANCE="powerSwitch"
            local TST_STT=$(\
                ${JQ} \
                    -r '.payload.capabilities.[1].state.value' \
                    ${CURL_JSON_STT} \
                )
            if [[ ${TST_STT} == 1 ]]
            then
                readonly VALUE=0
            else
                readonly VALUE=1
            fi
        elif [[ ${OPTION} == "online" ]]
        then
            readonly TYPE="devices.capabilities.online"
            readonly INSTANCE="online"
            local TST_STT=$(\
                ${JQ} \
                    -r '.payload.capabilities.[0].state.value' \
                    ${CURL_JSON_STT} \
                )
            if [[ ${TST_STT} == false ]]
            then
                readonly VALUE=true
            fi
        elif [[ ${OPTION} == "bright" ]]
        then
            readonly TYPE="devices.capabilities.range"
            readonly INSTANCE="brightness"
            local TST_STT=$(\
                ${JQ} \
                    -r '.payload.capabilities.[3].state.value' \
                    ${CURL_JSON_STT} \
                )
            if [[ ${BTT} == "reset" ]]
            then
                readonly VALUE=100
            elif [[ ${BTT} == "dec" ]]
            then
                readonly VALUE=$( expr ${TST_STT} - 20 )
            elif [[ ${BTT} == "inc" ]]
            then
                readonly VALUE=$( expr ${TST_STT} + 20 )
            fi
        elif [[ ${OPTION} == "color" ]]
        then
            readonly TYPE="devices.capabilities.color_setting"
            readonly INSTANCE="colorRgb"
            local SET_COLOR="$( printf %d/\n 0x${COLOR} )"
            ## echo $((16#ff0000))
            readonly VALUE="${SET_COLOR}"
        fi

        ${CURL} \
            -s -X POST \
            -H "Content-Type: ${CNT_TYPE}" \
            -H "${API_KEY}" \
            --data "$(generate_json_data)" \
            ${API_URL}/router/api/v1/device/control
    done
}

gv_Info()
{
    ## parse info of ID's
    gv_Count
    DEV_ID_TTL=$(\
        ${JQ} \
            -r '.data.devices[] | (.device + "," + .model)' \
            ${CURL_JSON_CNT} \
    )

    for ITER in ${DEV_ID_TTL}
    do
        local DEV_ID=${ITER%%,*}
        local DEV_SKU=${ITER##*,}

        ${CURL} \
            -X POST \
            -H "Content-Type: ${CNT_TYPE}" \
            -H "${API_KEY}" \
            --data "$(generate_state_data)" \
            ${API_URL}/router/api/v1/device/state \
            | ${JQ} '.'
    done
}

gv_Alert()
{
    ## alert actions
    local OPTION=${BTT}
    gv_Count
    DEV_ID_TTL=$(\
        ${JQ} \
            -r '.data.devices[] | (.device + "," + .model)' \
            ${CURL_JSON_CNT} \
    )

    for ITER in ${DEV_ID_TTL}
    do
        local DEV_ID=${ITER%%,*}
        local DEV_SKU=${ITER##*,}

        if [[ ${OPTION} == "alert" ]]
        then
            readonly TYPE="devices.capabilities.color_setting"
            readonly INSTANCE="colorRgb"
            ## echo $((16#ff0000))
            readonly VALUE="16711680"
        elif [[ ${OPTION} == "clear" ]]
        then
            readonly TYPE="devices.capabilities.color_setting"
            readonly INSTANCE="colorTemperatureK"
            readonly VALUE="2700"
        fi

        ${CURL} \
            -s -X POST \
            -H "Content-Type: ${CNT_TYPE}" \
            -H "${API_KEY}" \
            --data "$(generate_json_data)" \
            ${API_URL}/router/api/v1/device/control
    done
}

generate_json_data()
{
  cat <<EOF
{
  "requestId": "${DATE}",
  "payload": {
    "sku": "${DEV_SKU}",
    "device": "${DEV_ID}",
    "capability": {
      "type": "${TYPE}",
      "instance": "${INSTANCE}",
      "value": ${VALUE}
    }
  }
}
EOF
}

generate_state_data()
{
  cat <<EOF
{
  "requestId": "${DATE}",
  "payload": {
    "sku": "${DEV_SKU}",
    "device": "${DEV_ID}"
  }
}
EOF
}

function _USAGE()
{
    clear
echo -e "
NAME
    ${GV_NAME}

SYNOPSIS
    ${GV_NAME} [OPTION]...

DESCRIPTION
    This script controls functionality of one or multiple internet connected
    Govee lights. It can be enabled in to be used on cron, mapped to specific
    keyboard shortcuts, run from the command line, or added / called from other
    scripts to change light colors in case of alerts or as notifiers.

OPTIONS

    -a [alert | clear]
            This option will set all the lights into an alert mode (red if 
            alert specified) and then clear them if clear is passed.

    -b [inc | dec | reset]
            This option when passed with either inc (increase), dec (decrease),
            or reset (set lights back to 100%) will control brightness from 
            1 - 100 in increments of 20.

    -c [hex color code]
            This option allows setting all the lights to the same defined 
            color in hex rgb of format "FFFFFF" with the range of 000001 - 
            FFFFFF. 

            Hex code must be defined as a 6 character number.

    -i
            This option gives you information on all lamps connected in JSON
            output format.

    -p
            This option toggles power on or off.

Examples
    Toggle light on / off :

            ./gv_light.sh -p

    Set all lamps to red :

            ./gv_light.sh -c 00ff00

Requirement
    This script requires that the ".gv_light.conf" be configured with the
    contents containing your API key (google it) in the format similar to below
    where the "XXXXXXXXXXXXXXXXXXXXXXXXXX" is replaced with the API key :

            API_KEY="Govee-API-Key:XXXXXXXXXXXXXXXXXXXXXXXXXX"

    This script also requires that both JQ and cURL be installed.
    "
}

## clearing for main options
clear
main

## option selection 
while getopts ":a:b:c:iop" OPT
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
            gv_Info
            ;;
        'o')
            gv_Action online
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
