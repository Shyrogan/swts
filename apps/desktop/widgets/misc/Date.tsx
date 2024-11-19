import { GLib, Variable, bind } from "astal"

export default function Date() {
  function currentDate() {
    return GLib.DateTime.new_now_local().format("%H:%M • %d/%m") || ""
  }
  const date = Variable(currentDate())
    .poll(1000, currentDate)
  return <label className="date" label={date()} onDestroy={date.drop} />
}
