##
# Create and destroy snapshots.
#

[[ "${_SRC_GUARD_SNAPS:-0}" != '0' ]] && return 0
declare -r _SRC_GUARD_SNAPS='1'

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

# shellcheck source=SCRIPTDIR/vars.bash
source "$(dirname "${BASH_SOURCE[0]}" | xargs -d'\n' readlink -f -n | xargs -d'\n' printf '%s/vars.bash' || true)"

declare -r SNAPS_DIR='.btrfs'

##
# @param[in] {@code do} to calculate a timestamp or {@code rm} to create a pattern to match against.
# @return E.g. {@code btrfs-auto-snap_adhoc_20260308T191320} or {@code foobar}, depending on the configured name format.
#
snaps::_calc_dir_name() {
  local -r arg_for="${1:?No purpose given.}"
  local    snap_date

  if [[ "${arg_for}" == 'do' ]]; then
             snap_date="$(date '+%Y%m%dT%H%M%S')"
    local -r snap_date="${snap_date:?No snapshot date calculated.}"
  else
    local -r snap_date='[[:digit:]]{4}-?[[:digit:]]{2}-?[[:digit:]]{2}[-T][[:digit:]]{4,6}'
  fi

  local    snap_name
           # shellcheck disable=SC2059
           snap_name="$(printf "${ARGS['snaps.name-fmt']}" "${ARGS['snaps.label']}" "${snap_date}")"
  local -r snap_name="${snap_name:?No snap directory name calculated.}"

  printf '%s' "${snap_name}"
}

##
# Either excute or only log the given command, depending on the current {@code dry-run}-settings.
#
snaps::_exec_if() {
  if [[ "${ARGS['snaps.dry-run']}" -eq 1 ]]; then
    log::dry_run "${@}"
    return "${ERR_SUCCESS}"
  fi

  "${@}"
}

##
# @param[in] Newline delimited string of individual paths to process.
#
snaps::do() {
  local -r arg_paths="${1:?No paths given.}"
  local    snap_name
           snap_name="$(snaps::_calc_dir_name 'do')"
  local -r snap_name="${snap_name:?No snap directory name calculated.}"

  local arg_path
  while IFS='' read -r arg_path; do
    local    snaps_dir="${arg_path%/}/${SNAPS_DIR}"
    local    snap_dir="${snaps_dir}/${snap_name}"
    local -a opts=("${ARGS[snaps.writeable]}" "${arg_path}" "${snap_dir}")

    log::info "Creating snapshot: '${snap_dir}'"

    # By design, only the parent dir for all snaps might be missing, if at all. So don't use "-p" here to not hide some
    # unexpected problems.
    [[ ! -d "${snaps_dir}" ]] && mkdir "${snaps_dir}"

    # Creating snapshots too frequently might result in overlapping directory names, which either results in errors for
    # read-only file systems or new subdirs created in existing snapshot dirs. The latter is a problem, because those
    # dirs prevent deletion of snapshots, as they contain non-snap data. The following is a workaround for those cases
    # especially making tests easier. Though, the same problem might occur because of changes to daylight saving time,
    # which results in the same snap names getting calculated twice.
    # shellcheck disable=SC2310
    snaps::_exec_if btrfs subvolume delete -c "${snap_dir}" 2>'/dev/null' || true
    snaps::_exec_if btrfs subvolume snapshot  "${opts[@]}"
  done <<< "${arg_paths}"
}

##
# @param[in] Newline delimited string of individual paths to process.
#
snaps::rm() {
  local -r arg_paths="${1:?No paths given.}"
  local -r snaps_keep="${ARGS['snaps.keep']}"
  local    snap_name
           snap_name="$(snaps::_calc_dir_name 'rm')"
  local -r snap_name="${snap_name:?No snap directory name calculated.}"

  log::info "Destroying all but the newest ${snaps_keep} snapshots."

  local arg_path
  while IFS= read -r arg_path; do
    local snaps_orig
    local snaps_proc

    # We are only interested in snaps this time, which follow a special naming scheme. This makes it easy to ignore all
    # subvolumes being children of the current path for some reason and therefore present in the output. We either don't
    # care about those or handle them anyway as part of posibly additional paths to process. The args used for "list"
    # make sure that we only get snaps for the subvolume of intrest and no others, so it's somewhat safe to remove based
    # on conventions.
    snaps_orig="$(btrfs subvolume list -g -o -s --sort=gen "${arg_path}")"
    snaps_proc="$(echo "${snaps_orig}" | sort -r -n -k 4 | awk '{print $NF}')"
    snaps_proc="$(echo "${snaps_proc}" | sed  -r "\#/?${SNAPS_DIR}/#!d")"
    snaps_proc="$(echo "${snaps_proc}" | sed  -r "s!^(.+/)?${SNAPS_DIR}/!${arg_path}/${SNAPS_DIR}/!")"
    snaps_proc="$(echo "${snaps_proc}" | sed  -r "s!^//${SNAPS_DIR}/!/${SNAPS_DIR}/!")"
    snaps_proc="$(echo "${snaps_proc}" | sed  -r "\#/${SNAPS_DIR}/${snap_name}#!d")"
    snaps_proc="$(echo "${snaps_proc}" | tail -n "+$((snaps_keep + 1))")"

    local snap_proc
    while IFS='' read -r snap_proc; do
        [[ -z "${snap_proc}" ]] && continue

        log::info "Destroying snapshot: '${snap_proc}'"
        snaps::_exec_if btrfs subvolume delete -c "${snap_proc}"
    done <<<"${snaps_proc}"
  done <<< "${arg_paths}"
}
