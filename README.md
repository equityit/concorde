Message For You, Sir
====================

Bash scripting in my own particular...\[sigh\]...

Concorde: "Idiom, sir?"

Idiom!

Concorde is a small-ish library which distills some of the most useful
things I've done in bash.

Goals
=====

-   encourage development of reusable scripts and libraries

-   encourage testable code

-   encourage use of functions

-   encourage use of local variables and reduce dependence on globals;
    generally reduce namespace clutter

-   make arrays and hashes (associative arrays) friendlier

-   make debugging easier

-   make option parsing standard

-   reduce visual noise (quotes, braces, dollar-signs)

-   encourage patterns with some of the advantages of object-orientation

With this toolset, it is simple to create bash scripts which:

-   are more readable

-   can be developed in a test-driven manner

-   are able to receive and parse GNU-style options

-   automatically stop on unexpected errors and produce tracebacks

-   are easily refactorable into shared libraries of functions

Features
========

-   a GNU-style option parser

-   strict mode

-   ruby-style tracebacks

-   ruby-style require/load

-   namespace manipulation functions

-   string, array and hash utility functions

Prerequisites
=============

-   GNU readlink in your PATH, as `readlink`

-   `sed` in your PATH

Installation
============

Clone this repo or copy `lib/concorde.bash`. Make the location of
`concorde.bash` (e.g. `~/concorde/lib`) available in your PATH. Then use
`source concorde.bash` in your scripts.

Reserved Variables
==================

Concorde reserves the following global variables for its own use:

-   `__` - double-underscore, used for returning strings from functions

-   `__feature_hsh` - a hash for feature (i.e. library) meta-data

-   `__instance_hsh` - a hash for holding object-like data structures

Tutorial
========

Let's start with a simple script, developed in a test-driven fashion.

I use [shpec] and [entr] to run my tests. If you want to follow along,
install those first.

Basic Test-Driven Development with Bash
---------------------------------------

The script and shpec file start in the same directory. In one window I
fire up vim on `myscript_shpec.bash` and start with:

``` bash
source myscript

describe hello_world
  it "outputs 'Hello, world!'"
    result=$(hello_world)
    assert equal "Hello, world!" "$result"
  end
end
```

Don't worry about the shpec syntax for the moment. It's just regular
bash. Shpec tries to make itself look like ruby by providing ruby-like
function names as well as encouraging ruby-like indentation.  However,
bash doesn't care about the indentation.

Now I switch to editing `myscript`:

``` bash
#!/usr/bin/env bash
```

Now I save it.  In another window, I run:

``` bash
> echo myscript | entr bash -c 'shpec myscript_shpec.bash'
```

This will monitor the `myscript` file and re-run the test suite whenever
it changes.

I save `myscript` again and the test runs and fails. That's a good
thing, since it shows that the test isn't providing a false positive.

Now to add the function to `myscript`:

``` bash
#!/usr/bin/env bash

hello_world () {
  echo "Hello, world!"
}
```

I save and now the test suite passes. Our first green!

Doing More than Just Passing the Test
-------------------------------------

However, `myscript` isn't all that exciting. In fact, if you make it
executable and run it, it doesn't do anything!

``` bash
> chmod +x myscript
> ./myscript
>
```

That's because the `hello_world` function exists, but nothing's calling
it. So I call it:

``` bash
#!/usr/bin/env bash

hello_world () {
  echo "Hello, world!"
}

hello_world
```

Now it runs correctly:

``` bash
> ./myscript
Hello, world!
>
```

But something's wrong in the test window. Now the test shows passing,
but it also shows the "Hello, world!" output, which it's not supposed
to.

That's because the test is runs the script when it gets to its `source
myscript` line, and that causes *all* of the actions in the script to
occur. When testing, we just want to test the functions, not run the
script!

Treating the Same File as Both Script and Library
-------------------------------------------------

A script runs and accomplishes a task.  A library provides functions for
scripts but doesn't usually do anything itself.

Shpec needs to treat the script as a library however.  Can we have a
script that acts like a library too? (Spoiler: yes)

I'll add concorde and a call to one of its functions:

``` bash
#!/usr/bin/env bash

source concorde.bash

hello_world () {
  echo "Hello, world!"
}

