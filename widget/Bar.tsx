import app from "ags/gtk4/app"
import { Astal, Gdk } from "ags/gtk4"
import Workspaces from "./bar/Workspaces"
import Mpris from "./bar/Mpris"
import Time from "./bar/Time"
import Title from "./bar/Title"
import Quicksettings from "./bar/Quicksettings"
import { onCleanup } from "ags"

type Props = {
  gdkmonitor: Gdk.Monitor
}

export default function Bar({ gdkmonitor }: Props) {
  let win: Astal.Window
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor

  return (
    <window
      visible
      name={`bar-${gdkmonitor.connector}`}
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

          <Title />
        </box>
        <box $type="center">
          <Mpris />
        </box>
        <box $type="end">
          <Quicksettings />
          <Time dateFormat="%d.%m.%Y" hourFormat="%R" />
        </box>
      </centerbox>
    </window>
  )
}
