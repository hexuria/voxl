#!/bin/zsh
# Run a command in the guest: ./ssh.sh 'Get-ComputerInfo'
cd "${0:A:h}"
exec ssh -i ssh/id_ed25519 -p 2222 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR Docker@127.0.0.1 "$@"
