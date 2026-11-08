# Guest account on the mini: `nicholas`

A colleague, Nicholas, has a temporary account on the mini
(`docs/qiushi-mini.md`) until his own Mac mini arrives. He isn't an engineer,
and he reaches the mini by SSH over the company tailnet. Strike a pending item
by deleting it. Delete this file, and its pointer in `docs/qiushi-mini.md`,
once the account is gone.

## How the account is set up

- **A standard user, not an admin:** `nicholas`, UID 503, in `staff`. He has
  no sudo. `qiushiyan`'s home (`drwx------`), `~/.secrets*` and `~/.aws`
  are closed to him.
- **SSH by key only:** Remote Login on the mini is limited to
  `com.apple.access_ssh`, whose only nested group is `admin`, so `nicholas`
  was added to it by name. A `Match User nicholas` block at the end of
  `/etc/ssh/sshd_config` turns off password and keyboard-interactive login
  and TCP forwarding for him alone. With those off, his local password gets
  nobody in over the network. While his `~/.ssh/authorized_keys` is empty,
  nobody can log in as him.
- **The block sits at the end of `sshd_config`, not in `sshd_config.d/`.** The
  `Include` line is at the top of `sshd_config`, so a `Match` block in an
  included file would also capture the `AuthorizedKeysFile` and `Subsystem`
  lines below it.
- **No SecureToken,** so he can't unlock FileVault at boot.
  `sysadminctl -secureTokenStatus nicholas` reports `DISABLED`.
- **He can still reach what listens on localhost.** Homebrew's Postgres trusts
  every local connection (`pg_hba.conf`), so he could open the planlab lane
  databases as `qiushiyan`. The gazette site (8790, 8791) and `drive page`
  (8792) are open to him in the same way. Closing this means putting
  passwords on Postgres and breaking the lanes' connection strings, which
  isn't worth it for a short guest account.

`sysadminctl -addUser` stalls over SSH on the headless mini. It hung after
creating the record and before setting the password. Finish such a record with
`dscl`, which also grants no SecureToken:

```bash
sudo dscl . -passwd /Users/nicholas          # prompts for the new password
sudo createhomedir -c -u nicholas
```

## Pending

- **Ask a tailnet admin** whether the company's Tailscale ACLs let his device
  reach `qiushi-mini`. I am a member, not an admin, so I can't check this
  myself.
- **Settle what he'll use the mini for.** A terminal works as it is set up. If
  he needs the desktop through Screen Sharing, his local password starts to
  matter, so give him a strong one.
- **Add his public key** when he sends it. If he has no key yet, ask him to
  run `ssh-keygen -t ed25519`, press Enter at each prompt, then send me the
  line `cat ~/.ssh/id_ed25519.pub` prints.

  ```bash
  echo '<his public key>' | sudo tee /Users/nicholas/.ssh/authorized_keys
  ```

  He connects with `ssh nicholas@qiushi-mini.tailf7adf1.ts.net`.
- **Remove the account when his Mac mini arrives.** Delete the account and its
  home, remove the `Match User nicholas` block from `/etc/ssh/sshd_config`,
  check the config, then delete this file:

  ```bash
  sudo sysadminctl -deleteUser nicholas
  sudo sshd -t
  ```

  If `sysadminctl` stalls here too, use `sudo dscl . -delete /Users/nicholas`
  and `sudo rm -rf /Users/nicholas`.

## Checks

These run from the mini without sudo:

```bash
dsmemberutil checkmembership -U nicholas -G com.apple.access_ssh   # is a member
dsmemberutil checkmembership -U nicholas -G admin                  # is not a member
sysadminctl -secureTokenStatus nicholas                            # DISABLED
ssh -o PubkeyAuthentication=no nicholas@qiushi-mini.tailf7adf1.ts.net true
# → Permission denied (publickey)
```
