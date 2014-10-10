#! /bin/sh

# ----------------------------------------------------------------------
# opt-in option pre-parser
# library (c) 2014, Mikkel Fahnøe Jørgensen
# License: MIT
# ----------------------------------------------------------------------

# free to embed and drop comments in production code, but consider adding a
# public repo link to full source - it is supposed to be small, practical, and
# reuseable.
#
# A small option pre-parser library that allows reasonably complex long options
# without using non-portable getops features, or getopts at all.
# return value is important when chaining commands and debug is off!
function _opt_dbg { [ $_opt_dbg_enabled -ne 0 ] && echo "debug: $@"; return 0; }

# See README.md for quote and escape discussion
function _opt_esc { _opt_ping="'\''"; _opt_qv="${1//\'/$_opt_ping}"; _opt_qv="'${_opt_qv}'"; }

function _opt_push { _opt_dbg "pushing: $@";
    for _opt_i; do _opt_esc "$_opt_i"; _opt_args="${_opt_args}${_opt_qv} "; done; } 

function _opt_value { _opt_dbg _value_; _opt_push "$1"; unset _opt_expect; unset _opt_missing; }

# NOTE: it is exceedingly important to pass parameters in quoted expansions like "$arg",
# otherwise string content can and will get lost.
#
# If this function does not abort, a default missing value is assigned for reason missing-option
# and for reason invalid-option, an error token is inserted before breaking into
# non-option mode for the remaining tokens.
#
# Override this function as needed before calling opt_init, or disable
# it with opt_init silent.
# Possible 'reason' values: "missing-value" | "invalid-option" | "default-option".
function opt_user_fail { reason="$1"; name="$2"; msg="$3";
    echo >&2 "$msg $name"; exit 1; }

function opt_missing { _opt_dbg _missing_;
    _opt_value "${1:-${_opt_missing:-$_opt_tmissing}}";
    [ $_opt_silent -eq 0 ] && \
        opt_user_fail "missing-value" "$_opt_expect" "error: option expected a value: "; }

# If _opt_eager is set, potential options will be treated as values instead of
# of injecting a default value and triggering a missing value error.
# To illustrate eager consider the tar utilities eager behaviour:
# e.g. "touch x && tar -c -f -foo x" wil create the file '-foo'
# rather than failing on invalid option. On the other hand,
# the rm tool will not remove it with 'rm -foo' but will with 'rm -- -foo'.
# The latter is not eager or non-eager, it is an invalid option.
# If tar has issued an invalid option error on the above, it would have
# been strict behavior - and it would be difficult to create files that are
# named similar to options. Whether that is good or bad is open for debate,
# hence the choice of modes.
function _opt_put {
    if [ -n "$_opt_expect" ]; then [ $_opt_eager -ne 0 ] && _opt_dbg "_eager_" && \
        _opt_value "$_opt_token" && return 0;
        _opt_dbg "_strict_default_"; opt_missing; fi;
    _opt_dbg "_type_: $1"; _opt_push "$2"; [ -n "$3" ] && _opt_value "$3"; }

function opt_invalid { _opt_brk=1;
    _opt_put "i: invalid option" "${1:-$_opt_tinvalid}" "$_opt_token";
    [ $_opt_silent -eq 0 ] &&  \
        opt_user_fail "invalid-option" "$_opt_token" "error: invalid option: "; }

# key-value option, e.g.: -o=<outfile> | --output=<outfile> (splits into -o "<outfile>")
function opt_kv { _opt_put "kv: key value" "$1" "${_opt_token#*=}"; }

# expect-value option, e.g.: -o <outfile> | --ouput <outfile>
# (consume -o, expects next token to be <outfile>) the next token must be
# matched such that it reach opt_pos, or is ignored with opt_resume.
function opt_ev { _opt_missing="$2"; _opt_put "ev: expect value option" "$1";
    _opt_expect="$_opt_token"; } 

# value option, e.g.: -o<outfile> (splits into -o "<outfile>" with proper escapes.
function opt_v { _opt_put "v: value option"  "$1" "${_opt_token:2}"; }

# value given option: second arg is the explicit value
function opt_vg { _opt_put "vg: value given option"  "$1" "$2"; }

# value suffix option" second arg is the prefix to be removed
function opt_vs { _opt_put "vs: value suffix" "$1" "${_opt_token#$2}"; }

# flag option, e.g.: -v | --verbose
function opt_f { _opt_put "f: flag option" "$1"; }

# Break from option into non-option parsing. Typically when ' --' has been seen.
# $1 is typically '--', or empty if separator should be skipped.
# opt_pos has a similar argument, but inserts current token after.
# Forces missing value error, also with eager parsing.
function opt_break { [ -n "$_opt_expect" ] && _opt_dbg _break_expecting_ && opt_missing;
    [ $_opt_brk -eq 0 ] && [ -n "$1" ] && _opt_dbg _break_ && _opt_push "$1"; _opt_brk=1; }

