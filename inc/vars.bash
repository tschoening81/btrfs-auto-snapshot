##
# Various different variables needed by most scripts.
#

[[ "${_SRC_GUARD_VARS:-0}" != '0' ]] && return 0
declare -r _SRC_GUARD_VARS='1'

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

            SCRIPT_PATH="$(readlink -f -n "${0}")"
declare -rx SCRIPT_PATH="${SCRIPT_PATH:?No script path calculated.}"
            SCRIPT_DIR="$(dirname "${SCRIPT_PATH}")"
declare -rx SCRIPT_DIR="${SCRIPT_DIR:?No script dir calculated.}"
            SCRIPT_DNAME="$(basename "${SCRIPT_DIR}")"
declare -rx SCRIPT_DNAME="${SCRIPT_DNAME:?No script dname calculated.}"
            SCRIPT_FNAME="$(basename "${SCRIPT_PATH}" '.sh')"
declare -rx SCRIPT_FNAME="${SCRIPT_FNAME:?No script fname calculated.}"

declare -rx ERR_SUCCESS=0
declare -rx ERR_ARG_WRONG_NAME=1
declare -rx ERR_ARG_WRONG_VALUE=2

# "log.level" influences if to generate messages at all, while e.g. "journalctl" is able to filter those based on the
#             associated priority on its own already. Not sure if our config is that useful, need to think about it.
# "snaps.path" stores newline seperated paths to make forwaridn ginto different functions easier!
declare -Ax ARGS=(
  ['help']='0'
  ['log.level']='info'
  ['log.prefix']='btrfs-auto-snap'
  ['snaps.dry-run']='0'
  ['snaps.keep']='1'
  ['snaps.label']='adhoc'
  ['snaps.writeable']='-r'
  ['snaps.paths']=''
  ['snaps.prefix']='btrfs-auto-snap'
)

declare -rax ARGS_SPEC=(
  'help'
  'log.level:' 'log.prefix:'
  'snaps.dry-run' 'snaps.keep:' 'snaps.label:' 'snaps.writable' 'snaps.paths:' 'snaps.prefix'
)

declare -rx SNAPS_DIR='.btrfs'
