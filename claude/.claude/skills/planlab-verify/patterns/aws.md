# The personal AWS account

Real AWS shape (EC2 hosts, systemd units on a real boot, instance profiles,
S3, IAM, a Lambda) runs in the owner's personal account, 288947333156. The
production account is for reads only.

**It cannot show** production's data, traffic or fleet size, and anything
no kit builds (an Auto Scaling group's lifecycle hooks and instance
refresh).

## Credentials

```bash
aws sts get-caller-identity --profile planlab-personal          # PowerUserAccess: EC2, S3, Lambda
aws sts get-caller-identity --profile planlab-personal-deploy   # DeploymentCreator: also IAM roles and instance profiles
```

This shell's default profile is production (`AWS_PROFILE=planlab-prod`),
and `infra/loopy-smoke/provision.sh` takes the default when its config names
none and checks no account. So put `AWS_PROFILE=planlab-personal` (or
`-deploy`) in the stack's config, pass `--profile` on every call of your
own, and before provisioning stop unless
`aws sts get-caller-identity --profile <it> --query Account --output text`
prints 288947333156.

When either fails on an expired sign-in, stop and tell the owner: signing in
is theirs (`aws-login <profile>` in their terminal). Use the profiles
rather than digging credentials out of the SSO cache yourself; a kit's own
scripts may read the cache, which is fine.

## Kits that exist

Read each kit's procedure before provisioning.

- **`infra/loopy-smoke/`**: a disposable Loopy stack. `single` is one Ubuntu
  host with the app, the master, Postgres and Inngest as systemd units;
  `two-host` splits the app and the master, with run inputs crossing through
  S3. `RIG_REMOTE_WORKERS=<n>` adds a remote worker box that boots from
  production's templates and runs its units, converger and lifecycle agent
  (README § The remote worker box). Fault and release drills are in
  `drills/`, `rig_fault.sh` and `rig_app_release.sh`. Everything is tagged
  `planlab:loopy-smoke=<stack>`. It builds no Auto Scaling group.
- **`infra/search-rig/`**: the search service's stack; its `rig_guard`
  refuses any other account.
- **`infra/app-tier-rig/`**: the web tier under load; its procedure is the
  header of `rig.sh` and `docs/loopy/infra/specs/2026-10-21-app-tier-rig-spec.md`.

Use a kit as it is where it reaches the claim. A claim that needs a shape no
kit builds is reported as not driven, with the shape that would drive it.

## Rules

- Launch the smallest shape the claim needs, in one region.
- Tag every resource with the branch (the kits tag with their stack name;
  name the stack after the branch, shortened where a kit limits the length).
- Tear down before you report, and list what you removed. A resource you
  could not remove goes at the top of the report.
- Say roughly what it cost when it ran more than an hour or used more than
  one host.
