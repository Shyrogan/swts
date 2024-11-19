import Hyprland from "gi://AstalHyprland";
import { Gdk } from "astal/gtk3";
import { bind } from "astal"
import WorkspacesGroup from "./WorkspacesGroup";

type Props = {
  monitor: Gdk.Monitor;
}

function groupify(hyprland: Hyprland.Hyprland) {
  const workspaces: number[][] = [[1]]

  for (let current = 2; current <= 10; current++) {
    const group = workspaces[workspaces.length - 1];
    const last = group[group.length - 1];

    if (!!hyprland.get_workspace(current) === !!hyprland.get_workspace(last)) {
      group.push(current)
    } else {
      workspaces.push([current])
    }
  }

  return workspaces
}

export default function Workspaces({ }: Props) {
  const hyprland = Hyprland.get_default();

  return <box className="workspaces">
    {bind(hyprland, "workspaces").as(() => groupify(hyprland)
      .map((group) => <WorkspacesGroup
        hyprland={hyprland}
        group={group}
      />)
    )}
  </box>
}
