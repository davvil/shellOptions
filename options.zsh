# Options library for zsh, v1.6

# Adapted from the bash version, probably some things could be done more
# efficiently in zsh directly.
# Main differences:
# - Arrays start at 1 (zsh)
# - dests variables have the $ included

# Copyright 2009 David Vilar
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser Public License as published by
# the Free Software Foundation, version 3 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

#function debug { $* > /dev/stderr; }
function debug {}

function setUsage() {
    __programUsage__="$*"
}

typeset -a __shortOptions__
typeset -a __longOptions__
typeset -a __optionDests__
typeset -a __optionActions__
typeset -a __optionDefaults__
typeset -a __optionRequired__
typeset -a __optionFlag__
typeset -a __optionHelp__
typeset -a __dontShow__

typeset -a optArgv
optArgc=0
__nOptions__=0;
__programUsage__="usage: `basename $0` [options]\n\nOptions:\n"

function addOption() {
    ((++__nOptions__))
    debug echo "Option #${__nOptions__}:"
    # These arrays must have the same length
    __longOptions__[$__nOptions__]="___not_a_valid_option___"
    __shortOptions__[$__nOptions__]="___not_a_valid_option___"
    local i
    for i in "$@"; do
        if [[ "${i[1,2]}" = -- ]]; then
            __longOptions__[$__nOptions__]=${i[3,-1]}
            debug echo -e "\tRegistered long option ${i[3,-1]}"

        elif [[ "${i[1]}" = - ]]; then
            __shortOptions__[$__nOptions__]=${i[2,-1]}
            debug echo -e "\tRegistered short option ${i[2,-1]}"

        elif [[ "${i[1,5]}" = dest= ]]; then
            __optionDests__[$__nOptions__]=\$${i[6,-1]}
            debug echo -e "\tOption dest is ${i[6,-1]}"

        elif [[ "${i[1,7]}" = action= ]]; then
            __optionActions__[$__nOptions__]=${i[8,-1]}
            debug echo -e "\tOption action is ${i[8,-1]}"

        elif [[ "${i[1,8]}" = default= ]]; then
            __optionDefaults__[$__nOptions__]="${i[9,-1]}"
            debug echo -e "\tOption default is ${i[9,-1]}"

        elif [[ "$i" = required ]]; then
            __optionRequired__[$__nOptions__]=1
            debug echo -e "\tOption required"

        elif [[ "${i[1,5]}" = help= ]]; then
            __optionHelp__[$__nOptions__]=${i[6,-1]}
            debug echo -e "\tRegistered help \"${i[6,-1]}\""

        elif [[ "$i" = flagTrue ]]; then
            __optionFlag__[$__nOptions__]=1
            debug echo -e "\tOption is flag (true)"

        elif [[ "$i" = flagFalse ]]; then
            __optionFlag__[$__nOptions__]=0
            debug echo -e "\tOption is flag (false)"

        elif [[ "$i" = configFile ]]; then
            __configFile__=$__nOptions__

        elif [[ "$i" = dontShow ]]; then
            __dontShow__[$__nOptions__]=1
            debug echo -e "\tDon't show this option"

        else
            echo "Unknown parameter to registerOption: $i" > /dev/stderr
            exit 1
        fi
    done

    if [[ "${__optionDests__[$__nOptions__]}" = "" && "${__longOptions__[$__nOptions__]}" != "" ]]; then
        __optionDests__[$__nOptions__]=\$${__longOptions__[$__nOptions__]}
        debug echo -e "\tSet default dest to ${__optionDests__[$__nOptions__]}"
    fi
}

function __searchInArray__() {
    debug echo -e "\t__searchInArray__ $*"
    local searchFor=$1
    shift
    local i=1;
    while [[ "$1" != "" ]]; do
        if [ $1 = $searchFor ]; then
            debug echo -e "\tFound as option $i"
            echo $i
            return
        fi
        ((++i))
        shift
    done
}

function __searchOption__() {
    local pos
    if [[ "${1[0,2]}" = -- ]]; then
        debug echo -e "\tIt's a long option"
        pos=`__searchInArray__ ${1[3,-1]} "${__longOptions__[@]}"`
    elif [[ "${1[0,1]}" = - ]]; then
        debug echo -e "\tIt's a short option"
        pos=`__searchInArray__ ${1[2,-1]} ${__shortOptions__[*]}`
    fi
    debug echo -e "\tResulting pos: $pos"
    echo $pos
}

