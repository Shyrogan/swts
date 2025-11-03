import AstalHyprland from "gi://AstalHyprland?version=0.1"
import { Accessor, createBinding, createComputed, With } from "gnim"
import { cn } from "../../utils"

type Props = {
  workspace: AstalHyprland.Workspace
}

const hyprland = AstalHyprland.get_default()

export default function Workspace({ workspace }: Props) {
  const focusedWorkspace = createBinding(hyprland, "focusedWorkspace")
  return (
    <box>
      <With value={focusedWorkspace}>
        {(w) => (
          <button
            class={cn(
              w.id === workspace.id && "font-bold text-alt-main",
              "text-xs py-1 px-1",
            )}
            onClicked={() =>
              hyprland.dispatch("workspace", workspace.id.toString())
            }
            label={workspace.id.toString()}
          />
        )}
      </With>
    </box>
  )
}
