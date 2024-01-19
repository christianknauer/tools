# restic

# ----------------------------------------------------------------
# variant 1 (restriced key access)

# this allows *only one repo* (here located in "./repo1") at the
# remote, since the repo path is never constructed for rclone by restic
# (the rclone command given to "ssh" can actually be anything)

# > restic -o rclone.program="ssh hsb-restic-repo1-ao rclone" -r rclone:repo1 init

# authorized_keys of hsb-sub contains
#restrict,command="rclone serve restic --stdio --config=/dev/null --append-only --verbose ./repo1",no-port-forwarding,no-X11-forwarding,no-pty,no-agent-forwarding,no-user-rc ssh-...

# CAVE: in that case the "repo2" part of the following repository path is ignored
# > restic -o rclone.program="ssh hsb-restic-repo1-ao forced-command" -r rclone:repo2 snapshots
# i.e., the command actually works on the repo1 repository

# ----------------------------------------------------------------
# variant 2 (full key access)
# this is the generic solution 
# pros: 
#  - arbitrary repos per remote/key 
# cons: 
#  - cannot enforce restic dir (solution: use hsb sub-account only for restic)
#  - cannot enforce append-only mode via ssh

# authorized_keys only contains the key

export RESTIC_PASSWORD='x'

pushd /tmp

touch I_AM_IN_REPO1 I_AM_IN_REPO2

# full key access
# "--append-only" is voluntary
restic -o rclone.program="ssh hsb-restic rclone" \
       -o rclone.args="serve restic --stdio --append-only --config=/dev/null --verbose" \
       -r rclone:repo1 \
       init 

# full key access 
# "--append-only" is missing
restic -o rclone.program="ssh hsb-restic rclone" \
       -o rclone.args="serve restic --stdio --config=/dev/null --verbose" \
       -r rclone:repo2 \
       init 

# limited key access 
# "--append-only" is forced (by ssh)
# NOTE: "ssh ... ANYTHING" also works instead of "ssh ... rclone" (rclone is forced by ssh) 
# NOTE: "-r rclone:" also works instead of "-r rclone:repo1" (repo1 is force by ssh)
restic -o rclone.program="ssh hsb-restic-repo1-ao rclone" \
       -r rclone:repo1 \
       backup I_AM_IN_REPO1

# full key access 
restic -o rclone.program="ssh hsb-restic rclone" \
       -o rclone.args="serve restic --stdio --append-only --config=/dev/null --verbose" \
       -r rclone:repo2 \
       backup I_AM_IN_REPO2

# full key access 
restic -o rclone.program="ssh hsb-restic rclone" \
       -o rclone.args="serve restic --stdio --config=/dev/null --verbose" \
       -r rclone:repo1 \
       snapshots

# full key access 
restic -o rclone.program="ssh hsb-restic rclone" \
       -o rclone.args="serve restic --stdio --config=/dev/null --verbose" \
       -r rclone:repo2 \
       snapshots

rm -f I_AM_IN_REPO1 I_AM_IN_REPO2

popd

# get repos via rsync:
rsync --progress --delete --recursive hsb-restic:repo1 repos/
rsync --progress --delete --recursive hsb-restic:repo2 repos/

# CAVE: ssh key restriction does not work on hsb
#restrict,command="rsync ",no-pty,no-agent-forwarding,no-port-forwarding ssh-ed25519 ...

# EOF