function __readConfig__() {
    if [[ "$__configFile__" != "" ]]; then
        local -a options
        options=("$@")
        local i=1;
        while (($i < ${#options[*]})); do
            if [[ "${options[$i]}" = -${__shortOptions__[$__configFile__]} ||
                  "${options[$i]}" = "--${__longOptions__[$__configFile__]}" ]]; then
                . ${options[$((i+1))]}
                break
            fi
            if [[ "${options[$i]}" = "--" ]]; then
                break
            fi
            ((++i))
        done
    fi
}

function parseOptions() {
    # Set default values
    local i=1;
    while (($i <= $__nOptions__)); do
        default=${__optionDefaults__[$i]}
        if [[ "$default" != "" ]]; then
            eval ${__optionDests__[$i][2,-1]}=\"$default\"
        elif [[ "${__optionFlag__[$i]}" != "" ]]; then
            flag=${__optionFlag__[$i]}
            if [[ $flag = 1 ]]; then
                eval ${__optionDests__[$i][2,-1]}=false
            else
                eval ${__optionDests__[$i][2,-1]}=true
            fi
        fi
        ((++i))
    done

    # Read a config file (if we have one)
    __readConfig__ "$@"

    # Parse the options
    local minusMinusSeen=false
    while (($# > 0)); do
        if ! $minusMinusSeen; then
            debug echo "Searching option $1"
            if [[ "$1" = "--" ]]; then
                minusMinusSeen=true
            else
                local pos=`__searchOption__ "$1"`
                if [[ "$pos" == "" ]]; then
                    if [[ "${1[1]}" = "-" ]]; then
                        echo "Error: Unknown option $1" > /dev/stderr
                        exit 1
                    else
                        debug echo "Argument found: $1"
                        ((++optArgc))
                        optArgv[$optArgc]="$1"
                    fi
                else
                    local dest=${__optionDests__[$pos]}
                    if [[ "$dest" != "" ]]; then
                        debug echo "\tOption has a dest: $dest"
                        local isFlag=${__optionFlag__[$pos]}
                        if [[ "$isFlag" != "" ]]; then
                            debug echo -e "\tOption $i is a flag"
                            if [[ $isFlag = 1 ]]; then
                                eval ${dest[2,-1]}=true
                            else
                                eval ${dest[2,-1]}=false
                            fi

                        else # It's not a flag
                            shift
                            value="$1"
                            eval ${dest[2,-1]}=\"$value\"
                        fi
                    fi

                    local action=${__optionActions__[$pos]}
                    if [[ "$action" != "" ]]; then
                        debug echo -e "\tOption has an Action"
                        eval ${__optionActions__[$pos]}
                    fi
                fi
            fi
        else # minusMinusSeen
            ((++optArgc))
            optArgv[$optArgc]="$1"
        fi

        shift
    done

    # Check for required values
    i=1
    local -a missingOptions
    while (($i <= $__nOptions__)); do
        debug echo "Checking option $i, required=\"${__optionRequired__[$i]}\", destValue=${(e)__optionDests__[$i]}"
        if [[ "${__optionRequired__[$i]}" != "" && "${(e)__optionDests__[$i]}" = "" ]]; then
            debug echo -e "\tMissing option"
            local optionName=${__shortOptions__[$i]}
            if [[ "$optionName" = "___not_a_valid_option___" ]]; then
                optionName="--"${__longOptions__[$i]}
            else
                optionName="-"$optionName
            fi
            missingOptions[${#missingOptions[*]}+1]=$optionName
        fi
        ((++i))
    done
    if (( ${#missingOptions[*]} > 0 )); then
        echo -n "Error: following mandatory options are missing: ${missingOptions[1]}" > /dev/stderr
        i=2
        while (($i <= ${#missingOptions[*]})); do
            echo -n ",${missingOptions[$i]}" > /dev/stderr
            ((++i))
        done
        echo "" > /dev/stderr
        exit 1
    fi
}

function __printOptionHelp__() {
    local i=$1
    if [[ "${__dontShow__[$i]}" = 1 ]]; then
        return
    fi
    local optionId=${__shortOptions__[$i]}
    if [[ $optionId != ___not_a_valid_option___ ]]; then
        optionId=-$optionId
        if [[ ${__longOptions__[$i]} != ___not_a_valid_option___ ]]; then
            optionId=$optionId","
        fi
    else
        optionId=""
    fi
    if [[ ${__longOptions__[$i]} != ___not_a_valid_option___ ]]; then
        optionId=${optionId}"--"${__longOptions__[$i]}
    fi
    optionId="   "$optionId
    local firstIndentLine
    if ((${#optionId} < 30)); then
        echo -n "$optionId"
        local c
        for c in `seq ${#optionId} 29`; do
            echo -n " "
        done
        firstIndentLine=2
    else
        echo "$optionId"
        firstIndentLine=1
    fi
    local thirtySpaces="                              "
    echo "${__optionHelp__[$i]}" | fmt -w 50 | sed "$firstIndentLine,\$s/^/$thirtySpaces/"
}

function __showHelp__() {
    echo -e "$__programUsage__"
    local i=2 # -h is the first option
    while (($i <= $__nOptions__)); do
        __printOptionHelp__ $i
        ((++i))
    done
    __printOptionHelp__ 0 # -h
    exit 0
}

addOption -h --help action=__showHelp__ help="Show this help message"
