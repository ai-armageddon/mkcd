# mkcd

`mkcd` creates brace-expanded directory trees and drops you into a selected branch.

## What It Does

Given:

```zsh
mkcd test/{test1,test2}/ok/{first,second}
```

it will:

1. Create all combinations:
   - `test/test1/ok/first`
   - `test/test1/ok/second`
   - `test/test2/ok/first`
   - `test/test2/ok/second`
2. `cd` into the selected path (default first option at each brace level).

## Features

- Works with quoted and unquoted brace paths
- 1-based index selection per brace level (`2,1`)
- Empty or `0` index means default (`1`)
  - `,1`
  - `0,2`
  - `0, 2`
- Optional trailing dot suffix to step up from selected path
  - `..`
  - `../..`

## Requirements

- `zsh`
- `mkdir` (standard on macOS/Linux)

## Install (macOS + Linux)

From repo root:

```bash
./install.sh
```

Then reload your shell:

```bash
source ~/.zshrc
# or source ~/.bashrc / ~/.bash_profile depending on your shell
```

### Installer options

```bash
./install.sh --shell zsh|bash
./install.sh --rc-file /path/to/rcfile
./install.sh --prefix /custom/install/dir
./install.sh --skip-rc
./install.sh --force
```

## Usage

### Basic

```zsh
mkcd test/{a,b}/x/{y,z}
# cd => test/a/x/y
```

### Indexed branch selection

```zsh
mkcd test/{a,b}/x/{y,z} 2,1
# cd => test/b/x/y
```

### Defaulting with empty/0 indexes

```zsh
mkcd test/{test1,test2}/ok/{first,second} ,1
# cd => test/test1/ok/first

mkcd test/{test1,test2}/ok/{first,second} 0, 2
# cd => test/test1/ok/second
```

### Dot suffix navigation

```zsh
mkcd test/{test1,test2}/ok/{first,second} 2,1 ..
# cd => test/test2/ok

mkcd test/{test1,test2}/ok/{first,second} ..
# cd => test/test1/ok
```

## Tests

Run:

```bash
zsh ./test_mkcd.zsh
```

Expected:

```text
All mkcd tests passed.
```

## Uninstall

1. Remove the source line from your shell rc file.
2. Delete the installed file (default):

```bash
rm -f "$HOME/.local/share/mkcd/mkcd.zsh"
```
