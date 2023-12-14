#!/bin/bash

# Define a series of variables as shortcuts for color escape codes
colblk='\033[0;30m'  # Black - Regular
colred='\033[0;31m'  # Red
colgrn='\033[0;32m'  # Green
colylw='\033[0;33m'  # Yellow
colblu='\033[0;34m'  # Blue
colpur='\033[0;35m'  # Purple
colcyn='\033[0;36m'  # Cyan
colwht='\033[0;37m'  # White
colbblk='\033[1;30m' # Black - Bold
colbred='\033[1;31m' # Red
colbgrn='\033[1;32m' # Green
colbylw='\033[1;33m' # Yellow
colbblu='\033[1;34m' # Blue
colbpur='\033[1;35m' # Purple
colbcyn='\033[1;36m' # Cyan
colbwht='\033[1;37m' # White
colublk='\033[4;30m' # Black - Underline
colured='\033[4;31m' # Red
colugrn='\033[4;32m' # Green
coluylw='\033[4;33m' # Yellow
colublu='\033[4;34m' # Blue
colupur='\033[4;35m' # Purple
colucyn='\033[4;36m' # Cyan
coluwht='\033[4;37m' # White
colbgblk='\033[40m'  # Black - Background
colbgred='\033[41m'  # Red
colbggrn='\033[42m'  # Green
colbgylw='\033[43m'  # Yellow
colbgblu='\033[44m'  # Blue
colbgpur='\033[45m'  # Purple
colbgcyn='\033[46m'  # Cyan
colbgwht='\033[47m'  # White
colrst='\033[0m'     # Text Reset

### LOG_VERBOSITY levels
silent_lvl=0
crt_lvl=1
err_lvl=2
wrn_lvl=3
ntf_lvl=4
inf_lvl=5
dbg_lvl=6

## esilent prints output even in silent mode
function esilent() { verb_lvl=$silent_lvl elog "$@"; }
function enotify() { verb_lvl=$ntf_lvl elog "$@"; }
function eok() { verb_lvl=$ntf_lvl elog "SUCCESS - $@"; }
function ewarn() { verb_lvl=$wrn_lvl elog "${colylw}WARNING${colrst} - $@"; }
function einfo() { verb_lvl=$inf_lvl elog "${colwht}INFO${colrst} ---- $@"; }
function edebug() { verb_lvl=$dbg_lvl elog "${colgrn}DEBUG${colrst} --- $@"; }
function eerror() { verb_lvl=$err_lvl elog "${colred}ERROR${colrst} --- $@"; }
function ecrit() { verb_lvl=$crt_lvl elog "${colpur}FATAL${colrst} --- $@"; }
function edumpvar() { for var in $@; do edebug "$var=${!var}"; done; }
function elog() {
    if [ $LOG_VERBOSITY -ge $verb_lvl ]; then
        datestring=$(date +"%Y-%m-%d %H:%M:%S")
        echo -e "$datestring - $@"
    fi
}

function Log_Open() {

    FULLLOGDIR=$(dirname ${SINGLE_LOGFILE})
    LOGFILE=${SINGLE_LOGFILE}
    [[ -d ${FULLLOGDIR} ]] || mkdir -p ${FULLLOGDIR}
    exec 3>&1
    if $STDOUT_LOG; then
        Pipe=/tmp/${SCRIPT_BASE}_${DATETIME}.pipe
        mkfifo -m 700 $Pipe
        tee -a ${LOGFILE} <$Pipe >&3 &
        teepid=$!
        exec 1>$Pipe
        PIPE_OPENED=1
    else
        exec 1>>${LOGFILE} 2>&1
    fi
    #    esilent "---------- Logging to $LOGFILE ----------"                       # (*)
    #    [ $SUDO_USER ] && enotify "Sudo user: $SUDO_USER" #(*)
}

function Log_Close() {
    if [ ${PIPE_OPENED} ]; then
        exec 1<&3
        if $STDOUT_LOG; then
            sleep 0.2
            ps --pid $teepid >/dev/null
            if [ $? -eq 0 ]; then
                # a wait $teepid whould be better but some
                # commands leave file descriptors open
                sleep 1
                kill $teepid
            fi
            rm $Pipe
            unset PIPE_OPENED
        fi
    fi
}
