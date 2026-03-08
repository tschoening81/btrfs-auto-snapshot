##
# Utilities regarding path handling.
#

[[ "${_SRC_GUARD_PATHS:-0}" != '0' ]] && return 0
declare -r _SRC_GUARD_PATHS='1'

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

##
# Validate the given path to make sense to be given as commandline arguments.
#
# * {@code //} and some explicitly given paths must not be mixed.
# * Given explicit paths need to exist.
#
# @param[in] Callers need to forward each individual path as individual argument.
# @return    A newline seperated vewrison of the given paths, if they are valid.
#
paths::validate_as_args() {
  for path in "${@}"; do
    if [[ "${path}" == '//' ]] && [[ "${#}" -ne 1 ]]; then
      log::error "'${path}' must not be mixed with explicit given ones."
      exit "${ERR_ARG_WRONG_VALUE}"
    fi

    if [[ "${path}" != '//' ]] && [[ ! -d "${path}" ]]; then
      log::error "Given path doesn't exist: '${path}'"
      exit "${ERR_ARG_WRONG_VALUE}"
    fi
  done

  printf '%s\n' "${@}"
}
