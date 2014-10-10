# ----------------------------------------------------------------------
# opt-in core option parser library, (c) 2014, Mikkel Fahnøe Jørgensen
# Version: v0.1.1, License: MIT
# ----------------------------------------------------------------------
function _opt_dbg { [ $_opt_dbg_enabled -ne 0 ] && echo "debug: $@"; return 0; }
function _opt_esc { _opt_ping="'\''"; _opt_qv="${1//\'/$_opt_ping}"; _opt_qv="'${_opt_qv}'"; }
function _opt_push { _opt_dbg "pushing: $@";
    for _opt_i; do _opt_esc "$_opt_i"; _opt_args="${_opt_args}${_opt_qv} "; done; } 
function _opt_value { _opt_dbg _value_; _opt_push "$1"; unset _opt_expect; unset _opt_missing; }
function opt_user_fail { reason="$1"; name="$2"; msg="$3";
    echo >&2 "$msg $name"; exit 1; }
function opt_missing { _opt_dbg _missing_;
    _opt_value "${1:-${_opt_missing:-$_opt_tmissing}}";
    [ $_opt_silent -eq 0 ] && \
        opt_user_fail "missing-value" "$_opt_expect" "error: option expected a value: "; }
function _opt_put {
    if [ -n "$_opt_expect" ]; then [ $_opt_eager -ne 0 ] && _opt_dbg "_eager_" && \
        _opt_value "$_opt_token" && return 0;
        _opt_dbg "_strict_default_"; opt_missing; fi;
    _opt_dbg "_type_: $1"; _opt_push "$2"; [ -n "$3" ] && _opt_value "$3"; }
function opt_invalid { _opt_brk=1;
    _opt_put "i: invalid option" "${1:-$_opt_tinvalid}" "$_opt_token";
    [ $_opt_silent -eq 0 ] &&  \
        opt_user_fail "invalid-option" "$_opt_token" "error: invalid option: "; }
function opt_kv { _opt_put "kv: key value" "$1" "${_opt_token#*=}"; }
function opt_ev { _opt_missing="$2"; _opt_put "ev: expect value option" "$1";
    _opt_expect="$_opt_token"; } 
function opt_v { _opt_put "v: value option"  "$1" "${_opt_token:2}"; }
function opt_vg { _opt_put "vg: value given option"  "$1" "$2"; }
function opt_vs { _opt_put "vs: value suffix" "$1" "${_opt_token#$2}"; }
function opt_f { _opt_put "f: flag option" "$1"; }
function opt_break { [ -n "$_opt_expect" ] && _opt_dbg _break_expecting_ && opt_missing;
    [ $_opt_brk -eq 0 ] && [ -n "$1" ] && _opt_dbg _break_ && _opt_push "$1"; _opt_brk=1; }
function opt_nonopt { opt_break "$1"; _opt_dbg _nonopt_; _opt_push "$_opt_token"; }
function opt_pos { _opt_dbg _pos_; [ -n "$_opt_expect" ] && _opt_value "$_opt_token" \
    || opt_nonopt "$1"; }
function opt_resume { _opt_brk=0; _opt_dbg _resume_; }
function opt_next { _opt_token="$1"; OPT_TOKEN="$1";
    _opt_dbg "args so far: $_opt_args"; _opt_dbg "next token: $1";
    if [ $_opt_brk -eq 0 ]; then return 0; else opt_pos; return 1; fi; }
function opt_get { _opt_tail="$1"; if [ "${1:0:1}" == "-" ] && [ ! $_opt_brk -ne 0 ] &&
    ( [ -z "$_opt_expect" ] || [ $_opt_eager -eq 0 ] ); then 
    while [ "$2" != "${2/${_opt_tail:1:1}/}" ]; do
        _opt_dbg "_combine_: flag '$_opt_tail' in '$2'"
        opt_next "${_opt_tail:0:2}"; opt_f "$OPT_TOKEN"; _opt_tail="-${_opt_tail:2}";
        [ "$_opt_tail" == '-' ] && return 1; done; fi; opt_next "$_opt_tail"; }
function opt_debug { echo >&2 "opt: token='$_opt_token'"; }
function opt_init { _opt_args=""; _opt_token=""; _opt_qv=""; 
    _opt_brk=0; unset _opt_expect; unset OPT_ARGS; _opt_silent=0; _opt_eager=1;
    _opt_tinvalid='?'; _opt_tmissing=':'; _opt_dbg_enabled=0;
    for _opt_i; do _opt_dbg _opt_init_ arg "$_opt_i"
        case "$_opt_i" in silent) _opt_silent=1;; eager) _opt_eager=1;;
    strict) _opt_eager=0;; noisy) _opt_silent=0;; debug) _opt_dbg_enabled=1;;
    invalid=*) _opt_tinvalid=${_opt_i#*=};; missing=*) _opt_tmissing=${_opt_i#*=};;
    *) echo >&2 "error: opt-in opt_init: invalid argument: $_opt_i";; esac; done; }
function opt_final { [ -z "$_opt_expect" ] || opt_missing;
    OPT_ARGS="${_opt_args%?}"; OPT_IN="eval set -- $OPT_ARGS"; _opt_dbg "OPT_ARGS: $OPT_ARGS"
    unset _opt_args; unset _opt_token; unset _opt_qv; unset _opt_silent;unset _opt_debug_enabled;
    unset _opt_eager; unset _opt_tmissing; unset _opt_tinvaild; unset _opt_ping; unset _opt_tail;
    unset opt_i; unset _opt_brk; unset _opt_expect; unset _opt_missing; unset OPT_TOKEN; }
# ------------------------- end opt-in library -------------------------
