#!/usr/bin/env zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/mkcd.zsh"

fail() {
  print -u2 -- "FAIL: $*"
  exit 1
}

assert_dir() {
  local d="$1"
  [[ -d "$d" ]] || fail "expected directory to exist: $d"
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  [[ "$actual" == "$expected" ]] || fail "expected '$expected' but got '$actual'"
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
cd "$tmp_dir"

# Test 1: create all combinations, default to first branch at each brace level.
mkcd 'test/{a,b}/x/{y,z}'
assert_dir "$tmp_dir/test/a/x/y"
assert_dir "$tmp_dir/test/a/x/z"
assert_dir "$tmp_dir/test/b/x/y"
assert_dir "$tmp_dir/test/b/x/z"
assert_eq "$PWD" "$tmp_dir/test/a/x/y"

# Test 2: create all combinations and cd using explicit indexes.
cd "$tmp_dir"
mkcd 'test2/{a,b}/x/{y,z}' '2,1'
assert_dir "$tmp_dir/test2/a/x/y"
assert_dir "$tmp_dir/test2/a/x/z"
assert_dir "$tmp_dir/test2/b/x/y"
assert_dir "$tmp_dir/test2/b/x/z"
assert_eq "$PWD" "$tmp_dir/test2/b/x/y"

# Test 3: escaped spaces in brace options.
cd "$tmp_dir"
mkcd 'hi/{hello,other\ greets,welcome}/Truty/{yes,no}' '2,2'
assert_dir "$tmp_dir/hi/other greets/Truty/yes"
assert_dir "$tmp_dir/hi/other greets/Truty/no"
assert_eq "$PWD" "$tmp_dir/hi/other greets/Truty/no"

# Test 4: invalid index returns non-zero.
cd "$tmp_dir"
if mkcd 'bad/{a,b}' '3' >/dev/null 2>&1; then
  fail "mkcd should fail for out-of-range index"
fi

# Test 5: too many indexes returns non-zero.
if mkcd 'bad2/{a,b}' '1,2' >/dev/null 2>&1; then
  fail "mkcd should fail for extra indexes"
fi

# Test 6: unquoted brace input works (shell-expanded args).
cd "$tmp_dir"
mkcd test3/{a,b}/x/{y,z}
assert_dir "$tmp_dir/test3/a/x/y"
assert_dir "$tmp_dir/test3/a/x/z"
assert_dir "$tmp_dir/test3/b/x/y"
assert_dir "$tmp_dir/test3/b/x/z"
assert_eq "$PWD" "$tmp_dir/test3/a/x/y"

# Test 7: unquoted brace input with indexes works.
cd "$tmp_dir"
mkcd test4/{a,b}/x/{y,z} 2,2
assert_dir "$tmp_dir/test4/a/x/y"
assert_dir "$tmp_dir/test4/a/x/z"
assert_dir "$tmp_dir/test4/b/x/y"
assert_dir "$tmp_dir/test4/b/x/z"
assert_eq "$PWD" "$tmp_dir/test4/b/x/z"

# Test 8: empty first index token defaults to 1.
cd "$tmp_dir"
mkcd test5/{a,b}/ok/{first,second} ,1
assert_eq "$PWD" "$tmp_dir/test5/a/ok/first"

# Test 9: 0 index token defaults to 1 (including split form: "0," "2").
cd "$tmp_dir"
mkcd test6/{a,b}/ok/{first,second} 0, 2
assert_eq "$PWD" "$tmp_dir/test6/a/ok/second"

# Test 10: trailing dot suffix applies after index selection.
cd "$tmp_dir"
mkcd test7/{a,b}/ok/{first,second} 2,1 ..
assert_eq "$PWD" "$tmp_dir/test7/b/ok"

# Test 11: trailing dot suffix works without an index spec.
cd "$tmp_dir"
mkcd test8/{a,b}/ok/{first,second} ..
assert_eq "$PWD" "$tmp_dir/test8/a/ok"

# Test 12: adjacent brace groups in a single segment expand as a cartesian product.
cd "$tmp_dir"
mkcd 'adj/{a,b}{1,2}'
assert_dir "$tmp_dir/adj/a1"
assert_dir "$tmp_dir/adj/a2"
assert_dir "$tmp_dir/adj/b1"
assert_dir "$tmp_dir/adj/b2"
assert_eq "$PWD" "$tmp_dir/adj/a1"

# Test 13: mid-segment braces expand instead of creating a literal dir.
cd "$tmp_dir"
mkcd 'mid/pre{a,b}'
assert_dir "$tmp_dir/mid/prea"
assert_dir "$tmp_dir/mid/preb"
assert_eq "$PWD" "$tmp_dir/mid/prea"

# Test 14: index selection applies to adjacent-group cartesian options.
cd "$tmp_dir"
mkcd 'lvl/{a,b}{1,2}' 3
assert_eq "$PWD" "$tmp_dir/lvl/b1"

# Test 15: escaped comma inside a brace group is a literal comma in the name.
cd "$tmp_dir"
mkcd 'esc/{a\,b,c}'
assert_dir "$tmp_dir/esc/a,b"
assert_dir "$tmp_dir/esc/c"
assert_eq "$PWD" "$tmp_dir/esc/a,b"

# Test 16: absolute path input works.
cd "$tmp_dir"
mkcd "$tmp_dir/abs/{a,b}"
assert_dir "$tmp_dir/abs/a"
assert_dir "$tmp_dir/abs/b"
assert_eq "$PWD" "$tmp_dir/abs/a"

# Test 17: multi-level dot suffix applies after index selection.
cd "$tmp_dir"
mkcd 'multi/{a,b}/x/{y,z}' 2,2 ../..
assert_eq "$PWD" "$tmp_dir/multi/b"

# Test 18: plain single-directory mkcd.
cd "$tmp_dir"
mkcd plaindir
assert_dir "$tmp_dir/plaindir"
assert_eq "$PWD" "$tmp_dir/plaindir"

# Test 19: split-form index spec (trailing number as a separate arg).
cd "$tmp_dir"
mkcd 'split/{a,b}/ok/{first,second}' 1, 2
assert_eq "$PWD" "$tmp_dir/split/a/ok/second"

print -- "All mkcd tests passed."
