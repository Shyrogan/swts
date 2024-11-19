import { App, Astal, Gdk } from "astal/gtk3"
import Battery from "../misc/Battery"
import QuickSettingsUserWidget from "./widgets/User";

export function quickSettingsName(monitor: Gdk.Monitor) {
  return `quick-settings-${monitor.get_model() || "unknown"}`
}

export default function QuickSettingsMenu(monitor: Gdk.Monitor) {
  const anchor = Astal.WindowAnchor.TOP
      | Astal.WindowAnchor.RIGHT;

  return <window
    gdkmonitor={monitor}
    name={quickSettingsName(monitor)}
    anchor={anchor}
    setup={(self) => {
      App.add_window(self);
      App.toggle_window(self.name);
    }}
  >
    <box>
      <Battery label={true} />
      <QuickSettingsUserWidget />
    </box>
  </window>
}
