import { createPoll } from "ags/time"
import GLib from "gi://GLib?version=2.0"
import Quicksettings from "./Quicksettings"

type Props = {
  dateFormat: "%d.%m.%Y"
  hourFormat: "%H:%M" | "%R"
}

export default function Time({ dateFormat, hourFormat }: Props) {
  const time = createPoll(
    "",
    1000,
    () => GLib.DateTime.new_now_local().format(hourFormat)!,
  )
  const date = createPoll(
    "",
    1000,
    () => GLib.DateTime.new_now_local().format(dateFormat)!,
  )

  return (
    <menubutton>
      <box class="space-x-2 text-base pr-4">
        <label label={date} />
        <label label={time} class="font-bold" />
      </box>
      <Quicksettings />
    </menubutton>
  )
}
