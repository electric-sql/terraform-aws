import * as fs from "fs"
import * as path from "path"
import * as pulumi from "@pulumi/pulumi"

/**
 * Renders the shared user-data template (shared/user-data.sh.tpl) that
 * formats and mounts the host's data disk(s) and joins it to the ECS
 * cluster.
 *
 * The template uses Terraform `templatefile()` syntax: `${cluster_name}`
 * and `${instance_label}` are injection points, and literal bash `${...}`
 * is escaped as `$${...}`. This renderer applies the same rules so both
 * tools share one template.
 *
 * Returns the base64-encoded script for `aws.ec2.LaunchTemplate.userData`.
 */
export function renderUserData(
  clusterName: pulumi.Input<string>,
  instanceLabel: string
): pulumi.Output<string> {
  const template = fs.readFileSync(
    path.join(__dirname, "..", "..", "shared", "user-data.sh.tpl"),
    "utf8"
  )
  return pulumi.output(clusterName).apply((cluster) => {
    // split().join() does a literal global replace, the same as
    // String.replaceAll but without depending on the ES2021 lib — Pulumi's
    // runtime ts-node doesn't honour this project's `target` for lib
    // selection, so replaceAll fails to compile there. Order matters:
    // substitute the two injection points first, then unescape `$${`.
    const script = template
      .split("${cluster_name}").join(cluster)
      .split("${instance_label}").join(instanceLabel)
      .split("$${").join("${")
    return Buffer.from(script).toString("base64")
  })
}
