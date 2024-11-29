import { Astal, Gtk, Gdk } from "astal/gtk3"
import Date from "./misc/Date";
import QuickSettingsTrigger from "./quick-settings/Trigger";
import Workspaces from "./hyprland/Workspaces";
import SysTray from "./misc/Tray";

export default function Bar(monitor: Gdk.Monitor) {
  const anchor = Astal.WindowAnchor.TOP
      | Astal.WindowAnchor.LEFT
      | Astal.WindowAnchor.RIGHT;

  return <window
    gdkmonitor={monitor}
    exclusivity={Astal.Exclusivity.EXCLUSIVE}
    anchor={anchor}>
    <centerbox className="bar">
      <box className="left" hexpand halign={Gtk.Align.START}>
      </box>
      <box className="center" hexpand halign={Gtk.Align.CENTER}>
        <Workspaces monitor={monitor} />
        <Date />
        <QuickSettingsTrigger monitor={monitor} />
      </box>
      <box className="right" hexpand halign={Gtk.Align.END}>
        <SysTray />
      </box>
    </centerbox>
  </window>
}
