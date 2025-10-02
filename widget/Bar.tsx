import app from "ags/gtk4/app"
import { Astal, Gtk, Gdk } from "ags/gtk4"
import { execAsync } from "ags/process"
import { createPoll } from "ags/time"
import Workspaces from "./bar/Workspaces"

export default function Bar(monitor: Gdk.Monitor) {
  const time = createPoll("", 1000, "date")
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor

  return (
    <window
      visible
      name="bar"
      gdkmonitor={monitor}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={TOP | LEFT | RIGHT}
      application={app}
    >
      <centerbox class="pt-1">
        <menubutton $type="end" hexpand halign={Gtk.Align.CENTER} class="mb-0">
          <Workspaces monitor={monitor} />
        </menubutton>
      </centerbox>
    </window>
  )
}
