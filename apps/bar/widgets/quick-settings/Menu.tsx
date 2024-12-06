import { App, Astal, Gdk } from "astal/gtk3"
import Battery from "../misc/Battery"
import QuickSettingsUserWidget from "./widgets/User";
import QuickSettingsCircularButton from "./widgets/IconButton";
import QuickSettingsSlider from "./widgets/Slider";

export function quickSettingsName(monitor: Gdk.Monitor) {
  return `quick-settings-${monitor.get_model() || "unknown"}`
}

export default function QuickSettingsMenu(monitor: Gdk.Monitor) {
  const anchor = Astal.WindowAnchor.TOP;

  return <window
    gdkmonitor={monitor}
    name={quickSettingsName(monitor)}
    anchor={anchor}
    setup={(self) => {
      App.add_window(self);
      App.toggle_window(self.name);
    }}
  >
    <box vertical className="menu quick-settings">
      <box>
        <QuickSettingsUserWidget />
        
        <QuickSettingsCircularButton icon="system-lock-screen-symbolic" />
        <QuickSettingsCircularButton icon="system-shutdown-symbolic" />
      </box>
      <box className="ptop">
        <Battery label={true} />
      </box>
    </box>
  </window>
}
