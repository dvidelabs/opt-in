# opt-in Option Pre-parser Shell Library 

(c) 2014, Mikkel Fahnøe Jørgensen

License: MIT

A small shell script option pre-parser library that allows for
reasonably complex short and long options without relying non-portable
getop or getops features. It provides an approach similar to many ad-hoc
two pass solutions for long options, avoids many pitfalls, notably
handling missing values and arguments with spaces and special
characters. It also sports a useful debugging facility.

As is the case with most two pass solutions, this library is optional
in the sense that the second pass does not require the first pass.
It can be retrofittet to existing option parsing logic.

The embedded core library takes up about 60 lines of dense shell script
with no external or internal dependencies other than the most basic
shell features. We also refer to this as the core library.

The library can be made a bit more convenient by adding wrappers to
automate repetitive tasks. Since we want the core library to be small
and the wrappers might need customization, we provide an extension
library which really should just be seen as a starting point for 
customization. This document mostly focus on the core library, and
the extension is mostly self-explaining.


## Quick Start with Extension Example

We primarily focus on the core library in this document, but here we
show a short high level use with the extension library. Many will probably
prefer this version, but for users with own parsing loops, the core
can be used to make these more solid. For the rest, the following
is just an example, you are supposed to customize the match functions
to adapt to your style.

Make sure you have both the core and the extension library sourced
into a shell script.

The following is found in the `demo.sh` file:



    #!/usr/bin/env bash

    source $(dirname $0)/opt-in.core.sh
    source $(dirname $0)/opt-in.extension.sh

    opt_init 'missing=<missing>'
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


## Installation

A build script strips all comments to provide an easily embeddable core
library snippet. The source is `opt-in.core.sh` and the snippet is
called `opt-in.embed.sh`. If the library is not embedded, it must be
sourced - it is not an external program.

Note: all files are pre-built and checked in. You only need to build if
you change files and depend on the build products.

The library is supposed to be portable but has only been tested in Bash
in `#! /bin/sh` mode. It is recommended to use `#!/usr/bin/env bash`.

If you can tolerate the dependency on `gunzip` and `base64`, and you
have the ability to use the `source <(command)` shell construct (like
Bash on OS-X or Linux core distribution), you can also embed the core
library as a self-extracting archive. See `opt-in.archive.sh`.


## Known Posix Issues

- Substring parsing syntax like `${1:0:2}` is not very elegant in Posix
shells, so in its current state, the parser will require a bash
compatible shell.

- The `function myfunction { ... }` syntax should be `myfunction() { ...
  }`, but will work with bash shells.

- `==` should be `=` and string comparisons should add a suffix to
avoid empty string arguments to `test`, like `[ "$1"x = "-" ]` rather
than `[ "$1" == "-" ]`.


## Motivation

It may seem like an overkill for simple option parsing, but it is in fact
quite difficult to get right, and to maintain once it gets right, not to
mention handling escaped quotations correctly - which is very important
when forwarding some arguments to other commands.

For those who are not aware, there are two established libraries:
    
    getopt
    getopts

`getopt` is considered outdated by many. It handles long options but not
special characters or whitespaces very reliably. `getopts` is a Posix
standard shell built-in construct which does not support long options
without non-portablye extensions. It is, reportedly, not possible to
re-implement `getopts` in shell script due to how it updates values.

Due to these issues, there are many suggestions for small simple option
parsers in online forums, some of which have inspired this one with many
good ideas, but all approached visited, have been broken in some cases
either due to bugs, or difficulty in adaptation without breaking parser
state, or because they fail to handle escapes properly, or in some cases
because they simple choose not to support some features, such as
`option=value`.

The `opt-in` library attempts to solve the portability issue by
embedding itself within the script using it, and only use very basic
shell features. It attempts to address the long option issue by using an
oft-recommended method of pre-parsing options to a normalized form, and
it attempts to address spaces and special characters by being paranoid
about using quoated arguments in a specific way.

It does not attempt to provide a very compact input string syntax to do
all the parsing such as getopts does. This would make the library larger
and less embeddable, and also less flexible, but it does mean the same
option may be listed multiple times because of the different ways to do
the same thing.


## Basic Operation

