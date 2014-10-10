#! /bin/sh

source $(dirname $0)/opt-in.core.sh
source $(dirname $0)/opt-in.extension.sh

opt_init 'missing=<missing>' silent # debug
for arg
do
    if opt_get "$arg" "hxci"; then 

        opt_match_cf -  --stdin      ||

        opt_match_cf -h --help       ||
        opt_match_cf -x --extract    ||
        opt_match_cf -c --compress   ||
        opt_match_cf -i --index      ||
        opt_match_cf -v --verbose    ||
        
        opt_match_cv -f --file       ||
        opt_match_cv -O --output     ||

        opt_match_nonoptions 
    fi
done
opt_final
echo "incoming arg list:"; echo "    $@"
$OPT_IN
echo "pre-processed arg list:"; echo "    $@"
# Note: 'while [ -n "$1" ]' would not handle empty arguments correctly
echo "handled options (if any):"
while [ $# -gt 0 ]
do
    case "$1" in
        -h) echo "    -h: help message" ;;
        -x) echo "    -x: extract" ;;
        -c) echo "    -c: compress" ;;
        -i) echo "    -i: index" ;;
        -v) echo "    -v: verbose" ;;
        -f) echo "    -f: filename=${2:-<empty>}"; shift ;;
        -O) echo "    -o: output=${2:-<empty>}"; shift ;;
        --) echo "    --: command separator, or file list continuation"; shift; break ;;
         -) echo "     -: stdin" ;;
         ?) echo "     ?: invalid option $1, aborting."; exit 1 ;;
         *) echo "     unexpected, aborting: $1" ;;
    esac
    shift
done
echo "remaining non-options (if any):"; echo "    $@"

