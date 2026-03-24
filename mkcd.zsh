# mkcd: create brace-expanded directories and cd into a selected branch.
# Usage:
#   mkcd 'path/{a,b}/x/{y,z}'
#   mkcd 'path/{a,b}/x/{y,z}' '2,1'
#   mkcd path/{a,b}/x/{y,z}
#   mkcd path/{a,b}/x/{y,z} 2,1
#   mkcd path/{a,b}/x/{y,z} ,1
#   mkcd path/{a,b}/x/{y,z} 0, 2
#   mkcd path/{a,b}/x/{y,z} 2,1 ..
#   mkcd path/{a,b}/x/{y,z} ..

_mkcd_is_dot_suffix() {
  emulate -L zsh
  local candidate="$1"
  [[ "$candidate" =~ '^(\.\.?)(/\.\.?)*$' ]]
}

_mkcd_parse_picks() {
  emulate -L zsh
  setopt localoptions no_shwordsplit

  local spec="$1"
  reply=()

  [[ -z "$spec" ]] && return 0

  if [[ ! "$spec" =~ '^[0-9,[:space:]]+$' ]]; then
    print -u2 -- "mkcd: invalid index spec '$spec'"
    return 1
  fi

  local -a raw
  raw=(${(s:,:)spec})

  local tok
  for tok in "${raw[@]}"; do
    tok="${${tok##[[:space:]]#}%%[[:space:]]#}"

    if [[ -z "$tok" || "$tok" == 0 ]]; then
      # Empty or 0 means "use default (1)" for this level.
      reply+=("")
    elif [[ "$tok" == <-> ]]; then
      reply+=("$tok")
    else
      print -u2 -- "mkcd: invalid index '$tok' in spec '$spec'"
      return 1
    fi
  done

  # Ignore trailing defaults so specs like "2," don't count as extra indexes.
  while (( ${#reply} > 0 )) && [[ -z "${reply[-1]}" ]]; do
    reply[-1]=()
  done
}

_mkcd_apply_suffix() {
  emulate -L zsh

  local base="$1"
  local suffix="$2"

  if [[ -z "$suffix" ]]; then
    REPLY="$base"
    return 0
  fi

  if [[ "$base" == "/" ]]; then
    REPLY="/$suffix"
  elif [[ -z "$base" || "$base" == "." ]]; then
    REPLY="./$suffix"
  else
    REPLY="$base/$suffix"
  fi
}

_mkcd_from_pattern() {
  emulate -L zsh
  setopt localoptions no_shwordsplit

  local input_path="$1"
  local index_spec="${2-}"
  local cd_suffix="${3-}"

  local -a picks
  if ! _mkcd_parse_picks "$index_spec"; then
    return 1
  fi
  picks=("${reply[@]}")

  local -a parts
  parts=(${(s:/:)input_path})

  local is_absolute=0
  [[ "$input_path" == /* ]] && is_absolute=1

  local -a expanded_dirs next_dirs
  expanded_dirs=("")

  local brace_level=0
  local out_path=""
  local part inner idx selected_part
  local base opt i
  local -a options

  for part in "${parts[@]}"; do
    [[ -z "$part" ]] && continue

    selected_part="${(Q)part}"
    options=("$selected_part")

    if [[ "$part" == \{*\} ]]; then
      inner="${part#\{}"
      inner="${inner%\}}"
      options=(${(s:,:)inner})
      options=("${(@Q)options}")
      if (( ${#options} == 0 )); then
        print -u2 -- "mkcd: empty brace expression in segment '$part'"
        return 1
      fi

      (( brace_level += 1 ))
      idx=1
      if (( brace_level <= ${#picks} )) && [[ -n "${picks[brace_level]}" ]]; then
        idx=${picks[brace_level]}
      fi

      if (( idx < 1 || idx > ${#options} )); then
        print -u2 -- "mkcd: index $idx out of range at brace level $brace_level (1..${#options})"
        return 1
      fi

      selected_part="${options[idx]}"
    fi

    next_dirs=()
    for base in "${expanded_dirs[@]}"; do
      for opt in "${options[@]}"; do
        if [[ -z "$base" ]]; then
          next_dirs+=("$opt")
        else
          next_dirs+=("$base/$opt")
        fi
      done
    done
    expanded_dirs=("${next_dirs[@]}")

    if [[ -z "$out_path" ]]; then
      out_path="$selected_part"
    else
      out_path+="/$selected_part"
    fi
  done

  if (( ${#picks} > brace_level )); then
    print -u2 -- "mkcd: too many indexes provided (${#picks}); path has $brace_level brace levels"
    return 1
  fi

  if (( is_absolute )); then
    if [[ -z "$out_path" ]]; then
      out_path="/"
    else
      out_path="/${out_path}"
    fi

    for (( i = 1; i <= ${#expanded_dirs}; i++ )); do
      if [[ -z "${expanded_dirs[i]}" ]]; then
        expanded_dirs[i]="/"
      elif [[ "${expanded_dirs[i]}" != /* ]]; then
        expanded_dirs[i]="/${expanded_dirs[i]}"
      fi
    done
  fi

  if [[ -z "$out_path" ]]; then
    out_path="."
  fi

  if (( ${#expanded_dirs} == 0 )); then
    print -u2 -- "mkcd: no directories produced from path: $input_path"
    return 1
  fi

  command mkdir -p -- "${expanded_dirs[@]}" || return 1

  _mkcd_apply_suffix "$out_path" "$cd_suffix"
  builtin cd -- "$REPLY"
}

_mkcd_from_expanded() {
  emulate -L zsh
  setopt localoptions no_shwordsplit

  local index_spec="$1"
  local cd_suffix="$2"
  shift 2

  local -a expanded_dirs
  expanded_dirs=("$@")

  if (( ${#expanded_dirs} == 0 )); then
    print -u2 -- "usage: mkcd <path-with-braces> [indexes] [dot-suffix]"
    return 1
  fi

  command mkdir -p -- "${expanded_dirs[@]}" || return 1

  if [[ -z "$index_spec" ]]; then
    local out_path="${expanded_dirs[1]}"
    _mkcd_apply_suffix "$out_path" "$cd_suffix"
    builtin cd -- "$REPLY"
    return 0
  fi

  local -a picks
  if ! _mkcd_parse_picks "$index_spec"; then
    return 1
  fi
  picks=("${reply[@]}")

  local first_path="${expanded_dirs[1]}"
  local is_absolute=0
  [[ "$first_path" == /* ]] && is_absolute=1

  local -a raw_parts first_parts
  raw_parts=(${(s:/:)first_path})
  local seg
  first_parts=()
  for seg in "${raw_parts[@]}"; do
    [[ -z "$seg" ]] && continue
    first_parts+=("$seg")
  done

  local seg_count=${#first_parts}
  local -a varying_positions
  local -a path_parts unique_vals
  local -A seen_vals
  local p path_val pos

  for (( pos = 1; pos <= seg_count; pos++ )); do
    unique_vals=()
    seen_vals=()

    for p in "${expanded_dirs[@]}"; do
      raw_parts=(${(s:/:)p})
      path_parts=()
      for seg in "${raw_parts[@]}"; do
        [[ -z "$seg" ]] && continue
        path_parts+=("$seg")
      done

      if (( ${#path_parts} != seg_count )); then
        print -u2 -- "mkcd: cannot infer indexes from expanded input with inconsistent path depth"
        return 1
      fi

      path_val="${path_parts[pos]}"
      if [[ -z "${seen_vals[$path_val]-}" ]]; then
        unique_vals+=("$path_val")
        seen_vals[$path_val]=1
      fi
    done

    if (( ${#unique_vals} > 1 )); then
      varying_positions+=("$pos")
    fi
  done

  if (( ${#picks} > ${#varying_positions} )); then
    print -u2 -- "mkcd: too many indexes provided (${#picks}); path has ${#varying_positions} varying levels"
    return 1
  fi

  local level=0 idx
  for pos in "${varying_positions[@]}"; do
    (( level += 1 ))
    unique_vals=()
    seen_vals=()

    for p in "${expanded_dirs[@]}"; do
      raw_parts=(${(s:/:)p})
      path_parts=()
      for seg in "${raw_parts[@]}"; do
        [[ -z "$seg" ]] && continue
        path_parts+=("$seg")
      done

      path_val="${path_parts[pos]}"
      if [[ -z "${seen_vals[$path_val]-}" ]]; then
        unique_vals+=("$path_val")
        seen_vals[$path_val]=1
      fi
    done

    idx=1
    if (( level <= ${#picks} )) && [[ -n "${picks[level]}" ]]; then
      idx=${picks[level]}
    fi

    if (( idx < 1 || idx > ${#unique_vals} )); then
      print -u2 -- "mkcd: index $idx out of range at varying level $level (1..${#unique_vals})"
      return 1
    fi

    first_parts[pos]="${unique_vals[idx]}"
  done

  local out_path="${(j:/:)first_parts}"
  if (( is_absolute )); then
    out_path="/${out_path}"
  fi
  if [[ -z "$out_path" ]]; then
    out_path="."
  fi

  _mkcd_apply_suffix "$out_path" "$cd_suffix"
  builtin cd -- "$REPLY"
}

mkcd() {
  emulate -L zsh
  setopt localoptions no_shwordsplit

  if (( $# == 0 )); then
    print -u2 -- "usage: mkcd <path-with-braces> [indexes] [dot-suffix]"
    return 1
  fi

  local -a args
  args=("$@")

  local cd_suffix=""
  if (( ${#args} > 0 )) && _mkcd_is_dot_suffix "${args[-1]}"; then
    cd_suffix="${args[-1]}"
    args[-1]=()
  fi

  if (( ${#args} == 0 )); then
    print -u2 -- "usage: mkcd <path-with-braces> [indexes] [dot-suffix]"
    return 1
  fi

  # Quoted/literal brace path mode.
  if [[ "${args[1]}" == *\{*\}* ]]; then
    local input_path="${args[1]}"
    args[1]=()

    # Join remaining args with no separator, so "0," "2" becomes "0,2".
    local index_spec="${(j::)args}"
    _mkcd_from_pattern "$input_path" "$index_spec" "$cd_suffix"
    return $?
  fi

  # Unquoted mode: shell already expanded braces into multiple path args.
  local index_spec=""
  local -a expanded_dirs
  expanded_dirs=("${args[@]}")

  # Parse tail index specs like "2,1", ",1", "0,2", or split form "0," "2".
  if (( ${#expanded_dirs} > 1 )) && [[ "${expanded_dirs[-1]}" == *,* ]]; then
    index_spec="${expanded_dirs[-1]}"
    expanded_dirs[-1]=()
  elif (( ${#expanded_dirs} > 2 )) \
    && [[ "${expanded_dirs[-2]}" == *,* ]] \
    && [[ "${expanded_dirs[-1]}" =~ '^[[:space:]]*[0-9]+[[:space:]]*$' ]]; then
    index_spec="${expanded_dirs[-2]}${expanded_dirs[-1]}"
    expanded_dirs[-1]=()
    expanded_dirs[-1]=()
  fi

  _mkcd_from_expanded "$index_spec" "$cd_suffix" "${expanded_dirs[@]}"
}