The library is a collection of small parser functions that are easily
extended. It works as a two pass solution where the first pass reads as
an executable lexer syntax, and the second pass is completely
independent of this library, which can focus on a much simpler syntax
with no concern for syntax errors. The first pass is thus an option that
can be added later when the script has been worked out.

For example, the following arguments:

    --buffer 42 --now -Ox -I=imgpack --optimize=gfx publish 400 300 

will be converted to the following `$OPT_ARGS` string, given the rules
in the example below:

    echo "$OPT_ARGS"

    '-b' '42' '-n' '-O' 'x' '-I' 'imgpack' '-O' 'gfx' '--' 'publish' '400' '300'

The resuling `$OPT_ARGS` string can be re-assigned to the original
argument list with:

    $OPT_IN

and processed in a simplified manner in a second pass.


### Pre-processing (first pass)

Rules are defined by spoon feeding tokens with the `opt_next` function:


    function usage {
        echo "Usage: TBD"
    }
    
    opt_init debug silent
    for arg
    do
        if opt_get "$arg"; then
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
            esac
        fi
    done
    opt_final
    $OPT_IN

Important: be sure to arrange the patterns with the most specific match
first. For example, `-O*` should follow `-O=*`, otherwise the wrong
command will be matched. See also later section on how we can create
higher level constructs to automate this. You can also capture combined
options by giving a string.

Each `opt_` command defines a certain type of value. `_opt_ev` is expect
value, so in the example, `--buffer` expects a value to follow, but
`--now` does not and only has this one form. `--optimize`, aka `-O`, has
several forms, one of which is expecting a value, and one which is a
key-value pair, and one has a value immediately after the short option
form. The `opt_break` function takes an optional argument. It will
consume or replace a token such as `--` and ensure further values are
treated as non-options.  `opt_break` only has an effect if the user
gives the token, here `--`, but in our example input, we detected
non-options by seeing token where no value was expected, and it also
insert `--`. `STDIN` is just to show we can use arbitrary tokens in the
resulting stream.

It is not necessarily a good idea to define such a varied and inconsistent
interface. This is just to show the various possibilities.

The if condition ensures that we skip option matching as soon as
non-options are encountered because `opt_next` will handle these by
itself. The `opt_pos` command handles both values and non-option
keywords and arguments, and handles missing value errors, and inserts
missing `--` before first non-option if given.

Observe that we might as well have used `case "$arg" in` instead of
`case "$OPT_TOKEN" in` because the values are the same. But for future
extension, and for dealing with combined flags, this will change. So be
sure to use "$OPT_OPTION" as shown.

More advanced use can process the else branch and return to
option parsing later by calling `opt_resume`.

Arguments that are followed immediately by a value, such as `-O1`, can
only have the short form and is given by the value option command
`opt_v`. If a long form is needed, it is not difficult to create an
extension that does this. 

As shown, the same logical option may appear multiple times in the rule
spec for the first pass. Some users may dislike this feature, but it
allows for a simple specification and very granular control over which
syntax variations of short and long options are to be supported.

All the operations check for pending missing values, and `opt_final`
checks for a finally pending missing value.


### Consuming the Output

Once `opt_final` has been called, the only values left by the library is
the above `$OPT_ARGS` value, and `$OPT_IN`. Temporary values use the
`_opt_` prefix.

You can either use the resulting argument list as is, with `$OPT_ARGS`,
or assign it to the current argument list with

    eval set -- $OPT_ARGS

or use the following shorthand for the above:

    $OPT_IN

Note that the above will only affect the argument list inside the
current function if not executed in global scope.

### Post-Processing (2nd pass)

None of the following is specific to the opt-in library, with the
exception of the missing value ':' and invalid token '?' symbols,
which are compatible with `getopts` convention.

