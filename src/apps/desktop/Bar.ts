import Workspaces from "widgets/hyprland/Workspaces";
import QuickSettings from "widgets/quick-settings/Root"

export default function() {
  return Widget.Window({
    name: "bar",
    anchor: ["top", "left", "right"],
    exclusivity: "exclusive",
    child: Widget.CenterBox({
      className: "nav-content",
      centerWidget: Widget.Box({
        children: [Workspaces()]
      }),
      endWidget: Widget.Box({
        hpack: "end",
        children: [QuickSettings.Button()]
      })
    }),
  })
}
