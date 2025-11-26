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
    readonly API_URL="https://openapi.api.govee.com"
    readonly API_ID_URL="https://developer-api.govee.com/v1/devices"
    readonly CNT_TYPE="application/json"
    readonly DATE="$(date +%s)"
    readonly GV_DIR=$(readlink -m $(dirname $0))

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
    readonly CURL_JSON=$(mktemp -t curl_json_lights.XXXXXX)

    ## clean up left over files on exit
    trap "rm -f ${CURL_JSON}" 0 1 2 15
}

gv_Count()
{
    ## count all devices and map ID's
    DEV_ID_TTL=$(\
    ${CURL} \
        -H "${API_KEY}" \
        ${API_ID_URL} \
        | ${JQ} -r '.data.devices[] | (.device + "," + .model)'
    )
}

gv_State()
{
    ## pull state of specific id
    ${CURL} \
        -X POST \
        -H "Content-Type: ${CNT_TYPE}" \
        -H "${API_KEY}" \
        --data "$(generate_state_data)" \
        ${API_URL}/router/api/v1/device/state
}

gv_Action()
{
    ## action function
    local OPTION=${1}
    gv_Count
    for ITER in ${DEV_ID_TTL}
    do
        DEV_ID=${ITER%%,*}
        DEV_SKU=${ITER##*,}

        if [[ ${OPTION} == "power" ]]
        then
            TYPE="devices.capabilities.on_off"
            INSTANCE="powerSwitch"
            TST_STT=$(\
                gv_State \
                | ${JQ} '.payload.capabilities.[1].state.value')
            if [[ ${TST_STT} == 1 ]]
            then
                VALUE=0
            else
                VALUE=1
            fi
        elif [[ ${OPTION} == "online" ]]
        then
            TYPE="devices.capabilities.online"
            INSTANCE="online"
            local TST_STT=$(\
                gv_State \
                | ${JQ} '.payload.capabilities.[0].state.value')
            if [[ ${TST_STT} == false ]]
            then
                VALUE=true
            fi
        elif [[ ${OPTION} == "bright" ]]
        then
            TYPE="devices.capabilities.range"
            INSTANCE="brightness"
            local TST_STT=$(\
                gv_State \
                | ${JQ} '.payload.capabilities.[3].state.value')
            if [[ ${BTT} == "reset" ]]
            then
                local SET_BTT=100
            elif [[ ${BTT} == "dec" ]]
            then
                local SET_BTT=$( expr ${TST_STT} - 20 )
            elif [[ ${BTT} == "inc" ]]
            then
                local SET_BTT=$( expr ${TST_STT} + 20 )
            else
                something
            fi
                VALUE=${SET_BTT}
        else
            something
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
    for ITER in ${DEV_ID_TTL}
    do
        DEV_ID=${ITER%%,*}
        DEV_SKU=${ITER##*,}

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
    for ITER in ${DEV_ID_TTL}
    do
        DEV_ID=${ITER%%,*}
        DEV_SKU=${ITER##*,}

        if [[ ${OPTION} == "alert" ]]
        then
            TYPE="devices.capabilities.color_setting"
            INSTANCE="colorRgb"
            TST_STT=$(\
                gv_State \
                | ${JQ} '.payload.capabilities.[6].state.value')
            ## echo $((16#ff0000))
            VALUE="16711680"
        elif [[ ${OPTION} == "clear" ]]
        then
            TYPE="devices.capabilities.color_setting"
            INSTANCE="colorTemperatureK"
            TST_STT=$(\
                gv_State \
                | ${JQ} '.payload.capabilities.[7].state.value')
            VALUE="2700"
        else
            something
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

clear

main

## option selection 
while getopts ":a:b:iop" OPT
do
    case "${OPT}" in
        'a')
            if \
                [[ ${OPTARG} == "alert" ]] \
                || [[ ${OPTARG} == "clear" ]]
            then
                readonly BTT="${OPTARG}"
            else
                echo WRONG
                exit 0
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
                echo WRONG
                exit 0
            fi
            gv_Action bright
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
            echo "WRONG"
            exit 0
            ;;
    esac
done
