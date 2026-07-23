# ecs_ec2_capacity

Provides EC2 capacity for an ECS cluster: an ECS-optimized AL2023 launch
template, a single-instance autoscaling group, and an ECS capacity provider
with managed termination protection.

On boot, the instance's user-data (see `shared/user-data.sh.tpl`) discovers
every non-root NVMe device — either the host's local NVMe instance store
(i4i/m6id instance types) or an attached gp3 EBS data volume — RAID0s them
if there is more than one, formats the result as XFS, and mounts it at
`/mnt/nvme`. The Electric task bind-mounts `/mnt/nvme/electric/<label>` as
its storage directory.

Storage is chosen via `data_storage`:

- `{ kind = "nvme" }` — use the instance type's local NVMe instance store
  (requires an i4i/m6id/other `d`-suffixed instance type). Fastest disk;
  data survives task restarts but not host replacement.
- `{ kind = "ebs-gp3", size_gb = 100, iops = 3000, throughput_mbps = 125 }`
  — attach a gp3 data volume to a compute-only instance type (m6a/m6i/
  m7a/m7i). IOPS and throughput are tunable in place with a later
  `terraform apply`.

Either way Electric treats the disk as a warm cache: it rebuilds shape data
from Postgres if the host (and its disk) is replaced.
