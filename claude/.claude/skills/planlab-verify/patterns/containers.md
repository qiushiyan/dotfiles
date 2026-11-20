# A container on this machine

Docker runs through OrbStack (`docker` on the PATH). Several sessions share
the machine, so name every container after the branch, take a free port
(`lsof -iTCP:<port> -sTCP:LISTEN` shows a taken one), and remove what you
started before you report.

**It cannot show** AWS itself (instance profiles, metadata, Auto Scaling,
real S3 behaviour under load): see aws.

## Linux-only behaviour

Loopy's sandbox commands (`ls`, `grep` and the rest) are just-bash and run
the same on the lane, so drive them there. Their GNU answers come from the
repo's own corpus image, `packages/loopy/scripts/gnu_parity.Dockerfile`
(`pnpm --filter @planlab/loopy run record:gnu-parity`), which
`packages/loopy/src/sandbox/gnu_parity.sandbox.test.ts` checks against:
that test may already settle the claim, and a new answer is recorded with
that image, not another distribution.

For file-system semantics, or a shell command as a Linux host runs it:

```bash
docker run --rm -v "$PWD":/w -w /w ubuntu:22.04 bash -lc '<the command>'
```

systemd on a real boot needs a host: see aws.

## Loopy's S3 staging (staged-objects mode)

The lane runs Loopy with local directories. A claim about runs whose inputs
cross hosts through S3 needs a store: MinIO in a container.

```bash
N=<branch-slug>-minio; P=<free port>
docker run -d --name $N -p $P:9000 -e MINIO_ROOT_USER=verify -e MINIO_ROOT_PASSWORD=verify-secret \
  minio/minio:latest server /data
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:$P/minio/health/live     # 200
env -u AWS_PROFILE AWS_ACCESS_KEY_ID=verify AWS_SECRET_ACCESS_KEY=verify-secret \
  aws --endpoint-url http://127.0.0.1:$P --region us-east-1 s3 mb s3://<bucket>
```

The app and the master both read `LOOPY_STAGING_S3_BUCKET` (setting it is
what turns staged-objects mode on), `LOOPY_STAGING_S3_ENDPOINT`,
`LOOPY_STAGING_S3_PREFIX`, `LOOPY_STAGING_S3_REGION`, and the SDK's
`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
(`packages/loopy-master-host/src/staging_identity.ts`). Both must see the
same values: the store's identity includes the endpoint, and dispatch refuses
a mismatch. `lane up` hands its own environment to the processes it starts,
so export them, then `lane stop` and `lane up`. The lane has no switch for
this, and it has been done by hand once: confirm from the master's log that
it staged to the bucket before trusting a verdict, and stop and remove the
container afterwards (`docker rm -f $N`).
