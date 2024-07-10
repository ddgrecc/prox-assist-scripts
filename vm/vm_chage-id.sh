#!/bin/bash

###################################################
#  How to use:
#  ./vm_change-id.sh [-c | --cleanup] [-n | --no-start] <old-ID> <new-ID> [storage]
#
###################################################

# Function to display usage
usage() {
  echo "Usage: $0 [-c | --cleanup] [-n | --no-start] <old-ID> <new-ID> [storage]"
  exit 1
}

# Check if the script receives at least two arguments
if [ "$#" -lt 2 ]; then
  usage
fi

# Initialize variables
CLEANUP=false
NO_START=false
DEFAULT_STORAGE="local-lvm"

# Parse options
while [[ "$1" =~ ^- ]]; do
  case "$1" in
    -c | --cleanup)
      CLEANUP=true
      shift
      ;;
    -n | --no-start)
      NO_START=true
      shift
      ;;
    *)
      usage
      ;;
  esac
done

# Check if the remaining arguments are at least two and at most three
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  usage
fi

# Assign remaining arguments to variables
OLD_ID=$1
NEW_ID=$2
STORAGE=${3:-$DEFAULT_STORAGE}

# Define the backup directory
BACKUP_DIR="/var/lib/vz/dump"

# Function to check the status of the last command and exit if it failed
check_status() {
  if [ $? -ne 0 ]; then
    echo "An error occurred. Exiting."
    exit 1
  fi
}

# Stop the old VM
echo "Stopping VM with ID $OLD_ID..."
qm stop $OLD_ID
check_status

# Create a backup of the old VM
echo "Creating backup of VM with ID $OLD_ID..."
vzdump $OLD_ID --dumpdir $BACKUP_DIR
check_status

# Find the backup file
BACKUP_FILE=$(ls -t $BACKUP_DIR/vzdump-qemu-$OLD_ID-*.vma | head -n 1)

# Check if the backup file exists
if [ -z "$BACKUP_FILE" ]; then
  echo "Backup file for VM with ID $OLD_ID not found!"
  exit 1
fi

# Delete the old VM
echo "Deleting VM with ID $OLD_ID..."
qm destroy $OLD_ID
check_status

# Restore the VM with the new ID
echo "Restoring VM from backup to new ID $NEW_ID using storage $STORAGE..."
qmrestore $BACKUP_FILE $NEW_ID --storage $STORAGE
check_status

# Start the new VM unless the no-start option is set
if [ "$NO_START" = false ]; then
  echo "Starting VM with new ID $NEW_ID..."
  qm start $NEW_ID
  check_status
fi

# Cleanup the backup file if the cleanup option is set and the restoration was successful
if [ "$CLEANUP" = true ]; then
  echo "Cleaning up backup file $BACKUP_FILE..."
  rm -f $BACKUP_FILE
  check_status
fi

echo "VM ID change completed successfully."
