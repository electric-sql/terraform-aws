#!/bin/bash
set -euo pipefail
exec > /var/log/user-data.log 2>&1

dnf install -y nvme-cli jq mdadm xfsprogs

# Find the root device so we can exclude it from the data-device list.
# On AL2023 Nitro hosts the root is typically /dev/nvme0n1 but resolve
# dynamically to be safe.
ROOT_PART=$(findmnt -n -o SOURCE /)
ROOT_DEV=$(lsblk -no PKNAME "$ROOT_PART" 2>/dev/null || true)
ROOT_PATH="/dev/$${ROOT_DEV:-nvme0n1}"

# Wait up to 60s for at least one non-root NVMe device. NVMe instance
# store appears immediately; EBS data volumes can take a few seconds
# after instance boot. Both appear as /dev/nvme* on Nitro hosts, so the
# same discovery works for either storage backing.
DEVS=""
for i in $(seq 1 12); do
  DEVS=$(nvme list -o json | jq -r --arg root "$ROOT_PATH" '.Devices[] | select(.DevicePath != $root) | .DevicePath' | sort -u)
  if [ -n "$DEVS" ]; then break; fi
  echo "waiting for data device (attempt $i)..."
  sleep 5
done

COUNT=$(printf '%s\n' "$DEVS" | grep -c . || true)

if [ "$COUNT" -eq 0 ]; then
  echo "no data device (NVMe instance store or EBS) found after 60s" >&2
  exit 1
elif [ "$COUNT" -gt 1 ]; then
  # Multiple instance-store disks (i4i.8xlarge+, m6id.12xlarge+): RAID0.
  mdadm --create --verbose /dev/md0 --level=0 --raid-devices="$COUNT" $DEVS
  TARGET=/dev/md0
else
  TARGET=$(printf '%s' "$DEVS" | head -n1)
fi

mkfs.xfs -f "$TARGET"

# fstab outlives this script, which only runs on first boot, so it has to
# name the disk in a way that survives a reboot. Device paths don't: NVMe
# enumeration order isn't guaranteed, and a RAID array reassembled on boot
# can come back under a different name (/dev/md127). Probe with -p so the
# UUID comes from the filesystem just written rather than a stale cache.
FS_UUID=$(blkid -p -s UUID -o value "$TARGET")
if [ -z "$FS_UUID" ]; then
  echo "could not read filesystem UUID from $TARGET" >&2
  exit 1
fi

mkdir -p /mnt/nvme
# nofail: a blank or absent data disk (instance store is wiped by a
# stop/start) must not drop the host into emergency mode on boot.
echo "UUID=$FS_UUID /mnt/nvme xfs defaults,noatime,nodiscard,nofail 0 2" >> /etc/fstab
mount /mnt/nvme

# The Electric container runs as uid 1000; the bind-mounted data dir
# must be writable by it.
mkdir -p /mnt/nvme/electric/${instance_label}
chown 1000:1000 /mnt/nvme/electric/${instance_label}

{
  echo "ECS_CLUSTER=${cluster_name}"
  echo "ECS_RESERVED_MEMORY=512"
  echo "ECS_ENABLE_TASK_IAM_ROLE=true"
  echo "ECS_ENABLE_CONTAINER_METADATA=true"
} >> /etc/ecs/ecs.config

# Force-load the cached agent tar if Docker doesn't already have the
# image. The ECS-optimized AMI is supposed to do this on first boot,
# but the auto-load occasionally fails silently and ecs-init then
# hangs trying to pull.
if [ -f /var/cache/ecs/ecs-agent.tar ] \
   && ! docker image inspect amazon/amazon-ecs-agent:latest >/dev/null 2>&1; then
  docker load -i /var/cache/ecs/ecs-agent.tar || true
fi

# --no-block so cloud-init isn't held by the long-lived agent process.
systemctl enable ecs
systemctl start --no-block ecs
