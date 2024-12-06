import { App, Gdk } from "astal/gtk3"
import Battery from "../misc/Battery";
import { quickSettingsName } from "./Menu";
import WiFi from "../misc/WiFi";
import PowerProfile from "../misc/PowerProfile";

type Props = {
  monitor: Gdk.Monitor
}

export default function QuickSettingsTrigger({ monitor }: Props) {
  function toggleQuickSettings() {
    App.toggle_window(quickSettingsName(monitor))
  }

  return <button className="quick-settings trigger" onClick={toggleQuickSettings}>
    <box>
      <Battery label={false} />
      <WiFi label={false} />
      <PowerProfile label={false} />
    </box>
  </button>
}
