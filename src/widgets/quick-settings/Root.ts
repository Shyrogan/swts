const isOpen = Variable(false)

function Window() {
  return Widget.Window({
    name: "quick-settings",
    anchor: ["top", "right"],
    child: Widget.Box({
      child: Widget.Revealer({
        revealChild: isOpen.bind(),
        transition: "slide_down",
        transitionDuration: 200,
        child: Widget.Label('hello!'),
        setup: (self) => (self.reveal_child = true),
      })
    }),
  })
}

function Button() {
  return Widget.Button({
    label: "Quick Settings",
    onClicked: () => {
      isOpen.value = true;
    }
  })
}

export default {
  Window,
  Button,
};

