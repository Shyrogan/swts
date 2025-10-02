import AstalHyprland from "gi://AstalHyprland?version=0.1"
import { Accessor, createComputed } from "gnim"

type Props = {
  workspace: Accessor<AstalHyprland.Workspace>
}

export default function Workspace({ workspace }: Props) {
  const id = workspace.as((w) => w.id.toString())
  return (
    <button
      class="w-2 rounded-full text-xs py-1 px-2 active:bg-red"
      label={id}
    />
  )
}
