# backup to hsb with borg

pushd /tmp

mkdir I_AM_IN_ARCHIVE1 I_AM_IN_ARCHIVE2
touch I_AM_IN_ARCHIVE1/f1
touch I_AM_IN_ARCHIVE2/f2

# accounts:
# 1. hsb-borg 
#    account for backup management
# 
# 2. hsb-borg-ao-repo1
#    account for append-only backup to repo1

# access to the same repo with different accounts
# alerts borg to a relocated repo. the following 
# setting takes care of the confirmation required.
export BORG_RELOCATED_REPO_ACCESS_IS_OK=yes

# create repo repo1 using the hsb-borg-ao-repo1 account
borg init --encryption=none hsb-borg-ao-repo1:repo1
# create repo repo2 using the hsb-borg account
borg init --encryption=none hsb-borg:repo2
# encryption options:
# --encryption=repokey-blake2 
# repokey encryption, BLAKE2b (often faster, since Borg 1.1)
# --encryption=keyfile
# keyfile: stores the (encrypted) key into ~/.config/borg/keys/

# create archive archive1 in repo1 using the hsb-borg-ao-repo1 account
borg create -C zlib,6 hsb-borg-ao-repo1:repo1::archive1 I_AM_IN_ARCHIVE1/
# create archive archive2 in repo2 using the hsb-borg account
borg create -C zlib,6 hsb-borg:repo2::archive2 I_AM_IN_ARCHIVE2/

borg info hsb-borg-ao-repo1:repo1
borg info hsb-borg:repo2

# this creates a repo-relocation warning (see above)
borg info hsb-borg:repo1

rm -rf I_AM_IN_ARCHIVE1 I_AM_IN_ARCHIVE2

popd

return 0

# only repository paths below borg/.. are allowed
#restrict,command="borg serve --append-only --restrict-to-path ./borg",no-port-forwarding,no-X11-forwarding,no-pty,no-agent-forwarding,no-user-rc ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMcM7KY7ashZEP4YxOxNS4fY4exN3qP4vDiZxdIR8iu/


return 0

 restic

# ----------------------------------------------------------------
# variant 1 (restriced key access)

# this allows *only one repo* (here located in "./repo1") at the
# remote, since the repo path is never constructed for rclone by restic
# (the rclone command given to "ssh" can actually be anything)

# > restic -o rclone.program="ssh hsb-restic-ao-repo1 rclone" -r rclone:repo1 init

# authorized_keys of hsb-sub contains
#restrict,command="rclone serve restic --stdio --config=/dev/null --append-only --verbose ./repo1",no-port-forwarding,no-X11-forwarding,no-pty,no-agent-forwarding,no-user-rc ssh-...

# CAVE: in that case the "repo2" part of the following repository path is ignored
# > restic -o rclone.program="ssh hsb-sub1-restic-ao forced-command" -r rclone:repo2 snapshots
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

# EOF
