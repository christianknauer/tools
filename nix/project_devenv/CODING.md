# Coding conventions

This document describes a few coding conventions for execline scripts.

## Command abbreviations

We use some "prepocessor" definitions/substitutions to abbreviate some execline commands.
The following code is used very early (after env manipulating commands, such as `getcwd`:

```bash
multisubstitute {
  multidefine -d : "foreground:background" { fg bg }
  ...
}
```

## Variable names

 - names of env vars start with an underscore, e.g.,

```bash
getcwd _fcwd 
```

- names of non-env vars do not start with an underscore, e.g.,

```bash
importas -ui fcwd _fcwd
```

## Substitutions

We try to minimize (costly) substitutions by collecting them  in (few) `multisubstitute` commands:

```bash
getcwd _fcwd 

multisubstitute {
  multidefine -d : "foreground:background" { fg bg }
  importas -ui fcwd _fcwd
}

backtick { basename ${fcwd} }

multisubstitute {
  importas -ui cwd _cwd
}
```

## Positional parameters

Whenever we only have to substitute the positional parameters, and don't need to go 
through the whole `elgetpositionals` and `emptyenv` chain we use the `-S` option of `execlineb`.
Specifically, from most efficient (but less flexible) to least efficient (but more flexible) [see](https://skarnet.org/software/execline/el_pushenv.html), we

- use `execlineb -P` if wo don't need positional parameters at all,
- use `execlineb -Sn` if we need only simple positional parameter substitution,
- use `execlineb -p`, then elgetpositionals if we don't mind overwriting the current stack of positional parameters, and
- use `execlineb`, then `elgetpositionals`, then `emptyenv -P` if we need the full power of positional parameter handling.
