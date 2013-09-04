Installation
------------

`~/.gitconfig`:

    [merge "suse-changelog-merge"]
            name = SUSE .changes merge driver
            driver = /(wherever)/suse-changelog-merge %A %O %B

`~/.config/git/attributes`:

    *.changes       merge=suse-changelog-merge

Features and Limitations
------------------------

`suse-changelog-merge` takes 3 arguments: CURRENT, COMMON, OTHER
(like `merge(1)`)
and works by taking what was added between COMMON and OTHER,
and putting it on top of CURRENT.

Suppose the .changes in the master branch has

    -------------------------------------------------------------------
    Tue Sep  3 12:00:00 CEST 2013 - ada@example.com
    
    - Implemented the difference engine.
    
    -------------------------------------------------------------------
    Mon Sep  2 12:00:00 CEST 2013 - ada@example.com
    
    - Initial packaging.

Suppose we now branch `a-feature`, with

    Friday:    Implemented the differentiation engine.
    Tuesday:   Implemented the difference engine.
    Monday:    Initial packaging.

and in the meantime `master` becomes

    Wednesday: Implemented two ring machines.
    Tuesday:   Implemented the difference engine.
    Monday:    Initial packaging.

Merging `a-feature` into `master` will work just fine, producing
a chronological changelog:

    Friday:    Implemented the differentiation engine.
    Wednesday: Implemented two ring machines.
    Tuesday:   Implemented the difference engine.
    Monday:    Initial packaging.

However, merging `master` into `a-feature` will produce a conflict:

    <<<
    ===
    Wednesday: Implemented two ring machines.
    >>>
    Friday:    Implemented the differentiation engine.
    Tuesday:   Implemented the difference engine.
    Monday:    Initial packaging.

This is because the history up to Friday may have been already
published in an OBS instance that disallows inserting in the
middle of the changelog.

TODO, not implemented yet: we could adjust the Wednesday
timestamp to the current time automatically.