This is just an example of how one could go about processing the
simplified argument list in the second pass.


    # optional: add opt-in pre-parser
    # # function opt_user_fail {}
    # opt_init
    # ...
    # opt_final
    # $OPT_IN

    unset fd; unset BUFFER; unset NOW; unset CLONE; unset OPTIM; unset INC;
   
    # Don't use 'while [ -n "$1" ]', it won't handle empty args correctly.
    while [ $# -gt 0 ]
    do
        case "$arg" in
            -b)  BUFFER="$2"; shift ;;
            -n   NOW=1 ;;
            -c   CLONE="$2"; shift ;;
            -I)  INC="$2"; shift ;;
            -O   OPTIM="$2"; shift ;;
            --)  shift; break ;;
            STDIN) fd=1 ;;
            '?') echo "invalid argument"; exit 1 ;;
            *) break ;;
        esac
        shift
    done
    # check for empty or other invalid argument values
    [ "$CLONE" == ":" ] && 
        echo >&2 "warning: skipping missing clone argument";
    [ -z "$BUFFER" ] &&
        echo >&2 "error: abort on empty or absent buffer argument" &&
        exit 1;
    #...

    # the process the remaining non-options:
    function myhandler {
        case "$1" in
            publish) echo "publishing" ;;
            *) echo "not publishing" ;;
        esac
    }
    
    # do use quotes, it will expand to all args - special @ feature
    myhandler "$@"

Note that this second pass can actually be on its own. The pre-parser
can be added later, and probably retro-fitted to many homegrown option
parsers to make them more solid and flexible.

Note also that it is rather important to quote strings like `"$arg"` in
the above.



## Initialization

You can supply a custom error handler, or process error tokens getopt
style via the '?' argument, and ':' missing value, or supply your own to
`opt_init`. These will work the same with or without an error handler
function, assuming the error handler does not abort:

    opt_init invalid=_my_invalid_token_ missing=my_missing_value

Deactivate, or activate the error handler with:

    opt_init silent
    opt_init noisy

`opt_init` should be called exactly once per parse and take multiple
arguments.

The default error handler aborts. You can customize the error handler
and if it returns, the other logic works as if in silent mode.

    function opt_user_fail {
        reason=$1
        name=$2
        msg=$3
        #...
    }

The name is interesting because it knows the name of the option that was
expecting a value, they way the user typed it. This information will be
lost in the second pass.


### Eager and Strict Modes

    opt_init strict

or

    opt_init eager

`opt_init` takes a `strict` or `eager` mode. `eager` is the default, and a
commonly used unix style, but it can lead to confusion when, say, a tar
arhive is created with what was thought to be an option name.  In
`eager` mode, the next valid or invalid option is consumed as a value if
one is expected and only processed as the alternative if not. In strict
mode, the recognized valid and invalid formats take precedence and
missing value errors may be used to warn the user or to assign default
values.

Missing values are not necessarily fatal - here we use `opt_ev` to
actively assign a default value - assuming silent mode or a non-terminal
error handler.

    ...
    -o|--output) opt_ev -o 'dump.txt' ;;
    ...

It is probably best to keep application logic out of the parser spec,
and test for default in the post-procesing step, in which case the
default ':' might work just as well as default value, or the
missing=value default given to `opt_init`.

Also see the comments to functions in the library source for further
details.


## Debugging

    opt_init debug silent

Dumps a trace of the values being processed and the argument string
built so far. Silent is useful since the default error handler
exits ASAP.

## Adding Combined Flags

You can support combined flags by listing them as a string of single
letter options. These take precedence over other flags. They cannot be
translated to a different name, such as the explicit use of `opt_f`
allows for.


Consider the classical `tar -xzf filename`. In the next example we will
add support for this syntax.

Without copying the entire example from earlier we recall the single
line:

    if opt_get "$arg"; then
    ...

we change this line to:

    if opt_get "$arg" "tzcxf"; then
    ...

The `"$arg"` value will internally be consumed to the point where no
short options are avaible. The rest is passed to the `then` branch and
stored in `$OPT_TOKEN` with a `-` prefix (the prefix only if there were
flags before).

    opt_get "-xzf" "xzcth"

