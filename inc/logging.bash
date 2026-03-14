##
# Some logging related helpers, basically just forwarding to {@code logger}.
#
# This slightly(!) mimics common log library approaches like SLF4j, Log4j2 etc., by giving the caller some methods to
# decide at which log level things should be logged at all and calls otherwise being no-ops. Though, depending on where
# {@code logger} sends to, one might be able to additionally filter based on log-levels there as well, e.g. using cmds
# like {@code journald -p 'err' -u 'btrfs-auto-snap'}. If more through debugging/tracing is needed, the easiest should
# be to use {@code bash -x} when invoking the script, so that we don't need to implement too much on our own.
#

[[ "${_SRC_GUARD_LOGGING:-0}" != '0' ]] && return 0
declare -r _SRC_GUARD_LOGGING='1'

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

# shellcheck source=SCRIPTDIR/vars.bash
source "$(dirname "${BASH_SOURCE[0]}" | xargs -d'\n' readlink -f -n | xargs -d'\n' printf '%s/vars.bash' || true)"

declare -rA LOG_LEVELS=(
  ['error']='40000'
  ['info']='20000'
  ['debug']='10000'
)

##
# @param[in] Log level of the caller to decide if to log at all.
# @param[in] Which value to forward as priority for {@code logger}.
# @param[in] All log messages forwarded by the caller using {@code ${@}}.
#
log::_impl() {
  local -r arg_level="${1:?No invocation log level given.}"
  local -r arg_prio="${2:?No logger priority given.}"

  # Method call args shouldn't be forwarded as part of the actual log message.
  shift ; shift

  local -r call_level_dec="${LOG_LEVELS["${arg_level}"]}"
  local -r cmd_level_dec="${LOG_LEVELS[${ARGS['log.level']}]}"

  [[ "${call_level_dec}" -lt "${cmd_level_dec}" ]] && return "${ERR_SUCCESS}"

  # "${*}" needs to be used, because "logger" expects one large message string only! "${@}" would create many individual
  # arguments instead if multiple would be given, each quoted properly, but that doesn't help us here.
  logger -t "${ARGS['log.prefix']}" -p "daemon.${arg_prio}" -- "${*}"
}

log::debug() {
  log::_impl 'debug' 'debug' "${@}"
}

##
# Print the entire given arguments as {@code debug} without checking any currently configured log level.
#
# This use-case seems to be special enough currently to have a custom method, while at the same time we don't need to
# check and porribly override log-levels configured at the commandline this way.
#
log::dry_run() {
  logger -t "${ARGS['log.prefix']}" -p "daemon.debug" -- "${*}"
}

log::info() {
  log::_impl 'info' 'info' "${@}"
}

log::error() {
  log::_impl 'error' 'err' "${@}"

  # Not sure currently if we want to entirely rely on "logger", and wherever it forwards to, or especially have errors
  # printed on STDERR as well. The latter might be useful e.g. in case excution is scheduled using CRON, as that might
  # send helpful mails in case of errors.
  printf '%s\n' "${*}" >&2
}

##
# @param[in] Log level from the command line.
# @return    Log level from the command line, IF(!) a valid value is given.
#
log::validate_level() {
  local -r arg_level="${1:?No log level given.}"

  # A lookup by key to check if the result is empty or not doesn't work, because it might result in "unbound variable".
  for level in "${!LOG_LEVELS[@]}"; do
    if [[ "${arg_level}" == "${level}" ]]; then
      printf '%s' "${arg_level}"
      return "${ERR_SUCCESS}"
    fi
  done

  log::error "Unsupported log-level: ${arg_level}"
  exit "${ERR_ARG_WRONG_VALUE}"
}
