# ----------------------------------------------------------------------
# opt-in extension library, (c) 2014, Mikkel Fahnøe Jørgensen
# License: MIT
# ----------------------------------------------------------------------
#
# This extension is intended to for customization, pick what makes sense
# and adapt as needed. It relies on the core opt-in library.
#
# Be sure to source first the core library, then the extensions in this
# file, before running the following snippet.
#
#
#
# Example usage: see 'demo.sh`



# to match the common value form:
#    -O 2 -O2 --optimize 42 --optimize=42 -O=42
#
# usage: opt_match_cv shortname longname [default-value]
#
# The short form does not strictly have to by one letter nor does
# it have to prefixed by '-', this is just convention.
function opt_match_cv {
    # Order is important!
    case "$OPT_TOKEN" in
        "$2") opt_ev "$1" "$3" ;;
        "$1") opt_ev "$1" "$3" ;;
        "$2"=*) opt_kv $1 ;;

        # comment out the following line for getopt compatibility
        "$1"=*) opt_kv $1 ;;
        
        "$1"*) opt_vs "$1" "$1" ;;
            *) return 1 ;;
    esac
    return 0;
}

# to match the flag form:
#    -v --verbose
#
# usage: opt_match_cf shortname longname 
function opt_match_cf {
    case "$OPT_TOKEN" in
        "$1") opt_f "$1" ;;
        "$2") opt_f "$1" ;;
        *) return 1 ;;
    esac
    return 0;
}

# to match --, handle invalid options, commands and values
function opt_match_nonoptions {
    case "$OPT_TOKEN" in
        --) opt_break -- ;;
        -*) opt_invalid ;;
        *) opt_pos -- ;;
    esac
    return 0;
}

# customize opt_in error handler - this version does not abort 
function opt_user_fail {
    reason=$1; name=$2; msg=$3;
    fail "$msg $name"
}

# -------------------- end opt-in extension library --------------------

