import Tray from "gi://AstalTray"
import { App, Gdk } from "astal/gtk3"
import { bind } from "astal"

export default function SysTray() {
  const tray = Tray.get_default()
  const items = bind(tray, 'items')
  
  print("Items: ", items.get())
  items.subscribe((v) => print("Items: ", v))

  return <box className="tray">
    {items.as((items) => items.map(t => <Item item={t} /> ))}
  </box>
}

function Item({ item } : { item: Tray.TrayItem }) {
   if (item.iconThemePath)
      App.add_icons(item.iconThemePath)

  const menu = item.create_menu()
  return <button
      tooltipMarkup={bind(item, "tooltipMarkup")}
      onDestroy={() => menu?.destroy()}
      onClickRelease={self => {
          menu?.popup_at_widget(self, Gdk.Gravity.SOUTH, Gdk.Gravity.NORTH, null)
      }}>
      <icon gIcon={bind(item, "gicon")} />
  </button>
}
