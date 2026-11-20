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

The lane runs Loopy with local directories, and it cannot run staged-objects
yet: with `LOOPY_STAGING_S3_BUCKET` set, `lane status` calls the master's
staging a mismatch, marks Loopy unavailable and suggests `lane master
restart`, which changes nothing, and `planlab --lane` refuses every turn. So
drive a staged-objects claim end to end on `infra/loopy-smoke`'s `two-host`
topology (aws), which stages through real S3. MinIO in a container serves
the claims a test can reach: the master's S3 client against a real
S3-compatible store.

```bash
N=<branch-slug>-minio; P=<free port>
docker run -d --name $N -p $P:9000 -e MINIO_ROOT_USER=verify -e MINIO_ROOT_PASSWORD=verify-secret \
  minio/minio:latest server /data
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:$P/minio/health/live     # 200
env -u AWS_PROFILE AWS_ACCESS_KEY_ID=verify AWS_SECRET_ACCESS_KEY=verify-secret \
  aws --endpoint-url http://127.0.0.1:$P --region us-east-1 s3 mb s3://<bucket>
```

Point the code under test at it with `LOOPY_STAGING_S3_BUCKET`,
`LOOPY_STAGING_S3_ENDPOINT` (`http://127.0.0.1:$P`), `LOOPY_STAGING_S3_PREFIX`
and `LOOPY_STAGING_S3_REGION`, as
`packages/loopy-master-host/src/staging_identity.ts` reads them, with the
container's keys passed to the test alone: exported into `lane up`, they
would also replace the AWS credentials the lane's Bedrock calls use. Remove
the container afterwards (`docker rm -f $N`).
