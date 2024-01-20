# Coding conventions

This document describes a few coding conventions for execline scripts.

## Command abbreviations

We use some "prepocessor" definitions/substitutions to abbreviate some execline commands.
The following code is used very early (after env manipulating commands, such as `getcwd`:

```bash
multisubstitute
     {
       multidefine -d : "foreground:background:pipeline:backtick" { fg bg pipe bt }
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

multisubstitute
     {
       multidefine -d : "foreground:background:pipeline:backtick" { fg bg pipe bt }
       importas -ui fcwd _fcwd
     }

$bt _cwd    { basename ${fcwd} }

multisubstitute
     {
       importas -ui cwd _cwd
     }
```