Will result in `opt_get` return success with:

    `OPT_TOKEN="-f"

buf if called with just

    opt_get "-xz"

it would consume both flags and emit '-x' and '-z' before returning
false (non-zero) to indicate this argument has nothing left.

If we called with any argument that does not match a listed flag,
we see the same behavior as if no flag list were given as in the
earlier example.

Values can also be embedded:

    if opt_get "-zsO42" "szx"; then
        case "$OPT_TOKEN" in
            ...
            -O*) opt_v -O;;
    ...

would emit:

    '-z' -s' '-O' '42'


## Higher Level Constructs

Entering the same option in several different ways can become tedious,
and since ordering is important, it can also be error prone.

We can easily create higher level matching constructs around the library
to deal with this. But since each user may have a different opinion on
the standard type of flag options, and because the library quickly
grows, we just show how such constructs may be added.

Be aware that the library primitives are output operations, and the
function shown is a matching primitive. It's use has already been
demonstrated in the Quick Start chapter. You can find the function along
with a few other in the extensions library.


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


## Core Extensions

It is actually quite easy to extend the syntax of the core library
parser. Look at the `opt_kv` and `opt_v` function to see how they match
the token value and passes it on to the lower level engine. A syntax
such as:

    myoption:myvalue

could easily be added.

The following is the implementation of `opt_v` which understands `-Ox`
style options:

    function opt_v { 
        _opt_put "v: value option"  "$1" "${OPT_TOKEN:2}";
    }

If we look at `_opt_put` the first argument is debug information, the
second argument with the value "$1", is the resulting option name given
to `opt_v` in the user interface. It would probably be "-O" in our
example. The last argument is the actual value of the option.
`OPT_TOKEN` holds the current input token, and since '-Ox' is such a
token, we get the value 'x' because 'x' begins at index 2 in our token
matching pattern.

If we want to make an extension that supports "object:value", we first
realize that the token matching is the users responsibility in the
input, so if our extension is called, we can assume that there is a ':'
in the token, and we attempt to match the value after it.

Thus we create our extension:

    function opt_user_ov { 
        _opt_put "u_ov: object value"  "$1" "${OPT_TOKEN#*:}";
    }

by relying on shell pattern matching. And the user would use it as:

    case "$arg" in
    # ...
    deny-access:*)  opt_user_ov 'ALLOW' ;;
    allow-access:*) opt_user_ov 'DENY' ;;
    # ...

And the end-user could use the new option style on the command line like:

    access-tool allow-access:dept2 deny-access:dept11

If we are not sufficiently carefull with the library matching rule, the
application might think the user entered the above, when the user in
fact entered:

    access-tool allow-access:dept1:dept7:dept2 deny-access:dept11

because shell pattern matching has both shortest and longest matching
forms. Such pitfalls are a good motivation for using library functions over
ad-hoc interface parsing.

You could also create an extension that maps a name to a value of
another option:

    function opt_user_kw { 
        _opt_put "u_kw: value option"  "$1" "$2"
    }

(notice how religious we are about quoting)

with the example:

    
    case "$arg" in
    # ...
    --enable-password)  opt_user_kw -p yes ;;
    --disable-password) opt_user_kw -p no ;;
    -p) opt_user_kw -p yes ;;
    # ...

(notice how the library user can be more relaxed about quoting, but
still have to be careful with special characters)

Extending the syntax with expected values where the value is not
contained in, or infered from, the same token as the option name, is
much more involved, and not recommended because it easily becomes
fragile with missing value states. The exception to this is when
wrapping the public `opt_ev` instead of `_opt_put` in the library
function.

You do not need to modify the library, just add the extension below the
point where it is included.


## Synopsis

Consult the above example to see how to craft case patterns suitable
for each of the following operators.

This synopsis only reference the core library, it does not cover the use
of the extension library.


    opt_get <arg> [<flags>]
    
        Main driving function. 

        Simply stated - it consumes some stuff, and tells if there is something
        left to be processed in OPT_TOKEN by returning success.
        
        Consumes none, some, or all of the argument depending on the situation.
        Returns success (zero) if OPT_TOKEN should be processed subsequently,
        and failure (not-zero) otherwise. OPT_TOKEN may be the full argument,
        or whatever is left after simple flags matching the flags list have
        been consumed. Flags are only consumed if <arg> begins with '-'. If the
        OPT_TOKEN value is non-empty but also not the full <arg>, it will be
        prefixed with '-'. If the parser is in breaking mode, that is, after an
        invalid option or after non-option has been seen (which is not an
        expected value), then all subsequent tokens are consumed and copied
        verbatim, except if the opt_resume has been called.


    opt_f <name>
    
        Flag option.

        Replace a simple flag option that has no value, e.g. '--foo' with '-f'
        or, '-f' unchanged as '-f'. The input token is not matched here, this
        applies to output functions. By convention '<name>' begins with a '-'
        because this looks like a short option when processed by the later 2nd
        simplified parsing stage, but it need not be so. 'opt_f' is also called
        implicitly by 'opt_get' to process combined flags. In this case the
        '<name>' will be the same as the option name, with '-' prefixed.


    opt_ev <name> [<default>]
    
        Expect Value option.
        
        E.g.: --foo file becomes -f with opt_ev -f file will only appear as the
        next token and will be matched by most any opt_ command in eager mode,
        and only by opt_pos in strict mode. If not matched, a default token is
        inserted and the following token is handled according to what it
        appears to be.  The default value is taken first from <default> if
        available, or missing=<default> as argument to opt_init, or ':' by
        default.


    opt_v <name>

        Value option.
        
        Replace token with <name> and insert a token created as the token
        string after the first two characters, e.g. -Ffile becomes '-f' 'file'
        with opt_v '-f'.
        

    opt_vs <name> <prefix>

        Value suffix option.

        Similar to 'opt_v', but takes a specific option string as prefix,
        strips it from the token and use the suffix as value. E.g.: 'opt_v -b
        -buf' will get the value '42' from the token '-buf42' and use '-b' as
        the resulting option name.


    opt_vg <name> <value>
    
        Value given option.
        
        Outputs an option with said name followed by a given value. May be used
        to translate custom matches, or to translate a keyword like
        '--no-access' to '--access no'.       


    opt_kv <name>

        Key Value option.

        Replace the token with <name> followed by a value created from the
        token string after the '=' sign.


    opt_pos [<break>]

        Position Argument (Value or Non-Option Argument).

        If there is an expected value, just insert it and complete the opt_ev
        command. Otherwise raise non-option mode and insert <break> if given.
        <break> is by convention '--'. If already in non-option mode, we
        should not call antyhing 'opt_next' will return false. In this case
        'opt_resume' may be called to continue option processing.


    opt_break [<break>]
   
        Explicit Break of Option Stream.

        Handles the conventional '--' break character without potentially
        treating it as a value for opt_ev. Either removes it or replaces it
        with the <break> value which is typically '--'. If opt_pos already
        triggered non-option mode, this command will not take effect, and vice
        versa.


    opt_resume
    
        Resume Broken Option Stream (rarely used).
    
        Only call this when opt_next returns falls, or immediately after
        opt_break or opt_pos to cancel non-option mode, for example after a
        count or a keyword. It may also be used with opt_invalid.


    opt_invalid
   
        Invalid Option (distinct from Positional).

        Signals the token is invalid inserts an error token before the token,
        then enters non-option mode so opt_next copies the and copies the
        failing and remaining tokens verbatim.  The token inserted is
        invalid=<invalid-token> given to opt_init, or '?' by default. It is
        typically detected by an argument starting with '-' but no recognized
        suffix unlike positional arguments which do not normally start with
        '-'.


    opt_init

        Initializes parsing state.

        Required, takes zero or more arguments:
        [debug] [strict | eager] [silent | noisy]
        [missing=<value>] [invalid=<token>]
        Defaults: opt_init eager noisy 'missing=:' 'invalid=?'

        silent, noisy: only effects the call to the error handler.
        eager, strict: see separate discussion.

        debug: dumps parser state and is (ironically) most useful in
        silent mode or with a custom error handler that does not abort.


    opt_final
        
        Checks for pending expected value and cleans up used variables.

        Last operation except optionally $OPT_IN. Assigns the $OPT_ARGS
        variable and unsets all temporary '_opt_...' variables.


    opt_user_fail
    
        A default error handler that can overridden.
        
        The default prints a message to stderr and aborts. Should be defined
        after the library, before the call to opt_init. On in effect in noisy
        mode.
        
        Takes three arguments:
        
        $1 reason: invalid-option|missing-value)
        $2 name:   <literal name of token that failed>
        $3 msg:    <a default error message>


    $OPT_ARGS

        String represention of resulting argument list after call to 'opt_final'.


    $OPT_IN

        Shorthand for 'eval set -- $OPT_ARGS'. Sets the current argument
        list to the result after call to 'opt_final'.


    $OPT_TOKEN

        Variable to be processed after call to 'opt_get'. Do not use the
        'arg' variable given as input to 'opt_get "$arg"' instead of
        'OPT_TOKEN', even if they are often identical, because it breaks
        down when 'opt_get' handles combined flags.



## Appendix A. Quoting and Escaping Values

This should be trivial, but isn't, and in FreeBSD's getopt man page,
they have basically given up - citation:


    man getopt
    GETOPT(1)
    ...
    Bugs:

      Arguments containing white space or embedded shell metacharacters
      generally will not survive intact;  this looks easy to fix but
      isn't.  People trying to fix getopt or the example in this manpage
      should check the history of this file in FreeBSD.


Why is uncertain, and the following approach might have issues, given
the problems getopt apparently has, but so far it seems to work well
in ... a bash shell.

Quotes are really important - perhaps not in the `-h) help; exit;` case
but otherwise: values passed from the command line to a script and on to
another command may have any kind of structure, and they may be called
by ancient complex scripts relying on standard shell behavior from
decades of evolution.  Quotes are also important because shells do not
have dynamic arrays so we use strings as buffers. These need to be
escaped. `eval` is very particular, even if a string otherwise appears to
be sane - for example, a double quoted string with a question mark blows
up. And finally, not being in control of the arguments is a huge attack
vector for hackers.

To summarize, most of our problems arise from quoting string like

    "arg1 here" "arg2 here"

without ambiguity, and especailly when giving it to the epxression:

    items="arg1 here" "arg2 here"
    eval set -- $items

The above assigns two arguments to $1 and $2. Eval is needed to process
the spaces correctly so we get two and not four items, but this
processing leads to further issues.

As it turns out, the solution is deceptively simple, and probably well
known to many, but it is not widely used in the many published option
parsing snippets floating the web, and this is why such a library is
needed.

So, how does quoting work?

The incoming argument list is already processed by the shell. And if
each argument is given to `opt_next` within a string such as `"$arg"`,
and not `$arg`, it will remain as is within the `opt-in` framework.

The `opt-in` engine pushes tokens onto a queue which is simply a string
holding space separated tokens. Each token is enclosed in single quotes
and have embedded single quotes replaced with an escape sequence that
will be discussed shortly. `eval` understands this string because it
does not mess with single quoted strings, and because it understands
string concatenation.

Single quoted strings work because nothing, absolutely nothing, is
escaped in-between two single quotes, so we only need to deal with
embedded single quotes. This is done by splitting a single quoted string
into two strings and embed a another valid string with just the single
quote.

First, consider the double quoted string:

    "I won't do it."

which would be valid in this particular case, but in general it will
fail, or at least be difficult to escape, as we shall see below.

    'I won't do it.'

will not work, neither will

    'I won\'t do it.'

but - the following is almost correct:

    'I won'
    "'"
    't do it.'

or

    'I won'
    \'
    't do it.'

except this is now three tokens, not one. Fortunately, if we leave out
the space between the strings, they become one, and we get:

    'I won'"'"'t do it.'

or

    'I won'\''t do it.'

So why not just use the cleaner double quotes?

    "I won't do it!"

The above will fail because `!` is seen as an event indicactor by some
shells, and escaping it with `\!` will result in the desired `!` but
unfortunately preceeded by the undesired `\` (probably depending on the
exact shell). All of this when inside double quotes, that is. There are
numerous other issues. The following, on the other hand, works
predictably correct:

    'I won'\''t do it!'

Also, the question:

    "Will you do it?"

is a positive when echo'ed to the console, but a sounding NO when asking
`eval` the same question. It will trash the question mark, then you
could try to escape, but no, no - not quite there. Before wasting more
time on that, consider instead:

    'Will you do it?'

YES - `eval` will do it.

The following test case is where the double quote approach was
definitively abandoned. Here is the raw shell input line, that is,
without any quotes other than what the user wrote.

    \'"'\"lima?:\$x'2\\4"\ .

This is actually a single token and will enter the shell as one
argument. Our task is to escape it correctly for embedding in an
argument string, our `$OPT_ARGS` string. It might be possible with
double quotes, though likely not. And as we have seen, it is a fragile
path to go down, especially once the string hits the `eval` function.

With single quotes we get `$OPT_ARGS` set to:

    ''\'''\''"lima?:$x'\''2\4 .'

and this becomes a single argument after `eval`, which echo prints
unquoted as:

    ''"lima?:$x'2\4 .

While all of this may still fail in some arbitrary old shell, it is a
best effort for now, and it does handle spaces and various
meta-characters, and as such it should fare better than both getopt and
most homegrown solutions, while handling long options, which getopts
does not, at least not in any portable fashion.

