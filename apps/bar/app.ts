import { App, Gdk, Gtk } from "astal/gtk3"
import { bind } from "astal"
import style from "./style.scss"
import Bar from "./widgets/Bar"
import QuickSettingsMenu from "./widgets/quick-settings/Menu"

const bars = new Map<Gdk.Monitor, Gtk.Widget[]>()

function addWindows(monitor: Gdk.Monitor) {
  const bar = Bar(monitor)
  const qsMenu = QuickSettingsMenu(monitor)
  bars.set(monitor, [bar, qsMenu])
}

function destroyWindows(monitor: Gdk.Monitor) {
  bars.get(monitor)?.forEach(w => w.destroy())
  bars.delete(monitor)
}

App.start({
  css: style,
  iconTheme: "MoreWaita",
  main() {
    App.get_monitors().map(addWindows)

    // On adding/removing display
    App.connect('monitor-added', (_, monitor) => addWindows(monitor))
    App.connect('monitor-removed', (_, monitor) => destroyWindows(monitor))
  },
})
