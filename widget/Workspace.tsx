import { bind, Variable } from "astal";
import { Astal } from "astal/gtk3";
import { EventBox } from "astal/gtk3/widget";
import AstalHyprland from "gi://AstalHyprland?version=0.1"

const hyprland = AstalHyprland.get_default();

export default function Workspaces() {
  function scrollWs(self: EventBox, e: Astal.ScrollEvent) {
    hyprland.dispatch("workspace", e.delta_y > 0 ? "+1" : "-1");
  }

  return <eventbox onScroll={scrollWs}>
    <box vertical className="bg-bg rounded py-2">
      {[...Array(10).keys()].map((id) => <Workspace id={id + 1} />)}
    </box>
  </eventbox>
}

type WorkspaceProps = {
  id: number
}

export function Workspace({ id }: WorkspaceProps) {
  const className = Variable.derive([bind(hyprland, 'workspaces'), bind(hyprland, 'focusedWorkspace')], (workspaces, focused) => {
    const allClasses: string[] = ["text-bg-mid"]
    const workspace = workspaces.find((w) => w.id === id)

    if (workspace) {
      if (workspace.get_clients().length > 0) {
        allClasses.push('text-light')
      }

      if (focused.id === id) {
        allClasses.push('text-blue')
      }
    }

    return allClasses.join(" ")
  })
  return <button className={className()} onClick={() => hyprland.dispatch("workspace", `${id}`)}>
    <label label={id.toString()} />
  </button>
}
