# Ideas

* dry_run
    * exec read-only operations always, only writes need to be wrapped
        * bash::exec_rw_if?
        * if dry_run, log as DEBUG/INFO/..., without taking log-level at shell into account
* logging
    * log-level+log-prefix
    * log-level works like log4j2 -> DEBUG(100) + INFO(200) + ERROR(300) -> DEBUG <= ...
    * Generic implementation?
    * document somewhere that thorugh internal debugging can easily be done with bash -x
* argsp commandline parser
    * don't return in hash to make requirements and calls easier
    * introduce ARG_-vars and set those from parser
    * remove trap+kill in favour of errexit and returning non-0
* use multi-line strings instead of array with EVAL etc. -> easier to handle/debug/write
* calc all subvols ONLY when // is given
    * don't check individual given paths against calced subvols, because of possible errors -> users know best
    * improves performance as well
    * //-case needs to forward to processing of one path
* README.md
    * Describe rewrite and reasons for reduces?
    * before merging into master, create a branch keeping it for lookup-reasons, e.g. master-2.x or ...
    * Create PR upstream? -> possibly not because of code style etc.
* Remove Github-Templates?

# Issues to address?

* relative paths
    * https://github.com/hunleyd/btrfs-auto-snapshot/issues/15
