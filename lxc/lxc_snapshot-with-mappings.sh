#!/bin/bash
####################################################################
#  How to use:
#  ./lxc_snapshot-with-mappings.sh <ID1> <ID2> <ID3> <...>
#  or
#  ./lxc_snapshot-with-mappings.sh all
#  or
#  ./lxc_snapshot-with-mappings.sh running
#
####################################################################

# Function to list available LXCs
list_lxcs() {
  echo "Es wurden keine Container definiert."
  echo "Bitte aus den folgenden Containern auswählen:"
  pct list | grep -E '^\s*[0-9]' | awk '{print $1 "\t" $2}'
}

# Function to get all LXC IDs
get_all_lxc_ids() {
  pct list | grep -E '^\s*[0-9]' | awk '{print $1}'
}

# Function to get running LXC IDs
get_running_lxc_ids() {
  pct list | grep -E '^\s*[0-9]' | awk '$2 ~ /running/ {print $1}'
}

# Check if at least one LXC ID is provided or 'all'/'running' is specified
if [ "$#" -eq 0 ]; then
  list_lxcs
  exit 1
elif [ "$1" == "all" ]; then
  LXC_IDS=($(get_all_lxc_ids))
elif [ "$1" == "running" ]; then
  LXC_IDS=($(get_running_lxc_ids))
else
  LXC_IDS=("$@")
fi

# Function to remove mount points from LXC config file
remove_mounts() {
  local lxc_id=$1
  local config_file="/etc/pve/lxc/${lxc_id}.conf"
  grep -E '^mp[0-9]+:' $config_file > /tmp/lxc_${lxc_id}_mounts
  sed -i -E '/^mp[0-9]+:/d' $config_file
}

# Function to restore mount points to LXC config file
restore_mounts() {
  local lxc_id=$1
  local config_file="/etc/pve/lxc/${lxc_id}.conf"
  
  # Create a new temporary config file
  local temp_file="/tmp/lxc_${lxc_id}_new_config"
  
  # Copy the part of the config file before the first section starting with '['
  sed '/^\[.*\]/,$d' $config_file > $temp_file
  
  # Append the mount points
  cat /tmp/lxc_${lxc_id}_mounts >> $temp_file
  
  # Append the rest of the original config file
  sed -n '/^\[.*\]/,$p' $config_file >> $temp_file
  
  # Copy the content back to the original config file
  cp $temp_file $config_file
}

# Process each LXC
for lxc_id in "${LXC_IDS[@]}"; do
  echo "Processing LXC $lxc_id..."
  
  # Stop the LXC
  echo "Stopping LXC $lxc_id..."
  pct stop $lxc_id
  
  # Get LXC name
  LXC_NAME=$(pct config $lxc_id | grep -i "hostname:" | awk '{print $2}')
  
  # Remove mount points
  echo "Removing mount points from LXC $lxc_id..."
  remove_mounts $lxc_id
  
  # Create snapshot if possible
  SNAPSHOT_NAME="${LXC_NAME}_snap$(date +%Y%m%d_%H%M)"
  echo "Creating snapshot for LXC $lxc_id with name $SNAPSHOT_NAME..."
  if pct snapshot $lxc_id $SNAPSHOT_NAME; then
    echo "Snapshot for LXC $lxc_id created successfully with name $SNAPSHOT_NAME."
  else
    echo "Failed to create snapshot for LXC $lxc_id."
  fi
  
  # Restore mount points
  echo "Restoring mount points for LXC $lxc_id..."
  restore_mounts $lxc_id
  
  # Start the LXC
  echo "Starting LXC $lxc_id..."
  pct start $lxc_id
  
  echo "LXC $lxc_id processing completed."
done

echo "All specified LXCs processed."


echo "All specified LXCs processed."
