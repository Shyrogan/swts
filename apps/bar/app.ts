import { App } from "astal/gtk3"
import style from "./style.scss"
import Bar from "./widgets/Bar"
import QuickSettingsMenu from "./widgets/quick-settings/Menu"

App.start({
  css: style,
  iconTheme: "MoreWaita",
  main() {
    App.get_monitors().map(Bar)
    // Other menus
    App.get_monitors().map(QuickSettingsMenu)
  },
})
