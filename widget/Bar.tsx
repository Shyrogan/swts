import app from "ags/gtk4/app"
import { Astal, Gdk } from "ags/gtk4"
import Workspaces from "./bar/Workspaces"
import Title from "./bar/Title"
import Time from "./bar/Time"

export default function Bar(gdkmonitor: Gdk.Monitor) {
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor

  return (
    <window
      visible
      name="bar"
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.NORMAL}
      layer={Astal.Layer.TOP}
      anchor={TOP | LEFT | RIGHT}
      application={app}
      class="text-base font-medium"
    >
      <centerbox>
        <box $type="start" class="px-2 rounded-lg">
          <Workspaces monitor={gdkmonitor} />
        </box>
        <box $type="center">
          <Title />
        </box>
        <box $type="end">
          <Time dateFormat="%d.%m.%Y" hourFormat="%R" />
        </box>
      </centerbox>
    </window>
  )
}