sourced? && return

hello_world
```

Now the test runs and passes, but the output doesn't occur. That's
because `sourced?` detects that the script is being read with bash's
`source` command and not being run from the command line as a script.
(don't mind the question mark, it's part of the function's name)

The `return` stops the sourcing of the file there, so the interpreter
never reaches the line which calls `hello_world`. Instead, control is
returned to the shpec file.

If the script is being run from the command-line, however, the
`sourced?` call will return false and the script will continue to run
past that line, fulfilling the call to `hello_world`.

The implication for the structure of your scripts is that, for testing
purposes, you want all of the functions to be defined before calling any
of them.  Before you do call them, you want `sourced?` to intervene so
the test framework can short-circuit the script's actions.

Introducing Some Structure
--------------------------

Let's go back to the script. How about some refactoring, now that we've
got a function that we may want to use in other scripts as well?

First I'll stop the `entr` window with ctrl-c, since we'll be moving the
files anyway.

Then, I'll create a couple subdirectories; `lib` for a library we'll be
creating and `bin` for our script. I'll also make a `shpec` directory
for shpec files.

``` bash
> mkdir bin lib shpec
```

Here's `lib/hello_world.bash`:

``` bash
hello_world () {
  echo "Hello, world!"
}
```

And here's `bin/myscript`:

``` bash
#!/usr/bin/env bash

source concorde.bash
source hello_world.bash

sourced? && return

hello_world
```

We've split the source files, so now having two corresponding shpec
files makes sense.

`shpec/hello_world_shpec.bash`:

``` bash
source hello_world.bash

describe hello_world
  it "outputs 'Hello, world!'"
    result=$(hello_world)
    assert equal "Hello, world!" "$result"
  end
end
```

And `shpec/myscript_shpec.bash`:

``` bash
source myscript
```

Using "main"
------------

Hmm. There's nothing really to test for `myscript`, since it defines no
functions.  Perhaps we should change that by making a formal `main`
function which is responsible for taking the actions requested by the
user:

``` bash
#!/usr/bin/env bash

source concorde.bash
source hello_world.bash

main () {
  hello_world
}

sourced? && return

main "$@"
```

Now we could test `main` in `myscript_shpec.bash`, but I think we'll
hold off until it does something more than just call `hello_world`,
since we've already got that covered.

In a regular script, you might not choose to use functions at all,
instead just writing a list of commands that need to go together. That's
fine, but concorde won't help with that much. I'd encourage you to start
writing functions in order to make them testable.

Sourcing Features Correctly
---------------------------

I'm using the word "feature" here as a fancy name for a library, such as
our `hello_world` library.

First let's run one of the shpecs. I run:

``` bash
> cd lib
> shpec ../shpec/hello_world_shpec.bash
```

and see that the test runs correctly, as it does. Proud of my code, but
humble enough to know that you can never do enough testing, I decide to
run the test once more for good measure, changing directory first:

``` bash
> cd ..
> shpec shpec/hello_world_shpec.bash
shpec/hello_world_shpec.bash: line 1: hello_world.bash: No such file or directory
```

What? It failed?

Oh yeah, when `hello_world_shpec.bash` runs `source hello_world.bash`,
bash looks for `hello_world.bash` in the current directory, so the
current directory determines whether the test is able to run. Darn it.

I could just change the line to `source lib/hello_world.bash`, but then
the test would only work when I run the command from this directory and
I'd basically have the same problem.  I want it to work from anywhere.

I know, let's update `hello_world_shpec.bash`:

``` bash
source concorde.bash
$(require_relative ../lib/hello_world)

