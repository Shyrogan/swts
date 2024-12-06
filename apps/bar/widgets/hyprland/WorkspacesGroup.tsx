import Hyprland from "gi://AstalHyprland";
import Workspace from "./Workspace";
import { bind } from "astal"

type Props = {
  hyprland: Hyprland.Hyprland,
  group: number[]
}

export default function WorkspacesGroup({ hyprland, group }: Props) {
  // Should not happen
  if (group.length === 0)
    return <></>

  const focusedWs = bind(hyprland, "focusedWorkspace")
  const isCreated = !!hyprland.get_workspace(group[group.length - 1])

  return <box setup={(self) => {
    self.toggleClassName("created", isCreated)
    self.toggleClassName("not-created", !isCreated)
  }}>
    {group.map((w) =>
      <Workspace
        isFocus={focusedWs.as((ws) => ws?.get_id() === w)}
      />
    )}
  </box>
}
