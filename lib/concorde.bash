concorde.array () {
  concorde.xtrace_begin
  printf -v __ 'declare %s=( %s )' "${1%%=*}" "${1#*=}"
  concorde.emit "$__"
  concorde.xtrace_end
}

concorde.defined () {
  declare -p "${1%%[*}" >/dev/null 2>&1 && [[ -n ${!1+x} ]]
}

concorde.emit () {
  concorde.xtrace_begin
  printf 'eval eval %q' "$1"
  concorde.xtrace_end
}

concorde.escape_items () {
  concorde.xtrace_begin
  printf -v __ '%q ' "$@"
  __=${__% }
  concorde.xtrace_end
}

concorde.get () {
  concorde.xtrace_begin
  local space

  concorde.get_raw
  space=${__%%[^[:space:]]*}
  printf -v __ %s "${__#$space}"
  printf -v __ %s "${__//$'\n'$space/$'\n'}"
  concorde.xtrace_end
}

concorde.get_raw () {
  IFS=$'\n' read -rd '' __ ||:
}

concorde.grab () {
  concorde.xtrace_begin
  [[ $2 == from ]] || { concorde.raise ArgumentError return=0; return ;}
  $(concorde.array name_ary="$1")
  $(concorde.hash arg_hsh="$3"  )
  local IFS=$IFS
  local name
  local rc
  local statement_ary=()

  for name in "${name_ary[@]}"; do
    concorde.defined arg_hsh[$name] && rc=$? || rc=$?
    case $rc in
      0 ) printf -v __ 'declare %s=%q'                              "$name" "${arg_hsh[$name]}"   ;;
      * ) printf -v __ '! $(concorde.is_local %s) && declare %s=%q' "$name"  "$name" "${arg_hsh[$name]:-}" ;;
    esac
    statement_ary+=( "$__" )
  done
  statement_ary+=( : )
  IFS=$'\n'
  concorde.emit "${statement_ary[*]}"
  concorde.xtrace_end
}

concorde.grabkw () {
  concorde.xtrace_begin
  [[ $2 == from ]] || { concorde.raise ArgumentError return=0; return ;}
  { (( $# < 3 )) || [[ -z $3 ]] ;} && __='' || concorde.escape_items "${@:3}"
  concorde.grab "$1" from "$__"
  concorde.xtrace_end
}

concorde.hash () {
  concorde.xtrace_begin
  local name=${1%%=*}
  $(concorde.array value_ary="${1#*=}")
  local ary=()
  local item

  (( ! ${#value_ary[@]} )) && { concorde.emit "declare -A $name=()"; return ;}
  for item in "${value_ary[@]}"; do
    printf -v __ '[%s]=%q' "${item%%=*}" "${item#*=}"
    ary+=( "$__" )
  done
  concorde.emit "declare -A $name=( ${ary[*]} )"
  concorde.xtrace_end
}

concorde.hashkw () {
  concorde.xtrace_begin
  concorde.escape_items "$@"
  concorde.hash "$__"
  concorde.xtrace_end
}

concorde.is_local () {
  concorde.xtrace_begin
  concorde.get <<'  EOS'
    concorde.defined %s                        && \
      {
        (( ! ${#FUNCNAME[@]} ))       || \
          (
            declare -g %s=$'sigil\037'
            [[ $%s != $'sigil\037' ]] && \
              {
                unset -v %s
                ! concorde.defined %s
              }
          )
      }
  EOS
  printf -v __ "$__" "$1" "$1" "$1" "$1" "$1"
  concorde.emit "$__"
  concorde.xtrace_end
}

concorde.raise () {
  local rc=$?
  concorde.xtrace_begin
  local type=''
  local msg=''
  local return=1

  [[ -n ${1:-} && $1 != rc=?* && $1 != return=?* ]] && { type=$1; shift ;}
  [[ -n ${1:-} && $1 != rc=?* && $1 != return=?* ]] && { msg=$1 ; shift ;}
  while (( $# )); do
    case $1 in
      rc=*      ) rc=${1#rc=}         ;;
      return=*  ) return=${1#return=} ;;
    esac
    shift
  done
  [[ $rc == 113 && -z $type ]] && { concorde.emit 'return 113'; return ;}
  [[ -z $type ]] && type=StandardError
  concorde.get <<'  EOS'
    __errcode=%q
    __errmsg=%q
    __errtype=%q
  EOS
  __+=$'\n'
  case $return in
    0 ) __+='( exit 113 )';;
    * ) __+='return 113'  ;;
  esac
  printf -v __ "$__" "$rc" "$msg" "$type"
  concorde.emit "$__"
  concorde.xtrace_end
}

concorde.repr_hash () {
  concorde.xtrace_begin
  local __name=$1
  local __ary=()
  local __item
  local __var

  __=$(declare -p "$__name" 2>/dev/null)  || $(concorde.raise ArgumentError)
  [[ ${__:9:1} == A ]]                    || $(concorde.raise TypeError    )
  printf -v __ '(( ${#%s[@]} )) && set -- "${!%s[@]}" || { __=''; return ;}' "$__name" "$__name"
  eval "$__"
  for __item in "$@"; do
    __var=$__name[$__item]
    printf -v __ '%s=%q' "$__item" "${!__var}"
    __ary+=( "$__" )
  done
  __=${__ary[*]}
  concorde.xtrace_end
}

concorde.xtrace_begin () {
  (( ${__xtrace:-} )) && return;:
  [[ $- != *x* ]] && __xtrace_set=$? || __xtrace_set=$?
  set +o xtrace
}

concorde.xtrace_end () {
  (( ${__xtrace_set:-} )) && set -o xtrace;:
}
