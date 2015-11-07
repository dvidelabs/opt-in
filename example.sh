#!/usr/bin/env bash
#
# opt_in example

# This is a bit messy because we play around with different constructs.
# also comments in the opt-in.xtension.sh file for a clean high level example.

# test input: 
#
#    --buffer 42 --now -Ox -I=imgpack --optimize=gfx publish 400 300 
#
# test output:
# 
#    '-b' '42' '-n' '-O' 'x' '-I' 'imgpack' '-O' 'gfx' '--' 'publish' '400' '300'
#

source $(dirname $0)/'opt-in.source.sh'
#source $(dirname $0)/'opt-in.embed.sh'
#source $(dirname $0)/'opt-in.archive.sh' 

appname=$(basename $0);

function usage {
  cat << EOF
opt-in option parser example, see README.md

This script will do, and mean, nothing - except for parsing some options.

You may want to experimentally change the opt_init parameters in
the source, or change the opt_user_fail function, or use this script
to prototype your own interfaces.

Usage:
    ${appname} options [--] <command> file1 ...
    ${appname} -h | --help

    <command>
        publish | debug 

Options:
    -b|-buffer <bufcount>  (required)
        (don't use -b=42 or -b42 here, we are testing different option types)

    -I[=]<package-name>

    -c <clone-file>       
        experimental feature

    -l | --lazy
        process later

    -n | --now
        process now

    -G | --generate <code>
        where code is a short string

    -O[=]<setting> | --optimize[=]<setting>
        where setting=1|2|3|x|gfx

    -
        read from STDIN

Example:
    ${appname} -b 42  -lnOgfx publish
EOF
}


# NOTE: we have modified the extension match functions to take an extra
# name argument as first parameter, so we can remap short option names
# since we cannot remap the combined short flags our second stage
# needs to handle both flag types - this is of course not how you
# would design a real application.

# to match the common value form:
#    -O 2 -O2 --optimize 42 --optimize-42 -O=42
#
# usage: opt_user_match_cv name shortname longname default-value
function opt_user_match_cv {
    case "$OPT_TOKEN" in
        "$3") opt_ev "$1" "$4" ;;
        "$2") opt_ev "$1" "$4" ;;
        "$3"=*) opt_kv $1 ;;

        # comment out the following line for getopt compatibility
        "$2"=*) opt_kv $1 ;;

        "$2"*) opt_vs "$1" "$2" ;;
            *) return 1 ;;
    esac
    return 0;
}

# to match the flag form:
#    -v --verbose
# usage: opt_user_match_cf name shortname longname 
function opt_user_match_cf {
    case "$OPT_TOKEN" in
        "$2") opt_f "$1" ;;
        "$3") opt_f "$1" ;;
        *) return 1 ;;
    esac
    return 0;
}

function opt_user_fail {
    reason-$1; name=$2; msg=$3;
    usage >&2; echo >&2 $msg $2;
    exit 1;
}

# Wraps 'opt_next' to also handle combined short flags:
# usage: opt_get arg [ flags ]
# where flags is a string of single letter flags (no ':' or '-'). The flags
# is not like getopt, since it does not deal with values - those are handled
# after the call.
# 'arg' is a command line argument that may contain multiple flags, unlike opt_next 'arg'.
# e.g. with 'tar -xzf <file>', we may have:
#     opt_get "-xzf" "xczt"
# which pushes the flags '-x' '-z' and returns with OPT_TOKEN="-f" and returns success.
# if flags are partially matched (as in the above example), or not at all, OPT_TOKEN
# holds the rest with success as return code. It returns false and consumes the entire
# argument if non-options are currently processed.
# If a value is expected, the argument is consumed entirely in eager mode.
# In strict mode, if the first flag matches, it is handled like any other strict
# flag processed after opt_next, and if the first flag does not match, the
# entire token is also given to opt_next and handled the same way. We cannot
# have an expected value conflict inside the token because we stop at the first
# option that requires a value and handle it later.
# Observe that it is not possible to translate flags given as second argument,
# unlike when using opt_f at a later stage.
function opt_get { _opt_tail="$1"
    if [ ! $_opt_brk -ne 0 ] && ( [ -z "$_opt_expect" ] || [ $_opt_eager -eq 0 ] ); then
    while [ -n "${_opt_tail#-*}" ] && [ "$2" != "${2/${_opt_tail:1:1}/}" ]; do
        _opt_dbg _combine_;
        opt_next "${_opt_tail:0:2}"; opt_f "$OPT_TOKEN"; _opt_tail="-${_opt_tail:2}";
        [ "$_opt_tail" == '-' ] && return 1; done; fi; opt_next "$_opt_tail"; }

