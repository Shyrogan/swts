import Bar from "./Bar";
import QuickSettings from "widgets/quick-settings/Root"

App.config({
  style: "./style.css",
  windows: [
    Bar(),
    QuickSettings.Window()
  ]
})
