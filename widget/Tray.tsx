import { bind, Variable } from "astal";
import { Gtk } from "astal/gtk3";
import AstalTray from "gi://AstalTray?version=0.1";

const tray = AstalTray.get_default()
export const isTrayVisible = Variable(false)

export default function Tray() {
  const { CENTER } = Gtk.Align

  bind(tray, "items").as(i => {
    isTrayVisible.set(i.length != 0);
  })

  return <box vertical valign={CENTER} halign={CENTER} className="bg-bg rounded pt-2 px-4">
    {bind(tray, "items").as(items => items.map(item => (
      <menubutton
        className="pb-2"
        tooltipMarkup={bind(item, "tooltipMarkup")}
        usePopover={false}
        menuModel={bind(item, "menu_model")}>
        <icon gicon={bind(item, "gicon")} />
      </menubutton>
    )))}
  </box>
}