describe hello_world
[...]
```

From the project root, where I just was:

``` bash
> shpec shpec/hello_world_shpec.bash
```

Everything's happy again!

`require_relative` is a function which sources another file, but takes
the current directory out of the equation. It finds the sourced file
relative to the location of your file, not your shell's current
directory.

`require_relative` also doesn't require a file extension when you name
the file, if the file's extension is `.bash` or `.sh`. Hence the
`../lib/hello_world` above.  This borrows from ruby, where the library
is called a "feature" and is referred to by its name, without an
extension.

I'm sure you've noticed the process substitution around the call to
`require_relative`. (the "$()")  That's because it actually generates a
`source` statement on stdout, which is then executed in the context of
the caller.  If the `source` command were actually run by the
`require_relative` function itself, certain statements (such as
`declare`s) would not be evaluated properly.

When to Use "require_relative" vs "require"
-------------------------------------------

Looking back at `bin/myscript`, notice that we are sourcing
`hello_world.bash` there as well, but now we know that that will not
work.  If I decide to distribute `hello_world.bash` with `myscript`,
then I'll just use `require_relative` to load it.

However, if I intend to distribute `hello_world.bash` separately, I'll
install it on the PATH and just source it.  In that case, I could
instead use concorde's `require` instead of `source`. `require` does not
require a file extension, just like `require_relative`.

Otherwise `require` is pretty much the same as `source`, with one major
exception.  Unlike both `source` and ruby's `require`, concorde's
`require` doesn't search the local directory.  If you need to load a
file from the current directory, you'll need to provide an absolute or
relative path to either `require` or `require_relative`, respectively.

In this case, I'll choose `require_relative` for `myscript`:

``` bash
#!/usr/bin/env bash

source concorde.bash
$(require_relative ../lib/hello_world)

main () {
  hello_world
}

sourced? && return

main "$@"
```

"require" and "feature"
-----------------------

`require` and company will source a file without needing the file
extension.  In ruby (but not concorde), `require` also makes sure that a
feature loaded this way doesn't get executed more than once, since it
may be `require`d more than once in a given project.  If it gets
`require`d again, ruby simply returns instead of loading it again.

Recognizing the fact that users may use `source` instead of concorde's
`require`, concorde provides a different function to ensure that
features aren't reloaded.  Adding `feature` to your library will prevent
reloads, whether the library is `source`d or `require`d.

I'll update `hello_world.bash` as an example:

``` bash
source concorde.bash
$(feature hello_world)

hello_world () {
  echo "Hello, world!"
}
```

This is actually already useful for our example, since now concorde is
loaded in two places: `myscript` and `hello_world.bash`.  Concorde uses
its own `feature` capability to ensure it is only loaded once.

More importantly, it's possible for a project to grow complex enough
that the files which source each other could go around in a circle,
which would cause an infinite loop when you try to run it.  `feature`
prevents such a loop from occurring by stopping when it sees that a
feature is already loaded.

Reloading with "load"
---------------------

Ruby also provides a `load` function, which forces the loading of the
file, even if the file has already been loaded.  Unlike `require`, it
needs the full name of the file, including extension.  If you need to
force the reload of a feature, for example during development, you can
use concorde's `load` function just like ruby's.

Command-line Parsing
--------------------

Let's get back to coding.

Now I want to add some command-line parsing to `myscript`.  I'm going to
add an argument which allows me specify the name I'd like the script to
say hello to.

I fire up entr again:

``` bash
> echo lib/hello_world.bash | entr bash -c 'shpec shpec/hello_world.bash'
```

First I'll allow `hello_world` to say a name, if provided.

`shpec/hello_world_shpec.bash`:

``` bash
[...]

describe hello_world
  it "outputs 'Hello, world!' if no argument"
    result=$(hello_world)
    assert equal "Hello, world!" "$result"
  end

  it "outputs 'Hello, [arg]!' if an argument"
    result=$(hello_world name)
    assert equal "Hello, name!" "$result"
  end
end
```

I save `lib/hello_world.bash` to trigger shpec, which fails on the
second test.  Good.

`lib/hello_world.bash`:

``` bash
[...]

hello_world () {
  local name=${1:-world}

  echo "Hello, $name!"
}
```

I save and this time the test passes.  Now I'll modify `myscript` to
accept a name.

This time, I'll write tests for `main`.

`shpec/myscript_shpec.bash`:

``` bash
source concorde.bash
$(require_relative ../bin/myscript)

describe main
  it "outputs 'Hello, world!' if no name option"
    result=$(main)
    assert equal "Hello, world!" "$result"
  end

  it "outputs 'Hello, [arg]!' if an option"
    result=$(main name)
    assert equal "Hello, name!" "$result"
  end
end
```

In this test, I'm expecting `main` to get a positional argument with the
name.

`bin/myscript`:

``` bash
[...]

