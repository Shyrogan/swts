import { App } from "astal/gtk3"
import style from "../tailwind.scss"
import Desktop from "../components/Desktop"

App.start({
  css: style,
  main() {
    App.get_monitors().map(Desktop)
  },
})
