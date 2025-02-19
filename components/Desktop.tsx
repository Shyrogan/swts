import { App, Astal, Gdk, Gtk } from "astal/gtk3";
import Date from "../widget/Date";
import Workspaces from "../widget/Workspace";
import Battery from "../widget/Battery";
import Volume from "../widget/Volume";
import Tray from "../widget/Tray";

export default function Desktop(monitor: Gdk.Monitor) {
  const { TOP, LEFT, BOTTOM } = Astal.WindowAnchor
  const { END } = Gtk.Align

  return <window
    className="bg-transparent"
    gdkmonitor={monitor}
    exclusivity={Astal.Exclusivity.EXCLUSIVE}
    anchor={TOP | LEFT | BOTTOM}
    layer={Astal.Layer.BACKGROUND}
    application={App}
  >
    <centerbox className="pl-1 py-3 text-base" vertical hexpand>
      <box vertical>
        <Date />
        <Battery />
        <Volume />
      </box>
      <Workspaces />
      <box vertical valign={END}>
        <Tray />
      </box>
    </centerbox>
  </window>

}

