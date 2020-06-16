#!/bin/bash
# Cleanup OSISM Testbed on OTC needs a little help
# Usage: cleanup-otc.sh [STACKNAME]
# STACKNAME defaults to the only deployed stack by default
# (c) Kurt Garloff <scs@garloff.de>, 2/2020, CC-BY-SA 3.0
STACK=$(openstack stack list -f value -c "Stack Name" -c "Stack Status")
STACK_NM=${1:-${STACK% *}}
if test -z "$STACK_NM"; then echo "Could not determine stack to delete. Use cleanup-otc.sh STACKNAME"; exit 1; fi
echo "Cleaning stack $STACK_NM"
if ! [[ "$STACK" == *"$STACK_NM"* ]]; then echo "No such stack $STACK_NM"; exit 2; fi
openstack stack delete -y --wait $STACK_NM
STACK=$(openstack stack list -f value -c "Stack Name" -c "Stack Status")
if ! [[ "$STACK" == *"$STACK_NM"* ]]; then exit 0; fi
openstack server list
for srv in testbed-manager testbed-node-2 testbed-node-1 testbed-node-0; do
  openstack server delete $srv
done
STACK=$(openstack stack list -f value -c "Stack Name" -c "Stack Status")
if ! [[ "$STACK" == *"$STACK_NM"* ]]; then exit 0; fi
openstack stack delete -y --wait $STACK_NM
STACK=$(openstack stack list -f value -c "Stack Name" -c "Stack Status")
openstack stack list
if ! [[ "$STACK" == *"$STACK_NM"* ]]; then exit 0; fi
for sg in testbed-external testbed-internal testbed-storage-backend testbed-storage-frontend testbed-management; do
  openstack security group delete $sg
done
openstack stack delete -y --wait $STACK_NM
echo "Stack should be gone now ..."
openstack stack list
STACK=$(openstack stack list -f value -c "Stack Name" -c "Stack Status")
if [[ "$STACK" == *"$STACK_NM"* ]]; then
  echo "Stack $STACK_NM still not gone"
  openstack stack show $STACK_NM -f value -c "stack_status_reason"
  openstack stack delete -y $STACK_NM
  exit 3
fi
rm -f .deploy.$STACK_NM .MANAGER_ADDRESS.$STACK_NM ~/.ssh/id_rsa.$STACK_NM
