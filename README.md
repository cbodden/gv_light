# gv_light![Unsupported](https://img.shields.io/badge/development_status-in_progress-green.svg)


gv_light.sh
====

    gv_light is a script to control the Govee internet collected lights from
    the linux command line. It offers multiple functions and can be triggered
    from multiple places.

Usage
----

<pre><code>
Name
    gv_light.sh

SYNOPSIS
    gv_light.sh [OPTION]...

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

    -i [list | detail]
            This option gives you information on all lamps connected in JSON
            output format if you select "detail". If "list" is selected it will
            just output per line the model and name of each device.

    -p
            This option toggles power on or off.


Examples
    Toggle light on / off :

            ./gv_light.sh -p

    Set all lamps to red :

            ./gv_light.sh -c 00ff00

Requirement
    This script requires that the ".gv_light.conf" be configured with the
    contents containing your API key (google it) in the format emailed to you.

    This script also requires that both JQ and cURL be installed.

</code></pre>

Requirements
----

- JQ (https://github.com/jqlang/jq)
- cURL (https://curl.se/)

License and Author
----

Copyright (c) 2025, cesar@poa.nyc
All rights reserved.

This source code is licensed under the BSD-style license
found in the LICENSE file in the root directory of this
source tree.