main () {
  hello_world "${1:-}"
}

[...]
```

Save and we see that it works.

However, a positional argument isn't really an option, it's an argument.
I'd like to use a short option of `-n` and a long option of `--name`
instead.

I'll be using concorde's option parser, which means I'll need to know a
bit about how it provides options to main.

First, I'll be calling the parser before I call `main`.  I'll provide it
with the relevant information about the options I'm defining, as well as
the positional arguments fed to the script so it can parse them.

The option parser is the function `parse_options`.  It wants an array of
option definitions, where the option definitions themselves are an array
of fields.

The fields are short option, long option, argument name (if desired) and
help.  Short or long can be omitted so long long as at least one of them
is defined.  Argument name is only used if we are storing a provided
followup value, as opposed to just defining a true/false flag.  Finally,
help is there to remind us what the option is supposed to be, although
it's not currently used for anything else.

If we were just defining an array, our option would look something like:

``` bash
option=(-n --name name 'a name to say hello to')
```

However, the option parser needs to take multiple such definitions,
themselves stored in an array.  Unfortunately, bash can only store
strings in array values, not other arrays.

Here's where we get to one of those idioms for which concorde is named.

API
===

Internal-use functions, of which there are but a couple, start with an
underscore. The rest form the public API.

Names which appear to be a little esoteric were typically chosen that
way in order to avoid conflicts with similarly-named programs that you
might find on a system. For example, `wed` instead of the more standard
`join` for arrays.

Some functions incorporate data types in their names when they deal with
such types, such as:

-   `ary`: arrays
-   `str`: strings
-   `hsh`: hashes (associative arrays)

Functions which return string values (which are almost all of them) do
so in the global variable `__` (double-underscore). This is very
important to understand since it is used everywhere. Additionally, this
means that, like `$?`, you can't rely on its value remaining the same
after you call another function. Hence you need to save `__` off to
another variable if you intend to make more use of its value.

A reference is simply a string variable which happens to hold either the
name of another string variable or the name and index of an item in an
array or hash (e.g. `my_hash[key]`). Only references to the variable
`__instanceh` or the names of array or hash variables may be passed to
functions written in concorde's idiom. Other uses of references may
result in namespace clashes.

All parameters designated as "\_array" or "\_hash" in function
signatures described below actually require the literal representation
of the array or hash as a string, e.g. "(three item list)" or
"(\[key\]=value \[pairs\]="")", since bash can't pass actual arrays or
hashes. If you already have such a literal stored in a variable, the API
usually allows you to pass the un-expanded variable name (no dollar
sign) instead and the value will be automatically extrapolated.

The usual way to obtain such a literal from an active array or hash is
via `repr` (short for "representation", a la Python):

``` bash
repr my_array
function_requiring_an_array_literal "$__"
```

Usually the above function would take the reference `__` as a valid
alternative for `$__`.

Option Parsing
--------------

-   **`parse_options`** *`definitions_array`* - creates a new instance
    of an options data structure

*Returns*: a reference to the option data structure

-   **`options_parse`** *`options_ref [options]`* - parses a list of
    options provided as-is from the command-line (i.e. "$@")

    Options definitions are in the form of an array literal, with each
    item containing a sub-array (literal) of four elements:

    -   *short option* (including hyphen) - may be omitted (with `''` in
        its place) if *long option* is defined

    -   *long option* (including double-hyphen) - may be omitted (with
        `''` in its place) if *short option* is defined

    -   *argument name* - if the option takes an argument, the name of
        the variable in which to store the value.

    -   if omitted with '' in its place, the option becomes a flag with
        the name `flag_[option]`, where \[option\] is the long name, if
        available, otherwise the short name. It receives either the
        value 1 if the flag is supplied, or does not exist if it wasn't

    -   *help string* - currently unused but can still be a useful
        reminder

    *definitions\_array* is usually supplied via `get_here_str`.
    Example:

``` bash
get_here_str <<'EOS'
  ( -o --option1            ''      'a flag'  )
  ( '' --option2 argument_name 'an argument'  )
EOS

options_new __
```

  [shpec]: https://github.com/rylnd/shpec
  [entr]: http://entrproject.org/
