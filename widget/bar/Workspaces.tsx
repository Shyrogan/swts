import { Gdk } from "ags/gtk4"
import AstalHyprland from "gi://AstalHyprland"
import { createBinding, createComputed, For } from "gnim"
import Workspace from "./Workspace"

const hyprland = AstalHyprland.get_default()

type Props = {
  monitor: Gdk.Monitor
}

export default function Workspaces({ monitor }: Props) {
  const hyprMonitors = createBinding(hyprland, "monitors")
  const hyprMonitor = createComputed(
    [hyprMonitors],
    (monitors) => monitors.find((m) => m.name === monitor.get_connector())!,
  )

  const hyprWorkspaces = createBinding(hyprland, "workspaces")
  const monitorWorkspaces = createComputed(
    [hyprWorkspaces, hyprMonitor],
    (ws, monitor) =>
      ws.sort((a, b) => a.id - b.id).filter((w) => w.monitor == monitor),
  )

  return (
    <box>
      <For each={monitorWorkspaces}>{(ws) => <Workspace workspace={ws} />}</For>
    </box>
  )
}
