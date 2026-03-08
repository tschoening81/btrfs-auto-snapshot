##
# Parse commandline arguments and make them available as global hash.
#
# Storing things in a global hash makes it easier to access all arguments in all functions instead of forwarding some
# textual structures around, needing to parse those regularly etc.
#

[[ "${_SRC_GUARD_ARGS:-0}" != '0' ]] && return 0
declare -r _SRC_GUARD_ARGS='1'

# Callers might know better about error handling than we do. Though, we make tools like ShellCheck happy by having the
# options available individually as well. That doesn't know if a file is sourced or not and only looks at it as-is.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -o errexit
  set -o errtrace
  set -o functrace
  set -o nounset
  set -o pipefail
  #set -o xtrace
fi

# shellcheck source=SCRIPTDIR/logging.bash
source "$(dirname "${BASH_SOURCE[0]}" | xargs -d'\n' readlink -f -n | xargs -d'\n' printf '%s/logging.bash' || true)"

# shellcheck source=SCRIPTDIR/paths.bash
source "$(dirname "${BASH_SOURCE[0]}" | xargs -d'\n' readlink -f -n | xargs -d'\n' printf '%s/paths.bash' || true)"

# shellcheck source=SCRIPTDIR/vars.bash
source "$(dirname "${BASH_SOURCE[0]}" | xargs -d'\n' readlink -f -n | xargs -d'\n' printf '%s/vars.bash' || true)"

##
# Parse and store everything given at the commandline.
#
# @param[in] Callers need to forward {@code ${@}}!
#
args::parse() {
  local    parsed_str
           parsed_str="$(getopt --long "$(printf '%s,' "${ARGS_SPEC[@]}")" --options '' -- "${@}")"
  local -r parsed_str="${parsed_str:?Arguments couldn\'t be parsed.}"

  # "getopt" creates a long string with space-separated arguments and their values, while each individual part itself is
  # properly quoted. That data needs to be put into some sort of array, because when processing from start to end, the
  # value of some option needs to be read during the iteration step of that option as well. It's not as easy as using a
  # "readarray", because that doesn't take the quoting of individual arguments into account properly. Instead, we need
  # to build some sort of long commandline, which gets then "executed", because that command honours the quotes.
        local -a  parsed=()
  eval "local -ra parsed=(${parsed_str})"

  for (( i=0; i<"${#parsed[@]}"; ++i )); do
    local arg="${parsed[${i}]}"

    case "${arg}" in
        (--help)
            ARGS['help']='1'
        ;;
        (--log.level)
            ARGS['log.level']="$(log::validate_level "${parsed[(( ++i ))]}")"
            (( ++i )) # Former increment happens in subshell -> not visible here.
        ;;
        (--log.prefix)
            ARGS['log.prefix']="${parsed[(( ++i ))]}"
        ;;
        (--snaps.dry-run)
            ARGS['snaps.dry-run']='1'
        ;;
        (--snaps.keep)
            ARGS['snaps.keep']="${parsed[(( ++i ))]}"
        ;;
        (--snaps.label)
            ARGS['snaps.label']="${parsed[(( ++i ))]}"
        ;;
        (--snaps.writable)
            ARGS['snaps.writable']=''
        ;;
        (--snaps.prefix)
            ARGS['snaps.prefix']="${parsed[(( ++i ))]}"
        ;;
        (--)
            ARGS['snaps.paths']="$(paths::validate_as_args "${parsed[@]:(( ++i ))}")"
            break
        ;;
        (*)
          # "getopt" should have stopped with a corresponding error message already.
          log::error "Unexpected option: ${arg}"
          exit "${ERR_ARG_WRONG_NAME}"
    esac
  done
}

args::print_usage_and_exit_if() {
  if [[ "${ARGS[help]}" -eq 0 ]]; then
    return "${ERR_SUCCESS}"
  fi

  cat <<EOT
Usage: ${0} [options] -- <'//' | name [name...]>

--help                                 Print this usage message.
--log.level=info                       Level to use at runtime, with all log statements for lower levels being ignored.
--log.prefix=btrfs-auto-snap           Prefix to use when forwarding messages to "logger".
--snaps.dry-run=0                      If to execute writing BTRFS commands at all or only log them.
--snaps.keep=1                         How many snapshots to keep within the same label.
--snaps.label=                         Name to group all snapshots of the same kind, e.g. "hourly".
--snaps.name-fmt=btrfs-auto-snap_%s_%s Format string for snap directory names, with "%s" being replaced by the label and
                                       a calculated date time string at runtime.
--snaps.writeable=-r                   If to create read-only (-r) or writable (empty string) snapshots.
name                                   Paths to BTRFS subvolumes to snapshot or "//" for all of those.
EOT

  exit "${ERR_SUCCESS}"
}