# Normally called via opt_pos to handle pending values
# but otherwise pushes token as is, possible inserting -- or custom separator.
function opt_nonopt { opt_break "$1"; _opt_dbg _nonopt_; _opt_push "$_opt_token"; }

# Postional value: <filename> | <command> | ...
# Either an expected value following opt_ev, and otherwise a call to opt_pos
# will break token parsing on first non-option and pass on values until either
# opt_resume is called, or opt_final stops the processing.
# If given an argument, like '--', it will be inserted as flag just before
# first non-option token, unless break was already called.
function opt_pos { _opt_dbg _pos_; [ -n "$_opt_expect" ] && _opt_value "$_opt_token" \
    || opt_nonopt "$1"; }

# All options have 0 or 1 expected arguments. After that option parsing is
# terminated extra non-option _opt_tokens are copied verbatim with opt_pos. It
# is possible to resume _opt_token parsing manually, for example after a count,
# by flagging resumopt_ev which takes no argument.
function opt_resume { _opt_brk=0; _opt_dbg _resume_; }

# Assigns the token to be parse and consumes tokens automatically after breaking
# into nonoption mode. It must still be called with each token, and the return
# code indicates if flags should be processed or skipped.
# OPT_TOKEN is for external consumption. It may be used to break a token
# into smaller pieces.
# If combined flags are not needed, this function can replace 'opt_get'.
function opt_next { _opt_token="$1"; OPT_TOKEN="$1";
    _opt_dbg "args so far: $_opt_args"; _opt_dbg "next token: $1";
    if [ $_opt_brk -eq 0 ]; then return 0; else opt_pos; return 1; fi; }

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
#
# NOTE: be careful not to have '-' or other non-letter symbol in
# the flags argument, it can give quite unexpected results.
function opt_get { _opt_tail="$1"; if [ "${1:0:1}" == "-" ] && [ ! $_opt_brk -ne 0 ] &&
    ( [ -z "$_opt_expect" ] || [ $_opt_eager -eq 0 ] ); then 
    while [ "$2" != "${2/${_opt_tail:1:1}/}" ]; do
        _opt_dbg "_combine_: flag '$_opt_tail' in '$2'"
        opt_next "${_opt_tail:0:2}"; opt_f "$OPT_TOKEN"; _opt_tail="-${_opt_tail:2}";
        [ "$_opt_tail" == '-' ] && return 1; done; fi; opt_next "$_opt_tail"; }

function opt_debug { echo >&2 "opt: token='$_opt_token'"; }

# Initialize before calling any other parse functions.
# Options: [debug] [silent | noisy] [eager | strict]
#          [invalid=`invalid-token`] [missing=`missing-value`]
function opt_init { _opt_args=""; _opt_token=""; _opt_qv=""; 
    _opt_brk=0; unset _opt_expect; unset OPT_ARGS; _opt_silent=0; _opt_eager=1;
    _opt_tinvalid='?'; _opt_tmissing=':'; _opt_dbg_enabled=0;
    for _opt_i; do _opt_dbg _opt_init_ arg "$_opt_i"
        case "$_opt_i" in silent) _opt_silent=1;; eager) _opt_eager=1;;
    strict) _opt_eager=0;; noisy) _opt_silent=0;; debug) _opt_dbg_enabled=1;;
    invalid=*) _opt_tinvalid=${_opt_i#*=};; missing=*) _opt_tmissing=${_opt_i#*=};;
    *) echo >&2 "error: opt-in opt_init: invalid argument: $_opt_i";; esac; done; }

# Replace the original command line options with the translated verions,
# ready for the second pass, and clear all state.
# OPT_ARGS holds an agument string of option value pairs all single quoted,
# followed optionally by non-option separtor (typicall --), followed by
# single quoted remaining tokens. Embedded single quotes are sandwiched as a
# a doulbe quoted string with a single quote. This means the string can be parsed
# predictably by counting single quotes. Each token is space separated.
#
# To inject into original argument list use: 
#
#     eval set -- $OPT_ARGS
#
# or, simply:
#
#     $OPT_IN
#
# OPT_ARGS is only available after the call to opt_final The above will affect
# the local function it is called in or the main argument list, depending on
# where it is executed. We can therefore not provide a function for it.

function opt_final { [ -z "$_opt_expect" ] || opt_missing;
    # trim trailing space
    OPT_ARGS="${_opt_args%?}"; OPT_IN="eval set -- $OPT_ARGS"; _opt_dbg "OPT_ARGS: $OPT_ARGS"
    unset _opt_args; unset _opt_token; unset _opt_qv; unset _opt_silent;unset _opt_debug_enabled;
    unset _opt_eager; unset _opt_tmissing; unset _opt_tinvaild; unset _opt_ping; unset _opt_tail;
    unset opt_i; unset _opt_brk; unset _opt_expect; unset _opt_missing; unset OPT_TOKEN; }


# ----------------------------------------------------------------------
# end opt-in library
# ----------------------------------------------------------------------
