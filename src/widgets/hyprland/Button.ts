const hyprland = await Service.import("hyprland")

export default function(id: number) {
  const onClicked = async () => {
    hyprland.messageAsync(`dispatch workspace ${id}`)
  }

  return Widget.Button({
    onClicked,

    setup: (b) => {
      b.hook(hyprland, () => {
        const active = hyprland.active.workspace.id === id;
        b.toggleClassName("active", active)
        b.toggleClassName("occupied", (hyprland.getWorkspace(id)?.windows || 0) > 0)
        b.label = active ? "•" : `${id}`;
      })
    }
  })
}
