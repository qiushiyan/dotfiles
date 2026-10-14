#!/bin/bash
# One read-only memory snapshot of this Mac. Runs on the other machine too:
#   ssh <host> 'bash -s' < snapshot.sh
gb() { awk '{printf "%.1f GB", $1/2^30}'; }

echo "== $(cat ~/.config/machine 2>/dev/null || hostname -s): $(sysctl -n hw.memsize | gb) RAM"
memory_pressure | tail -1
sysctl -n vm.swapusage
vm_stat | awk 'NR==1{ps=$8} /occupied by compressor/{printf "compressed: %.1f GB\n", $NF*ps/2^30}'
uptime | sed 's/.*up/up/'

echo; echo "== top by footprint (MEM includes compressed pages; RSS does not)"
top -l 1 -o mem -n 15 -stats pid,ppid,mem,cmprs,state,time,command 2>/dev/null | sed -n '/^PID/,$p'

echo; echo "== by app (RSS summed over helpers)"
ps -axo rss=,comm= | awk '{n=$2; for(i=3;i<=NF;i++) n=n" "$i; sub(".*/","",n); a[n]+=$1; c[n]++}
  END {for (k in a) printf "%6.2f GB %3d  %s\n", a[k]/2^20, c[k], k}' | sort -rn | head -12

echo; echo "== VMs"
command -v limactl >/dev/null && limactl list 2>/dev/null
command -v orb >/dev/null && { orb status 2>/dev/null; docker ps --format '{{.Names}} {{.Status}}' 2>/dev/null; }

cwd_of() {
  local d; d=$(lsof -a -p "$1" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')
  [ -n "$d" ] && [ ! -d "$d" ] && d="$d (deleted)"
  echo "${d:-?}"
}

echo; echo "== live Claude sessions"
for pid in $(pgrep -x claude); do
  printf '%s %s  cwd=%s\n' "$pid" "$(ps -o stat=,etime=,rss= -p "$pid" | awk '{printf "stat=%s age=%s %dMB", $1, $2, $3/1024}')" "$(cwd_of "$pid")"
done

echo; echo "== suspects: orphaned (ppid 1) dev processes and stopped processes"
ps -xo pid=,ppid=,stat=,etime=,rss=,command= | awk '
  {n=split($6, p, "/"); bin=p[n]}
  ($2==1 && bin ~ /^(node|tsgo|next-server|esbuild|bun|python3?)$/) || $3 ~ /^T/' |
while read -r pid ppid stat etime rss cmd; do
  printf '%s ppid=%s stat=%s age=%s %dMB %s\n    cwd=%s\n' "$pid" "$ppid" "$stat" "$etime" $((rss/1024)) "${cmd:0:140}" "$(cwd_of "$pid")"
done | head -40
