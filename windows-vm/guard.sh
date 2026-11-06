#!/bin/zsh
# Keeps the guest from hurting other work on this Mac. Limits agreed with the
# orchestrator session:
#   load over 100 for 5 minutes  -> pause; resume after 5 minutes back under it
#   memory_pressure under 10%    -> pause; stays paused until told to resume
# State lives in vm/guard.state, so a restarted guard picks up where it left off.
cd "${0:A:h}"
load_limit=100; hold=300; mem_limit=10
state_file=vm/guard.state
[[ -f $state_file ]] || print run > $state_file
mon() { printf '%s\n' "$1" | nc -U -w 2 vm/monitor.sock >/dev/null 2>&1 || true }
high_since=0; low_since=0; n=0
while true; do
  pid=$(cat vm/qemu.pid 2>/dev/null || print 0)
  if ! kill -0 "$pid" 2>/dev/null; then print "QEMU_EXITED: guest process gone"; exit 1; fi
  free=$(memory_pressure 2>/dev/null | sed -nE 's/.*free percentage: ([0-9]+)%.*/\1/p')
  free=${free:-100}
  load=$(sysctl -n vm.loadavg | awk '{print int($2)}')
  now=$(date +%s)
  state=$(cat $state_file)
  case $state in
    run)
      if (( free < mem_limit )); then
        mon stop; print memory > $state_file
        print "GUEST_PAUSED_MEMORY: free=${free}% load=${load}; waiting for orchestrator"
      elif (( load > load_limit )); then
        (( high_since == 0 )) && high_since=$now
        if (( now - high_since >= hold )); then
          mon stop; print load > $state_file; low_since=0
          print "GUEST_PAUSED_LOAD: load=${load} free=${free}%; will resume after 5 minutes under the limit"
        fi
      else
        high_since=0
      fi
      ;;
    load)
      if (( load <= load_limit && free >= mem_limit )); then
        (( low_since == 0 )) && low_since=$now
        if (( now - low_since >= hold )); then
          mon cont; print run > $state_file; high_since=0
          print "GUEST_RESUMED: load=${load} free=${free}%"
        fi
      else
        low_since=0
      fi
      ;;
  esac
  if [[ $state == run && ! -f vm/guard.ssh-up ]]; then
    if ssh -i ssh/id_ed25519 -p 2222 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 Docker@127.0.0.1 'echo ok' 2>/dev/null | grep -q ok; then
      touch vm/guard.ssh-up
      print "SSH_UP: guest reachable"
    fi
  fi
  n=$((n+1))
  (( n % 90 == 0 )) && print "STATUS: state=$(cat $state_file) free=${free}% load=${load}"
  sleep 10
done
