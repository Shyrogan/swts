import { Gdk } from "ags/gtk4"
import AstalHyprland from "gi://AstalHyprland"
import { createBinding, createComputed, For } from "gnim"
import Workspace from "./Workspace"

type Props = {
  monitor: Gdk.Monitor
}

export default function Workspaces({ monitor }: Props) {
  if (!monitor.get_connector()) return <label label="" />

  const hyprland = AstalHyprland.get_default()
  const hyprMonitor = createBinding(hyprland, "monitors").as(
    (monitors) => monitors.find((m) => m.name === monitor.get_connector())!,
  )
  if (!hyprMonitor) return <label label="" />

  const hyprWorkspaces = createBinding(hyprland, "workspaces").as((ws) =>
    ws.sort((a, b) => a.id - b.id),
  )
  const monitorWorkspaces = createComputed(
    [hyprWorkspaces, hyprMonitor],
    (ws, monitor) => ws.filter((w) => w.monitor == monitor),
  )

  return (
    <box>
      <For each={monitorWorkspaces}>{(ws) => <Workspace workspace={ws} />}</For>
    </box>
  )
}
