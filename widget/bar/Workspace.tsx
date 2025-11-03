import AstalHyprland from "gi://AstalHyprland?version=0.1"
import { Accessor, createComputed } from "gnim"

type Props = {
  workspace: AstalHyprland.Workspace
}

export default function Workspace({ workspace }: Props) {
  return <button class="text-xs py-1 px-1" label={workspace.id.toString()} />
}
