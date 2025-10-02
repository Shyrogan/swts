import { Gdk } from "ags/gtk4"
import AstalHyprland from "gi://AstalHyprland"
import { createBinding, createComputed } from "gnim"
import Workspace from "./Workspace"

type Props = {
  monitor: Gdk.Monitor
}

export default function Workspaces({ monitor }: Props) {
  if (!monitor.get_connector()) return <></>

  const hyprland = AstalHyprland.get_default()
  const hyprMonitor = createBinding(hyprland, "monitors").as(
    (monitors) => monitors.find((m) => m.name === monitor.get_connector())!,
  )
  if (!hyprMonitor) return <></>

  const hyprWorkspaces = createBinding(hyprland, "workspaces").as((ws) =>
    ws.sort((a, b) => a.id - b.id),
  )
  const monitorWorkspaces = createComputed(
    [hyprWorkspaces, hyprMonitor],
    (ws, monitor) => ws.filter((w) => w.monitor == monitor),
  )
  const monitorWorkspacesCount = createComputed(
    [monitorWorkspaces],
    (ws) => ws.length,
  )

  return (
    <box class="bg-background px-2 py-1 rounded-lg space-x-1">
      {Array.from(Array(monitorWorkspacesCount).keys()).map((i) => (
        <Workspace
          workspace={createComputed([monitorWorkspaces], (w) => w[i])}
        />
      ))}
    </box>
  )
}