opt_init debug silent 
for arg
do
    if opt_get "$arg" "ln"; then
    # if opt_next "$arg"; then
        if opt_user_match_cv gen -G --generate '*' ||
           opt_user_match_cf lazy -l --lazy;
        then continue; else
        case "$OPT_TOKEN" in
            -h   | --help)          usage; exit 0 ;;
            -b   | --buffer)        opt_ev -b ;;
                   --now)           opt_f  -n ;;
            -I=*)                   opt_kv -I ;;
            -I*)                    opt_v  -I ;;
            -c)                     opt_ev -c ;;
            -O   | --optimize)      opt_ev -O ;;
            -O=* | --optimize=*)    opt_kv -O ;;
            -O*)                    opt_v  -O ;;
            -)                      opt_f  STDIN ;; 
                   --)              opt_break -- ;;
            -*)                     opt_invalid  ;;
            *)                      opt_pos --   ;;
        esac;
        fi
    fi
done
opt_final

echo "arg list before \$OPT_IN:"
for arg
do
    echo "  arg: ($arg)";
done

$OPT_IN

echo "arg list after \$OPT_IN:"
for arg
do
    echo "  arg: ($arg)";
done

unset fd; unset BUFFER; unset NOW; unset CLONE; unset INC;
OPTIM="";

function check_optim {
    case "$1" in
        1|2|3|x|gfx) return 0 ;;
        *) echo >&2 "Uh - we have no such optimization, aborting ... (try -h)";
           exit 1 ;;
    esac
}

# Note: 'while [ -n "$1" ]' would not handle empty arguments correctly
while [ $# -gt 0 ]
do
    # TODO: warn if value empty or set multiple times;
    # optim already handled except multiple identical values.
    case "$1" in
        -b)  BUFFER="$2"; shift ;;
        -n)  NOW='yes, right now!' ;;
        -c)  CLONE="$2"; shift ;;
        -I)  INC="$2"; shift ;;
        -O)  check_optim $2; OPTIM="${OPTIM}:$2"; shift ;;
        gen) echo "ignoring generate option"; shift ;;
        -l | lazy) echo "suspending task" ;;

        
        --)  shift; break ;;
        STDIN) fd=1 ;;
       '?') echo "invalid argument (try -h): $2"; exit 1 ;;
        *) break ;;
    esac
    shift
done

echo "arg list after 2nd pass:"
for arg
do
    echo "  arg: ($arg)";
done


# check for empty or other invalid argument values
# This is incomplete - just for illustration.
[ "$CLONE" == ":" ] && 
    echo >&2 "warning: skipping missing clone argument";
[ -z "$BUFFER" ] &&
    echo >&2 "error: abort on empty or absent buffer argument (try -h)" &&
    exit 1;


function publish {
    if [ -z "$1" ]; then
        echo >&2 "no point in publishing no files, aborting, sorry ... (try -h)";
        exit 1;
    else
        echo "wee, we are publishing the files: $@";
    fi
}

function handler {
    case "$1" in
        publish) shift; echo "wee - we are publishing $@" ;;
        debug)
            echo "OPT_ARGS string from opt-in:";
            echo "";
            echo "$OPT_ARGS";
            echo "";
            echo "options read:";
            echo "";
            echo "BUFFER: $BUFFER";
            echo "CLONE: $CLONE";
            echo "INC: ${INC:-no include specified}";
            echo "NOW: ${NOW:-no, no now, job queued}";
            echo "OPTIM: ${OPTIM}";
            shift;
            echo "files: ${@:-no files specified, this is not allowed!}";
            ;;
        *) echo "hmm - we have no support for the command $1" ;;
    esac
}

# process the remaining non-options
handler "$@"

echo << COMMENT > /dev/null
COMMENT
