import { App, Gdk } from "astal/gtk3"
import Battery from "../misc/Battery";
import { quickSettingsName } from "./Menu";

type Props = {
  monitor: Gdk.Monitor
}

export default function QuickSettingsTrigger({ monitor }: Props) {
  function toggleQuickSettings() {
    print("Toggling")
    App.toggle_window(quickSettingsName(monitor))
  }

  return <button className="quick-settings trigger" onClick={toggleQuickSettings}>
    <Battery label={false} />
  </button>
}
