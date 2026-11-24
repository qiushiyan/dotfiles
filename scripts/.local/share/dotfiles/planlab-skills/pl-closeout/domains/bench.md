# Bench

A merge does not deploy Bench. Deploy it with `pl-deploy-bench-prod`, which
ships develop and smoke-tests it, then confirm with `pl-check-deployed`, the
merge commit as `--ref` and `bench` as `--target`.
