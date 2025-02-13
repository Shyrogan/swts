import { bind, Variable } from "astal";
import { Gtk } from "astal/gtk3";
import AstalBattery from "gi://AstalBattery?version=0.1";

const battery = AstalBattery.get_default()

export default function Battery() {
  const icon = bind(battery, 'iconName')
  const percent = bind(battery, 'percentage')
  const state = bind(battery, 'state')
  const color = Variable.derive([state, percent], (state, percent) => {
    if (state === AstalBattery.State.CHARGING || percent > 0.8)
      return "text-blue"
    if (percent > 0.4)
      return "text-light"
    if (percent > 0.2)
      return "text-yellow"
    return "text-red"
  })
  return <box className="bg-bg rounded p-2 mt-1" halign={Gtk.Align.CENTER}>
    <circularprogress halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} value={percent} rounded className={color((v) => `text-border ${v}`)} startAt={0} endAt={1} >
      <icon icon={icon} className="p-2 bg-bg text-xs text-light" />
    </circularprogress>
  </box>
}
