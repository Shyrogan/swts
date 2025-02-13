// ../../../../../nix/store/1ckqvmr9hngfanwa6aw23cskymvh215c-astal-gjs/share/astal/gjs/gtk3/index.ts
import Astal7 from "gi://Astal?version=3.0";
import Gtk4 from "gi://Gtk?version=3.0";
import Gdk from "gi://Gdk?version=3.0";

// ../../../../../nix/store/1ckqvmr9hngfanwa6aw23cskymvh215c-astal-gjs/share/astal/gjs/variable.ts
import Astal3 from "gi://AstalIO";

// ../../../../../nix/store/1ckqvmr9hngfanwa6aw23cskymvh215c-astal-gjs/share/astal/gjs/binding.ts
var snakeify = (str) => str.replace(/([a-z])([A-Z])/g, "$1_$2").replaceAll("-", "_").toLowerCase();
var kebabify = (str) => str.replace(/([a-z])([A-Z])/g, "$1-$2").replaceAll("_", "-").toLowerCase();
var Binding = class _Binding {
  transformFn = (v) => v;
  #emitter;
  #prop;
  static bind(emitter, prop) {
    return new _Binding(emitter, prop);
  }
  constructor(emitter, prop) {
    this.#emitter = emitter;
    this.#prop = prop && kebabify(prop);
  }
  toString() {
    return `Binding<${this.#emitter}${this.#prop ? `, "${this.#prop}"` : ""}>`;
  }
  as(fn) {
    const bind2 = new _Binding(this.#emitter, this.#prop);
    bind2.transformFn = (v) => fn(this.transformFn(v));
    return bind2;
  }
  get() {
    if (typeof this.#emitter.get === "function")
      return this.transformFn(this.#emitter.get());
    if (typeof this.#prop === "string") {
      const getter = `get_${snakeify(this.#prop)}`;
      if (typeof this.#emitter[getter] === "function")
        return this.transformFn(this.#emitter[getter]());
      return this.transformFn(this.#emitter[this.#prop]);
    }
    throw Error("can not get value of binding");
  }
  subscribe(callback) {
    if (typeof this.#emitter.subscribe === "function") {
      return this.#emitter.subscribe(() => {
        callback(this.get());
      });
    } else if (typeof this.#emitter.connect === "function") {
      const signal = `notify::${this.#prop}`;
      const id = this.#emitter.connect(signal, () => {
        callback(this.get());
      });
      return () => {
        this.#emitter.disconnect(id);
      };
    }
    throw Error(`${this.#emitter} is not bindable`);
  }
};
var { bind } = Binding;
var binding_default = Binding;

// ../../../../../nix/store/1ckqvmr9hngfanwa6aw23cskymvh215c-astal-gjs/share/astal/gjs/time.ts
import Astal from "gi://AstalIO";
var Time = Astal.Time;
function interval(interval2, callback) {
  return Astal.Time.interval(interval2, () => void callback?.());
}

// ../../../../../nix/store/1ckqvmr9hngfanwa6aw23cskymvh215c-astal-gjs/share/astal/gjs/process.ts
import Astal2 from "gi://AstalIO";
var Process = Astal2.Process;
function subprocess(argsOrCmd, onOut = print, onErr = printerr) {
  const args = Array.isArray(argsOrCmd) || typeof argsOrCmd === "string";
  const { cmd, err, out } = {
    cmd: args ? argsOrCmd : argsOrCmd.cmd,
    err: args ? onErr : argsOrCmd.err || onErr,
    out: args ? onOut : argsOrCmd.out || onOut
  };
  const proc = Array.isArray(cmd) ? Astal2.Process.subprocessv(cmd) : Astal2.Process.subprocess(cmd);
  proc.connect("stdout", (_, stdout) => out(stdout));
  proc.connect("stderr", (_, stderr) => err(stderr));
  return proc;
}
function execAsync(cmd) {
  return new Promise((resolve, reject) => {
    if (Array.isArray(cmd)) {
      Astal2.Process.exec_asyncv(cmd, (_, res) => {
        try {
          resolve(Astal2.Process.exec_asyncv_finish(res));
        } catch (error) {
          reject(error);
        }
      });
    } else {
      Astal2.Process.exec_async(cmd, (_, res) => {
        try {
          resolve(Astal2.Process.exec_finish(res));
        } catch (error) {
          reject(error);
        }
      });
    }
  });
}

// ../../../../../nix/store/1ckqvmr9hngfanwa6aw23cskymvh215c-astal-gjs/share/astal/gjs/variable.ts
var VariableWrapper = class extends Function {
  variable;
  errHandler = console.error;
  _value;
  _poll;
  _watch;
  pollInterval = 1e3;
  pollExec;
  pollTransform;
  pollFn;
  watchTransform;
  watchExec;
  constructor(init) {
    super();
    this._value = init;
    this.variable = new Astal3.VariableBase();
    this.variable.connect("dropped", () => {
      this.stopWatch();
      this.stopPoll();
    });
    this.variable.connect("error", (_, err) => this.errHandler?.(err));
    return new Proxy(this, {
      apply: (target, _, args) => target._call(args[0])
    });
  }
  _call(transform2) {
    const b = binding_default.bind(this);
    return transform2 ? b.as(transform2) : b;
  }
  toString() {
    return String(`Variable<${this.get()}>`);
  }
  get() {
    return this._value;
  }
  set(value) {
    if (value !== this._value) {
      this._value = value;
      this.variable.emit("changed");
    }
  }
  startPoll() {
    if (this._poll)
      return;
    if (this.pollFn) {
      this._poll = interval(this.pollInterval, () => {
        const v = this.pollFn(this.get());
        if (v instanceof Promise) {
          v.then((v2) => this.set(v2)).catch((err) => this.variable.emit("error", err));
        } else {
          this.set(v);
        }
      });
    } else if (this.pollExec) {
      this._poll = interval(this.pollInterval, () => {
        execAsync(this.pollExec).then((v) => this.set(this.pollTransform(v, this.get()))).catch((err) => this.variable.emit("error", err));
      });
    }
  }
  startWatch() {
    if (this._watch)
      return;
    this._watch = subprocess({
      cmd: this.watchExec,
      out: (out) => this.set(this.watchTransform(out, this.get())),
      err: (err) => this.variable.emit("error", err)
    });
  }
  stopPoll() {
    this._poll?.cancel();
    delete this._poll;
  }
  stopWatch() {
    this._watch?.kill();
    delete this._watch;
  }
  isPolling() {
    return !!this._poll;
  }
  isWatching() {
    return !!this._watch;
  }
  drop() {
    this.variable.emit("dropped");
  }
  onDropped(callback) {
    this.variable.connect("dropped", callback);
    return this;
  }
  onError(callback) {
    delete this.errHandler;
    this.variable.connect("error", (_, err) => callback(err));
    return this;
  }
  subscribe(callback) {
    const id = this.variable.connect("changed", () => {
      callback(this.get());
    });
    return () => this.variable.disconnect(id);
  }
  poll(interval2, exec, transform2 = (out) => out) {
    this.stopPoll();
    this.pollInterval = interval2;
    this.pollTransform = transform2;
    if (typeof exec === "function") {
      this.pollFn = exec;
      delete this.pollExec;
    } else {
      this.pollExec = exec;
      delete this.pollFn;
    }
    this.startPoll();
    return this;
  }
  watch(exec, transform2 = (out) => out) {
    this.stopWatch();
    this.watchExec = exec;
    this.watchTransform = transform2;
    this.startWatch();
    return this;
  }
  observe(objs, sigOrFn, callback) {
    const f = typeof sigOrFn === "function" ? sigOrFn : callback ?? (() => this.get());
    const set = (obj, ...args) => this.set(f(obj, ...args));
    if (Array.isArray(objs)) {
      for (const obj of objs) {
        const [o, s] = obj;
        const id = o.connect(s, set);
        this.onDropped(() => o.disconnect(id));
      }
    } else {
      if (typeof sigOrFn === "string") {
        const id = objs.connect(sigOrFn, set);
        this.onDropped(() => objs.disconnect(id));
      }
    }
    return this;
  }
  static derive(deps, fn = (...args) => args) {
    const update = () => fn(...deps.map((d) => d.get()));
    const derived = new Variable(update());
    const unsubs = deps.map((dep) => dep.subscribe(() => derived.set(update())));
    derived.onDropped(() => unsubs.map((unsub) => unsub()));
    return derived;
  }
};
var Variable = new Proxy(VariableWrapper, {
  apply: (_t, _a, args) => new VariableWrapper(args[0])
});
var { derive } = Variable;
var variable_default = Variable;

// ../../../../../nix/store/1ckqvmr9hngfanwa6aw23cskymvh215c-astal-gjs/share/astal/gjs/_astal.ts
var noImplicitDestroy = Symbol("no no implicit destroy");
var setChildren = Symbol("children setter method");
function mergeBindings(array) {
  function getValues(...args) {
    let i = 0;
    return array.map(
      (value) => value instanceof binding_default ? args[i++] : value
    );
  }
  const bindings = array.filter((i) => i instanceof binding_default);
  if (bindings.length === 0)
    return array;
  if (bindings.length === 1)
    return bindings[0].as(getValues);
  return variable_default.derive(bindings, getValues)();
}
function setProp(obj, prop, value) {
  try {
    const setter = `set_${snakeify(prop)}`;
    if (typeof obj[setter] === "function")
      return obj[setter](value);
    return obj[prop] = value;
  } catch (error) {
    console.error(`could not set property "${prop}" on ${obj}:`, error);
  }
}
function hook(widget, object, signalOrCallback, callback) {
  if (typeof object.connect === "function" && callback) {
    const id = object.connect(signalOrCallback, (_, ...args) => {
      return callback(widget, ...args);
    });
    widget.connect("destroy", () => {
      object.disconnect(id);
    });
  } else if (typeof object.subscribe === "function" && typeof signalOrCallback === "function") {
    const unsub = object.subscribe((...args) => {
      signalOrCallback(widget, ...args);
    });
    widget.connect("destroy", unsub);
  }
}
function construct(widget, config) {
  let { setup, child, children = [], ...props } = config;
  if (children instanceof binding_default) {
    children = [children];
  }
  if (child) {
    children.unshift(child);
  }
  for (const [key, value] of Object.entries(props)) {
    if (value === void 0) {
      delete props[key];
    }
  }
  const bindings = Object.keys(props).reduce((acc, prop) => {
    if (props[prop] instanceof binding_default) {
      const binding = props[prop];
      delete props[prop];
      return [...acc, [prop, binding]];
    }
    return acc;
  }, []);
  const onHandlers = Object.keys(props).reduce((acc, key) => {
    if (key.startsWith("on")) {
      const sig = kebabify(key).split("-").slice(1).join("-");
      const handler = props[key];
      delete props[key];
      return [...acc, [sig, handler]];
    }
    return acc;
  }, []);
  const mergedChildren = mergeBindings(children.flat(Infinity));
  if (mergedChildren instanceof binding_default) {
    widget[setChildren](mergedChildren.get());
    widget.connect("destroy", mergedChildren.subscribe((v) => {
      widget[setChildren](v);
    }));
  } else {
    if (mergedChildren.length > 0) {
      widget[setChildren](mergedChildren);
    }
  }
  for (const [signal, callback] of onHandlers) {
    const sig = signal.startsWith("notify") ? signal.replace("-", "::") : signal;
    if (typeof callback === "function") {
      widget.connect(sig, callback);
    } else {
      widget.connect(sig, () => execAsync(callback).then(print).catch(console.error));
    }
  }
  for (const [prop, binding] of bindings) {
    if (prop === "child" || prop === "children") {
      widget.connect("destroy", binding.subscribe((v) => {
        widget[setChildren](v);
      }));
    }
    widget.connect("destroy", binding.subscribe((v) => {
      setProp(widget, prop, v);
    }));
    setProp(widget, prop, binding.get());
  }
  for (const [key, value] of Object.entries(props)) {
    if (value === void 0) {
      delete props[key];
    }
  }
  Object.assign(widget, props);
  setup?.(widget);
  return widget;
}
function isArrowFunction(func) {
  return !Object.hasOwn(func, "prototype");
}
function jsx(ctors2, ctor, { children, ...props }) {
  children ??= [];
  if (!Array.isArray(children))
    children = [children];
  children = children.filter(Boolean);
  if (children.length === 1)
    props.child = children[0];
  else if (children.length > 1)
    props.children = children;
  if (typeof ctor === "string") {
    if (isArrowFunction(ctors2[ctor]))
      return ctors2[ctor](props);
    return new ctors2[ctor](props);
  }
  if (isArrowFunction(ctor))
    return ctor(props);
  return new ctor(props);
}

// ../../../../../nix/store/1ckqvmr9hngfanwa6aw23cskymvh215c-astal-gjs/share/astal/gjs/gtk3/astalify.ts
import Astal4 from "gi://Astal?version=3.0";
import Gtk from "gi://Gtk?version=3.0";
import GObject from "gi://GObject";
function astalify(cls, clsName = cls.name) {
  class Widget extends cls {
    get css() {
      return Astal4.widget_get_css(this);
    }
    set css(css) {
      Astal4.widget_set_css(this, css);
    }
    get_css() {
      return this.css;
    }
    set_css(css) {
      this.css = css;
    }
    get className() {
      return Astal4.widget_get_class_names(this).join(" ");
    }
    set className(className) {
      Astal4.widget_set_class_names(this, className.split(/\s+/));
    }
    get_class_name() {
      return this.className;
    }
    set_class_name(className) {
      this.className = className;
    }
    get cursor() {
      return Astal4.widget_get_cursor(this);
    }
    set cursor(cursor) {
      Astal4.widget_set_cursor(this, cursor);
    }
    get_cursor() {
      return this.cursor;
    }
    set_cursor(cursor) {
      this.cursor = cursor;
    }
    get clickThrough() {
      return Astal4.widget_get_click_through(this);
    }
    set clickThrough(clickThrough) {
      Astal4.widget_set_click_through(this, clickThrough);
    }
    get_click_through() {
      return this.clickThrough;
    }
    set_click_through(clickThrough) {
      this.clickThrough = clickThrough;
    }
    get noImplicitDestroy() {
      return this[noImplicitDestroy];
    }
    set noImplicitDestroy(value) {
      this[noImplicitDestroy] = value;
    }
    set actionGroup([prefix, group]) {
      this.insert_action_group(prefix, group);
    }
    set_action_group(actionGroup) {
      this.actionGroup = actionGroup;
    }
    getChildren() {
      if (this instanceof Gtk.Bin) {
        return this.get_child() ? [this.get_child()] : [];
      } else if (this instanceof Gtk.Container) {
        return this.get_children();
      }
      return [];
    }
    setChildren(children) {
      children = children.flat(Infinity).map((ch) => ch instanceof Gtk.Widget ? ch : new Gtk.Label({ visible: true, label: String(ch) }));
      if (this instanceof Gtk.Container) {
        for (const ch of children)
          this.add(ch);
      } else {
        throw Error(`can not add children to ${this.constructor.name}`);
      }
    }
    [setChildren](children) {
      if (this instanceof Gtk.Container) {
        for (const ch of this.getChildren()) {
          this.remove(ch);
          if (!children.includes(ch) && !this.noImplicitDestroy)
            ch?.destroy();
        }
      }
      this.setChildren(children);
    }
    toggleClassName(cn, cond = true) {
      Astal4.widget_toggle_class_name(this, cn, cond);
    }
    hook(object, signalOrCallback, callback) {
      hook(this, object, signalOrCallback, callback);
      return this;
    }
    constructor(...params) {
      super();
      const props = params[0] || {};
      props.visible ??= true;
      construct(this, props);
    }
  }
  GObject.registerClass({
    GTypeName: `Astal_${clsName}`,
    Properties: {
      "class-name": GObject.ParamSpec.string(
        "class-name",
        "",
        "",
        GObject.ParamFlags.READWRITE,
        ""
      ),
      "css": GObject.ParamSpec.string(
        "css",
        "",
        "",
        GObject.ParamFlags.READWRITE,
        ""
      ),
      "cursor": GObject.ParamSpec.string(
        "cursor",
        "",
        "",
        GObject.ParamFlags.READWRITE,
        "default"
      ),
      "click-through": GObject.ParamSpec.boolean(
        "click-through",
        "",
        "",
        GObject.ParamFlags.READWRITE,
        false
      ),
      "no-implicit-destroy": GObject.ParamSpec.boolean(
        "no-implicit-destroy",
        "",
        "",
        GObject.ParamFlags.READWRITE,
        false
      )
    }
  }, Widget);
  return Widget;
}

// ../../../../../nix/store/1ckqvmr9hngfanwa6aw23cskymvh215c-astal-gjs/share/astal/gjs/gtk3/app.ts
import Gtk2 from "gi://Gtk?version=3.0";
import Astal5 from "gi://Astal?version=3.0";

// ../../../../../nix/store/1ckqvmr9hngfanwa6aw23cskymvh215c-astal-gjs/share/astal/gjs/overrides.ts
var snakeify2 = (str) => str.replace(/([a-z])([A-Z])/g, "$1_$2").replaceAll("-", "_").toLowerCase();
async function suppress(mod, patch2) {
  return mod.then((m) => patch2(m.default)).catch(() => void 0);
}
function patch(proto, prop) {
  Object.defineProperty(proto, prop, {
    get() {
      return this[`get_${snakeify2(prop)}`]();
    }
  });
}
await suppress(import("gi://AstalApps"), ({ Apps, Application }) => {
  patch(Apps.prototype, "list");
  patch(Application.prototype, "keywords");
  patch(Application.prototype, "categories");
});
await suppress(import("gi://AstalBattery"), ({ UPower }) => {
  patch(UPower.prototype, "devices");
});
await suppress(import("gi://AstalBluetooth"), ({ Adapter, Bluetooth, Device }) => {
  patch(Adapter.prototype, "uuids");
  patch(Bluetooth.prototype, "adapters");
  patch(Bluetooth.prototype, "devices");
  patch(Device.prototype, "uuids");
});
await suppress(import("gi://AstalHyprland"), ({ Hyprland, Monitor, Workspace: Workspace2 }) => {
  patch(Hyprland.prototype, "monitors");
  patch(Hyprland.prototype, "workspaces");
  patch(Hyprland.prototype, "clients");
  patch(Monitor.prototype, "availableModes");
  patch(Monitor.prototype, "available_modes");
  patch(Workspace2.prototype, "clients");
});
await suppress(import("gi://AstalMpris"), ({ Mpris, Player }) => {
  patch(Mpris.prototype, "players");
  patch(Player.prototype, "supported_uri_schemes");
  patch(Player.prototype, "supportedUriSchemes");
  patch(Player.prototype, "supported_mime_types");
  patch(Player.prototype, "supportedMimeTypes");
  patch(Player.prototype, "comments");
});
await suppress(import("gi://AstalNetwork"), ({ Wifi }) => {
  patch(Wifi.prototype, "access_points");
  patch(Wifi.prototype, "accessPoints");
});
await suppress(import("gi://AstalNotifd"), ({ Notifd, Notification }) => {
  patch(Notifd.prototype, "notifications");
  patch(Notification.prototype, "actions");
});
await suppress(import("gi://AstalPowerProfiles"), ({ PowerProfiles }) => {
  patch(PowerProfiles.prototype, "actions");
});
await suppress(import("gi://AstalWp"), ({ Wp, Audio, Video }) => {
  patch(Wp.prototype, "endpoints");
  patch(Wp.prototype, "devices");
  patch(Audio.prototype, "streams");
  patch(Audio.prototype, "recorders");
  patch(Audio.prototype, "microphones");
  patch(Audio.prototype, "speakers");
  patch(Audio.prototype, "devices");
  patch(Video.prototype, "streams");
  patch(Video.prototype, "recorders");
  patch(Video.prototype, "sinks");
  patch(Video.prototype, "sources");
  patch(Video.prototype, "devices");
});

// ../../../../../nix/store/1ckqvmr9hngfanwa6aw23cskymvh215c-astal-gjs/share/astal/gjs/_app.ts
import { setConsoleLogDomain } from "console";
import { exit, programArgs } from "system";
import IO from "gi://AstalIO";
import GObject2 from "gi://GObject";
function mkApp(App) {
  return new class AstalJS extends App {
    static {
      GObject2.registerClass({ GTypeName: "AstalJS" }, this);
    }
    eval(body) {
      return new Promise((res, rej) => {
        try {
          const fn = Function(`return (async function() {
                        ${body.includes(";") ? body : `return ${body};`}
                    })`);
          fn()().then(res).catch(rej);
        } catch (error) {
          rej(error);
        }
      });
    }
    requestHandler;
    vfunc_request(msg, conn) {
      if (typeof this.requestHandler === "function") {
        this.requestHandler(msg, (response) => {
          IO.write_sock(
            conn,
            String(response),
            (_, res) => IO.write_sock_finish(res)
          );
        });
      } else {
        super.vfunc_request(msg, conn);
      }
    }
    apply_css(style, reset = false) {
      super.apply_css(style, reset);
    }
    quit(code) {
      super.quit();
      exit(code ?? 0);
    }
    start({ requestHandler, css, hold, main, client, icons, ...cfg } = {}) {
      const app = this;
      client ??= () => {
        print(`Astal instance "${app.instanceName}" already running`);
        exit(1);
      };
      Object.assign(this, cfg);
      setConsoleLogDomain(app.instanceName);
      this.requestHandler = requestHandler;
      app.connect("activate", () => {
        main?.(...programArgs);
      });
      try {
        app.acquire_socket();
      } catch (error) {
        return client((msg) => IO.send_message(app.instanceName, msg), ...programArgs);
      }
      if (css)
        this.apply_css(css, false);
      if (icons)
        app.add_icons(icons);
      hold ??= true;
      if (hold)
        app.hold();
      app.runAsync([]);
    }
  }();
}

// ../../../../../nix/store/1ckqvmr9hngfanwa6aw23cskymvh215c-astal-gjs/share/astal/gjs/gtk3/app.ts
Gtk2.init(null);
var app_default = mkApp(Astal5.Application);

// ../../../../../nix/store/1ckqvmr9hngfanwa6aw23cskymvh215c-astal-gjs/share/astal/gjs/gtk3/widget.ts
import Astal6 from "gi://Astal?version=3.0";
import Gtk3 from "gi://Gtk?version=3.0";
import GObject3 from "gi://GObject";
function filter(children) {
  return children.flat(Infinity).map((ch) => ch instanceof Gtk3.Widget ? ch : new Gtk3.Label({ visible: true, label: String(ch) }));
}
Object.defineProperty(Astal6.Box.prototype, "children", {
  get() {
    return this.get_children();
  },
  set(v) {
    this.set_children(v);
  }
});
var Box = class extends astalify(Astal6.Box) {
  static {
    GObject3.registerClass({ GTypeName: "Box" }, this);
  }
  constructor(props, ...children) {
    super({ children, ...props });
  }
  setChildren(children) {
    this.set_children(filter(children));
  }
};
var Button = class extends astalify(Astal6.Button) {
  static {
    GObject3.registerClass({ GTypeName: "Button" }, this);
  }
  constructor(props, child) {
    super({ child, ...props });
  }
};
var CenterBox = class extends astalify(Astal6.CenterBox) {
  static {
    GObject3.registerClass({ GTypeName: "CenterBox" }, this);
  }
  constructor(props, ...children) {
    super({ children, ...props });
  }
  setChildren(children) {
    const ch = filter(children);
    this.startWidget = ch[0] || new Gtk3.Box();
    this.centerWidget = ch[1] || new Gtk3.Box();
    this.endWidget = ch[2] || new Gtk3.Box();
  }
};
var CircularProgress = class extends astalify(Astal6.CircularProgress) {
  static {
    GObject3.registerClass({ GTypeName: "CircularProgress" }, this);
  }
  constructor(props, child) {
    super({ child, ...props });
  }
};
var DrawingArea = class extends astalify(Gtk3.DrawingArea) {
  static {
    GObject3.registerClass({ GTypeName: "DrawingArea" }, this);
  }
  constructor(props) {
    super(props);
  }
};
var Entry = class extends astalify(Gtk3.Entry) {
  static {
    GObject3.registerClass({ GTypeName: "Entry" }, this);
  }
  constructor(props) {
    super(props);
  }
};
var EventBox = class extends astalify(Astal6.EventBox) {
  static {
    GObject3.registerClass({ GTypeName: "EventBox" }, this);
  }
  constructor(props, child) {
    super({ child, ...props });
  }
};
var Icon = class extends astalify(Astal6.Icon) {
  static {
    GObject3.registerClass({ GTypeName: "Icon" }, this);
  }
  constructor(props) {
    super(props);
  }
};
var Label = class extends astalify(Astal6.Label) {
  static {
    GObject3.registerClass({ GTypeName: "Label" }, this);
  }
  constructor(props) {
    super(props);
  }
  setChildren(children) {
    this.label = String(children);
  }
};
var LevelBar = class extends astalify(Astal6.LevelBar) {
  static {
    GObject3.registerClass({ GTypeName: "LevelBar" }, this);
  }
  constructor(props) {
    super(props);
  }
};
var MenuButton = class extends astalify(Gtk3.MenuButton) {
  static {
    GObject3.registerClass({ GTypeName: "MenuButton" }, this);
  }
  constructor(props, child) {
    super({ child, ...props });
  }
};
Object.defineProperty(Astal6.Overlay.prototype, "overlays", {
  get() {
    return this.get_overlays();
  },
  set(v) {
    this.set_overlays(v);
  }
});
var Overlay = class extends astalify(Astal6.Overlay) {
  static {
    GObject3.registerClass({ GTypeName: "Overlay" }, this);
  }
  constructor(props, ...children) {
    super({ children, ...props });
  }
  setChildren(children) {
    const [child, ...overlays] = filter(children);
    this.set_child(child);
    this.set_overlays(overlays);
  }
};
var Revealer = class extends astalify(Gtk3.Revealer) {
  static {
    GObject3.registerClass({ GTypeName: "Revealer" }, this);
  }
  constructor(props, child) {
    super({ child, ...props });
  }
};
var Scrollable = class extends astalify(Astal6.Scrollable) {
  static {
    GObject3.registerClass({ GTypeName: "Scrollable" }, this);
  }
  constructor(props, child) {
    super({ child, ...props });
  }
};
var Slider = class extends astalify(Astal6.Slider) {
  static {
    GObject3.registerClass({ GTypeName: "Slider" }, this);
  }
  constructor(props) {
    super(props);
  }
};
var Stack = class extends astalify(Astal6.Stack) {
  static {
    GObject3.registerClass({ GTypeName: "Stack" }, this);
  }
  constructor(props, ...children) {
    super({ children, ...props });
  }
  setChildren(children) {
    this.set_children(filter(children));
  }
};
var Switch = class extends astalify(Gtk3.Switch) {
  static {
    GObject3.registerClass({ GTypeName: "Switch" }, this);
  }
  constructor(props) {
    super(props);
  }
};
var Window = class extends astalify(Astal6.Window) {
  static {
    GObject3.registerClass({ GTypeName: "Window" }, this);
  }
  constructor(props, child) {
    super({ child, ...props });
  }
};

// sass:/home/sebastien/Documents/personal-projects/swts/tailwind.scss
var tailwind_default = "/* Base16 Gruvbox Dark Hard Color Palette - SCSS Variables */\n/* Font Sizes */\n/* Reset GTK3 component styling */\n/* General Reset */\n* {\n  padding: 0;\n  margin: 0;\n  border: 0;\n  font-family: sans-serif;\n  font-size: 12px;\n}\n\n/* Remove default background and borders */\nGtkWidget {\n  background: transparent;\n  border: none;\n}\n\n/* Remove default padding for all containers */\nGtkContainer {\n  padding: 0;\n  margin: 0;\n}\n\n/* Remove default styling from buttons */\nbutton, GtkButton {\n  padding: 0;\n  border: none;\n  background: transparent;\n  box-shadow: none;\n  text-shadow: none;\n}\n\n/* Remove default border and background for entry widgets */\nGtkEntry, GtkTextView, GtkComboBox {\n  padding: 0;\n  margin: 0;\n  border: none;\n  background: transparent;\n  box-shadow: none;\n}\n\n/* Remove default padding and border for labels */\nGtkLabel {\n  padding: 0;\n  margin: 0;\n  border: none;\n  background: transparent;\n  text-shadow: none;\n}\n\n/* Remove default styling from sliders */\nGtkScale, GtkScrollbar {\n  padding: 0;\n  margin: 0;\n  border: none;\n  background: transparent;\n}\n\n/* Remove default styling from menus */\nGtkMenu, GtkMenuItem {\n  padding: 0;\n  margin: 0;\n  border: none;\n  background: transparent;\n}\n\n/* Remove default shadow from windows */\nGtkWindow {\n  border: none;\n  background: transparent;\n  box-shadow: none;\n}\n\n/* Remove default styling for tooltips */\nGtkTooltip {\n  border: none;\n  background: transparent;\n}\n\n/* Padding All Sides */\n.p-0 {\n  padding: 0;\n}\n\n.p-1 {\n  padding: 4px;\n}\n\n.p-1 {\n  padding: 4px;\n}\n\n.p-2 {\n  padding: 8px;\n}\n\n.p-3 {\n  padding: 12px;\n}\n\n.p-4 {\n  padding: 16px;\n}\n\n.p-5 {\n  padding: 20px;\n}\n\n.p-6 {\n  padding: 24px;\n}\n\n.p-7 {\n  padding: 28px;\n}\n\n.p-8 {\n  padding: 32px;\n}\n\n.p-9 {\n  padding: 36px;\n}\n\n.p-10 {\n  padding: 40px;\n}\n\n.p-11 {\n  padding: 44px;\n}\n\n.p-12 {\n  padding: 48px;\n}\n\n.p-13 {\n  padding: 52px;\n}\n\n.p-14 {\n  padding: 56px;\n}\n\n.p-15 {\n  padding: 60px;\n}\n\n.p-16 {\n  padding: 64px;\n}\n\n/* Horizontal Padding (Left & Right) */\n.px-0 {\n  padding-left: 0;\n  padding-right: 0;\n}\n\n.px-1 {\n  padding-left: 4px;\n  padding-right: 4px;\n}\n\n.px-2 {\n  padding-left: 8px;\n  padding-right: 8px;\n}\n\n.px-3 {\n  padding-left: 12px;\n  padding-right: 12px;\n}\n\n.px-4 {\n  padding-left: 16px;\n  padding-right: 16px;\n}\n\n.px-5 {\n  padding-left: 20px;\n  padding-right: 20px;\n}\n\n.px-6 {\n  padding-left: 24px;\n  padding-right: 24px;\n}\n\n.px-7 {\n  padding-left: 28px;\n  padding-right: 28px;\n}\n\n.px-8 {\n  padding-left: 32px;\n  padding-right: 32px;\n}\n\n.px-9 {\n  padding-left: 36px;\n  padding-right: 36px;\n}\n\n.px-10 {\n  padding-left: 40px;\n  padding-right: 40px;\n}\n\n.px-11 {\n  padding-left: 44px;\n  padding-right: 44px;\n}\n\n.px-12 {\n  padding-left: 48px;\n  padding-right: 48px;\n}\n\n.px-13 {\n  padding-left: 52px;\n  padding-right: 52px;\n}\n\n.px-14 {\n  padding-left: 56px;\n  padding-right: 56px;\n}\n\n.px-15 {\n  padding-left: 60px;\n  padding-right: 60px;\n}\n\n.px-16 {\n  padding-left: 64px;\n  padding-right: 64px;\n}\n\n/* Vertical Padding (Top & Bottom) */\n.py-0 {\n  padding-top: 0;\n  padding-bottom: 0;\n}\n\n.py-1 {\n  padding-top: 4px;\n  padding-bottom: 4px;\n}\n\n.py-2 {\n  padding-top: 8px;\n  padding-bottom: 8px;\n}\n\n.py-3 {\n  padding-top: 12px;\n  padding-bottom: 12px;\n}\n\n.py-4 {\n  padding-top: 16px;\n  padding-bottom: 16px;\n}\n\n.py-5 {\n  padding-top: 20px;\n  padding-bottom: 20px;\n}\n\n.py-6 {\n  padding-top: 24px;\n  padding-bottom: 24px;\n}\n\n.py-7 {\n  padding-top: 28px;\n  padding-bottom: 28px;\n}\n\n.py-8 {\n  padding-top: 32px;\n  padding-bottom: 32px;\n}\n\n.py-9 {\n  padding-top: 36px;\n  padding-bottom: 36px;\n}\n\n.py-10 {\n  padding-top: 40px;\n  padding-bottom: 40px;\n}\n\n.py-11 {\n  padding-top: 44px;\n  padding-bottom: 44px;\n}\n\n.py-12 {\n  padding-top: 48px;\n  padding-bottom: 48px;\n}\n\n.py-13 {\n  padding-top: 52px;\n  padding-bottom: 52px;\n}\n\n.py-14 {\n  padding-top: 56px;\n  padding-bottom: 56px;\n}\n\n.py-15 {\n  padding-top: 60px;\n  padding-bottom: 60px;\n}\n\n.py-16 {\n  padding-top: 64px;\n  padding-bottom: 64px;\n}\n\n/* Padding Left */\n.pl-0 {\n  padding-left: 0;\n}\n\n.pl-1 {\n  padding-left: 4px;\n}\n\n.pl-2 {\n  padding-left: 8px;\n}\n\n.pl-3 {\n  padding-left: 12px;\n}\n\n.pl-4 {\n  padding-left: 16px;\n}\n\n.pl-5 {\n  padding-left: 20px;\n}\n\n.pl-6 {\n  padding-left: 24px;\n}\n\n.pl-7 {\n  padding-left: 28px;\n}\n\n.pl-8 {\n  padding-left: 32px;\n}\n\n.pl-9 {\n  padding-left: 36px;\n}\n\n.pl-10 {\n  padding-left: 40px;\n}\n\n.pl-11 {\n  padding-left: 44px;\n}\n\n.pl-12 {\n  padding-left: 48px;\n}\n\n.pl-13 {\n  padding-left: 52px;\n}\n\n.pl-14 {\n  padding-left: 56px;\n}\n\n.pl-15 {\n  padding-left: 60px;\n}\n\n.pl-16 {\n  padding-left: 64px;\n}\n\n/* Padding Right */\n.pr-0 {\n  padding-right: 0;\n}\n\n.pr-1 {\n  padding-right: 4px;\n}\n\n.pr-2 {\n  padding-right: 8px;\n}\n\n.pr-3 {\n  padding-right: 12px;\n}\n\n.pr-4 {\n  padding-right: 16px;\n}\n\n.pr-5 {\n  padding-right: 20px;\n}\n\n.pr-6 {\n  padding-right: 24px;\n}\n\n.pr-7 {\n  padding-right: 28px;\n}\n\n.pr-8 {\n  padding-right: 32px;\n}\n\n.pr-9 {\n  padding-right: 36px;\n}\n\n.pr-10 {\n  padding-right: 40px;\n}\n\n.pr-11 {\n  padding-right: 44px;\n}\n\n.pr-12 {\n  padding-right: 48px;\n}\n\n.pr-13 {\n  padding-right: 52px;\n}\n\n.pr-14 {\n  padding-right: 56px;\n}\n\n.pr-15 {\n  padding-right: 60px;\n}\n\n.pr-16 {\n  padding-right: 64px;\n}\n\n/* Padding Top */\n.pt-0 {\n  padding-top: 0;\n}\n\n.pt-1 {\n  padding-top: 4px;\n}\n\n.pt-2 {\n  padding-top: 8px;\n}\n\n.pt-3 {\n  padding-top: 12px;\n}\n\n.pt-4 {\n  padding-top: 16px;\n}\n\n.pt-5 {\n  padding-top: 20px;\n}\n\n.pt-6 {\n  padding-top: 24px;\n}\n\n.pt-7 {\n  padding-top: 28px;\n}\n\n.pt-8 {\n  padding-top: 32px;\n}\n\n.pt-9 {\n  padding-top: 36px;\n}\n\n.pt-10 {\n  padding-top: 40px;\n}\n\n.pt-11 {\n  padding-top: 44px;\n}\n\n.pt-12 {\n  padding-top: 48px;\n}\n\n.pt-13 {\n  padding-top: 52px;\n}\n\n.pt-14 {\n  padding-top: 56px;\n}\n\n.pt-15 {\n  padding-top: 60px;\n}\n\n.pt-16 {\n  padding-top: 64px;\n}\n\n/* Padding Bottom */\n.pb-0 {\n  padding-bottom: 0;\n}\n\n.pb-1 {\n  padding-bottom: 4px;\n}\n\n.pb-2 {\n  padding-bottom: 8px;\n}\n\n.pb-3 {\n  padding-bottom: 12px;\n}\n\n.pb-4 {\n  padding-bottom: 16px;\n}\n\n.pb-5 {\n  padding-bottom: 20px;\n}\n\n.pb-6 {\n  padding-bottom: 24px;\n}\n\n.pb-7 {\n  padding-bottom: 28px;\n}\n\n.pb-8 {\n  padding-bottom: 32px;\n}\n\n.pb-9 {\n  padding-bottom: 36px;\n}\n\n.pb-10 {\n  padding-bottom: 40px;\n}\n\n.pb-11 {\n  padding-bottom: 44px;\n}\n\n.pb-12 {\n  padding-bottom: 48px;\n}\n\n.pb-13 {\n  padding-bottom: 52px;\n}\n\n.pb-14 {\n  padding-bottom: 56px;\n}\n\n.pb-15 {\n  padding-bottom: 60px;\n}\n\n.pb-16 {\n  padding-bottom: 64px;\n}\n\n/* Margin All Sides */\n.m-0 {\n  margin: 0;\n}\n\n.m-1 {\n  margin: 4px;\n}\n\n.m-2 {\n  margin: 8px;\n}\n\n.m-3 {\n  margin: 12px;\n}\n\n.m-4 {\n  margin: 16px;\n}\n\n.m-5 {\n  margin: 20px;\n}\n\n.m-6 {\n  margin: 24px;\n}\n\n.m-7 {\n  margin: 28px;\n}\n\n.m-8 {\n  margin: 32px;\n}\n\n.m-9 {\n  margin: 36px;\n}\n\n.m-10 {\n  margin: 40px;\n}\n\n.m-11 {\n  margin: 44px;\n}\n\n.m-12 {\n  margin: 48px;\n}\n\n.m-13 {\n  margin: 52px;\n}\n\n.m-14 {\n  margin: 56px;\n}\n\n.m-15 {\n  margin: 60px;\n}\n\n.m-16 {\n  margin: 64px;\n}\n\n/* Horizontal Margin (Left & Right) */\n.mx-0 {\n  margin-left: 0;\n  margin-right: 0;\n}\n\n.mx-1 {\n  margin-left: 4px;\n  margin-right: 4px;\n}\n\n.mx-2 {\n  margin-left: 8px;\n  margin-right: 8px;\n}\n\n.mx-3 {\n  margin-left: 12px;\n  margin-right: 12px;\n}\n\n.mx-4 {\n  margin-left: 16px;\n  margin-right: 16px;\n}\n\n.mx-5 {\n  margin-left: 20px;\n  margin-right: 20px;\n}\n\n.mx-6 {\n  margin-left: 24px;\n  margin-right: 24px;\n}\n\n.mx-7 {\n  margin-left: 28px;\n  margin-right: 28px;\n}\n\n.mx-8 {\n  margin-left: 32px;\n  margin-right: 32px;\n}\n\n.mx-9 {\n  margin-left: 36px;\n  margin-right: 36px;\n}\n\n.mx-10 {\n  margin-left: 40px;\n  margin-right: 40px;\n}\n\n.mx-11 {\n  margin-left: 44px;\n  margin-right: 44px;\n}\n\n.mx-12 {\n  margin-left: 48px;\n  margin-right: 48px;\n}\n\n.mx-13 {\n  margin-left: 52px;\n  margin-right: 52px;\n}\n\n.mx-14 {\n  margin-left: 56px;\n  margin-right: 56px;\n}\n\n.mx-15 {\n  margin-left: 60px;\n  margin-right: 60px;\n}\n\n.mx-16 {\n  margin-left: 64px;\n  margin-right: 64px;\n}\n\n/* Vertical Margin (Top & Bottom) */\n.my-0 {\n  margin-top: 0;\n  margin-bottom: 0;\n}\n\n.my-1 {\n  margin-top: 4px;\n  margin-bottom: 4px;\n}\n\n.my-2 {\n  margin-top: 8px;\n  margin-bottom: 8px;\n}\n\n.my-3 {\n  margin-top: 12px;\n  margin-bottom: 12px;\n}\n\n.my-4 {\n  margin-top: 16px;\n  margin-bottom: 16px;\n}\n\n.my-5 {\n  margin-top: 20px;\n  margin-bottom: 20px;\n}\n\n.my-6 {\n  margin-top: 24px;\n  margin-bottom: 24px;\n}\n\n.my-7 {\n  margin-top: 28px;\n  margin-bottom: 28px;\n}\n\n.my-8 {\n  margin-top: 32px;\n  margin-bottom: 32px;\n}\n\n.my-9 {\n  margin-top: 36px;\n  margin-bottom: 36px;\n}\n\n.my-10 {\n  margin-top: 40px;\n  margin-bottom: 40px;\n}\n\n.my-11 {\n  margin-top: 44px;\n  margin-bottom: 44px;\n}\n\n.my-12 {\n  margin-top: 48px;\n  margin-bottom: 48px;\n}\n\n.my-13 {\n  margin-top: 52px;\n  margin-bottom: 52px;\n}\n\n.my-14 {\n  margin-top: 56px;\n  margin-bottom: 56px;\n}\n\n.my-15 {\n  margin-top: 60px;\n  margin-bottom: 60px;\n}\n\n.my-16 {\n  margin-top: 64px;\n  margin-bottom: 64px;\n}\n\n/* Margin Left */\n.ml-0 {\n  margin-left: 0;\n}\n\n.ml-1 {\n  margin-left: 4px;\n}\n\n.ml-2 {\n  margin-left: 8px;\n}\n\n.ml-3 {\n  margin-left: 12px;\n}\n\n.ml-4 {\n  margin-left: 16px;\n}\n\n.ml-5 {\n  margin-left: 20px;\n}\n\n.ml-6 {\n  margin-left: 24px;\n}\n\n.ml-7 {\n  margin-left: 28px;\n}\n\n.ml-8 {\n  margin-left: 32px;\n}\n\n.ml-9 {\n  margin-left: 36px;\n}\n\n.ml-10 {\n  margin-left: 40px;\n}\n\n.ml-11 {\n  margin-left: 44px;\n}\n\n.ml-12 {\n  margin-left: 48px;\n}\n\n.ml-13 {\n  margin-left: 52px;\n}\n\n.ml-14 {\n  margin-left: 56px;\n}\n\n.ml-15 {\n  margin-left: 60px;\n}\n\n.ml-16 {\n  margin-left: 64px;\n}\n\n/* Margin Right */\n.mr-0 {\n  margin-right: 0;\n}\n\n.mr-1 {\n  margin-right: 4px;\n}\n\n.mr-2 {\n  margin-right: 8px;\n}\n\n.mr-3 {\n  margin-right: 12px;\n}\n\n.mr-4 {\n  margin-right: 16px;\n}\n\n.mr-5 {\n  margin-right: 20px;\n}\n\n.mr-6 {\n  margin-right: 24px;\n}\n\n.mr-7 {\n  margin-right: 28px;\n}\n\n.mr-8 {\n  margin-right: 32px;\n}\n\n.mr-9 {\n  margin-right: 36px;\n}\n\n.mr-10 {\n  margin-right: 40px;\n}\n\n.mr-11 {\n  margin-right: 44px;\n}\n\n.mr-12 {\n  margin-right: 48px;\n}\n\n.mr-13 {\n  margin-right: 52px;\n}\n\n.mr-14 {\n  margin-right: 56px;\n}\n\n.mr-15 {\n  margin-right: 60px;\n}\n\n.mr-16 {\n  margin-right: 64px;\n}\n\n/* Margin Top */\n.mt-0 {\n  margin-top: 0;\n}\n\n.mt-1 {\n  margin-top: 4px;\n}\n\n.mt-2 {\n  margin-top: 8px;\n}\n\n.mt-3 {\n  margin-top: 12px;\n}\n\n.mt-4 {\n  margin-top: 16px;\n}\n\n.mt-5 {\n  margin-top: 20px;\n}\n\n.mt-6 {\n  margin-top: 24px;\n}\n\n.mt-7 {\n  margin-top: 28px;\n}\n\n.mt-8 {\n  margin-top: 32px;\n}\n\n.mt-9 {\n  margin-top: 36px;\n}\n\n.mt-10 {\n  margin-top: 40px;\n}\n\n.mt-11 {\n  margin-top: 44px;\n}\n\n.mt-12 {\n  margin-top: 48px;\n}\n\n.mt-13 {\n  margin-top: 52px;\n}\n\n.mt-14 {\n  margin-top: 56px;\n}\n\n.mt-15 {\n  margin-top: 60px;\n}\n\n.mt-16 {\n  margin-top: 64px;\n}\n\n/* Margin Bottom */\n.mb-0 {\n  margin-bottom: 0;\n}\n\n.mb-1 {\n  margin-bottom: 4px;\n}\n\n.mb-2 {\n  margin-bottom: 8px;\n}\n\n.mb-3 {\n  margin-bottom: 12px;\n}\n\n.mb-4 {\n  margin-bottom: 16px;\n}\n\n.mb-5 {\n  margin-bottom: 20px;\n}\n\n.mb-6 {\n  margin-bottom: 24px;\n}\n\n.mb-7 {\n  margin-bottom: 28px;\n}\n\n.mb-8 {\n  margin-bottom: 32px;\n}\n\n.mb-9 {\n  margin-bottom: 36px;\n}\n\n.mb-10 {\n  margin-bottom: 40px;\n}\n\n.mb-11 {\n  margin-bottom: 44px;\n}\n\n.mb-12 {\n  margin-bottom: 48px;\n}\n\n.mb-13 {\n  margin-bottom: 52px;\n}\n\n.mb-14 {\n  margin-bottom: 56px;\n}\n\n.mb-15 {\n  margin-bottom: 60px;\n}\n\n.mb-16 {\n  margin-bottom: 64px;\n}\n\n/* Border Radius All Corners */\n.rounded-0 {\n  border-radius: 0;\n}\n\n.rounded-sm {\n  border-radius: 4px;\n}\n\n.rounded {\n  border-radius: 8px;\n}\n\n.rounded-md {\n  border-radius: 12px;\n}\n\n.rounded-lg {\n  border-radius: 16px;\n}\n\n.rounded-xl {\n  border-radius: 24px;\n}\n\n.rounded-2xl {\n  border-radius: 32px;\n}\n\n.rounded-3xl {\n  border-radius: 40px;\n}\n\n.rounded-full {\n  border-radius: 9999px;\n}\n\n/* Top Corners */\n.rounded-t-0 {\n  border-top-left-radius: 0;\n  border-top-right-radius: 0;\n}\n\n.rounded-t-sm {\n  border-top-left-radius: 4px;\n  border-top-right-radius: 4px;\n}\n\n.rounded-t {\n  border-top-left-radius: 8px;\n  border-top-right-radius: 8px;\n}\n\n.rounded-t-md {\n  border-top-left-radius: 12px;\n  border-top-right-radius: 12px;\n}\n\n.rounded-t-lg {\n  border-top-left-radius: 16px;\n  border-top-right-radius: 16px;\n}\n\n.rounded-t-xl {\n  border-top-left-radius: 24px;\n  border-top-right-radius: 24px;\n}\n\n.rounded-t-2xl {\n  border-top-left-radius: 32px;\n  border-top-right-radius: 32px;\n}\n\n.rounded-t-3xl {\n  border-top-left-radius: 40px;\n  border-top-right-radius: 40px;\n}\n\n.rounded-t-full {\n  border-top-left-radius: 9999px;\n  border-top-right-radius: 9999px;\n}\n\n/* Bottom Corners */\n.rounded-b-0 {\n  border-bottom-left-radius: 0;\n  border-bottom-right-radius: 0;\n}\n\n.rounded-b-sm {\n  border-bottom-left-radius: 4px;\n  border-bottom-right-radius: 4px;\n}\n\n.rounded-b {\n  border-bottom-left-radius: 8px;\n  border-bottom-right-radius: 8px;\n}\n\n.rounded-b-md {\n  border-bottom-left-radius: 12px;\n  border-bottom-right-radius: 12px;\n}\n\n.rounded-b-lg {\n  border-bottom-left-radius: 16px;\n  border-bottom-right-radius: 16px;\n}\n\n.rounded-b-xl {\n  border-bottom-left-radius: 24px;\n  border-bottom-right-radius: 24px;\n}\n\n.rounded-b-2xl {\n  border-bottom-left-radius: 32px;\n  border-bottom-right-radius: 32px;\n}\n\n.rounded-b-3xl {\n  border-bottom-left-radius: 40px;\n  border-bottom-right-radius: 40px;\n}\n\n.rounded-b-full {\n  border-bottom-left-radius: 9999px;\n  border-bottom-right-radius: 9999px;\n}\n\n/* Left Corners */\n.rounded-l-0 {\n  border-top-left-radius: 0;\n  border-bottom-left-radius: 0;\n}\n\n.rounded-l-sm {\n  border-top-left-radius: 4px;\n  border-bottom-left-radius: 4px;\n}\n\n.rounded-l {\n  border-top-left-radius: 8px;\n  border-bottom-left-radius: 8px;\n}\n\n.rounded-l-md {\n  border-top-left-radius: 12px;\n  border-bottom-left-radius: 12px;\n}\n\n.rounded-l-lg {\n  border-top-left-radius: 16px;\n  border-bottom-left-radius: 16px;\n}\n\n.rounded-l-xl {\n  border-top-left-radius: 24px;\n  border-bottom-left-radius: 24px;\n}\n\n.rounded-l-2xl {\n  border-top-left-radius: 32px;\n  border-bottom-left-radius: 32px;\n}\n\n.rounded-l-3xl {\n  border-top-left-radius: 40px;\n  border-bottom-left-radius: 40px;\n}\n\n.rounded-l-full {\n  border-top-left-radius: 9999px;\n  border-bottom-left-radius: 9999px;\n}\n\n/* Right Corners */\n.rounded-r-0 {\n  border-top-right-radius: 0;\n  border-bottom-right-radius: 0;\n}\n\n.rounded-r-sm {\n  border-top-right-radius: 4px;\n  border-bottom-right-radius: 4px;\n}\n\n.rounded-r {\n  border-top-right-radius: 8px;\n  border-bottom-right-radius: 8px;\n}\n\n.rounded-r-md {\n  border-top-right-radius: 12px;\n  border-bottom-right-radius: 12px;\n}\n\n.rounded-r-lg {\n  border-top-right-radius: 16px;\n  border-bottom-right-radius: 16px;\n}\n\n.rounded-r-xl {\n  border-top-right-radius: 24px;\n  border-bottom-right-radius: 24px;\n}\n\n.rounded-r-2xl {\n  border-top-right-radius: 32px;\n  border-bottom-right-radius: 32px;\n}\n\n.rounded-r-3xl {\n  border-top-right-radius: 40px;\n  border-bottom-right-radius: 40px;\n}\n\n.rounded-r-full {\n  border-top-right-radius: 9999px;\n  border-bottom-right-radius: 9999px;\n}\n\n/* Individual Corners */\n.rounded-tl-0 {\n  border-top-left-radius: 0;\n}\n\n.rounded-tl-sm {\n  border-top-left-radius: 4px;\n}\n\n.rounded-tl {\n  border-top-left-radius: 8px;\n}\n\n.rounded-tl-md {\n  border-top-left-radius: 12px;\n}\n\n.rounded-tl-lg {\n  border-top-left-radius: 16px;\n}\n\n.rounded-tl-xl {\n  border-top-left-radius: 24px;\n}\n\n.rounded-tl-2xl {\n  border-top-left-radius: 32px;\n}\n\n.rounded-tl-3xl {\n  border-top-left-radius: 40px;\n}\n\n.rounded-tl-full {\n  border-top-left-radius: 9999px;\n}\n\n.rounded-tr-0 {\n  border-top-right-radius: 0;\n}\n\n.rounded-tr-sm {\n  border-top-right-radius: 4px;\n}\n\n.rounded-tr {\n  border-top-right-radius: 8px;\n}\n\n.rounded-tr-md {\n  border-top-right-radius: 12px;\n}\n\n.rounded-tr-lg {\n  border-top-right-radius: 16px;\n}\n\n.rounded-tr-xl {\n  border-top-right-radius: 24px;\n}\n\n.rounded-tr-2xl {\n  border-top-right-radius: 32px;\n}\n\n.rounded-tr-3xl {\n  border-top-right-radius: 40px;\n}\n\n.rounded-tr-full {\n  border-top-right-radius: 9999px;\n}\n\n.rounded-bl-0 {\n  border-bottom-left-radius: 0;\n}\n\n.rounded-bl-sm {\n  border-bottom-left-radius: 4px;\n}\n\n.rounded-bl {\n  border-bottom-left-radius: 8px;\n}\n\n.rounded-bl-md {\n  border-bottom-left-radius: 12px;\n}\n\n.rounded-bl-lg {\n  border-bottom-left-radius: 16px;\n}\n\n.rounded-bl-xl {\n  border-bottom-left-radius: 24px;\n}\n\n.rounded-bl-2xl {\n  border-bottom-left-radius: 32px;\n}\n\n.rounded-bl-3xl {\n  border-bottom-left-radius: 40px;\n}\n\n.rounded-bl-full {\n  border-bottom-left-radius: 9999px;\n}\n\n.rounded-br-0 {\n  border-bottom-right-radius: 0;\n}\n\n.rounded-br-sm {\n  border-bottom-right-radius: 4px;\n}\n\n.rounded-br {\n  border-bottom-right-radius: 8px;\n}\n\n.rounded-br-md {\n  border-bottom-right-radius: 12px;\n}\n\n.rounded-br-lg {\n  border-bottom-right-radius: 16px;\n}\n\n.rounded-br-xl {\n  border-bottom-right-radius: 24px;\n}\n\n.rounded-br-2xl {\n  border-bottom-right-radius: 32px;\n}\n\n.rounded-br-3xl {\n  border-bottom-right-radius: 40px;\n}\n\n.rounded-br-full {\n  border-bottom-right-radius: 9999px;\n}\n\n/* Background Colors */\n.bg-bg {\n  background-color: #282828;\n}\n\n.bg-bg-alt {\n  background-color: #3c3836;\n}\n\n.bg-bg-mid {\n  background-color: #504945;\n}\n\n.bg-bg-light {\n  background-color: #665c54;\n}\n\n.bg-text {\n  background-color: #a89984;\n}\n\n.bg-text-light {\n  background-color: #ebdbb2;\n}\n\n.bg-text-highlight {\n  background-color: #fbf1c7;\n}\n\n.bg-red {\n  background-color: #cc241d;\n}\n\n.bg-orange {\n  background-color: #d79921;\n}\n\n.bg-yellow {\n  background-color: #fabd2f;\n}\n\n.bg-green {\n  background-color: #b8bb26;\n}\n\n.bg-aqua {\n  background-color: #8ec07c;\n}\n\n.bg-blue {\n  background-color: #83a598;\n}\n\n.bg-purple {\n  background-color: #b16286;\n}\n\n.bg-brown {\n  background-color: #d65d0e;\n}\n\n/* Text Colors */\n.text-bg {\n  color: #282828;\n}\n\n.text-bg-alt {\n  color: #3c3836;\n}\n\n.text-bg-mid {\n  color: #504945;\n}\n\n.text-bg-light {\n  color: #665c54;\n}\n\n.text-muted {\n  color: #928374;\n}\n\n.text-base {\n  color: #a89984;\n}\n\n.text-light {\n  color: #ebdbb2;\n}\n\n.text-highlight {\n  color: #fbf1c7;\n}\n\n/* Font Sizes */\n.text-border {\n  font-size: 2px;\n}\n\n.text-xxs {\n  font-size: 6px;\n}\n\n.text-xs {\n  font-size: 10px;\n}\n\n.text-sm {\n  font-size: 12px;\n}\n\n.text-base {\n  font-size: 14px;\n}\n\n.text-lg {\n  font-size: 16px;\n}\n\n.text-xl {\n  font-size: 18px;\n}\n\n.text-2xl {\n  font-size: 20px;\n}\n\n.text-3xl {\n  font-size: 24px;\n}\n\n.text-4xl {\n  font-size: 30px;\n}\n\n.text-5xl {\n  font-size: 36px;\n}\n\n.text-6xl {\n  font-size: 48px;\n}\n\n/* Font Variants */\n.font-thin {\n  font-weight: 100;\n}\n\n.font-extralight {\n  font-weight: 200;\n}\n\n.font-light {\n  font-weight: 300;\n}\n\n.font-normal {\n  font-weight: 400;\n}\n\n.font-medium {\n  font-weight: 500;\n}\n\n.font-semibold {\n  font-weight: 600;\n}\n\n.font-bold {\n  font-weight: 700;\n}\n\n.font-extrabold {\n  font-weight: 800;\n}\n\n.font-black {\n  font-weight: 900;\n}\n\n.italic {\n  font-style: italic;\n}\n\n.not-italic {\n  font-style: normal;\n}\n\n.underline {\n  text-decoration: underline;\n}\n\n.line-through {\n  text-decoration: line-through;\n}\n\n.no-underline {\n  text-decoration: none;\n}\n\n.text-red {\n  color: #cc241d;\n}\n\n.text-orange {\n  color: #d79921;\n}\n\n.text-yellow {\n  color: #fabd2f;\n}\n\n.text-green {\n  color: #b8bb26;\n}\n\n.text-aqua {\n  color: #8ec07c;\n}\n\n.text-blue {\n  color: #83a598;\n}\n\n.text-purple {\n  color: #b16286;\n}\n\n.text-brown {\n  color: #d65d0e;\n}\n\n/* Border Colors */\n.border-bg {\n  border-color: #282828;\n}\n\n.border-bg-alt {\n  border-color: #3c3836;\n}\n\n.border-bg-mid {\n  border-color: #504945;\n}\n\n.border-bg-light {\n  border-color: #665c54;\n}\n\n.border-text {\n  border-color: #a89984;\n}\n\n.border-text-light {\n  border-color: #ebdbb2;\n}\n\n.border-text-highlight {\n  border-color: #fbf1c7;\n}\n\n.border-red {\n  border-color: #cc241d;\n}\n\n.border-orange {\n  border-color: #d79921;\n}\n\n.border-yellow {\n  border-color: #fabd2f;\n}\n\n.border-green {\n  border-color: #b8bb26;\n}\n\n.border-aqua {\n  border-color: #8ec07c;\n}\n\n.border-blue {\n  border-color: #83a598;\n}\n\n.border-purple {\n  border-color: #b16286;\n}\n\n.border-brown {\n  border-color: #d65d0e;\n}\n\n/* Hover States */\n.hover\\:bg-red:hover {\n  background-color: #cc241d;\n}\n\n.hover\\:bg-orange:hover {\n  background-color: #d79921;\n}\n\n.hover\\:bg-yellow:hover {\n  background-color: #fabd2f;\n}\n\n.hover\\:bg-green:hover {\n  background-color: #b8bb26;\n}\n\n.hover\\:bg-aqua:hover {\n  background-color: #8ec07c;\n}\n\n.hover\\:bg-blue:hover {\n  background-color: #83a598;\n}\n\n.hover\\:bg-purple:hover {\n  background-color: #b16286;\n}\n\n.hover\\:bg-brown:hover {\n  background-color: #d65d0e;\n}\n\n/* Min-Height Classes */\n.min-h-0 {\n  min-height: 0;\n}\n\n.min-h-px {\n  min-height: 1px;\n}\n\n.min-h-1 {\n  min-height: 4px;\n}\n\n.min-h-2 {\n  min-height: 8px;\n}\n\n.min-h-3 {\n  min-height: 12px;\n}\n\n.min-h-4 {\n  min-height: 16px;\n}\n\n.min-h-5 {\n  min-height: 20px;\n}\n\n.min-h-6 {\n  min-height: 24px;\n}\n\n.min-h-8 {\n  min-height: 32px;\n}\n\n.min-h-10 {\n  min-height: 40px;\n}\n\n.min-h-12 {\n  min-height: 48px;\n}\n\n.min-h-16 {\n  min-height: 64px;\n}\n\n.min-h-20 {\n  min-height: 80px;\n}\n\n.min-h-24 {\n  min-height: 96px;\n}\n\n.min-h-32 {\n  min-height: 128px;\n}\n\n.min-h-40 {\n  min-height: 160px;\n}\n\n.min-h-48 {\n  min-height: 192px;\n}\n\n.min-h-64 {\n  min-height: 256px;\n}\n\n/* Min-Width Classes */\n.min-w-0 {\n  min-width: 0;\n}\n\n.min-w-px {\n  min-width: 1px;\n}\n\n.min-w-1 {\n  min-width: 4px;\n}\n\n.min-w-2 {\n  min-width: 8px;\n}\n\n.min-w-3 {\n  min-width: 12px;\n}\n\n.min-w-4 {\n  min-width: 16px;\n}\n\n.min-w-5 {\n  min-width: 20px;\n}\n\n.min-w-6 {\n  min-width: 24px;\n}\n\n.min-w-8 {\n  min-width: 32px;\n}\n\n.min-w-10 {\n  min-width: 40px;\n}\n\n.min-w-12 {\n  min-width: 48px;\n}\n\n.min-w-16 {\n  min-width: 64px;\n}\n\n.min-w-20 {\n  min-width: 80px;\n}\n\n.min-w-24 {\n  min-width: 96px;\n}\n\n.min-w-32 {\n  min-width: 128px;\n}\n\n.min-w-40 {\n  min-width: 160px;\n}\n\n.min-w-48 {\n  min-width: 192px;\n}\n\n.min-w-64 {\n  min-width: 256px;\n}";

// ../../../../../nix/store/1ckqvmr9hngfanwa6aw23cskymvh215c-astal-gjs/share/astal/gjs/index.ts
import { default as default3 } from "gi://AstalIO?version=0.1";

// ../../../../../nix/store/1ckqvmr9hngfanwa6aw23cskymvh215c-astal-gjs/share/astal/gjs/file.ts
import Astal8 from "gi://AstalIO";
import Gio from "gi://Gio?version=2.0";

// ../../../../../nix/store/1ckqvmr9hngfanwa6aw23cskymvh215c-astal-gjs/share/astal/gjs/gobject.ts
import GObject4 from "gi://GObject";
import { default as default2 } from "gi://GLib?version=2.0";
var meta = Symbol("meta");
var priv = Symbol("priv");
var { ParamSpec, ParamFlags } = GObject4;

// ../../../../../nix/store/1ckqvmr9hngfanwa6aw23cskymvh215c-astal-gjs/share/astal/gjs/gtk3/jsx-runtime.ts
function Fragment({ children = [], child }) {
  if (child) children.push(child);
  return mergeBindings(children);
}
function jsx2(ctor, props) {
  return jsx(ctors, ctor, props);
}
var ctors = {
  box: Box,
  button: Button,
  centerbox: CenterBox,
  circularprogress: CircularProgress,
  drawingarea: DrawingArea,
  entry: Entry,
  eventbox: EventBox,
  // TODO: fixed
  // TODO: flowbox
  icon: Icon,
  label: Label,
  levelbar: LevelBar,
  // TODO: listbox
  menubutton: MenuButton,
  overlay: Overlay,
  revealer: Revealer,
  scrollable: Scrollable,
  slider: Slider,
  stack: Stack,
  switch: Switch,
  window: Window
};
var jsxs = jsx2;

// widget/Date.tsx
var hour = Variable(0).poll(
  500,
  "date +'%H'",
  (out, prev) => parseInt(out)
);
var minute = Variable(0).poll(
  500,
  "date +'%M'",
  (out, prev) => parseInt(out)
);
var dm = Variable(0).poll(
  500,
  "date +'%d%m'",
  (out, prev) => parseInt(out)
);
var year = Variable(0).poll(
  500,
  "date +'%Y'",
  (out, prev) => parseInt(out)
);
var transform = (v) => v.toString().length % 2 == 0 ? v.toString() : "0" + v.toString();
function Date() {
  return /* @__PURE__ */ jsxs("box", { vertical: true, className: "bg-bg rounded p-2", children: [
    /* @__PURE__ */ jsx2("label", { className: "text-light font-bold text-xxs", label: dm(transform) }),
    /* @__PURE__ */ jsx2("label", { className: "text-light font-semibold", label: hour(transform) }),
    /* @__PURE__ */ jsx2("label", { className: "text-light font-semibold", label: minute(transform) }),
    /* @__PURE__ */ jsx2("label", { className: "text-light font-bold text-xxs", label: year(transform) })
  ] });
}

// widget/Workspace.tsx
import AstalHyprland from "gi://AstalHyprland?version=0.1";
var hyprland = AstalHyprland.get_default();
function Workspaces() {
  function scrollWs(self, e) {
    hyprland.dispatch("workspace", e.delta_y > 0 ? "+1" : "-1");
  }
  return /* @__PURE__ */ jsx2("eventbox", { onScroll: scrollWs, children: /* @__PURE__ */ jsx2("box", { vertical: true, className: "bg-bg rounded py-2", children: [...Array(10).keys()].map((id) => /* @__PURE__ */ jsx2(Workspace, { id: id + 1 })) }) });
}
function Workspace({ id }) {
  const className = Variable.derive([bind(hyprland, "workspaces"), bind(hyprland, "focusedWorkspace")], (workspaces, focused) => {
    const allClasses = ["text-bg-mid"];
    const workspace = workspaces.find((w) => w.id === id);
    if (workspace) {
      if (workspace.get_clients().length > 0) {
        allClasses.push("text-light");
      }
      if (focused.id === id) {
        allClasses.push("text-blue");
      }
    }
    return allClasses.join(" ");
  });
  return /* @__PURE__ */ jsx2("button", { className: className(), onClick: () => hyprland.dispatch("workspace", `${id}`), children: /* @__PURE__ */ jsx2("label", { label: id.toString() }) });
}

// widget/Battery.tsx
import AstalBattery from "gi://AstalBattery?version=0.1";
var battery = AstalBattery.get_default();
function Battery() {
  const icon = bind(battery, "iconName");
  const percent = bind(battery, "percentage");
  const state = bind(battery, "state");
  const color = Variable.derive([state, percent], (state2, percent2) => {
    if (state2 === AstalBattery.State.CHARGING || percent2 > 0.8)
      return "text-blue";
    if (percent2 > 0.4)
      return "text-light";
    if (percent2 > 0.2)
      return "text-yellow";
    return "text-red";
  });
  return /* @__PURE__ */ jsx2("box", { className: "bg-bg rounded p-2 mt-1", halign: Gtk4.Align.CENTER, children: /* @__PURE__ */ jsx2("circularprogress", { halign: Gtk4.Align.CENTER, valign: Gtk4.Align.CENTER, value: percent, rounded: true, className: color((v) => `text-border ${v}`), startAt: 0, endAt: 1, children: /* @__PURE__ */ jsx2("icon", { icon, className: "p-2 bg-bg text-xs text-light" }) }) });
}

// widget/Volume.tsx
import AstalWp from "gi://AstalWp?version=0.1";
var wp = AstalWp.get_default();
function Volume() {
  if (!wp) return /* @__PURE__ */ jsx2(Fragment, {});
  const { CENTER } = Gtk4.Align;
  const speaker = bind(wp.audio, "default_speaker");
  const speakerVolume = speaker.as((s) => s.volume / 100);
  const speakerIcon = speaker.as((s) => s.icon && s.icon.length > 0 && s.icon !== "audio-card-symbolic" ? s.icon : "audio-speakers-symbolic");
  const mic = bind(wp.audio, "default_microphone");
  const micVolume = mic.as((s) => s.volume / 100);
  const micIcon = mic.as((s) => s.icon && s.icon.length > 0 && s.icon !== "audio-card-symbolic" ? s.icon : "audio-input-microphone-symbolic");
  return /* @__PURE__ */ jsxs("box", { vertical: true, className: "bg-bg rounded p-2 mt-1", halign: Gtk4.Align.CENTER, children: [
    /* @__PURE__ */ jsx2("circularprogress", { halign: CENTER, valign: CENTER, value: speakerVolume, rounded: true, className: "text-border", startAt: 0, endAt: 1, children: /* @__PURE__ */ jsx2("icon", { icon: speakerIcon, className: "p-2 bg-bg text-xs text-light" }) }),
    /* @__PURE__ */ jsx2("circularprogress", { halign: CENTER, valign: CENTER, value: micVolume, rounded: true, className: "text-border pt-4", startAt: 0, endAt: 1, children: /* @__PURE__ */ jsx2("icon", { icon: micIcon, className: "p-2 bg-bg text-xs text-light" }) })
  ] });
}

// widget/Tray.tsx
import AstalTray from "gi://AstalTray?version=0.1";
var tray = AstalTray.get_default();
var isTrayVisible = Variable(false);
function Tray() {
  const { CENTER } = Gtk4.Align;
  bind(tray, "items").as((i) => {
    isTrayVisible.set(i.length != 0);
  });
  return /* @__PURE__ */ jsx2("box", { vertical: true, valign: CENTER, halign: CENTER, className: "bg-bg rounded pt-2 px-4", children: bind(tray, "items").as((items) => items.map((item) => /* @__PURE__ */ jsx2(
    "menubutton",
    {
      className: "pb-2",
      tooltipMarkup: bind(item, "tooltipMarkup"),
      usePopover: false,
      menuModel: bind(item, "menu_model"),
      children: /* @__PURE__ */ jsx2("icon", { gicon: bind(item, "gicon") })
    }
  ))) });
}

// components/Desktop.tsx
function Desktop(monitor) {
  const { TOP, LEFT, BOTTOM } = Astal7.WindowAnchor;
  const { END, CENTER } = Gtk4.Align;
  return /* @__PURE__ */ jsx2(
    "window",
    {
      className: "bg-transparent",
      gdkmonitor: monitor,
      exclusivity: Astal7.Exclusivity.EXCLUSIVE,
      anchor: TOP | LEFT | BOTTOM,
      layer: Astal7.Layer.BACKGROUND,
      application: app_default,
      children: /* @__PURE__ */ jsxs("centerbox", { className: "pl-1 py-3 ", vertical: true, hexpand: true, children: [
        /* @__PURE__ */ jsxs("box", { vertical: true, children: [
          /* @__PURE__ */ jsx2(Date, {}),
          /* @__PURE__ */ jsx2(Battery, {}),
          /* @__PURE__ */ jsx2(Volume, {})
        ] }),
        /* @__PURE__ */ jsx2(Workspaces, {}),
        /* @__PURE__ */ jsx2("box", { vertical: true, valign: END, children: /* @__PURE__ */ jsx2(Tray, {}) })
      ] })
    }
  );
}

// apps/desktop.ts
app_default.start({
  css: tailwind_default,
  main() {
    app_default.get_monitors().map(Desktop);
  }
});
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsiLi4vLi4vLi4vLi4vLi4vbml4L3N0b3JlLzFja3F2bXI5aG5nZmFud2E2YXcyM2Nza3ltdmgyMTVjLWFzdGFsLWdqcy9zaGFyZS9hc3RhbC9nanMvZ3RrMy9pbmRleC50cyIsICIuLi8uLi8uLi8uLi8uLi9uaXgvc3RvcmUvMWNrcXZtcjlobmdmYW53YTZhdzIzY3NreW12aDIxNWMtYXN0YWwtZ2pzL3NoYXJlL2FzdGFsL2dqcy92YXJpYWJsZS50cyIsICIuLi8uLi8uLi8uLi8uLi9uaXgvc3RvcmUvMWNrcXZtcjlobmdmYW53YTZhdzIzY3NreW12aDIxNWMtYXN0YWwtZ2pzL3NoYXJlL2FzdGFsL2dqcy9iaW5kaW5nLnRzIiwgIi4uLy4uLy4uLy4uLy4uL25peC9zdG9yZS8xY2txdm1yOWhuZ2ZhbndhNmF3MjNjc2t5bXZoMjE1Yy1hc3RhbC1nanMvc2hhcmUvYXN0YWwvZ2pzL3RpbWUudHMiLCAiLi4vLi4vLi4vLi4vLi4vbml4L3N0b3JlLzFja3F2bXI5aG5nZmFud2E2YXcyM2Nza3ltdmgyMTVjLWFzdGFsLWdqcy9zaGFyZS9hc3RhbC9nanMvcHJvY2Vzcy50cyIsICIuLi8uLi8uLi8uLi8uLi9uaXgvc3RvcmUvMWNrcXZtcjlobmdmYW53YTZhdzIzY3NreW12aDIxNWMtYXN0YWwtZ2pzL3NoYXJlL2FzdGFsL2dqcy9fYXN0YWwudHMiLCAiLi4vLi4vLi4vLi4vLi4vbml4L3N0b3JlLzFja3F2bXI5aG5nZmFud2E2YXcyM2Nza3ltdmgyMTVjLWFzdGFsLWdqcy9zaGFyZS9hc3RhbC9nanMvZ3RrMy9hc3RhbGlmeS50cyIsICIuLi8uLi8uLi8uLi8uLi9uaXgvc3RvcmUvMWNrcXZtcjlobmdmYW53YTZhdzIzY3NreW12aDIxNWMtYXN0YWwtZ2pzL3NoYXJlL2FzdGFsL2dqcy9ndGszL2FwcC50cyIsICIuLi8uLi8uLi8uLi8uLi9uaXgvc3RvcmUvMWNrcXZtcjlobmdmYW53YTZhdzIzY3NreW12aDIxNWMtYXN0YWwtZ2pzL3NoYXJlL2FzdGFsL2dqcy9vdmVycmlkZXMudHMiLCAiLi4vLi4vLi4vLi4vLi4vbml4L3N0b3JlLzFja3F2bXI5aG5nZmFud2E2YXcyM2Nza3ltdmgyMTVjLWFzdGFsLWdqcy9zaGFyZS9hc3RhbC9nanMvX2FwcC50cyIsICIuLi8uLi8uLi8uLi8uLi9uaXgvc3RvcmUvMWNrcXZtcjlobmdmYW53YTZhdzIzY3NreW12aDIxNWMtYXN0YWwtZ2pzL3NoYXJlL2FzdGFsL2dqcy9ndGszL3dpZGdldC50cyIsICJzYXNzOi9ob21lL3NlYmFzdGllbi9Eb2N1bWVudHMvcGVyc29uYWwtcHJvamVjdHMvc3d0cy90YWlsd2luZC5zY3NzIiwgIi4uLy4uLy4uLy4uLy4uL25peC9zdG9yZS8xY2txdm1yOWhuZ2ZhbndhNmF3MjNjc2t5bXZoMjE1Yy1hc3RhbC1nanMvc2hhcmUvYXN0YWwvZ2pzL2luZGV4LnRzIiwgIi4uLy4uLy4uLy4uLy4uL25peC9zdG9yZS8xY2txdm1yOWhuZ2ZhbndhNmF3MjNjc2t5bXZoMjE1Yy1hc3RhbC1nanMvc2hhcmUvYXN0YWwvZ2pzL2ZpbGUudHMiLCAiLi4vLi4vLi4vLi4vLi4vbml4L3N0b3JlLzFja3F2bXI5aG5nZmFud2E2YXcyM2Nza3ltdmgyMTVjLWFzdGFsLWdqcy9zaGFyZS9hc3RhbC9nanMvZ29iamVjdC50cyIsICIuLi8uLi8uLi8uLi8uLi9uaXgvc3RvcmUvMWNrcXZtcjlobmdmYW53YTZhdzIzY3NreW12aDIxNWMtYXN0YWwtZ2pzL3NoYXJlL2FzdGFsL2dqcy9ndGszL2pzeC1ydW50aW1lLnRzIiwgIndpZGdldC9EYXRlLnRzeCIsICJ3aWRnZXQvV29ya3NwYWNlLnRzeCIsICJ3aWRnZXQvQmF0dGVyeS50c3giLCAid2lkZ2V0L1ZvbHVtZS50c3giLCAid2lkZ2V0L1RyYXkudHN4IiwgImNvbXBvbmVudHMvRGVza3RvcC50c3giLCAiYXBwcy9kZXNrdG9wLnRzIl0sCiAgInNvdXJjZXNDb250ZW50IjogWyJpbXBvcnQgQXN0YWwgZnJvbSBcImdpOi8vQXN0YWw/dmVyc2lvbj0zLjBcIlxuaW1wb3J0IEd0ayBmcm9tIFwiZ2k6Ly9HdGs/dmVyc2lvbj0zLjBcIlxuaW1wb3J0IEdkayBmcm9tIFwiZ2k6Ly9HZGs/dmVyc2lvbj0zLjBcIlxuaW1wb3J0IGFzdGFsaWZ5LCB7IHR5cGUgQ29uc3RydWN0UHJvcHMsIHR5cGUgQmluZGFibGVQcm9wcyB9IGZyb20gXCIuL2FzdGFsaWZ5LmpzXCJcblxuZXhwb3J0IHsgQXN0YWwsIEd0aywgR2RrIH1cbmV4cG9ydCB7IGRlZmF1bHQgYXMgQXBwIH0gZnJvbSBcIi4vYXBwLmpzXCJcbmV4cG9ydCB7IGFzdGFsaWZ5LCBDb25zdHJ1Y3RQcm9wcywgQmluZGFibGVQcm9wcyB9XG5leHBvcnQgKiBhcyBXaWRnZXQgZnJvbSBcIi4vd2lkZ2V0LmpzXCJcbmV4cG9ydCB7IGhvb2sgfSBmcm9tIFwiLi4vX2FzdGFsXCJcbiIsICJpbXBvcnQgQXN0YWwgZnJvbSBcImdpOi8vQXN0YWxJT1wiXG5pbXBvcnQgQmluZGluZywgeyB0eXBlIENvbm5lY3RhYmxlLCB0eXBlIFN1YnNjcmliYWJsZSB9IGZyb20gXCIuL2JpbmRpbmcuanNcIlxuaW1wb3J0IHsgaW50ZXJ2YWwgfSBmcm9tIFwiLi90aW1lLmpzXCJcbmltcG9ydCB7IGV4ZWNBc3luYywgc3VicHJvY2VzcyB9IGZyb20gXCIuL3Byb2Nlc3MuanNcIlxuXG5jbGFzcyBWYXJpYWJsZVdyYXBwZXI8VD4gZXh0ZW5kcyBGdW5jdGlvbiB7XG4gICAgcHJpdmF0ZSB2YXJpYWJsZSE6IEFzdGFsLlZhcmlhYmxlQmFzZVxuICAgIHByaXZhdGUgZXJySGFuZGxlcj8gPSBjb25zb2xlLmVycm9yXG5cbiAgICBwcml2YXRlIF92YWx1ZTogVFxuICAgIHByaXZhdGUgX3BvbGw/OiBBc3RhbC5UaW1lXG4gICAgcHJpdmF0ZSBfd2F0Y2g/OiBBc3RhbC5Qcm9jZXNzXG5cbiAgICBwcml2YXRlIHBvbGxJbnRlcnZhbCA9IDEwMDBcbiAgICBwcml2YXRlIHBvbGxFeGVjPzogc3RyaW5nW10gfCBzdHJpbmdcbiAgICBwcml2YXRlIHBvbGxUcmFuc2Zvcm0/OiAoc3Rkb3V0OiBzdHJpbmcsIHByZXY6IFQpID0+IFRcbiAgICBwcml2YXRlIHBvbGxGbj86IChwcmV2OiBUKSA9PiBUIHwgUHJvbWlzZTxUPlxuXG4gICAgcHJpdmF0ZSB3YXRjaFRyYW5zZm9ybT86IChzdGRvdXQ6IHN0cmluZywgcHJldjogVCkgPT4gVFxuICAgIHByaXZhdGUgd2F0Y2hFeGVjPzogc3RyaW5nW10gfCBzdHJpbmdcblxuICAgIGNvbnN0cnVjdG9yKGluaXQ6IFQpIHtcbiAgICAgICAgc3VwZXIoKVxuICAgICAgICB0aGlzLl92YWx1ZSA9IGluaXRcbiAgICAgICAgdGhpcy52YXJpYWJsZSA9IG5ldyBBc3RhbC5WYXJpYWJsZUJhc2UoKVxuICAgICAgICB0aGlzLnZhcmlhYmxlLmNvbm5lY3QoXCJkcm9wcGVkXCIsICgpID0+IHtcbiAgICAgICAgICAgIHRoaXMuc3RvcFdhdGNoKClcbiAgICAgICAgICAgIHRoaXMuc3RvcFBvbGwoKVxuICAgICAgICB9KVxuICAgICAgICB0aGlzLnZhcmlhYmxlLmNvbm5lY3QoXCJlcnJvclwiLCAoXywgZXJyKSA9PiB0aGlzLmVyckhhbmRsZXI/LihlcnIpKVxuICAgICAgICByZXR1cm4gbmV3IFByb3h5KHRoaXMsIHtcbiAgICAgICAgICAgIGFwcGx5OiAodGFyZ2V0LCBfLCBhcmdzKSA9PiB0YXJnZXQuX2NhbGwoYXJnc1swXSksXG4gICAgICAgIH0pXG4gICAgfVxuXG4gICAgcHJpdmF0ZSBfY2FsbDxSID0gVD4odHJhbnNmb3JtPzogKHZhbHVlOiBUKSA9PiBSKTogQmluZGluZzxSPiB7XG4gICAgICAgIGNvbnN0IGIgPSBCaW5kaW5nLmJpbmQodGhpcylcbiAgICAgICAgcmV0dXJuIHRyYW5zZm9ybSA/IGIuYXModHJhbnNmb3JtKSA6IGIgYXMgdW5rbm93biBhcyBCaW5kaW5nPFI+XG4gICAgfVxuXG4gICAgdG9TdHJpbmcoKSB7XG4gICAgICAgIHJldHVybiBTdHJpbmcoYFZhcmlhYmxlPCR7dGhpcy5nZXQoKX0+YClcbiAgICB9XG5cbiAgICBnZXQoKTogVCB7IHJldHVybiB0aGlzLl92YWx1ZSB9XG4gICAgc2V0KHZhbHVlOiBUKSB7XG4gICAgICAgIGlmICh2YWx1ZSAhPT0gdGhpcy5fdmFsdWUpIHtcbiAgICAgICAgICAgIHRoaXMuX3ZhbHVlID0gdmFsdWVcbiAgICAgICAgICAgIHRoaXMudmFyaWFibGUuZW1pdChcImNoYW5nZWRcIilcbiAgICAgICAgfVxuICAgIH1cblxuICAgIHN0YXJ0UG9sbCgpIHtcbiAgICAgICAgaWYgKHRoaXMuX3BvbGwpXG4gICAgICAgICAgICByZXR1cm5cblxuICAgICAgICBpZiAodGhpcy5wb2xsRm4pIHtcbiAgICAgICAgICAgIHRoaXMuX3BvbGwgPSBpbnRlcnZhbCh0aGlzLnBvbGxJbnRlcnZhbCwgKCkgPT4ge1xuICAgICAgICAgICAgICAgIGNvbnN0IHYgPSB0aGlzLnBvbGxGbiEodGhpcy5nZXQoKSlcbiAgICAgICAgICAgICAgICBpZiAodiBpbnN0YW5jZW9mIFByb21pc2UpIHtcbiAgICAgICAgICAgICAgICAgICAgdi50aGVuKHYgPT4gdGhpcy5zZXQodikpXG4gICAgICAgICAgICAgICAgICAgICAgICAuY2F0Y2goZXJyID0+IHRoaXMudmFyaWFibGUuZW1pdChcImVycm9yXCIsIGVycikpXG4gICAgICAgICAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICAgICAgICAgICAgdGhpcy5zZXQodilcbiAgICAgICAgICAgICAgICB9XG4gICAgICAgICAgICB9KVxuICAgICAgICB9IGVsc2UgaWYgKHRoaXMucG9sbEV4ZWMpIHtcbiAgICAgICAgICAgIHRoaXMuX3BvbGwgPSBpbnRlcnZhbCh0aGlzLnBvbGxJbnRlcnZhbCwgKCkgPT4ge1xuICAgICAgICAgICAgICAgIGV4ZWNBc3luYyh0aGlzLnBvbGxFeGVjISlcbiAgICAgICAgICAgICAgICAgICAgLnRoZW4odiA9PiB0aGlzLnNldCh0aGlzLnBvbGxUcmFuc2Zvcm0hKHYsIHRoaXMuZ2V0KCkpKSlcbiAgICAgICAgICAgICAgICAgICAgLmNhdGNoKGVyciA9PiB0aGlzLnZhcmlhYmxlLmVtaXQoXCJlcnJvclwiLCBlcnIpKVxuICAgICAgICAgICAgfSlcbiAgICAgICAgfVxuICAgIH1cblxuICAgIHN0YXJ0V2F0Y2goKSB7XG4gICAgICAgIGlmICh0aGlzLl93YXRjaClcbiAgICAgICAgICAgIHJldHVyblxuXG4gICAgICAgIHRoaXMuX3dhdGNoID0gc3VicHJvY2Vzcyh7XG4gICAgICAgICAgICBjbWQ6IHRoaXMud2F0Y2hFeGVjISxcbiAgICAgICAgICAgIG91dDogb3V0ID0+IHRoaXMuc2V0KHRoaXMud2F0Y2hUcmFuc2Zvcm0hKG91dCwgdGhpcy5nZXQoKSkpLFxuICAgICAgICAgICAgZXJyOiBlcnIgPT4gdGhpcy52YXJpYWJsZS5lbWl0KFwiZXJyb3JcIiwgZXJyKSxcbiAgICAgICAgfSlcbiAgICB9XG5cbiAgICBzdG9wUG9sbCgpIHtcbiAgICAgICAgdGhpcy5fcG9sbD8uY2FuY2VsKClcbiAgICAgICAgZGVsZXRlIHRoaXMuX3BvbGxcbiAgICB9XG5cbiAgICBzdG9wV2F0Y2goKSB7XG4gICAgICAgIHRoaXMuX3dhdGNoPy5raWxsKClcbiAgICAgICAgZGVsZXRlIHRoaXMuX3dhdGNoXG4gICAgfVxuXG4gICAgaXNQb2xsaW5nKCkgeyByZXR1cm4gISF0aGlzLl9wb2xsIH1cbiAgICBpc1dhdGNoaW5nKCkgeyByZXR1cm4gISF0aGlzLl93YXRjaCB9XG5cbiAgICBkcm9wKCkge1xuICAgICAgICB0aGlzLnZhcmlhYmxlLmVtaXQoXCJkcm9wcGVkXCIpXG4gICAgfVxuXG4gICAgb25Ecm9wcGVkKGNhbGxiYWNrOiAoKSA9PiB2b2lkKSB7XG4gICAgICAgIHRoaXMudmFyaWFibGUuY29ubmVjdChcImRyb3BwZWRcIiwgY2FsbGJhY2spXG4gICAgICAgIHJldHVybiB0aGlzIGFzIHVua25vd24gYXMgVmFyaWFibGU8VD5cbiAgICB9XG5cbiAgICBvbkVycm9yKGNhbGxiYWNrOiAoZXJyOiBzdHJpbmcpID0+IHZvaWQpIHtcbiAgICAgICAgZGVsZXRlIHRoaXMuZXJySGFuZGxlclxuICAgICAgICB0aGlzLnZhcmlhYmxlLmNvbm5lY3QoXCJlcnJvclwiLCAoXywgZXJyKSA9PiBjYWxsYmFjayhlcnIpKVxuICAgICAgICByZXR1cm4gdGhpcyBhcyB1bmtub3duIGFzIFZhcmlhYmxlPFQ+XG4gICAgfVxuXG4gICAgc3Vic2NyaWJlKGNhbGxiYWNrOiAodmFsdWU6IFQpID0+IHZvaWQpIHtcbiAgICAgICAgY29uc3QgaWQgPSB0aGlzLnZhcmlhYmxlLmNvbm5lY3QoXCJjaGFuZ2VkXCIsICgpID0+IHtcbiAgICAgICAgICAgIGNhbGxiYWNrKHRoaXMuZ2V0KCkpXG4gICAgICAgIH0pXG4gICAgICAgIHJldHVybiAoKSA9PiB0aGlzLnZhcmlhYmxlLmRpc2Nvbm5lY3QoaWQpXG4gICAgfVxuXG4gICAgcG9sbChcbiAgICAgICAgaW50ZXJ2YWw6IG51bWJlcixcbiAgICAgICAgZXhlYzogc3RyaW5nIHwgc3RyaW5nW10sXG4gICAgICAgIHRyYW5zZm9ybT86IChzdGRvdXQ6IHN0cmluZywgcHJldjogVCkgPT4gVFxuICAgICk6IFZhcmlhYmxlPFQ+XG5cbiAgICBwb2xsKFxuICAgICAgICBpbnRlcnZhbDogbnVtYmVyLFxuICAgICAgICBjYWxsYmFjazogKHByZXY6IFQpID0+IFQgfCBQcm9taXNlPFQ+XG4gICAgKTogVmFyaWFibGU8VD5cblxuICAgIHBvbGwoXG4gICAgICAgIGludGVydmFsOiBudW1iZXIsXG4gICAgICAgIGV4ZWM6IHN0cmluZyB8IHN0cmluZ1tdIHwgKChwcmV2OiBUKSA9PiBUIHwgUHJvbWlzZTxUPiksXG4gICAgICAgIHRyYW5zZm9ybTogKHN0ZG91dDogc3RyaW5nLCBwcmV2OiBUKSA9PiBUID0gb3V0ID0+IG91dCBhcyBULFxuICAgICkge1xuICAgICAgICB0aGlzLnN0b3BQb2xsKClcbiAgICAgICAgdGhpcy5wb2xsSW50ZXJ2YWwgPSBpbnRlcnZhbFxuICAgICAgICB0aGlzLnBvbGxUcmFuc2Zvcm0gPSB0cmFuc2Zvcm1cbiAgICAgICAgaWYgKHR5cGVvZiBleGVjID09PSBcImZ1bmN0aW9uXCIpIHtcbiAgICAgICAgICAgIHRoaXMucG9sbEZuID0gZXhlY1xuICAgICAgICAgICAgZGVsZXRlIHRoaXMucG9sbEV4ZWNcbiAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICAgIHRoaXMucG9sbEV4ZWMgPSBleGVjXG4gICAgICAgICAgICBkZWxldGUgdGhpcy5wb2xsRm5cbiAgICAgICAgfVxuICAgICAgICB0aGlzLnN0YXJ0UG9sbCgpXG4gICAgICAgIHJldHVybiB0aGlzIGFzIHVua25vd24gYXMgVmFyaWFibGU8VD5cbiAgICB9XG5cbiAgICB3YXRjaChcbiAgICAgICAgZXhlYzogc3RyaW5nIHwgc3RyaW5nW10sXG4gICAgICAgIHRyYW5zZm9ybTogKHN0ZG91dDogc3RyaW5nLCBwcmV2OiBUKSA9PiBUID0gb3V0ID0+IG91dCBhcyBULFxuICAgICkge1xuICAgICAgICB0aGlzLnN0b3BXYXRjaCgpXG4gICAgICAgIHRoaXMud2F0Y2hFeGVjID0gZXhlY1xuICAgICAgICB0aGlzLndhdGNoVHJhbnNmb3JtID0gdHJhbnNmb3JtXG4gICAgICAgIHRoaXMuc3RhcnRXYXRjaCgpXG4gICAgICAgIHJldHVybiB0aGlzIGFzIHVua25vd24gYXMgVmFyaWFibGU8VD5cbiAgICB9XG5cbiAgICBvYnNlcnZlKFxuICAgICAgICBvYmpzOiBBcnJheTxbb2JqOiBDb25uZWN0YWJsZSwgc2lnbmFsOiBzdHJpbmddPixcbiAgICAgICAgY2FsbGJhY2s6ICguLi5hcmdzOiBhbnlbXSkgPT4gVCxcbiAgICApOiBWYXJpYWJsZTxUPlxuXG4gICAgb2JzZXJ2ZShcbiAgICAgICAgb2JqOiBDb25uZWN0YWJsZSxcbiAgICAgICAgc2lnbmFsOiBzdHJpbmcsXG4gICAgICAgIGNhbGxiYWNrOiAoLi4uYXJnczogYW55W10pID0+IFQsXG4gICAgKTogVmFyaWFibGU8VD5cblxuICAgIG9ic2VydmUoXG4gICAgICAgIG9ianM6IENvbm5lY3RhYmxlIHwgQXJyYXk8W29iajogQ29ubmVjdGFibGUsIHNpZ25hbDogc3RyaW5nXT4sXG4gICAgICAgIHNpZ09yRm46IHN0cmluZyB8ICgob2JqOiBDb25uZWN0YWJsZSwgLi4uYXJnczogYW55W10pID0+IFQpLFxuICAgICAgICBjYWxsYmFjaz86IChvYmo6IENvbm5lY3RhYmxlLCAuLi5hcmdzOiBhbnlbXSkgPT4gVCxcbiAgICApIHtcbiAgICAgICAgY29uc3QgZiA9IHR5cGVvZiBzaWdPckZuID09PSBcImZ1bmN0aW9uXCIgPyBzaWdPckZuIDogY2FsbGJhY2sgPz8gKCgpID0+IHRoaXMuZ2V0KCkpXG4gICAgICAgIGNvbnN0IHNldCA9IChvYmo6IENvbm5lY3RhYmxlLCAuLi5hcmdzOiBhbnlbXSkgPT4gdGhpcy5zZXQoZihvYmosIC4uLmFyZ3MpKVxuXG4gICAgICAgIGlmIChBcnJheS5pc0FycmF5KG9ianMpKSB7XG4gICAgICAgICAgICBmb3IgKGNvbnN0IG9iaiBvZiBvYmpzKSB7XG4gICAgICAgICAgICAgICAgY29uc3QgW28sIHNdID0gb2JqXG4gICAgICAgICAgICAgICAgY29uc3QgaWQgPSBvLmNvbm5lY3Qocywgc2V0KVxuICAgICAgICAgICAgICAgIHRoaXMub25Ecm9wcGVkKCgpID0+IG8uZGlzY29ubmVjdChpZCkpXG4gICAgICAgICAgICB9XG4gICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgICBpZiAodHlwZW9mIHNpZ09yRm4gPT09IFwic3RyaW5nXCIpIHtcbiAgICAgICAgICAgICAgICBjb25zdCBpZCA9IG9ianMuY29ubmVjdChzaWdPckZuLCBzZXQpXG4gICAgICAgICAgICAgICAgdGhpcy5vbkRyb3BwZWQoKCkgPT4gb2Jqcy5kaXNjb25uZWN0KGlkKSlcbiAgICAgICAgICAgIH1cbiAgICAgICAgfVxuXG4gICAgICAgIHJldHVybiB0aGlzIGFzIHVua25vd24gYXMgVmFyaWFibGU8VD5cbiAgICB9XG5cbiAgICBzdGF0aWMgZGVyaXZlPFxuICAgICAgICBjb25zdCBEZXBzIGV4dGVuZHMgQXJyYXk8U3Vic2NyaWJhYmxlPGFueT4+LFxuICAgICAgICBBcmdzIGV4dGVuZHMge1xuICAgICAgICAgICAgW0sgaW4ga2V5b2YgRGVwc106IERlcHNbS10gZXh0ZW5kcyBTdWJzY3JpYmFibGU8aW5mZXIgVD4gPyBUIDogbmV2ZXJcbiAgICAgICAgfSxcbiAgICAgICAgViA9IEFyZ3MsXG4gICAgPihkZXBzOiBEZXBzLCBmbjogKC4uLmFyZ3M6IEFyZ3MpID0+IFYgPSAoLi4uYXJncykgPT4gYXJncyBhcyB1bmtub3duIGFzIFYpIHtcbiAgICAgICAgY29uc3QgdXBkYXRlID0gKCkgPT4gZm4oLi4uZGVwcy5tYXAoZCA9PiBkLmdldCgpKSBhcyBBcmdzKVxuICAgICAgICBjb25zdCBkZXJpdmVkID0gbmV3IFZhcmlhYmxlKHVwZGF0ZSgpKVxuICAgICAgICBjb25zdCB1bnN1YnMgPSBkZXBzLm1hcChkZXAgPT4gZGVwLnN1YnNjcmliZSgoKSA9PiBkZXJpdmVkLnNldCh1cGRhdGUoKSkpKVxuICAgICAgICBkZXJpdmVkLm9uRHJvcHBlZCgoKSA9PiB1bnN1YnMubWFwKHVuc3ViID0+IHVuc3ViKCkpKVxuICAgICAgICByZXR1cm4gZGVyaXZlZFxuICAgIH1cbn1cblxuZXhwb3J0IGludGVyZmFjZSBWYXJpYWJsZTxUPiBleHRlbmRzIE9taXQ8VmFyaWFibGVXcmFwcGVyPFQ+LCBcImJpbmRcIj4ge1xuICAgIDxSPih0cmFuc2Zvcm06ICh2YWx1ZTogVCkgPT4gUik6IEJpbmRpbmc8Uj5cbiAgICAoKTogQmluZGluZzxUPlxufVxuXG5leHBvcnQgY29uc3QgVmFyaWFibGUgPSBuZXcgUHJveHkoVmFyaWFibGVXcmFwcGVyIGFzIGFueSwge1xuICAgIGFwcGx5OiAoX3QsIF9hLCBhcmdzKSA9PiBuZXcgVmFyaWFibGVXcmFwcGVyKGFyZ3NbMF0pLFxufSkgYXMge1xuICAgIGRlcml2ZTogdHlwZW9mIFZhcmlhYmxlV3JhcHBlcltcImRlcml2ZVwiXVxuICAgIDxUPihpbml0OiBUKTogVmFyaWFibGU8VD5cbiAgICBuZXc8VD4oaW5pdDogVCk6IFZhcmlhYmxlPFQ+XG59XG5cbmV4cG9ydCBjb25zdCB7IGRlcml2ZSB9ID0gVmFyaWFibGVcbmV4cG9ydCBkZWZhdWx0IFZhcmlhYmxlXG4iLCAiZXhwb3J0IGNvbnN0IHNuYWtlaWZ5ID0gKHN0cjogc3RyaW5nKSA9PiBzdHJcbiAgICAucmVwbGFjZSgvKFthLXpdKShbQS1aXSkvZywgXCIkMV8kMlwiKVxuICAgIC5yZXBsYWNlQWxsKFwiLVwiLCBcIl9cIilcbiAgICAudG9Mb3dlckNhc2UoKVxuXG5leHBvcnQgY29uc3Qga2ViYWJpZnkgPSAoc3RyOiBzdHJpbmcpID0+IHN0clxuICAgIC5yZXBsYWNlKC8oW2Etel0pKFtBLVpdKS9nLCBcIiQxLSQyXCIpXG4gICAgLnJlcGxhY2VBbGwoXCJfXCIsIFwiLVwiKVxuICAgIC50b0xvd2VyQ2FzZSgpXG5cbmV4cG9ydCBpbnRlcmZhY2UgU3Vic2NyaWJhYmxlPFQgPSB1bmtub3duPiB7XG4gICAgc3Vic2NyaWJlKGNhbGxiYWNrOiAodmFsdWU6IFQpID0+IHZvaWQpOiAoKSA9PiB2b2lkXG4gICAgZ2V0KCk6IFRcbiAgICBba2V5OiBzdHJpbmddOiBhbnlcbn1cblxuZXhwb3J0IGludGVyZmFjZSBDb25uZWN0YWJsZSB7XG4gICAgY29ubmVjdChzaWduYWw6IHN0cmluZywgY2FsbGJhY2s6ICguLi5hcmdzOiBhbnlbXSkgPT4gdW5rbm93bik6IG51bWJlclxuICAgIGRpc2Nvbm5lY3QoaWQ6IG51bWJlcik6IHZvaWRcbiAgICBba2V5OiBzdHJpbmddOiBhbnlcbn1cblxuZXhwb3J0IGNsYXNzIEJpbmRpbmc8VmFsdWU+IHtcbiAgICBwcml2YXRlIHRyYW5zZm9ybUZuID0gKHY6IGFueSkgPT4gdlxuXG4gICAgI2VtaXR0ZXI6IFN1YnNjcmliYWJsZTxWYWx1ZT4gfCBDb25uZWN0YWJsZVxuICAgICNwcm9wPzogc3RyaW5nXG5cbiAgICBzdGF0aWMgYmluZDxcbiAgICAgICAgVCBleHRlbmRzIENvbm5lY3RhYmxlLFxuICAgICAgICBQIGV4dGVuZHMga2V5b2YgVCxcbiAgICA+KG9iamVjdDogVCwgcHJvcGVydHk6IFApOiBCaW5kaW5nPFRbUF0+XG5cbiAgICBzdGF0aWMgYmluZDxUPihvYmplY3Q6IFN1YnNjcmliYWJsZTxUPik6IEJpbmRpbmc8VD5cblxuICAgIHN0YXRpYyBiaW5kKGVtaXR0ZXI6IENvbm5lY3RhYmxlIHwgU3Vic2NyaWJhYmxlLCBwcm9wPzogc3RyaW5nKSB7XG4gICAgICAgIHJldHVybiBuZXcgQmluZGluZyhlbWl0dGVyLCBwcm9wKVxuICAgIH1cblxuICAgIHByaXZhdGUgY29uc3RydWN0b3IoZW1pdHRlcjogQ29ubmVjdGFibGUgfCBTdWJzY3JpYmFibGU8VmFsdWU+LCBwcm9wPzogc3RyaW5nKSB7XG4gICAgICAgIHRoaXMuI2VtaXR0ZXIgPSBlbWl0dGVyXG4gICAgICAgIHRoaXMuI3Byb3AgPSBwcm9wICYmIGtlYmFiaWZ5KHByb3ApXG4gICAgfVxuXG4gICAgdG9TdHJpbmcoKSB7XG4gICAgICAgIHJldHVybiBgQmluZGluZzwke3RoaXMuI2VtaXR0ZXJ9JHt0aGlzLiNwcm9wID8gYCwgXCIke3RoaXMuI3Byb3B9XCJgIDogXCJcIn0+YFxuICAgIH1cblxuICAgIGFzPFQ+KGZuOiAodjogVmFsdWUpID0+IFQpOiBCaW5kaW5nPFQ+IHtcbiAgICAgICAgY29uc3QgYmluZCA9IG5ldyBCaW5kaW5nKHRoaXMuI2VtaXR0ZXIsIHRoaXMuI3Byb3ApXG4gICAgICAgIGJpbmQudHJhbnNmb3JtRm4gPSAodjogVmFsdWUpID0+IGZuKHRoaXMudHJhbnNmb3JtRm4odikpXG4gICAgICAgIHJldHVybiBiaW5kIGFzIHVua25vd24gYXMgQmluZGluZzxUPlxuICAgIH1cblxuICAgIGdldCgpOiBWYWx1ZSB7XG4gICAgICAgIGlmICh0eXBlb2YgdGhpcy4jZW1pdHRlci5nZXQgPT09IFwiZnVuY3Rpb25cIilcbiAgICAgICAgICAgIHJldHVybiB0aGlzLnRyYW5zZm9ybUZuKHRoaXMuI2VtaXR0ZXIuZ2V0KCkpXG5cbiAgICAgICAgaWYgKHR5cGVvZiB0aGlzLiNwcm9wID09PSBcInN0cmluZ1wiKSB7XG4gICAgICAgICAgICBjb25zdCBnZXR0ZXIgPSBgZ2V0XyR7c25ha2VpZnkodGhpcy4jcHJvcCl9YFxuICAgICAgICAgICAgaWYgKHR5cGVvZiB0aGlzLiNlbWl0dGVyW2dldHRlcl0gPT09IFwiZnVuY3Rpb25cIilcbiAgICAgICAgICAgICAgICByZXR1cm4gdGhpcy50cmFuc2Zvcm1Gbih0aGlzLiNlbWl0dGVyW2dldHRlcl0oKSlcblxuICAgICAgICAgICAgcmV0dXJuIHRoaXMudHJhbnNmb3JtRm4odGhpcy4jZW1pdHRlclt0aGlzLiNwcm9wXSlcbiAgICAgICAgfVxuXG4gICAgICAgIHRocm93IEVycm9yKFwiY2FuIG5vdCBnZXQgdmFsdWUgb2YgYmluZGluZ1wiKVxuICAgIH1cblxuICAgIHN1YnNjcmliZShjYWxsYmFjazogKHZhbHVlOiBWYWx1ZSkgPT4gdm9pZCk6ICgpID0+IHZvaWQge1xuICAgICAgICBpZiAodHlwZW9mIHRoaXMuI2VtaXR0ZXIuc3Vic2NyaWJlID09PSBcImZ1bmN0aW9uXCIpIHtcbiAgICAgICAgICAgIHJldHVybiB0aGlzLiNlbWl0dGVyLnN1YnNjcmliZSgoKSA9PiB7XG4gICAgICAgICAgICAgICAgY2FsbGJhY2sodGhpcy5nZXQoKSlcbiAgICAgICAgICAgIH0pXG4gICAgICAgIH0gZWxzZSBpZiAodHlwZW9mIHRoaXMuI2VtaXR0ZXIuY29ubmVjdCA9PT0gXCJmdW5jdGlvblwiKSB7XG4gICAgICAgICAgICBjb25zdCBzaWduYWwgPSBgbm90aWZ5Ojoke3RoaXMuI3Byb3B9YFxuICAgICAgICAgICAgY29uc3QgaWQgPSB0aGlzLiNlbWl0dGVyLmNvbm5lY3Qoc2lnbmFsLCAoKSA9PiB7XG4gICAgICAgICAgICAgICAgY2FsbGJhY2sodGhpcy5nZXQoKSlcbiAgICAgICAgICAgIH0pXG4gICAgICAgICAgICByZXR1cm4gKCkgPT4ge1xuICAgICAgICAgICAgICAgICh0aGlzLiNlbWl0dGVyLmRpc2Nvbm5lY3QgYXMgQ29ubmVjdGFibGVbXCJkaXNjb25uZWN0XCJdKShpZClcbiAgICAgICAgICAgIH1cbiAgICAgICAgfVxuICAgICAgICB0aHJvdyBFcnJvcihgJHt0aGlzLiNlbWl0dGVyfSBpcyBub3QgYmluZGFibGVgKVxuICAgIH1cbn1cblxuZXhwb3J0IGNvbnN0IHsgYmluZCB9ID0gQmluZGluZ1xuZXhwb3J0IGRlZmF1bHQgQmluZGluZ1xuIiwgImltcG9ydCBBc3RhbCBmcm9tIFwiZ2k6Ly9Bc3RhbElPXCJcblxuZXhwb3J0IHR5cGUgVGltZSA9IEFzdGFsLlRpbWVcbmV4cG9ydCBjb25zdCBUaW1lID0gQXN0YWwuVGltZVxuXG5leHBvcnQgZnVuY3Rpb24gaW50ZXJ2YWwoaW50ZXJ2YWw6IG51bWJlciwgY2FsbGJhY2s/OiAoKSA9PiB2b2lkKSB7XG4gICAgcmV0dXJuIEFzdGFsLlRpbWUuaW50ZXJ2YWwoaW50ZXJ2YWwsICgpID0+IHZvaWQgY2FsbGJhY2s/LigpKVxufVxuXG5leHBvcnQgZnVuY3Rpb24gdGltZW91dCh0aW1lb3V0OiBudW1iZXIsIGNhbGxiYWNrPzogKCkgPT4gdm9pZCkge1xuICAgIHJldHVybiBBc3RhbC5UaW1lLnRpbWVvdXQodGltZW91dCwgKCkgPT4gdm9pZCBjYWxsYmFjaz8uKCkpXG59XG5cbmV4cG9ydCBmdW5jdGlvbiBpZGxlKGNhbGxiYWNrPzogKCkgPT4gdm9pZCkge1xuICAgIHJldHVybiBBc3RhbC5UaW1lLmlkbGUoKCkgPT4gdm9pZCBjYWxsYmFjaz8uKCkpXG59XG4iLCAiaW1wb3J0IEFzdGFsIGZyb20gXCJnaTovL0FzdGFsSU9cIlxuXG50eXBlIEFyZ3MgPSB7XG4gICAgY21kOiBzdHJpbmcgfCBzdHJpbmdbXVxuICAgIG91dD86IChzdGRvdXQ6IHN0cmluZykgPT4gdm9pZFxuICAgIGVycj86IChzdGRlcnI6IHN0cmluZykgPT4gdm9pZFxufVxuXG5leHBvcnQgdHlwZSBQcm9jZXNzID0gQXN0YWwuUHJvY2Vzc1xuZXhwb3J0IGNvbnN0IFByb2Nlc3MgPSBBc3RhbC5Qcm9jZXNzXG5cbmV4cG9ydCBmdW5jdGlvbiBzdWJwcm9jZXNzKGFyZ3M6IEFyZ3MpOiBBc3RhbC5Qcm9jZXNzXG5cbmV4cG9ydCBmdW5jdGlvbiBzdWJwcm9jZXNzKFxuICAgIGNtZDogc3RyaW5nIHwgc3RyaW5nW10sXG4gICAgb25PdXQ/OiAoc3Rkb3V0OiBzdHJpbmcpID0+IHZvaWQsXG4gICAgb25FcnI/OiAoc3RkZXJyOiBzdHJpbmcpID0+IHZvaWQsXG4pOiBBc3RhbC5Qcm9jZXNzXG5cbmV4cG9ydCBmdW5jdGlvbiBzdWJwcm9jZXNzKFxuICAgIGFyZ3NPckNtZDogQXJncyB8IHN0cmluZyB8IHN0cmluZ1tdLFxuICAgIG9uT3V0OiAoc3Rkb3V0OiBzdHJpbmcpID0+IHZvaWQgPSBwcmludCxcbiAgICBvbkVycjogKHN0ZGVycjogc3RyaW5nKSA9PiB2b2lkID0gcHJpbnRlcnIsXG4pIHtcbiAgICBjb25zdCBhcmdzID0gQXJyYXkuaXNBcnJheShhcmdzT3JDbWQpIHx8IHR5cGVvZiBhcmdzT3JDbWQgPT09IFwic3RyaW5nXCJcbiAgICBjb25zdCB7IGNtZCwgZXJyLCBvdXQgfSA9IHtcbiAgICAgICAgY21kOiBhcmdzID8gYXJnc09yQ21kIDogYXJnc09yQ21kLmNtZCxcbiAgICAgICAgZXJyOiBhcmdzID8gb25FcnIgOiBhcmdzT3JDbWQuZXJyIHx8IG9uRXJyLFxuICAgICAgICBvdXQ6IGFyZ3MgPyBvbk91dCA6IGFyZ3NPckNtZC5vdXQgfHwgb25PdXQsXG4gICAgfVxuXG4gICAgY29uc3QgcHJvYyA9IEFycmF5LmlzQXJyYXkoY21kKVxuICAgICAgICA/IEFzdGFsLlByb2Nlc3Muc3VicHJvY2Vzc3YoY21kKVxuICAgICAgICA6IEFzdGFsLlByb2Nlc3Muc3VicHJvY2VzcyhjbWQpXG5cbiAgICBwcm9jLmNvbm5lY3QoXCJzdGRvdXRcIiwgKF8sIHN0ZG91dDogc3RyaW5nKSA9PiBvdXQoc3Rkb3V0KSlcbiAgICBwcm9jLmNvbm5lY3QoXCJzdGRlcnJcIiwgKF8sIHN0ZGVycjogc3RyaW5nKSA9PiBlcnIoc3RkZXJyKSlcbiAgICByZXR1cm4gcHJvY1xufVxuXG4vKiogQHRocm93cyB7R0xpYi5FcnJvcn0gVGhyb3dzIHN0ZGVyciAqL1xuZXhwb3J0IGZ1bmN0aW9uIGV4ZWMoY21kOiBzdHJpbmcgfCBzdHJpbmdbXSkge1xuICAgIHJldHVybiBBcnJheS5pc0FycmF5KGNtZClcbiAgICAgICAgPyBBc3RhbC5Qcm9jZXNzLmV4ZWN2KGNtZClcbiAgICAgICAgOiBBc3RhbC5Qcm9jZXNzLmV4ZWMoY21kKVxufVxuXG5leHBvcnQgZnVuY3Rpb24gZXhlY0FzeW5jKGNtZDogc3RyaW5nIHwgc3RyaW5nW10pOiBQcm9taXNlPHN0cmluZz4ge1xuICAgIHJldHVybiBuZXcgUHJvbWlzZSgocmVzb2x2ZSwgcmVqZWN0KSA9PiB7XG4gICAgICAgIGlmIChBcnJheS5pc0FycmF5KGNtZCkpIHtcbiAgICAgICAgICAgIEFzdGFsLlByb2Nlc3MuZXhlY19hc3luY3YoY21kLCAoXywgcmVzKSA9PiB7XG4gICAgICAgICAgICAgICAgdHJ5IHtcbiAgICAgICAgICAgICAgICAgICAgcmVzb2x2ZShBc3RhbC5Qcm9jZXNzLmV4ZWNfYXN5bmN2X2ZpbmlzaChyZXMpKVxuICAgICAgICAgICAgICAgIH0gY2F0Y2ggKGVycm9yKSB7XG4gICAgICAgICAgICAgICAgICAgIHJlamVjdChlcnJvcilcbiAgICAgICAgICAgICAgICB9XG4gICAgICAgICAgICB9KVxuICAgICAgICB9IGVsc2Uge1xuICAgICAgICAgICAgQXN0YWwuUHJvY2Vzcy5leGVjX2FzeW5jKGNtZCwgKF8sIHJlcykgPT4ge1xuICAgICAgICAgICAgICAgIHRyeSB7XG4gICAgICAgICAgICAgICAgICAgIHJlc29sdmUoQXN0YWwuUHJvY2Vzcy5leGVjX2ZpbmlzaChyZXMpKVxuICAgICAgICAgICAgICAgIH0gY2F0Y2ggKGVycm9yKSB7XG4gICAgICAgICAgICAgICAgICAgIHJlamVjdChlcnJvcilcbiAgICAgICAgICAgICAgICB9XG4gICAgICAgICAgICB9KVxuICAgICAgICB9XG4gICAgfSlcbn1cbiIsICJpbXBvcnQgVmFyaWFibGUgZnJvbSBcIi4vdmFyaWFibGUuanNcIlxuaW1wb3J0IHsgZXhlY0FzeW5jIH0gZnJvbSBcIi4vcHJvY2Vzcy5qc1wiXG5pbXBvcnQgQmluZGluZywgeyBDb25uZWN0YWJsZSwga2ViYWJpZnksIHNuYWtlaWZ5LCBTdWJzY3JpYmFibGUgfSBmcm9tIFwiLi9iaW5kaW5nLmpzXCJcblxuZXhwb3J0IGNvbnN0IG5vSW1wbGljaXREZXN0cm95ID0gU3ltYm9sKFwibm8gbm8gaW1wbGljaXQgZGVzdHJveVwiKVxuZXhwb3J0IGNvbnN0IHNldENoaWxkcmVuID0gU3ltYm9sKFwiY2hpbGRyZW4gc2V0dGVyIG1ldGhvZFwiKVxuXG5leHBvcnQgZnVuY3Rpb24gbWVyZ2VCaW5kaW5ncyhhcnJheTogYW55W10pIHtcbiAgICBmdW5jdGlvbiBnZXRWYWx1ZXMoLi4uYXJnczogYW55W10pIHtcbiAgICAgICAgbGV0IGkgPSAwXG4gICAgICAgIHJldHVybiBhcnJheS5tYXAodmFsdWUgPT4gdmFsdWUgaW5zdGFuY2VvZiBCaW5kaW5nXG4gICAgICAgICAgICA/IGFyZ3NbaSsrXVxuICAgICAgICAgICAgOiB2YWx1ZSxcbiAgICAgICAgKVxuICAgIH1cblxuICAgIGNvbnN0IGJpbmRpbmdzID0gYXJyYXkuZmlsdGVyKGkgPT4gaSBpbnN0YW5jZW9mIEJpbmRpbmcpXG5cbiAgICBpZiAoYmluZGluZ3MubGVuZ3RoID09PSAwKVxuICAgICAgICByZXR1cm4gYXJyYXlcblxuICAgIGlmIChiaW5kaW5ncy5sZW5ndGggPT09IDEpXG4gICAgICAgIHJldHVybiBiaW5kaW5nc1swXS5hcyhnZXRWYWx1ZXMpXG5cbiAgICByZXR1cm4gVmFyaWFibGUuZGVyaXZlKGJpbmRpbmdzLCBnZXRWYWx1ZXMpKClcbn1cblxuZXhwb3J0IGZ1bmN0aW9uIHNldFByb3Aob2JqOiBhbnksIHByb3A6IHN0cmluZywgdmFsdWU6IGFueSkge1xuICAgIHRyeSB7XG4gICAgICAgIGNvbnN0IHNldHRlciA9IGBzZXRfJHtzbmFrZWlmeShwcm9wKX1gXG4gICAgICAgIGlmICh0eXBlb2Ygb2JqW3NldHRlcl0gPT09IFwiZnVuY3Rpb25cIilcbiAgICAgICAgICAgIHJldHVybiBvYmpbc2V0dGVyXSh2YWx1ZSlcblxuICAgICAgICByZXR1cm4gKG9ialtwcm9wXSA9IHZhbHVlKVxuICAgIH0gY2F0Y2ggKGVycm9yKSB7XG4gICAgICAgIGNvbnNvbGUuZXJyb3IoYGNvdWxkIG5vdCBzZXQgcHJvcGVydHkgXCIke3Byb3B9XCIgb24gJHtvYmp9OmAsIGVycm9yKVxuICAgIH1cbn1cblxuZXhwb3J0IHR5cGUgQmluZGFibGVQcm9wczxUPiA9IHtcbiAgICBbSyBpbiBrZXlvZiBUXTogQmluZGluZzxUW0tdPiB8IFRbS107XG59XG5cbmV4cG9ydCBmdW5jdGlvbiBob29rPFdpZGdldCBleHRlbmRzIENvbm5lY3RhYmxlPihcbiAgICB3aWRnZXQ6IFdpZGdldCxcbiAgICBvYmplY3Q6IENvbm5lY3RhYmxlIHwgU3Vic2NyaWJhYmxlLFxuICAgIHNpZ25hbE9yQ2FsbGJhY2s6IHN0cmluZyB8ICgoc2VsZjogV2lkZ2V0LCAuLi5hcmdzOiBhbnlbXSkgPT4gdm9pZCksXG4gICAgY2FsbGJhY2s/OiAoc2VsZjogV2lkZ2V0LCAuLi5hcmdzOiBhbnlbXSkgPT4gdm9pZCxcbikge1xuICAgIGlmICh0eXBlb2Ygb2JqZWN0LmNvbm5lY3QgPT09IFwiZnVuY3Rpb25cIiAmJiBjYWxsYmFjaykge1xuICAgICAgICBjb25zdCBpZCA9IG9iamVjdC5jb25uZWN0KHNpZ25hbE9yQ2FsbGJhY2ssIChfOiBhbnksIC4uLmFyZ3M6IHVua25vd25bXSkgPT4ge1xuICAgICAgICAgICAgcmV0dXJuIGNhbGxiYWNrKHdpZGdldCwgLi4uYXJncylcbiAgICAgICAgfSlcbiAgICAgICAgd2lkZ2V0LmNvbm5lY3QoXCJkZXN0cm95XCIsICgpID0+IHtcbiAgICAgICAgICAgIChvYmplY3QuZGlzY29ubmVjdCBhcyBDb25uZWN0YWJsZVtcImRpc2Nvbm5lY3RcIl0pKGlkKVxuICAgICAgICB9KVxuICAgIH0gZWxzZSBpZiAodHlwZW9mIG9iamVjdC5zdWJzY3JpYmUgPT09IFwiZnVuY3Rpb25cIiAmJiB0eXBlb2Ygc2lnbmFsT3JDYWxsYmFjayA9PT0gXCJmdW5jdGlvblwiKSB7XG4gICAgICAgIGNvbnN0IHVuc3ViID0gb2JqZWN0LnN1YnNjcmliZSgoLi4uYXJnczogdW5rbm93bltdKSA9PiB7XG4gICAgICAgICAgICBzaWduYWxPckNhbGxiYWNrKHdpZGdldCwgLi4uYXJncylcbiAgICAgICAgfSlcbiAgICAgICAgd2lkZ2V0LmNvbm5lY3QoXCJkZXN0cm95XCIsIHVuc3ViKVxuICAgIH1cbn1cblxuZXhwb3J0IGZ1bmN0aW9uIGNvbnN0cnVjdDxXaWRnZXQgZXh0ZW5kcyBDb25uZWN0YWJsZSAmIHsgW3NldENoaWxkcmVuXTogKGNoaWxkcmVuOiBhbnlbXSkgPT4gdm9pZCB9Pih3aWRnZXQ6IFdpZGdldCwgY29uZmlnOiBhbnkpIHtcbiAgICAvLyBlc2xpbnQtZGlzYWJsZS1uZXh0LWxpbmUgcHJlZmVyLWNvbnN0XG4gICAgbGV0IHsgc2V0dXAsIGNoaWxkLCBjaGlsZHJlbiA9IFtdLCAuLi5wcm9wcyB9ID0gY29uZmlnXG5cbiAgICBpZiAoY2hpbGRyZW4gaW5zdGFuY2VvZiBCaW5kaW5nKSB7XG4gICAgICAgIGNoaWxkcmVuID0gW2NoaWxkcmVuXVxuICAgIH1cblxuICAgIGlmIChjaGlsZCkge1xuICAgICAgICBjaGlsZHJlbi51bnNoaWZ0KGNoaWxkKVxuICAgIH1cblxuICAgIC8vIHJlbW92ZSB1bmRlZmluZWQgdmFsdWVzXG4gICAgZm9yIChjb25zdCBba2V5LCB2YWx1ZV0gb2YgT2JqZWN0LmVudHJpZXMocHJvcHMpKSB7XG4gICAgICAgIGlmICh2YWx1ZSA9PT0gdW5kZWZpbmVkKSB7XG4gICAgICAgICAgICBkZWxldGUgcHJvcHNba2V5XVxuICAgICAgICB9XG4gICAgfVxuXG4gICAgLy8gY29sbGVjdCBiaW5kaW5nc1xuICAgIGNvbnN0IGJpbmRpbmdzOiBBcnJheTxbc3RyaW5nLCBCaW5kaW5nPGFueT5dPiA9IE9iamVjdFxuICAgICAgICAua2V5cyhwcm9wcylcbiAgICAgICAgLnJlZHVjZSgoYWNjOiBhbnksIHByb3ApID0+IHtcbiAgICAgICAgICAgIGlmIChwcm9wc1twcm9wXSBpbnN0YW5jZW9mIEJpbmRpbmcpIHtcbiAgICAgICAgICAgICAgICBjb25zdCBiaW5kaW5nID0gcHJvcHNbcHJvcF1cbiAgICAgICAgICAgICAgICBkZWxldGUgcHJvcHNbcHJvcF1cbiAgICAgICAgICAgICAgICByZXR1cm4gWy4uLmFjYywgW3Byb3AsIGJpbmRpbmddXVxuICAgICAgICAgICAgfVxuICAgICAgICAgICAgcmV0dXJuIGFjY1xuICAgICAgICB9LCBbXSlcblxuICAgIC8vIGNvbGxlY3Qgc2lnbmFsIGhhbmRsZXJzXG4gICAgY29uc3Qgb25IYW5kbGVyczogQXJyYXk8W3N0cmluZywgc3RyaW5nIHwgKCgpID0+IHVua25vd24pXT4gPSBPYmplY3RcbiAgICAgICAgLmtleXMocHJvcHMpXG4gICAgICAgIC5yZWR1Y2UoKGFjYzogYW55LCBrZXkpID0+IHtcbiAgICAgICAgICAgIGlmIChrZXkuc3RhcnRzV2l0aChcIm9uXCIpKSB7XG4gICAgICAgICAgICAgICAgY29uc3Qgc2lnID0ga2ViYWJpZnkoa2V5KS5zcGxpdChcIi1cIikuc2xpY2UoMSkuam9pbihcIi1cIilcbiAgICAgICAgICAgICAgICBjb25zdCBoYW5kbGVyID0gcHJvcHNba2V5XVxuICAgICAgICAgICAgICAgIGRlbGV0ZSBwcm9wc1trZXldXG4gICAgICAgICAgICAgICAgcmV0dXJuIFsuLi5hY2MsIFtzaWcsIGhhbmRsZXJdXVxuICAgICAgICAgICAgfVxuICAgICAgICAgICAgcmV0dXJuIGFjY1xuICAgICAgICB9LCBbXSlcblxuICAgIC8vIHNldCBjaGlsZHJlblxuICAgIGNvbnN0IG1lcmdlZENoaWxkcmVuID0gbWVyZ2VCaW5kaW5ncyhjaGlsZHJlbi5mbGF0KEluZmluaXR5KSlcbiAgICBpZiAobWVyZ2VkQ2hpbGRyZW4gaW5zdGFuY2VvZiBCaW5kaW5nKSB7XG4gICAgICAgIHdpZGdldFtzZXRDaGlsZHJlbl0obWVyZ2VkQ2hpbGRyZW4uZ2V0KCkpXG4gICAgICAgIHdpZGdldC5jb25uZWN0KFwiZGVzdHJveVwiLCBtZXJnZWRDaGlsZHJlbi5zdWJzY3JpYmUoKHYpID0+IHtcbiAgICAgICAgICAgIHdpZGdldFtzZXRDaGlsZHJlbl0odilcbiAgICAgICAgfSkpXG4gICAgfSBlbHNlIHtcbiAgICAgICAgaWYgKG1lcmdlZENoaWxkcmVuLmxlbmd0aCA+IDApIHtcbiAgICAgICAgICAgIHdpZGdldFtzZXRDaGlsZHJlbl0obWVyZ2VkQ2hpbGRyZW4pXG4gICAgICAgIH1cbiAgICB9XG5cbiAgICAvLyBzZXR1cCBzaWduYWwgaGFuZGxlcnNcbiAgICBmb3IgKGNvbnN0IFtzaWduYWwsIGNhbGxiYWNrXSBvZiBvbkhhbmRsZXJzKSB7XG4gICAgICAgIGNvbnN0IHNpZyA9IHNpZ25hbC5zdGFydHNXaXRoKFwibm90aWZ5XCIpXG4gICAgICAgICAgICA/IHNpZ25hbC5yZXBsYWNlKFwiLVwiLCBcIjo6XCIpXG4gICAgICAgICAgICA6IHNpZ25hbFxuXG4gICAgICAgIGlmICh0eXBlb2YgY2FsbGJhY2sgPT09IFwiZnVuY3Rpb25cIikge1xuICAgICAgICAgICAgd2lkZ2V0LmNvbm5lY3Qoc2lnLCBjYWxsYmFjaylcbiAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICAgIHdpZGdldC5jb25uZWN0KHNpZywgKCkgPT4gZXhlY0FzeW5jKGNhbGxiYWNrKVxuICAgICAgICAgICAgICAgIC50aGVuKHByaW50KS5jYXRjaChjb25zb2xlLmVycm9yKSlcbiAgICAgICAgfVxuICAgIH1cblxuICAgIC8vIHNldHVwIGJpbmRpbmdzIGhhbmRsZXJzXG4gICAgZm9yIChjb25zdCBbcHJvcCwgYmluZGluZ10gb2YgYmluZGluZ3MpIHtcbiAgICAgICAgaWYgKHByb3AgPT09IFwiY2hpbGRcIiB8fCBwcm9wID09PSBcImNoaWxkcmVuXCIpIHtcbiAgICAgICAgICAgIHdpZGdldC5jb25uZWN0KFwiZGVzdHJveVwiLCBiaW5kaW5nLnN1YnNjcmliZSgodjogYW55KSA9PiB7XG4gICAgICAgICAgICAgICAgd2lkZ2V0W3NldENoaWxkcmVuXSh2KVxuICAgICAgICAgICAgfSkpXG4gICAgICAgIH1cbiAgICAgICAgd2lkZ2V0LmNvbm5lY3QoXCJkZXN0cm95XCIsIGJpbmRpbmcuc3Vic2NyaWJlKCh2OiBhbnkpID0+IHtcbiAgICAgICAgICAgIHNldFByb3Aod2lkZ2V0LCBwcm9wLCB2KVxuICAgICAgICB9KSlcbiAgICAgICAgc2V0UHJvcCh3aWRnZXQsIHByb3AsIGJpbmRpbmcuZ2V0KCkpXG4gICAgfVxuXG4gICAgLy8gZmlsdGVyIHVuZGVmaW5lZCB2YWx1ZXNcbiAgICBmb3IgKGNvbnN0IFtrZXksIHZhbHVlXSBvZiBPYmplY3QuZW50cmllcyhwcm9wcykpIHtcbiAgICAgICAgaWYgKHZhbHVlID09PSB1bmRlZmluZWQpIHtcbiAgICAgICAgICAgIGRlbGV0ZSBwcm9wc1trZXldXG4gICAgICAgIH1cbiAgICB9XG5cbiAgICBPYmplY3QuYXNzaWduKHdpZGdldCwgcHJvcHMpXG4gICAgc2V0dXA/Lih3aWRnZXQpXG4gICAgcmV0dXJuIHdpZGdldFxufVxuXG5mdW5jdGlvbiBpc0Fycm93RnVuY3Rpb24oZnVuYzogYW55KTogZnVuYyBpcyAoYXJnczogYW55KSA9PiBhbnkge1xuICAgIHJldHVybiAhT2JqZWN0Lmhhc093bihmdW5jLCBcInByb3RvdHlwZVwiKVxufVxuXG5leHBvcnQgZnVuY3Rpb24ganN4KFxuICAgIGN0b3JzOiBSZWNvcmQ8c3RyaW5nLCB7IG5ldyhwcm9wczogYW55KTogYW55IH0gfCAoKHByb3BzOiBhbnkpID0+IGFueSk+LFxuICAgIGN0b3I6IHN0cmluZyB8ICgocHJvcHM6IGFueSkgPT4gYW55KSB8IHsgbmV3KHByb3BzOiBhbnkpOiBhbnkgfSxcbiAgICB7IGNoaWxkcmVuLCAuLi5wcm9wcyB9OiBhbnksXG4pIHtcbiAgICBjaGlsZHJlbiA/Pz0gW11cblxuICAgIGlmICghQXJyYXkuaXNBcnJheShjaGlsZHJlbikpXG4gICAgICAgIGNoaWxkcmVuID0gW2NoaWxkcmVuXVxuXG4gICAgY2hpbGRyZW4gPSBjaGlsZHJlbi5maWx0ZXIoQm9vbGVhbilcblxuICAgIGlmIChjaGlsZHJlbi5sZW5ndGggPT09IDEpXG4gICAgICAgIHByb3BzLmNoaWxkID0gY2hpbGRyZW5bMF1cbiAgICBlbHNlIGlmIChjaGlsZHJlbi5sZW5ndGggPiAxKVxuICAgICAgICBwcm9wcy5jaGlsZHJlbiA9IGNoaWxkcmVuXG5cbiAgICBpZiAodHlwZW9mIGN0b3IgPT09IFwic3RyaW5nXCIpIHtcbiAgICAgICAgaWYgKGlzQXJyb3dGdW5jdGlvbihjdG9yc1tjdG9yXSkpXG4gICAgICAgICAgICByZXR1cm4gY3RvcnNbY3Rvcl0ocHJvcHMpXG5cbiAgICAgICAgcmV0dXJuIG5ldyBjdG9yc1tjdG9yXShwcm9wcylcbiAgICB9XG5cbiAgICBpZiAoaXNBcnJvd0Z1bmN0aW9uKGN0b3IpKVxuICAgICAgICByZXR1cm4gY3Rvcihwcm9wcylcblxuICAgIHJldHVybiBuZXcgY3Rvcihwcm9wcylcbn1cbiIsICJpbXBvcnQgeyBob29rLCBub0ltcGxpY2l0RGVzdHJveSwgc2V0Q2hpbGRyZW4sIG1lcmdlQmluZGluZ3MsIHR5cGUgQmluZGFibGVQcm9wcywgY29uc3RydWN0IH0gZnJvbSBcIi4uL19hc3RhbC5qc1wiXG5pbXBvcnQgQXN0YWwgZnJvbSBcImdpOi8vQXN0YWw/dmVyc2lvbj0zLjBcIlxuaW1wb3J0IEd0ayBmcm9tIFwiZ2k6Ly9HdGs/dmVyc2lvbj0zLjBcIlxuaW1wb3J0IEdkayBmcm9tIFwiZ2k6Ly9HZGs/dmVyc2lvbj0zLjBcIlxuaW1wb3J0IEdPYmplY3QgZnJvbSBcImdpOi8vR09iamVjdFwiXG5pbXBvcnQgR2lvIGZyb20gXCJnaTovL0dpbz92ZXJzaW9uPTIuMFwiXG5pbXBvcnQgQmluZGluZywgeyB0eXBlIENvbm5lY3RhYmxlLCB0eXBlIFN1YnNjcmliYWJsZSB9IGZyb20gXCIuLi9iaW5kaW5nLmpzXCJcblxuZXhwb3J0IHsgQmluZGFibGVQcm9wcywgbWVyZ2VCaW5kaW5ncyB9XG5cbmV4cG9ydCBkZWZhdWx0IGZ1bmN0aW9uIGFzdGFsaWZ5PFxuICAgIEMgZXh0ZW5kcyB7IG5ldyguLi5hcmdzOiBhbnlbXSk6IEd0ay5XaWRnZXQgfSxcbj4oY2xzOiBDLCBjbHNOYW1lID0gY2xzLm5hbWUpIHtcbiAgICBjbGFzcyBXaWRnZXQgZXh0ZW5kcyBjbHMge1xuICAgICAgICBnZXQgY3NzKCk6IHN0cmluZyB7IHJldHVybiBBc3RhbC53aWRnZXRfZ2V0X2Nzcyh0aGlzKSB9XG4gICAgICAgIHNldCBjc3MoY3NzOiBzdHJpbmcpIHsgQXN0YWwud2lkZ2V0X3NldF9jc3ModGhpcywgY3NzKSB9XG4gICAgICAgIGdldF9jc3MoKTogc3RyaW5nIHsgcmV0dXJuIHRoaXMuY3NzIH1cbiAgICAgICAgc2V0X2Nzcyhjc3M6IHN0cmluZykgeyB0aGlzLmNzcyA9IGNzcyB9XG5cbiAgICAgICAgZ2V0IGNsYXNzTmFtZSgpOiBzdHJpbmcgeyByZXR1cm4gQXN0YWwud2lkZ2V0X2dldF9jbGFzc19uYW1lcyh0aGlzKS5qb2luKFwiIFwiKSB9XG4gICAgICAgIHNldCBjbGFzc05hbWUoY2xhc3NOYW1lOiBzdHJpbmcpIHsgQXN0YWwud2lkZ2V0X3NldF9jbGFzc19uYW1lcyh0aGlzLCBjbGFzc05hbWUuc3BsaXQoL1xccysvKSkgfVxuICAgICAgICBnZXRfY2xhc3NfbmFtZSgpOiBzdHJpbmcgeyByZXR1cm4gdGhpcy5jbGFzc05hbWUgfVxuICAgICAgICBzZXRfY2xhc3NfbmFtZShjbGFzc05hbWU6IHN0cmluZykgeyB0aGlzLmNsYXNzTmFtZSA9IGNsYXNzTmFtZSB9XG5cbiAgICAgICAgZ2V0IGN1cnNvcigpOiBDdXJzb3IgeyByZXR1cm4gQXN0YWwud2lkZ2V0X2dldF9jdXJzb3IodGhpcykgYXMgQ3Vyc29yIH1cbiAgICAgICAgc2V0IGN1cnNvcihjdXJzb3I6IEN1cnNvcikgeyBBc3RhbC53aWRnZXRfc2V0X2N1cnNvcih0aGlzLCBjdXJzb3IpIH1cbiAgICAgICAgZ2V0X2N1cnNvcigpOiBDdXJzb3IgeyByZXR1cm4gdGhpcy5jdXJzb3IgfVxuICAgICAgICBzZXRfY3Vyc29yKGN1cnNvcjogQ3Vyc29yKSB7IHRoaXMuY3Vyc29yID0gY3Vyc29yIH1cblxuICAgICAgICBnZXQgY2xpY2tUaHJvdWdoKCk6IGJvb2xlYW4geyByZXR1cm4gQXN0YWwud2lkZ2V0X2dldF9jbGlja190aHJvdWdoKHRoaXMpIH1cbiAgICAgICAgc2V0IGNsaWNrVGhyb3VnaChjbGlja1Rocm91Z2g6IGJvb2xlYW4pIHsgQXN0YWwud2lkZ2V0X3NldF9jbGlja190aHJvdWdoKHRoaXMsIGNsaWNrVGhyb3VnaCkgfVxuICAgICAgICBnZXRfY2xpY2tfdGhyb3VnaCgpOiBib29sZWFuIHsgcmV0dXJuIHRoaXMuY2xpY2tUaHJvdWdoIH1cbiAgICAgICAgc2V0X2NsaWNrX3Rocm91Z2goY2xpY2tUaHJvdWdoOiBib29sZWFuKSB7IHRoaXMuY2xpY2tUaHJvdWdoID0gY2xpY2tUaHJvdWdoIH1cblxuICAgICAgICBkZWNsYXJlIHByaXZhdGUgW25vSW1wbGljaXREZXN0cm95XTogYm9vbGVhblxuICAgICAgICBnZXQgbm9JbXBsaWNpdERlc3Ryb3koKTogYm9vbGVhbiB7IHJldHVybiB0aGlzW25vSW1wbGljaXREZXN0cm95XSB9XG4gICAgICAgIHNldCBub0ltcGxpY2l0RGVzdHJveSh2YWx1ZTogYm9vbGVhbikgeyB0aGlzW25vSW1wbGljaXREZXN0cm95XSA9IHZhbHVlIH1cblxuICAgICAgICBzZXQgYWN0aW9uR3JvdXAoW3ByZWZpeCwgZ3JvdXBdOiBBY3Rpb25Hcm91cCkgeyB0aGlzLmluc2VydF9hY3Rpb25fZ3JvdXAocHJlZml4LCBncm91cCkgfVxuICAgICAgICBzZXRfYWN0aW9uX2dyb3VwKGFjdGlvbkdyb3VwOiBBY3Rpb25Hcm91cCkgeyB0aGlzLmFjdGlvbkdyb3VwID0gYWN0aW9uR3JvdXAgfVxuXG4gICAgICAgIHByb3RlY3RlZCBnZXRDaGlsZHJlbigpOiBBcnJheTxHdGsuV2lkZ2V0PiB7XG4gICAgICAgICAgICBpZiAodGhpcyBpbnN0YW5jZW9mIEd0ay5CaW4pIHtcbiAgICAgICAgICAgICAgICByZXR1cm4gdGhpcy5nZXRfY2hpbGQoKSA/IFt0aGlzLmdldF9jaGlsZCgpIV0gOiBbXVxuICAgICAgICAgICAgfSBlbHNlIGlmICh0aGlzIGluc3RhbmNlb2YgR3RrLkNvbnRhaW5lcikge1xuICAgICAgICAgICAgICAgIHJldHVybiB0aGlzLmdldF9jaGlsZHJlbigpXG4gICAgICAgICAgICB9XG4gICAgICAgICAgICByZXR1cm4gW11cbiAgICAgICAgfVxuXG4gICAgICAgIHByb3RlY3RlZCBzZXRDaGlsZHJlbihjaGlsZHJlbjogYW55W10pIHtcbiAgICAgICAgICAgIGNoaWxkcmVuID0gY2hpbGRyZW4uZmxhdChJbmZpbml0eSkubWFwKGNoID0+IGNoIGluc3RhbmNlb2YgR3RrLldpZGdldFxuICAgICAgICAgICAgICAgID8gY2hcbiAgICAgICAgICAgICAgICA6IG5ldyBHdGsuTGFiZWwoeyB2aXNpYmxlOiB0cnVlLCBsYWJlbDogU3RyaW5nKGNoKSB9KSlcblxuICAgICAgICAgICAgaWYgKHRoaXMgaW5zdGFuY2VvZiBHdGsuQ29udGFpbmVyKSB7XG4gICAgICAgICAgICAgICAgZm9yIChjb25zdCBjaCBvZiBjaGlsZHJlbilcbiAgICAgICAgICAgICAgICAgICAgdGhpcy5hZGQoY2gpXG4gICAgICAgICAgICB9IGVsc2Uge1xuICAgICAgICAgICAgICAgIHRocm93IEVycm9yKGBjYW4gbm90IGFkZCBjaGlsZHJlbiB0byAke3RoaXMuY29uc3RydWN0b3IubmFtZX1gKVxuICAgICAgICAgICAgfVxuICAgICAgICB9XG5cbiAgICAgICAgW3NldENoaWxkcmVuXShjaGlsZHJlbjogYW55W10pIHtcbiAgICAgICAgICAgIC8vIHJlbW92ZVxuICAgICAgICAgICAgaWYgKHRoaXMgaW5zdGFuY2VvZiBHdGsuQ29udGFpbmVyKSB7XG4gICAgICAgICAgICAgICAgZm9yIChjb25zdCBjaCBvZiB0aGlzLmdldENoaWxkcmVuKCkpIHtcbiAgICAgICAgICAgICAgICAgICAgdGhpcy5yZW1vdmUoY2gpXG4gICAgICAgICAgICAgICAgICAgIGlmICghY2hpbGRyZW4uaW5jbHVkZXMoY2gpICYmICF0aGlzLm5vSW1wbGljaXREZXN0cm95KVxuICAgICAgICAgICAgICAgICAgICAgICAgY2g/LmRlc3Ryb3koKVxuICAgICAgICAgICAgICAgIH1cbiAgICAgICAgICAgIH1cblxuICAgICAgICAgICAgLy8gYXBwZW5kXG4gICAgICAgICAgICB0aGlzLnNldENoaWxkcmVuKGNoaWxkcmVuKVxuICAgICAgICB9XG5cbiAgICAgICAgdG9nZ2xlQ2xhc3NOYW1lKGNuOiBzdHJpbmcsIGNvbmQgPSB0cnVlKSB7XG4gICAgICAgICAgICBBc3RhbC53aWRnZXRfdG9nZ2xlX2NsYXNzX25hbWUodGhpcywgY24sIGNvbmQpXG4gICAgICAgIH1cblxuICAgICAgICBob29rKFxuICAgICAgICAgICAgb2JqZWN0OiBDb25uZWN0YWJsZSxcbiAgICAgICAgICAgIHNpZ25hbDogc3RyaW5nLFxuICAgICAgICAgICAgY2FsbGJhY2s6IChzZWxmOiB0aGlzLCAuLi5hcmdzOiBhbnlbXSkgPT4gdm9pZCxcbiAgICAgICAgKTogdGhpc1xuICAgICAgICBob29rKFxuICAgICAgICAgICAgb2JqZWN0OiBTdWJzY3JpYmFibGUsXG4gICAgICAgICAgICBjYWxsYmFjazogKHNlbGY6IHRoaXMsIC4uLmFyZ3M6IGFueVtdKSA9PiB2b2lkLFxuICAgICAgICApOiB0aGlzXG4gICAgICAgIGhvb2soXG4gICAgICAgICAgICBvYmplY3Q6IENvbm5lY3RhYmxlIHwgU3Vic2NyaWJhYmxlLFxuICAgICAgICAgICAgc2lnbmFsT3JDYWxsYmFjazogc3RyaW5nIHwgKChzZWxmOiB0aGlzLCAuLi5hcmdzOiBhbnlbXSkgPT4gdm9pZCksXG4gICAgICAgICAgICBjYWxsYmFjaz86IChzZWxmOiB0aGlzLCAuLi5hcmdzOiBhbnlbXSkgPT4gdm9pZCxcbiAgICAgICAgKSB7XG4gICAgICAgICAgICBob29rKHRoaXMsIG9iamVjdCwgc2lnbmFsT3JDYWxsYmFjaywgY2FsbGJhY2spXG4gICAgICAgICAgICByZXR1cm4gdGhpc1xuICAgICAgICB9XG5cbiAgICAgICAgY29uc3RydWN0b3IoLi4ucGFyYW1zOiBhbnlbXSkge1xuICAgICAgICAgICAgc3VwZXIoKVxuICAgICAgICAgICAgY29uc3QgcHJvcHMgPSBwYXJhbXNbMF0gfHwge31cbiAgICAgICAgICAgIHByb3BzLnZpc2libGUgPz89IHRydWVcbiAgICAgICAgICAgIGNvbnN0cnVjdCh0aGlzLCBwcm9wcylcbiAgICAgICAgfVxuICAgIH1cblxuICAgIEdPYmplY3QucmVnaXN0ZXJDbGFzcyh7XG4gICAgICAgIEdUeXBlTmFtZTogYEFzdGFsXyR7Y2xzTmFtZX1gLFxuICAgICAgICBQcm9wZXJ0aWVzOiB7XG4gICAgICAgICAgICBcImNsYXNzLW5hbWVcIjogR09iamVjdC5QYXJhbVNwZWMuc3RyaW5nKFxuICAgICAgICAgICAgICAgIFwiY2xhc3MtbmFtZVwiLCBcIlwiLCBcIlwiLCBHT2JqZWN0LlBhcmFtRmxhZ3MuUkVBRFdSSVRFLCBcIlwiLFxuICAgICAgICAgICAgKSxcbiAgICAgICAgICAgIFwiY3NzXCI6IEdPYmplY3QuUGFyYW1TcGVjLnN0cmluZyhcbiAgICAgICAgICAgICAgICBcImNzc1wiLCBcIlwiLCBcIlwiLCBHT2JqZWN0LlBhcmFtRmxhZ3MuUkVBRFdSSVRFLCBcIlwiLFxuICAgICAgICAgICAgKSxcbiAgICAgICAgICAgIFwiY3Vyc29yXCI6IEdPYmplY3QuUGFyYW1TcGVjLnN0cmluZyhcbiAgICAgICAgICAgICAgICBcImN1cnNvclwiLCBcIlwiLCBcIlwiLCBHT2JqZWN0LlBhcmFtRmxhZ3MuUkVBRFdSSVRFLCBcImRlZmF1bHRcIixcbiAgICAgICAgICAgICksXG4gICAgICAgICAgICBcImNsaWNrLXRocm91Z2hcIjogR09iamVjdC5QYXJhbVNwZWMuYm9vbGVhbihcbiAgICAgICAgICAgICAgICBcImNsaWNrLXRocm91Z2hcIiwgXCJcIiwgXCJcIiwgR09iamVjdC5QYXJhbUZsYWdzLlJFQURXUklURSwgZmFsc2UsXG4gICAgICAgICAgICApLFxuICAgICAgICAgICAgXCJuby1pbXBsaWNpdC1kZXN0cm95XCI6IEdPYmplY3QuUGFyYW1TcGVjLmJvb2xlYW4oXG4gICAgICAgICAgICAgICAgXCJuby1pbXBsaWNpdC1kZXN0cm95XCIsIFwiXCIsIFwiXCIsIEdPYmplY3QuUGFyYW1GbGFncy5SRUFEV1JJVEUsIGZhbHNlLFxuICAgICAgICAgICAgKSxcbiAgICAgICAgfSxcbiAgICB9LCBXaWRnZXQpXG5cbiAgICByZXR1cm4gV2lkZ2V0XG59XG5cbnR5cGUgU2lnSGFuZGxlcjxcbiAgICBXIGV4dGVuZHMgSW5zdGFuY2VUeXBlPHR5cGVvZiBHdGsuV2lkZ2V0PixcbiAgICBBcmdzIGV4dGVuZHMgQXJyYXk8dW5rbm93bj4sXG4+ID0gKChzZWxmOiBXLCAuLi5hcmdzOiBBcmdzKSA9PiB1bmtub3duKSB8IHN0cmluZyB8IHN0cmluZ1tdXG5cbmV4cG9ydCB0eXBlIEJpbmRhYmxlQ2hpbGQgPSBHdGsuV2lkZ2V0IHwgQmluZGluZzxHdGsuV2lkZ2V0PlxuXG5leHBvcnQgdHlwZSBDb25zdHJ1Y3RQcm9wczxcbiAgICBTZWxmIGV4dGVuZHMgSW5zdGFuY2VUeXBlPHR5cGVvZiBHdGsuV2lkZ2V0PixcbiAgICBQcm9wcyBleHRlbmRzIEd0ay5XaWRnZXQuQ29uc3RydWN0b3JQcm9wcyxcbiAgICBTaWduYWxzIGV4dGVuZHMgUmVjb3JkPGBvbiR7c3RyaW5nfWAsIEFycmF5PHVua25vd24+PiA9IFJlY29yZDxgb24ke3N0cmluZ31gLCBhbnlbXT4sXG4+ID0gUGFydGlhbDx7XG4gICAgLy8gQHRzLWV4cGVjdC1lcnJvciBjYW4ndCBhc3NpZ24gdG8gdW5rbm93biwgYnV0IGl0IHdvcmtzIGFzIGV4cGVjdGVkIHRob3VnaFxuICAgIFtTIGluIGtleW9mIFNpZ25hbHNdOiBTaWdIYW5kbGVyPFNlbGYsIFNpZ25hbHNbU10+XG59PiAmIFBhcnRpYWw8e1xuICAgIFtLZXkgaW4gYG9uJHtzdHJpbmd9YF06IFNpZ0hhbmRsZXI8U2VsZiwgYW55W10+XG59PiAmIEJpbmRhYmxlUHJvcHM8UGFydGlhbDxQcm9wcyAmIHtcbiAgICBjbGFzc05hbWU/OiBzdHJpbmdcbiAgICBjc3M/OiBzdHJpbmdcbiAgICBjdXJzb3I/OiBzdHJpbmdcbiAgICBjbGlja1Rocm91Z2g/OiBib29sZWFuXG4gICAgYWN0aW9uR3JvdXA/OiBBY3Rpb25Hcm91cFxufT4+ICYgUGFydGlhbDx7XG4gICAgb25EZXN0cm95OiAoc2VsZjogU2VsZikgPT4gdW5rbm93blxuICAgIG9uRHJhdzogKHNlbGY6IFNlbGYpID0+IHVua25vd25cbiAgICBvbktleVByZXNzRXZlbnQ6IChzZWxmOiBTZWxmLCBldmVudDogR2RrLkV2ZW50KSA9PiB1bmtub3duXG4gICAgb25LZXlSZWxlYXNlRXZlbnQ6IChzZWxmOiBTZWxmLCBldmVudDogR2RrLkV2ZW50KSA9PiB1bmtub3duXG4gICAgb25CdXR0b25QcmVzc0V2ZW50OiAoc2VsZjogU2VsZiwgZXZlbnQ6IEdkay5FdmVudCkgPT4gdW5rbm93blxuICAgIG9uQnV0dG9uUmVsZWFzZUV2ZW50OiAoc2VsZjogU2VsZiwgZXZlbnQ6IEdkay5FdmVudCkgPT4gdW5rbm93blxuICAgIG9uUmVhbGl6ZTogKHNlbGY6IFNlbGYpID0+IHVua25vd25cbiAgICBzZXR1cDogKHNlbGY6IFNlbGYpID0+IHZvaWRcbn0+XG5cbnR5cGUgQ3Vyc29yID1cbiAgICB8IFwiZGVmYXVsdFwiXG4gICAgfCBcImhlbHBcIlxuICAgIHwgXCJwb2ludGVyXCJcbiAgICB8IFwiY29udGV4dC1tZW51XCJcbiAgICB8IFwicHJvZ3Jlc3NcIlxuICAgIHwgXCJ3YWl0XCJcbiAgICB8IFwiY2VsbFwiXG4gICAgfCBcImNyb3NzaGFpclwiXG4gICAgfCBcInRleHRcIlxuICAgIHwgXCJ2ZXJ0aWNhbC10ZXh0XCJcbiAgICB8IFwiYWxpYXNcIlxuICAgIHwgXCJjb3B5XCJcbiAgICB8IFwibm8tZHJvcFwiXG4gICAgfCBcIm1vdmVcIlxuICAgIHwgXCJub3QtYWxsb3dlZFwiXG4gICAgfCBcImdyYWJcIlxuICAgIHwgXCJncmFiYmluZ1wiXG4gICAgfCBcImFsbC1zY3JvbGxcIlxuICAgIHwgXCJjb2wtcmVzaXplXCJcbiAgICB8IFwicm93LXJlc2l6ZVwiXG4gICAgfCBcIm4tcmVzaXplXCJcbiAgICB8IFwiZS1yZXNpemVcIlxuICAgIHwgXCJzLXJlc2l6ZVwiXG4gICAgfCBcInctcmVzaXplXCJcbiAgICB8IFwibmUtcmVzaXplXCJcbiAgICB8IFwibnctcmVzaXplXCJcbiAgICB8IFwic3ctcmVzaXplXCJcbiAgICB8IFwic2UtcmVzaXplXCJcbiAgICB8IFwiZXctcmVzaXplXCJcbiAgICB8IFwibnMtcmVzaXplXCJcbiAgICB8IFwibmVzdy1yZXNpemVcIlxuICAgIHwgXCJud3NlLXJlc2l6ZVwiXG4gICAgfCBcInpvb20taW5cIlxuICAgIHwgXCJ6b29tLW91dFwiXG5cbnR5cGUgQWN0aW9uR3JvdXAgPSBbcHJlZml4OiBzdHJpbmcsIGFjdGlvbkdyb3VwOiBHaW8uQWN0aW9uR3JvdXBdXG4iLCAiaW1wb3J0IEd0ayBmcm9tIFwiZ2k6Ly9HdGs/dmVyc2lvbj0zLjBcIlxuaW1wb3J0IEFzdGFsIGZyb20gXCJnaTovL0FzdGFsP3ZlcnNpb249My4wXCJcbmltcG9ydCB7IG1rQXBwIH0gZnJvbSBcIi4uL19hcHBcIlxuXG5HdGsuaW5pdChudWxsKVxuXG5leHBvcnQgZGVmYXVsdCBta0FwcChBc3RhbC5BcHBsaWNhdGlvbilcbiIsICIvKipcbiAqIFdvcmthcm91bmQgZm9yIFwiQ2FuJ3QgY29udmVydCBub24tbnVsbCBwb2ludGVyIHRvIEpTIHZhbHVlIFwiXG4gKi9cblxuZXhwb3J0IHsgfVxuXG5jb25zdCBzbmFrZWlmeSA9IChzdHI6IHN0cmluZykgPT4gc3RyXG4gICAgLnJlcGxhY2UoLyhbYS16XSkoW0EtWl0pL2csIFwiJDFfJDJcIilcbiAgICAucmVwbGFjZUFsbChcIi1cIiwgXCJfXCIpXG4gICAgLnRvTG93ZXJDYXNlKClcblxuYXN5bmMgZnVuY3Rpb24gc3VwcHJlc3M8VD4obW9kOiBQcm9taXNlPHsgZGVmYXVsdDogVCB9PiwgcGF0Y2g6IChtOiBUKSA9PiB2b2lkKSB7XG4gICAgcmV0dXJuIG1vZC50aGVuKG0gPT4gcGF0Y2gobS5kZWZhdWx0KSkuY2F0Y2goKCkgPT4gdm9pZCAwKVxufVxuXG5mdW5jdGlvbiBwYXRjaDxQIGV4dGVuZHMgb2JqZWN0Pihwcm90bzogUCwgcHJvcDogRXh0cmFjdDxrZXlvZiBQLCBzdHJpbmc+KSB7XG4gICAgT2JqZWN0LmRlZmluZVByb3BlcnR5KHByb3RvLCBwcm9wLCB7XG4gICAgICAgIGdldCgpIHsgcmV0dXJuIHRoaXNbYGdldF8ke3NuYWtlaWZ5KHByb3ApfWBdKCkgfSxcbiAgICB9KVxufVxuXG5hd2FpdCBzdXBwcmVzcyhpbXBvcnQoXCJnaTovL0FzdGFsQXBwc1wiKSwgKHsgQXBwcywgQXBwbGljYXRpb24gfSkgPT4ge1xuICAgIHBhdGNoKEFwcHMucHJvdG90eXBlLCBcImxpc3RcIilcbiAgICBwYXRjaChBcHBsaWNhdGlvbi5wcm90b3R5cGUsIFwia2V5d29yZHNcIilcbiAgICBwYXRjaChBcHBsaWNhdGlvbi5wcm90b3R5cGUsIFwiY2F0ZWdvcmllc1wiKVxufSlcblxuYXdhaXQgc3VwcHJlc3MoaW1wb3J0KFwiZ2k6Ly9Bc3RhbEJhdHRlcnlcIiksICh7IFVQb3dlciB9KSA9PiB7XG4gICAgcGF0Y2goVVBvd2VyLnByb3RvdHlwZSwgXCJkZXZpY2VzXCIpXG59KVxuXG5hd2FpdCBzdXBwcmVzcyhpbXBvcnQoXCJnaTovL0FzdGFsQmx1ZXRvb3RoXCIpLCAoeyBBZGFwdGVyLCBCbHVldG9vdGgsIERldmljZSB9KSA9PiB7XG4gICAgcGF0Y2goQWRhcHRlci5wcm90b3R5cGUsIFwidXVpZHNcIilcbiAgICBwYXRjaChCbHVldG9vdGgucHJvdG90eXBlLCBcImFkYXB0ZXJzXCIpXG4gICAgcGF0Y2goQmx1ZXRvb3RoLnByb3RvdHlwZSwgXCJkZXZpY2VzXCIpXG4gICAgcGF0Y2goRGV2aWNlLnByb3RvdHlwZSwgXCJ1dWlkc1wiKVxufSlcblxuYXdhaXQgc3VwcHJlc3MoaW1wb3J0KFwiZ2k6Ly9Bc3RhbEh5cHJsYW5kXCIpLCAoeyBIeXBybGFuZCwgTW9uaXRvciwgV29ya3NwYWNlIH0pID0+IHtcbiAgICBwYXRjaChIeXBybGFuZC5wcm90b3R5cGUsIFwibW9uaXRvcnNcIilcbiAgICBwYXRjaChIeXBybGFuZC5wcm90b3R5cGUsIFwid29ya3NwYWNlc1wiKVxuICAgIHBhdGNoKEh5cHJsYW5kLnByb3RvdHlwZSwgXCJjbGllbnRzXCIpXG4gICAgcGF0Y2goTW9uaXRvci5wcm90b3R5cGUsIFwiYXZhaWxhYmxlTW9kZXNcIilcbiAgICBwYXRjaChNb25pdG9yLnByb3RvdHlwZSwgXCJhdmFpbGFibGVfbW9kZXNcIilcbiAgICBwYXRjaChXb3Jrc3BhY2UucHJvdG90eXBlLCBcImNsaWVudHNcIilcbn0pXG5cbmF3YWl0IHN1cHByZXNzKGltcG9ydChcImdpOi8vQXN0YWxNcHJpc1wiKSwgKHsgTXByaXMsIFBsYXllciB9KSA9PiB7XG4gICAgcGF0Y2goTXByaXMucHJvdG90eXBlLCBcInBsYXllcnNcIilcbiAgICBwYXRjaChQbGF5ZXIucHJvdG90eXBlLCBcInN1cHBvcnRlZF91cmlfc2NoZW1lc1wiKVxuICAgIHBhdGNoKFBsYXllci5wcm90b3R5cGUsIFwic3VwcG9ydGVkVXJpU2NoZW1lc1wiKVxuICAgIHBhdGNoKFBsYXllci5wcm90b3R5cGUsIFwic3VwcG9ydGVkX21pbWVfdHlwZXNcIilcbiAgICBwYXRjaChQbGF5ZXIucHJvdG90eXBlLCBcInN1cHBvcnRlZE1pbWVUeXBlc1wiKVxuICAgIHBhdGNoKFBsYXllci5wcm90b3R5cGUsIFwiY29tbWVudHNcIilcbn0pXG5cbmF3YWl0IHN1cHByZXNzKGltcG9ydChcImdpOi8vQXN0YWxOZXR3b3JrXCIpLCAoeyBXaWZpIH0pID0+IHtcbiAgICBwYXRjaChXaWZpLnByb3RvdHlwZSwgXCJhY2Nlc3NfcG9pbnRzXCIpXG4gICAgcGF0Y2goV2lmaS5wcm90b3R5cGUsIFwiYWNjZXNzUG9pbnRzXCIpXG59KVxuXG5hd2FpdCBzdXBwcmVzcyhpbXBvcnQoXCJnaTovL0FzdGFsTm90aWZkXCIpLCAoeyBOb3RpZmQsIE5vdGlmaWNhdGlvbiB9KSA9PiB7XG4gICAgcGF0Y2goTm90aWZkLnByb3RvdHlwZSwgXCJub3RpZmljYXRpb25zXCIpXG4gICAgcGF0Y2goTm90aWZpY2F0aW9uLnByb3RvdHlwZSwgXCJhY3Rpb25zXCIpXG59KVxuXG5hd2FpdCBzdXBwcmVzcyhpbXBvcnQoXCJnaTovL0FzdGFsUG93ZXJQcm9maWxlc1wiKSwgKHsgUG93ZXJQcm9maWxlcyB9KSA9PiB7XG4gICAgcGF0Y2goUG93ZXJQcm9maWxlcy5wcm90b3R5cGUsIFwiYWN0aW9uc1wiKVxufSlcblxuYXdhaXQgc3VwcHJlc3MoaW1wb3J0KFwiZ2k6Ly9Bc3RhbFdwXCIpLCAoeyBXcCwgQXVkaW8sIFZpZGVvIH0pID0+IHtcbiAgICBwYXRjaChXcC5wcm90b3R5cGUsIFwiZW5kcG9pbnRzXCIpXG4gICAgcGF0Y2goV3AucHJvdG90eXBlLCBcImRldmljZXNcIilcbiAgICBwYXRjaChBdWRpby5wcm90b3R5cGUsIFwic3RyZWFtc1wiKVxuICAgIHBhdGNoKEF1ZGlvLnByb3RvdHlwZSwgXCJyZWNvcmRlcnNcIilcbiAgICBwYXRjaChBdWRpby5wcm90b3R5cGUsIFwibWljcm9waG9uZXNcIilcbiAgICBwYXRjaChBdWRpby5wcm90b3R5cGUsIFwic3BlYWtlcnNcIilcbiAgICBwYXRjaChBdWRpby5wcm90b3R5cGUsIFwiZGV2aWNlc1wiKVxuICAgIHBhdGNoKFZpZGVvLnByb3RvdHlwZSwgXCJzdHJlYW1zXCIpXG4gICAgcGF0Y2goVmlkZW8ucHJvdG90eXBlLCBcInJlY29yZGVyc1wiKVxuICAgIHBhdGNoKFZpZGVvLnByb3RvdHlwZSwgXCJzaW5rc1wiKVxuICAgIHBhdGNoKFZpZGVvLnByb3RvdHlwZSwgXCJzb3VyY2VzXCIpXG4gICAgcGF0Y2goVmlkZW8ucHJvdG90eXBlLCBcImRldmljZXNcIilcbn0pXG4iLCAiaW1wb3J0IFwiLi9vdmVycmlkZXMuanNcIlxuaW1wb3J0IHsgc2V0Q29uc29sZUxvZ0RvbWFpbiB9IGZyb20gXCJjb25zb2xlXCJcbmltcG9ydCB7IGV4aXQsIHByb2dyYW1BcmdzIH0gZnJvbSBcInN5c3RlbVwiXG5pbXBvcnQgSU8gZnJvbSBcImdpOi8vQXN0YWxJT1wiXG5pbXBvcnQgR09iamVjdCBmcm9tIFwiZ2k6Ly9HT2JqZWN0XCJcbmltcG9ydCBHaW8gZnJvbSBcImdpOi8vR2lvP3ZlcnNpb249Mi4wXCJcbmltcG9ydCB0eXBlIEFzdGFsMyBmcm9tIFwiZ2k6Ly9Bc3RhbD92ZXJzaW9uPTMuMFwiXG5pbXBvcnQgdHlwZSBBc3RhbDQgZnJvbSBcImdpOi8vQXN0YWw/dmVyc2lvbj00LjBcIlxuXG50eXBlIENvbmZpZyA9IFBhcnRpYWw8e1xuICAgIGluc3RhbmNlTmFtZTogc3RyaW5nXG4gICAgY3NzOiBzdHJpbmdcbiAgICBpY29uczogc3RyaW5nXG4gICAgZ3RrVGhlbWU6IHN0cmluZ1xuICAgIGljb25UaGVtZTogc3RyaW5nXG4gICAgY3Vyc29yVGhlbWU6IHN0cmluZ1xuICAgIGhvbGQ6IGJvb2xlYW5cbiAgICByZXF1ZXN0SGFuZGxlcihyZXF1ZXN0OiBzdHJpbmcsIHJlczogKHJlc3BvbnNlOiBhbnkpID0+IHZvaWQpOiB2b2lkXG4gICAgbWFpbiguLi5hcmdzOiBzdHJpbmdbXSk6IHZvaWRcbiAgICBjbGllbnQobWVzc2FnZTogKG1zZzogc3RyaW5nKSA9PiBzdHJpbmcsIC4uLmFyZ3M6IHN0cmluZ1tdKTogdm9pZFxufT5cblxuaW50ZXJmYWNlIEFzdGFsM0pTIGV4dGVuZHMgQXN0YWwzLkFwcGxpY2F0aW9uIHtcbiAgICBldmFsKGJvZHk6IHN0cmluZyk6IFByb21pc2U8YW55PlxuICAgIHJlcXVlc3RIYW5kbGVyOiBDb25maWdbXCJyZXF1ZXN0SGFuZGxlclwiXVxuICAgIGFwcGx5X2NzcyhzdHlsZTogc3RyaW5nLCByZXNldD86IGJvb2xlYW4pOiB2b2lkXG4gICAgcXVpdChjb2RlPzogbnVtYmVyKTogdm9pZFxuICAgIHN0YXJ0KGNvbmZpZz86IENvbmZpZyk6IHZvaWRcbn1cblxuaW50ZXJmYWNlIEFzdGFsNEpTIGV4dGVuZHMgQXN0YWw0LkFwcGxpY2F0aW9uIHtcbiAgICBldmFsKGJvZHk6IHN0cmluZyk6IFByb21pc2U8YW55PlxuICAgIHJlcXVlc3RIYW5kbGVyPzogQ29uZmlnW1wicmVxdWVzdEhhbmRsZXJcIl1cbiAgICBhcHBseV9jc3Moc3R5bGU6IHN0cmluZywgcmVzZXQ/OiBib29sZWFuKTogdm9pZFxuICAgIHF1aXQoY29kZT86IG51bWJlcik6IHZvaWRcbiAgICBzdGFydChjb25maWc/OiBDb25maWcpOiB2b2lkXG59XG5cbnR5cGUgQXBwMyA9IHR5cGVvZiBBc3RhbDMuQXBwbGljYXRpb25cbnR5cGUgQXBwNCA9IHR5cGVvZiBBc3RhbDQuQXBwbGljYXRpb25cblxuZXhwb3J0IGZ1bmN0aW9uIG1rQXBwPEFwcCBleHRlbmRzIEFwcDM+KEFwcDogQXBwKTogQXN0YWwzSlNcbmV4cG9ydCBmdW5jdGlvbiBta0FwcDxBcHAgZXh0ZW5kcyBBcHA0PihBcHA6IEFwcCk6IEFzdGFsNEpTXG5cbmV4cG9ydCBmdW5jdGlvbiBta0FwcChBcHA6IEFwcDMgfCBBcHA0KSB7XG4gICAgcmV0dXJuIG5ldyAoY2xhc3MgQXN0YWxKUyBleHRlbmRzIEFwcCB7XG4gICAgICAgIHN0YXRpYyB7IEdPYmplY3QucmVnaXN0ZXJDbGFzcyh7IEdUeXBlTmFtZTogXCJBc3RhbEpTXCIgfSwgdGhpcyBhcyBhbnkpIH1cblxuICAgICAgICBldmFsKGJvZHk6IHN0cmluZyk6IFByb21pc2U8YW55PiB7XG4gICAgICAgICAgICByZXR1cm4gbmV3IFByb21pc2UoKHJlcywgcmVqKSA9PiB7XG4gICAgICAgICAgICAgICAgdHJ5IHtcbiAgICAgICAgICAgICAgICAgICAgY29uc3QgZm4gPSBGdW5jdGlvbihgcmV0dXJuIChhc3luYyBmdW5jdGlvbigpIHtcbiAgICAgICAgICAgICAgICAgICAgICAgICR7Ym9keS5pbmNsdWRlcyhcIjtcIikgPyBib2R5IDogYHJldHVybiAke2JvZHl9O2B9XG4gICAgICAgICAgICAgICAgICAgIH0pYClcbiAgICAgICAgICAgICAgICAgICAgZm4oKSgpLnRoZW4ocmVzKS5jYXRjaChyZWopXG4gICAgICAgICAgICAgICAgfSBjYXRjaCAoZXJyb3IpIHtcbiAgICAgICAgICAgICAgICAgICAgcmVqKGVycm9yKVxuICAgICAgICAgICAgICAgIH1cbiAgICAgICAgICAgIH0pXG4gICAgICAgIH1cblxuICAgICAgICByZXF1ZXN0SGFuZGxlcj86IENvbmZpZ1tcInJlcXVlc3RIYW5kbGVyXCJdXG5cbiAgICAgICAgdmZ1bmNfcmVxdWVzdChtc2c6IHN0cmluZywgY29ubjogR2lvLlNvY2tldENvbm5lY3Rpb24pOiB2b2lkIHtcbiAgICAgICAgICAgIGlmICh0eXBlb2YgdGhpcy5yZXF1ZXN0SGFuZGxlciA9PT0gXCJmdW5jdGlvblwiKSB7XG4gICAgICAgICAgICAgICAgdGhpcy5yZXF1ZXN0SGFuZGxlcihtc2csIChyZXNwb25zZSkgPT4ge1xuICAgICAgICAgICAgICAgICAgICBJTy53cml0ZV9zb2NrKGNvbm4sIFN0cmluZyhyZXNwb25zZSksIChfLCByZXMpID0+XG4gICAgICAgICAgICAgICAgICAgICAgICBJTy53cml0ZV9zb2NrX2ZpbmlzaChyZXMpLFxuICAgICAgICAgICAgICAgICAgICApXG4gICAgICAgICAgICAgICAgfSlcbiAgICAgICAgICAgIH0gZWxzZSB7XG4gICAgICAgICAgICAgICAgc3VwZXIudmZ1bmNfcmVxdWVzdChtc2csIGNvbm4pXG4gICAgICAgICAgICB9XG4gICAgICAgIH1cblxuICAgICAgICBhcHBseV9jc3Moc3R5bGU6IHN0cmluZywgcmVzZXQgPSBmYWxzZSkge1xuICAgICAgICAgICAgc3VwZXIuYXBwbHlfY3NzKHN0eWxlLCByZXNldClcbiAgICAgICAgfVxuXG4gICAgICAgIHF1aXQoY29kZT86IG51bWJlcik6IHZvaWQge1xuICAgICAgICAgICAgc3VwZXIucXVpdCgpXG4gICAgICAgICAgICBleGl0KGNvZGUgPz8gMClcbiAgICAgICAgfVxuXG4gICAgICAgIHN0YXJ0KHsgcmVxdWVzdEhhbmRsZXIsIGNzcywgaG9sZCwgbWFpbiwgY2xpZW50LCBpY29ucywgLi4uY2ZnIH06IENvbmZpZyA9IHt9KSB7XG4gICAgICAgICAgICBjb25zdCBhcHAgPSB0aGlzIGFzIHVua25vd24gYXMgSW5zdGFuY2VUeXBlPEFwcDMgfCBBcHA0PlxuXG4gICAgICAgICAgICBjbGllbnQgPz89ICgpID0+IHtcbiAgICAgICAgICAgICAgICBwcmludChgQXN0YWwgaW5zdGFuY2UgXCIke2FwcC5pbnN0YW5jZU5hbWV9XCIgYWxyZWFkeSBydW5uaW5nYClcbiAgICAgICAgICAgICAgICBleGl0KDEpXG4gICAgICAgICAgICB9XG5cbiAgICAgICAgICAgIE9iamVjdC5hc3NpZ24odGhpcywgY2ZnKVxuICAgICAgICAgICAgc2V0Q29uc29sZUxvZ0RvbWFpbihhcHAuaW5zdGFuY2VOYW1lKVxuXG4gICAgICAgICAgICB0aGlzLnJlcXVlc3RIYW5kbGVyID0gcmVxdWVzdEhhbmRsZXJcbiAgICAgICAgICAgIGFwcC5jb25uZWN0KFwiYWN0aXZhdGVcIiwgKCkgPT4ge1xuICAgICAgICAgICAgICAgIG1haW4/LiguLi5wcm9ncmFtQXJncylcbiAgICAgICAgICAgIH0pXG5cbiAgICAgICAgICAgIHRyeSB7XG4gICAgICAgICAgICAgICAgYXBwLmFjcXVpcmVfc29ja2V0KClcbiAgICAgICAgICAgIH0gY2F0Y2ggKGVycm9yKSB7XG4gICAgICAgICAgICAgICAgcmV0dXJuIGNsaWVudChtc2cgPT4gSU8uc2VuZF9tZXNzYWdlKGFwcC5pbnN0YW5jZU5hbWUsIG1zZykhLCAuLi5wcm9ncmFtQXJncylcbiAgICAgICAgICAgIH1cblxuICAgICAgICAgICAgaWYgKGNzcylcbiAgICAgICAgICAgICAgICB0aGlzLmFwcGx5X2Nzcyhjc3MsIGZhbHNlKVxuXG4gICAgICAgICAgICBpZiAoaWNvbnMpXG4gICAgICAgICAgICAgICAgYXBwLmFkZF9pY29ucyhpY29ucylcblxuICAgICAgICAgICAgaG9sZCA/Pz0gdHJ1ZVxuICAgICAgICAgICAgaWYgKGhvbGQpXG4gICAgICAgICAgICAgICAgYXBwLmhvbGQoKVxuXG4gICAgICAgICAgICBhcHAucnVuQXN5bmMoW10pXG4gICAgICAgIH1cbiAgICB9KVxufVxuIiwgIi8qIGVzbGludC1kaXNhYmxlIG1heC1sZW4gKi9cbmltcG9ydCBBc3RhbCBmcm9tIFwiZ2k6Ly9Bc3RhbD92ZXJzaW9uPTMuMFwiXG5pbXBvcnQgR3RrIGZyb20gXCJnaTovL0d0az92ZXJzaW9uPTMuMFwiXG5pbXBvcnQgR09iamVjdCBmcm9tIFwiZ2k6Ly9HT2JqZWN0XCJcbmltcG9ydCBhc3RhbGlmeSwgeyB0eXBlIENvbnN0cnVjdFByb3BzLCB0eXBlIEJpbmRhYmxlQ2hpbGQgfSBmcm9tIFwiLi9hc3RhbGlmeS5qc1wiXG5cbmZ1bmN0aW9uIGZpbHRlcihjaGlsZHJlbjogYW55W10pIHtcbiAgICByZXR1cm4gY2hpbGRyZW4uZmxhdChJbmZpbml0eSkubWFwKGNoID0+IGNoIGluc3RhbmNlb2YgR3RrLldpZGdldFxuICAgICAgICA/IGNoXG4gICAgICAgIDogbmV3IEd0ay5MYWJlbCh7IHZpc2libGU6IHRydWUsIGxhYmVsOiBTdHJpbmcoY2gpIH0pKVxufVxuXG4vLyBCb3hcbk9iamVjdC5kZWZpbmVQcm9wZXJ0eShBc3RhbC5Cb3gucHJvdG90eXBlLCBcImNoaWxkcmVuXCIsIHtcbiAgICBnZXQoKSB7IHJldHVybiB0aGlzLmdldF9jaGlsZHJlbigpIH0sXG4gICAgc2V0KHYpIHsgdGhpcy5zZXRfY2hpbGRyZW4odikgfSxcbn0pXG5cbmV4cG9ydCB0eXBlIEJveFByb3BzID0gQ29uc3RydWN0UHJvcHM8Qm94LCBBc3RhbC5Cb3guQ29uc3RydWN0b3JQcm9wcz5cbmV4cG9ydCBjbGFzcyBCb3ggZXh0ZW5kcyBhc3RhbGlmeShBc3RhbC5Cb3gpIHtcbiAgICBzdGF0aWMgeyBHT2JqZWN0LnJlZ2lzdGVyQ2xhc3MoeyBHVHlwZU5hbWU6IFwiQm94XCIgfSwgdGhpcykgfVxuICAgIGNvbnN0cnVjdG9yKHByb3BzPzogQm94UHJvcHMsIC4uLmNoaWxkcmVuOiBBcnJheTxCaW5kYWJsZUNoaWxkPikgeyBzdXBlcih7IGNoaWxkcmVuLCAuLi5wcm9wcyB9IGFzIGFueSkgfVxuICAgIHByb3RlY3RlZCBzZXRDaGlsZHJlbihjaGlsZHJlbjogYW55W10pOiB2b2lkIHsgdGhpcy5zZXRfY2hpbGRyZW4oZmlsdGVyKGNoaWxkcmVuKSkgfVxufVxuXG4vLyBCdXR0b25cbmV4cG9ydCB0eXBlIEJ1dHRvblByb3BzID0gQ29uc3RydWN0UHJvcHM8QnV0dG9uLCBBc3RhbC5CdXR0b24uQ29uc3RydWN0b3JQcm9wcywge1xuICAgIG9uQ2xpY2tlZDogW11cbiAgICBvbkNsaWNrOiBbZXZlbnQ6IEFzdGFsLkNsaWNrRXZlbnRdXG4gICAgb25DbGlja1JlbGVhc2U6IFtldmVudDogQXN0YWwuQ2xpY2tFdmVudF1cbiAgICBvbkhvdmVyOiBbZXZlbnQ6IEFzdGFsLkhvdmVyRXZlbnRdXG4gICAgb25Ib3Zlckxvc3Q6IFtldmVudDogQXN0YWwuSG92ZXJFdmVudF1cbiAgICBvblNjcm9sbDogW2V2ZW50OiBBc3RhbC5TY3JvbGxFdmVudF1cbn0+XG5leHBvcnQgY2xhc3MgQnV0dG9uIGV4dGVuZHMgYXN0YWxpZnkoQXN0YWwuQnV0dG9uKSB7XG4gICAgc3RhdGljIHsgR09iamVjdC5yZWdpc3RlckNsYXNzKHsgR1R5cGVOYW1lOiBcIkJ1dHRvblwiIH0sIHRoaXMpIH1cbiAgICBjb25zdHJ1Y3Rvcihwcm9wcz86IEJ1dHRvblByb3BzLCBjaGlsZD86IEJpbmRhYmxlQ2hpbGQpIHsgc3VwZXIoeyBjaGlsZCwgLi4ucHJvcHMgfSBhcyBhbnkpIH1cbn1cblxuLy8gQ2VudGVyQm94XG5leHBvcnQgdHlwZSBDZW50ZXJCb3hQcm9wcyA9IENvbnN0cnVjdFByb3BzPENlbnRlckJveCwgQXN0YWwuQ2VudGVyQm94LkNvbnN0cnVjdG9yUHJvcHM+XG5leHBvcnQgY2xhc3MgQ2VudGVyQm94IGV4dGVuZHMgYXN0YWxpZnkoQXN0YWwuQ2VudGVyQm94KSB7XG4gICAgc3RhdGljIHsgR09iamVjdC5yZWdpc3RlckNsYXNzKHsgR1R5cGVOYW1lOiBcIkNlbnRlckJveFwiIH0sIHRoaXMpIH1cbiAgICBjb25zdHJ1Y3Rvcihwcm9wcz86IENlbnRlckJveFByb3BzLCAuLi5jaGlsZHJlbjogQXJyYXk8QmluZGFibGVDaGlsZD4pIHsgc3VwZXIoeyBjaGlsZHJlbiwgLi4ucHJvcHMgfSBhcyBhbnkpIH1cbiAgICBwcm90ZWN0ZWQgc2V0Q2hpbGRyZW4oY2hpbGRyZW46IGFueVtdKTogdm9pZCB7XG4gICAgICAgIGNvbnN0IGNoID0gZmlsdGVyKGNoaWxkcmVuKVxuICAgICAgICB0aGlzLnN0YXJ0V2lkZ2V0ID0gY2hbMF0gfHwgbmV3IEd0ay5Cb3hcbiAgICAgICAgdGhpcy5jZW50ZXJXaWRnZXQgPSBjaFsxXSB8fCBuZXcgR3RrLkJveFxuICAgICAgICB0aGlzLmVuZFdpZGdldCA9IGNoWzJdIHx8IG5ldyBHdGsuQm94XG4gICAgfVxufVxuXG4vLyBDaXJjdWxhclByb2dyZXNzXG5leHBvcnQgdHlwZSBDaXJjdWxhclByb2dyZXNzUHJvcHMgPSBDb25zdHJ1Y3RQcm9wczxDaXJjdWxhclByb2dyZXNzLCBBc3RhbC5DaXJjdWxhclByb2dyZXNzLkNvbnN0cnVjdG9yUHJvcHM+XG5leHBvcnQgY2xhc3MgQ2lyY3VsYXJQcm9ncmVzcyBleHRlbmRzIGFzdGFsaWZ5KEFzdGFsLkNpcmN1bGFyUHJvZ3Jlc3MpIHtcbiAgICBzdGF0aWMgeyBHT2JqZWN0LnJlZ2lzdGVyQ2xhc3MoeyBHVHlwZU5hbWU6IFwiQ2lyY3VsYXJQcm9ncmVzc1wiIH0sIHRoaXMpIH1cbiAgICBjb25zdHJ1Y3Rvcihwcm9wcz86IENpcmN1bGFyUHJvZ3Jlc3NQcm9wcywgY2hpbGQ/OiBCaW5kYWJsZUNoaWxkKSB7IHN1cGVyKHsgY2hpbGQsIC4uLnByb3BzIH0gYXMgYW55KSB9XG59XG5cbi8vIERyYXdpbmdBcmVhXG5leHBvcnQgdHlwZSBEcmF3aW5nQXJlYVByb3BzID0gQ29uc3RydWN0UHJvcHM8RHJhd2luZ0FyZWEsIEd0ay5EcmF3aW5nQXJlYS5Db25zdHJ1Y3RvclByb3BzLCB7XG4gICAgb25EcmF3OiBbY3I6IGFueV0gLy8gVE9ETzogY2Fpcm8gdHlwZXNcbn0+XG5leHBvcnQgY2xhc3MgRHJhd2luZ0FyZWEgZXh0ZW5kcyBhc3RhbGlmeShHdGsuRHJhd2luZ0FyZWEpIHtcbiAgICBzdGF0aWMgeyBHT2JqZWN0LnJlZ2lzdGVyQ2xhc3MoeyBHVHlwZU5hbWU6IFwiRHJhd2luZ0FyZWFcIiB9LCB0aGlzKSB9XG4gICAgY29uc3RydWN0b3IocHJvcHM/OiBEcmF3aW5nQXJlYVByb3BzKSB7IHN1cGVyKHByb3BzIGFzIGFueSkgfVxufVxuXG4vLyBFbnRyeVxuZXhwb3J0IHR5cGUgRW50cnlQcm9wcyA9IENvbnN0cnVjdFByb3BzPEVudHJ5LCBHdGsuRW50cnkuQ29uc3RydWN0b3JQcm9wcywge1xuICAgIG9uQ2hhbmdlZDogW11cbiAgICBvbkFjdGl2YXRlOiBbXVxufT5cbmV4cG9ydCBjbGFzcyBFbnRyeSBleHRlbmRzIGFzdGFsaWZ5KEd0ay5FbnRyeSkge1xuICAgIHN0YXRpYyB7IEdPYmplY3QucmVnaXN0ZXJDbGFzcyh7IEdUeXBlTmFtZTogXCJFbnRyeVwiIH0sIHRoaXMpIH1cbiAgICBjb25zdHJ1Y3Rvcihwcm9wcz86IEVudHJ5UHJvcHMpIHsgc3VwZXIocHJvcHMgYXMgYW55KSB9XG59XG5cbi8vIEV2ZW50Qm94XG5leHBvcnQgdHlwZSBFdmVudEJveFByb3BzID0gQ29uc3RydWN0UHJvcHM8RXZlbnRCb3gsIEFzdGFsLkV2ZW50Qm94LkNvbnN0cnVjdG9yUHJvcHMsIHtcbiAgICBvbkNsaWNrOiBbZXZlbnQ6IEFzdGFsLkNsaWNrRXZlbnRdXG4gICAgb25DbGlja1JlbGVhc2U6IFtldmVudDogQXN0YWwuQ2xpY2tFdmVudF1cbiAgICBvbkhvdmVyOiBbZXZlbnQ6IEFzdGFsLkhvdmVyRXZlbnRdXG4gICAgb25Ib3Zlckxvc3Q6IFtldmVudDogQXN0YWwuSG92ZXJFdmVudF1cbiAgICBvblNjcm9sbDogW2V2ZW50OiBBc3RhbC5TY3JvbGxFdmVudF1cbn0+XG5leHBvcnQgY2xhc3MgRXZlbnRCb3ggZXh0ZW5kcyBhc3RhbGlmeShBc3RhbC5FdmVudEJveCkge1xuICAgIHN0YXRpYyB7IEdPYmplY3QucmVnaXN0ZXJDbGFzcyh7IEdUeXBlTmFtZTogXCJFdmVudEJveFwiIH0sIHRoaXMpIH1cbiAgICBjb25zdHJ1Y3Rvcihwcm9wcz86IEV2ZW50Qm94UHJvcHMsIGNoaWxkPzogQmluZGFibGVDaGlsZCkgeyBzdXBlcih7IGNoaWxkLCAuLi5wcm9wcyB9IGFzIGFueSkgfVxufVxuXG4vLyAvLyBUT0RPOiBGaXhlZFxuLy8gLy8gVE9ETzogRmxvd0JveFxuLy9cbi8vIEljb25cbmV4cG9ydCB0eXBlIEljb25Qcm9wcyA9IENvbnN0cnVjdFByb3BzPEljb24sIEFzdGFsLkljb24uQ29uc3RydWN0b3JQcm9wcz5cbmV4cG9ydCBjbGFzcyBJY29uIGV4dGVuZHMgYXN0YWxpZnkoQXN0YWwuSWNvbikge1xuICAgIHN0YXRpYyB7IEdPYmplY3QucmVnaXN0ZXJDbGFzcyh7IEdUeXBlTmFtZTogXCJJY29uXCIgfSwgdGhpcykgfVxuICAgIGNvbnN0cnVjdG9yKHByb3BzPzogSWNvblByb3BzKSB7IHN1cGVyKHByb3BzIGFzIGFueSkgfVxufVxuXG4vLyBMYWJlbFxuZXhwb3J0IHR5cGUgTGFiZWxQcm9wcyA9IENvbnN0cnVjdFByb3BzPExhYmVsLCBBc3RhbC5MYWJlbC5Db25zdHJ1Y3RvclByb3BzPlxuZXhwb3J0IGNsYXNzIExhYmVsIGV4dGVuZHMgYXN0YWxpZnkoQXN0YWwuTGFiZWwpIHtcbiAgICBzdGF0aWMgeyBHT2JqZWN0LnJlZ2lzdGVyQ2xhc3MoeyBHVHlwZU5hbWU6IFwiTGFiZWxcIiB9LCB0aGlzKSB9XG4gICAgY29uc3RydWN0b3IocHJvcHM/OiBMYWJlbFByb3BzKSB7IHN1cGVyKHByb3BzIGFzIGFueSkgfVxuICAgIHByb3RlY3RlZCBzZXRDaGlsZHJlbihjaGlsZHJlbjogYW55W10pOiB2b2lkIHsgdGhpcy5sYWJlbCA9IFN0cmluZyhjaGlsZHJlbikgfVxufVxuXG4vLyBMZXZlbEJhclxuZXhwb3J0IHR5cGUgTGV2ZWxCYXJQcm9wcyA9IENvbnN0cnVjdFByb3BzPExldmVsQmFyLCBBc3RhbC5MZXZlbEJhci5Db25zdHJ1Y3RvclByb3BzPlxuZXhwb3J0IGNsYXNzIExldmVsQmFyIGV4dGVuZHMgYXN0YWxpZnkoQXN0YWwuTGV2ZWxCYXIpIHtcbiAgICBzdGF0aWMgeyBHT2JqZWN0LnJlZ2lzdGVyQ2xhc3MoeyBHVHlwZU5hbWU6IFwiTGV2ZWxCYXJcIiB9LCB0aGlzKSB9XG4gICAgY29uc3RydWN0b3IocHJvcHM/OiBMZXZlbEJhclByb3BzKSB7IHN1cGVyKHByb3BzIGFzIGFueSkgfVxufVxuXG4vLyBUT0RPOiBMaXN0Qm94XG5cbi8vIE1lbnVCdXR0b25cbmV4cG9ydCB0eXBlIE1lbnVCdXR0b25Qcm9wcyA9IENvbnN0cnVjdFByb3BzPE1lbnVCdXR0b24sIEd0ay5NZW51QnV0dG9uLkNvbnN0cnVjdG9yUHJvcHM+XG5leHBvcnQgY2xhc3MgTWVudUJ1dHRvbiBleHRlbmRzIGFzdGFsaWZ5KEd0ay5NZW51QnV0dG9uKSB7XG4gICAgc3RhdGljIHsgR09iamVjdC5yZWdpc3RlckNsYXNzKHsgR1R5cGVOYW1lOiBcIk1lbnVCdXR0b25cIiB9LCB0aGlzKSB9XG4gICAgY29uc3RydWN0b3IocHJvcHM/OiBNZW51QnV0dG9uUHJvcHMsIGNoaWxkPzogQmluZGFibGVDaGlsZCkgeyBzdXBlcih7IGNoaWxkLCAuLi5wcm9wcyB9IGFzIGFueSkgfVxufVxuXG4vLyBPdmVybGF5XG5PYmplY3QuZGVmaW5lUHJvcGVydHkoQXN0YWwuT3ZlcmxheS5wcm90b3R5cGUsIFwib3ZlcmxheXNcIiwge1xuICAgIGdldCgpIHsgcmV0dXJuIHRoaXMuZ2V0X292ZXJsYXlzKCkgfSxcbiAgICBzZXQodikgeyB0aGlzLnNldF9vdmVybGF5cyh2KSB9LFxufSlcblxuZXhwb3J0IHR5cGUgT3ZlcmxheVByb3BzID0gQ29uc3RydWN0UHJvcHM8T3ZlcmxheSwgQXN0YWwuT3ZlcmxheS5Db25zdHJ1Y3RvclByb3BzPlxuZXhwb3J0IGNsYXNzIE92ZXJsYXkgZXh0ZW5kcyBhc3RhbGlmeShBc3RhbC5PdmVybGF5KSB7XG4gICAgc3RhdGljIHsgR09iamVjdC5yZWdpc3RlckNsYXNzKHsgR1R5cGVOYW1lOiBcIk92ZXJsYXlcIiB9LCB0aGlzKSB9XG4gICAgY29uc3RydWN0b3IocHJvcHM/OiBPdmVybGF5UHJvcHMsIC4uLmNoaWxkcmVuOiBBcnJheTxCaW5kYWJsZUNoaWxkPikgeyBzdXBlcih7IGNoaWxkcmVuLCAuLi5wcm9wcyB9IGFzIGFueSkgfVxuICAgIHByb3RlY3RlZCBzZXRDaGlsZHJlbihjaGlsZHJlbjogYW55W10pOiB2b2lkIHtcbiAgICAgICAgY29uc3QgW2NoaWxkLCAuLi5vdmVybGF5c10gPSBmaWx0ZXIoY2hpbGRyZW4pXG4gICAgICAgIHRoaXMuc2V0X2NoaWxkKGNoaWxkKVxuICAgICAgICB0aGlzLnNldF9vdmVybGF5cyhvdmVybGF5cylcbiAgICB9XG59XG5cbi8vIFJldmVhbGVyXG5leHBvcnQgdHlwZSBSZXZlYWxlclByb3BzID0gQ29uc3RydWN0UHJvcHM8UmV2ZWFsZXIsIEd0ay5SZXZlYWxlci5Db25zdHJ1Y3RvclByb3BzPlxuZXhwb3J0IGNsYXNzIFJldmVhbGVyIGV4dGVuZHMgYXN0YWxpZnkoR3RrLlJldmVhbGVyKSB7XG4gICAgc3RhdGljIHsgR09iamVjdC5yZWdpc3RlckNsYXNzKHsgR1R5cGVOYW1lOiBcIlJldmVhbGVyXCIgfSwgdGhpcykgfVxuICAgIGNvbnN0cnVjdG9yKHByb3BzPzogUmV2ZWFsZXJQcm9wcywgY2hpbGQ/OiBCaW5kYWJsZUNoaWxkKSB7IHN1cGVyKHsgY2hpbGQsIC4uLnByb3BzIH0gYXMgYW55KSB9XG59XG5cbi8vIFNjcm9sbGFibGVcbmV4cG9ydCB0eXBlIFNjcm9sbGFibGVQcm9wcyA9IENvbnN0cnVjdFByb3BzPFNjcm9sbGFibGUsIEFzdGFsLlNjcm9sbGFibGUuQ29uc3RydWN0b3JQcm9wcz5cbmV4cG9ydCBjbGFzcyBTY3JvbGxhYmxlIGV4dGVuZHMgYXN0YWxpZnkoQXN0YWwuU2Nyb2xsYWJsZSkge1xuICAgIHN0YXRpYyB7IEdPYmplY3QucmVnaXN0ZXJDbGFzcyh7IEdUeXBlTmFtZTogXCJTY3JvbGxhYmxlXCIgfSwgdGhpcykgfVxuICAgIGNvbnN0cnVjdG9yKHByb3BzPzogU2Nyb2xsYWJsZVByb3BzLCBjaGlsZD86IEJpbmRhYmxlQ2hpbGQpIHsgc3VwZXIoeyBjaGlsZCwgLi4ucHJvcHMgfSBhcyBhbnkpIH1cbn1cblxuLy8gU2xpZGVyXG5leHBvcnQgdHlwZSBTbGlkZXJQcm9wcyA9IENvbnN0cnVjdFByb3BzPFNsaWRlciwgQXN0YWwuU2xpZGVyLkNvbnN0cnVjdG9yUHJvcHMsIHtcbiAgICBvbkRyYWdnZWQ6IFtdXG59PlxuZXhwb3J0IGNsYXNzIFNsaWRlciBleHRlbmRzIGFzdGFsaWZ5KEFzdGFsLlNsaWRlcikge1xuICAgIHN0YXRpYyB7IEdPYmplY3QucmVnaXN0ZXJDbGFzcyh7IEdUeXBlTmFtZTogXCJTbGlkZXJcIiB9LCB0aGlzKSB9XG4gICAgY29uc3RydWN0b3IocHJvcHM/OiBTbGlkZXJQcm9wcykgeyBzdXBlcihwcm9wcyBhcyBhbnkpIH1cbn1cblxuLy8gU3RhY2tcbmV4cG9ydCB0eXBlIFN0YWNrUHJvcHMgPSBDb25zdHJ1Y3RQcm9wczxTdGFjaywgQXN0YWwuU3RhY2suQ29uc3RydWN0b3JQcm9wcz5cbmV4cG9ydCBjbGFzcyBTdGFjayBleHRlbmRzIGFzdGFsaWZ5KEFzdGFsLlN0YWNrKSB7XG4gICAgc3RhdGljIHsgR09iamVjdC5yZWdpc3RlckNsYXNzKHsgR1R5cGVOYW1lOiBcIlN0YWNrXCIgfSwgdGhpcykgfVxuICAgIGNvbnN0cnVjdG9yKHByb3BzPzogU3RhY2tQcm9wcywgLi4uY2hpbGRyZW46IEFycmF5PEJpbmRhYmxlQ2hpbGQ+KSB7IHN1cGVyKHsgY2hpbGRyZW4sIC4uLnByb3BzIH0gYXMgYW55KSB9XG4gICAgcHJvdGVjdGVkIHNldENoaWxkcmVuKGNoaWxkcmVuOiBhbnlbXSk6IHZvaWQgeyB0aGlzLnNldF9jaGlsZHJlbihmaWx0ZXIoY2hpbGRyZW4pKSB9XG59XG5cbi8vIFN3aXRjaFxuZXhwb3J0IHR5cGUgU3dpdGNoUHJvcHMgPSBDb25zdHJ1Y3RQcm9wczxTd2l0Y2gsIEd0ay5Td2l0Y2guQ29uc3RydWN0b3JQcm9wcz5cbmV4cG9ydCBjbGFzcyBTd2l0Y2ggZXh0ZW5kcyBhc3RhbGlmeShHdGsuU3dpdGNoKSB7XG4gICAgc3RhdGljIHsgR09iamVjdC5yZWdpc3RlckNsYXNzKHsgR1R5cGVOYW1lOiBcIlN3aXRjaFwiIH0sIHRoaXMpIH1cbiAgICBjb25zdHJ1Y3Rvcihwcm9wcz86IFN3aXRjaFByb3BzKSB7IHN1cGVyKHByb3BzIGFzIGFueSkgfVxufVxuXG4vLyBXaW5kb3dcbmV4cG9ydCB0eXBlIFdpbmRvd1Byb3BzID0gQ29uc3RydWN0UHJvcHM8V2luZG93LCBBc3RhbC5XaW5kb3cuQ29uc3RydWN0b3JQcm9wcz5cbmV4cG9ydCBjbGFzcyBXaW5kb3cgZXh0ZW5kcyBhc3RhbGlmeShBc3RhbC5XaW5kb3cpIHtcbiAgICBzdGF0aWMgeyBHT2JqZWN0LnJlZ2lzdGVyQ2xhc3MoeyBHVHlwZU5hbWU6IFwiV2luZG93XCIgfSwgdGhpcykgfVxuICAgIGNvbnN0cnVjdG9yKHByb3BzPzogV2luZG93UHJvcHMsIGNoaWxkPzogQmluZGFibGVDaGlsZCkgeyBzdXBlcih7IGNoaWxkLCAuLi5wcm9wcyB9IGFzIGFueSkgfVxufVxuIiwgIi8qIEJhc2UxNiBHcnV2Ym94IERhcmsgSGFyZCBDb2xvciBQYWxldHRlIC0gU0NTUyBWYXJpYWJsZXMgKi9cbi8qIEZvbnQgU2l6ZXMgKi9cbi8qIFJlc2V0IEdUSzMgY29tcG9uZW50IHN0eWxpbmcgKi9cbi8qIEdlbmVyYWwgUmVzZXQgKi9cbioge1xuICBwYWRkaW5nOiAwO1xuICBtYXJnaW46IDA7XG4gIGJvcmRlcjogMDtcbiAgZm9udC1mYW1pbHk6IHNhbnMtc2VyaWY7XG4gIGZvbnQtc2l6ZTogMTJweDtcbn1cblxuLyogUmVtb3ZlIGRlZmF1bHQgYmFja2dyb3VuZCBhbmQgYm9yZGVycyAqL1xuR3RrV2lkZ2V0IHtcbiAgYmFja2dyb3VuZDogdHJhbnNwYXJlbnQ7XG4gIGJvcmRlcjogbm9uZTtcbn1cblxuLyogUmVtb3ZlIGRlZmF1bHQgcGFkZGluZyBmb3IgYWxsIGNvbnRhaW5lcnMgKi9cbkd0a0NvbnRhaW5lciB7XG4gIHBhZGRpbmc6IDA7XG4gIG1hcmdpbjogMDtcbn1cblxuLyogUmVtb3ZlIGRlZmF1bHQgc3R5bGluZyBmcm9tIGJ1dHRvbnMgKi9cbmJ1dHRvbiwgR3RrQnV0dG9uIHtcbiAgcGFkZGluZzogMDtcbiAgYm9yZGVyOiBub25lO1xuICBiYWNrZ3JvdW5kOiB0cmFuc3BhcmVudDtcbiAgYm94LXNoYWRvdzogbm9uZTtcbiAgdGV4dC1zaGFkb3c6IG5vbmU7XG59XG5cbi8qIFJlbW92ZSBkZWZhdWx0IGJvcmRlciBhbmQgYmFja2dyb3VuZCBmb3IgZW50cnkgd2lkZ2V0cyAqL1xuR3RrRW50cnksIEd0a1RleHRWaWV3LCBHdGtDb21ib0JveCB7XG4gIHBhZGRpbmc6IDA7XG4gIG1hcmdpbjogMDtcbiAgYm9yZGVyOiBub25lO1xuICBiYWNrZ3JvdW5kOiB0cmFuc3BhcmVudDtcbiAgYm94LXNoYWRvdzogbm9uZTtcbn1cblxuLyogUmVtb3ZlIGRlZmF1bHQgcGFkZGluZyBhbmQgYm9yZGVyIGZvciBsYWJlbHMgKi9cbkd0a0xhYmVsIHtcbiAgcGFkZGluZzogMDtcbiAgbWFyZ2luOiAwO1xuICBib3JkZXI6IG5vbmU7XG4gIGJhY2tncm91bmQ6IHRyYW5zcGFyZW50O1xuICB0ZXh0LXNoYWRvdzogbm9uZTtcbn1cblxuLyogUmVtb3ZlIGRlZmF1bHQgc3R5bGluZyBmcm9tIHNsaWRlcnMgKi9cbkd0a1NjYWxlLCBHdGtTY3JvbGxiYXIge1xuICBwYWRkaW5nOiAwO1xuICBtYXJnaW46IDA7XG4gIGJvcmRlcjogbm9uZTtcbiAgYmFja2dyb3VuZDogdHJhbnNwYXJlbnQ7XG59XG5cbi8qIFJlbW92ZSBkZWZhdWx0IHN0eWxpbmcgZnJvbSBtZW51cyAqL1xuR3RrTWVudSwgR3RrTWVudUl0ZW0ge1xuICBwYWRkaW5nOiAwO1xuICBtYXJnaW46IDA7XG4gIGJvcmRlcjogbm9uZTtcbiAgYmFja2dyb3VuZDogdHJhbnNwYXJlbnQ7XG59XG5cbi8qIFJlbW92ZSBkZWZhdWx0IHNoYWRvdyBmcm9tIHdpbmRvd3MgKi9cbkd0a1dpbmRvdyB7XG4gIGJvcmRlcjogbm9uZTtcbiAgYmFja2dyb3VuZDogdHJhbnNwYXJlbnQ7XG4gIGJveC1zaGFkb3c6IG5vbmU7XG59XG5cbi8qIFJlbW92ZSBkZWZhdWx0IHN0eWxpbmcgZm9yIHRvb2x0aXBzICovXG5HdGtUb29sdGlwIHtcbiAgYm9yZGVyOiBub25lO1xuICBiYWNrZ3JvdW5kOiB0cmFuc3BhcmVudDtcbn1cblxuLyogUGFkZGluZyBBbGwgU2lkZXMgKi9cbi5wLTAge1xuICBwYWRkaW5nOiAwO1xufVxuXG4ucC0xIHtcbiAgcGFkZGluZzogNHB4O1xufVxuXG4ucC0xIHtcbiAgcGFkZGluZzogNHB4O1xufVxuXG4ucC0yIHtcbiAgcGFkZGluZzogOHB4O1xufVxuXG4ucC0zIHtcbiAgcGFkZGluZzogMTJweDtcbn1cblxuLnAtNCB7XG4gIHBhZGRpbmc6IDE2cHg7XG59XG5cbi5wLTUge1xuICBwYWRkaW5nOiAyMHB4O1xufVxuXG4ucC02IHtcbiAgcGFkZGluZzogMjRweDtcbn1cblxuLnAtNyB7XG4gIHBhZGRpbmc6IDI4cHg7XG59XG5cbi5wLTgge1xuICBwYWRkaW5nOiAzMnB4O1xufVxuXG4ucC05IHtcbiAgcGFkZGluZzogMzZweDtcbn1cblxuLnAtMTAge1xuICBwYWRkaW5nOiA0MHB4O1xufVxuXG4ucC0xMSB7XG4gIHBhZGRpbmc6IDQ0cHg7XG59XG5cbi5wLTEyIHtcbiAgcGFkZGluZzogNDhweDtcbn1cblxuLnAtMTMge1xuICBwYWRkaW5nOiA1MnB4O1xufVxuXG4ucC0xNCB7XG4gIHBhZGRpbmc6IDU2cHg7XG59XG5cbi5wLTE1IHtcbiAgcGFkZGluZzogNjBweDtcbn1cblxuLnAtMTYge1xuICBwYWRkaW5nOiA2NHB4O1xufVxuXG4vKiBIb3Jpem9udGFsIFBhZGRpbmcgKExlZnQgJiBSaWdodCkgKi9cbi5weC0wIHtcbiAgcGFkZGluZy1sZWZ0OiAwO1xuICBwYWRkaW5nLXJpZ2h0OiAwO1xufVxuXG4ucHgtMSB7XG4gIHBhZGRpbmctbGVmdDogNHB4O1xuICBwYWRkaW5nLXJpZ2h0OiA0cHg7XG59XG5cbi5weC0yIHtcbiAgcGFkZGluZy1sZWZ0OiA4cHg7XG4gIHBhZGRpbmctcmlnaHQ6IDhweDtcbn1cblxuLnB4LTMge1xuICBwYWRkaW5nLWxlZnQ6IDEycHg7XG4gIHBhZGRpbmctcmlnaHQ6IDEycHg7XG59XG5cbi5weC00IHtcbiAgcGFkZGluZy1sZWZ0OiAxNnB4O1xuICBwYWRkaW5nLXJpZ2h0OiAxNnB4O1xufVxuXG4ucHgtNSB7XG4gIHBhZGRpbmctbGVmdDogMjBweDtcbiAgcGFkZGluZy1yaWdodDogMjBweDtcbn1cblxuLnB4LTYge1xuICBwYWRkaW5nLWxlZnQ6IDI0cHg7XG4gIHBhZGRpbmctcmlnaHQ6IDI0cHg7XG59XG5cbi5weC03IHtcbiAgcGFkZGluZy1sZWZ0OiAyOHB4O1xuICBwYWRkaW5nLXJpZ2h0OiAyOHB4O1xufVxuXG4ucHgtOCB7XG4gIHBhZGRpbmctbGVmdDogMzJweDtcbiAgcGFkZGluZy1yaWdodDogMzJweDtcbn1cblxuLnB4LTkge1xuICBwYWRkaW5nLWxlZnQ6IDM2cHg7XG4gIHBhZGRpbmctcmlnaHQ6IDM2cHg7XG59XG5cbi5weC0xMCB7XG4gIHBhZGRpbmctbGVmdDogNDBweDtcbiAgcGFkZGluZy1yaWdodDogNDBweDtcbn1cblxuLnB4LTExIHtcbiAgcGFkZGluZy1sZWZ0OiA0NHB4O1xuICBwYWRkaW5nLXJpZ2h0OiA0NHB4O1xufVxuXG4ucHgtMTIge1xuICBwYWRkaW5nLWxlZnQ6IDQ4cHg7XG4gIHBhZGRpbmctcmlnaHQ6IDQ4cHg7XG59XG5cbi5weC0xMyB7XG4gIHBhZGRpbmctbGVmdDogNTJweDtcbiAgcGFkZGluZy1yaWdodDogNTJweDtcbn1cblxuLnB4LTE0IHtcbiAgcGFkZGluZy1sZWZ0OiA1NnB4O1xuICBwYWRkaW5nLXJpZ2h0OiA1NnB4O1xufVxuXG4ucHgtMTUge1xuICBwYWRkaW5nLWxlZnQ6IDYwcHg7XG4gIHBhZGRpbmctcmlnaHQ6IDYwcHg7XG59XG5cbi5weC0xNiB7XG4gIHBhZGRpbmctbGVmdDogNjRweDtcbiAgcGFkZGluZy1yaWdodDogNjRweDtcbn1cblxuLyogVmVydGljYWwgUGFkZGluZyAoVG9wICYgQm90dG9tKSAqL1xuLnB5LTAge1xuICBwYWRkaW5nLXRvcDogMDtcbiAgcGFkZGluZy1ib3R0b206IDA7XG59XG5cbi5weS0xIHtcbiAgcGFkZGluZy10b3A6IDRweDtcbiAgcGFkZGluZy1ib3R0b206IDRweDtcbn1cblxuLnB5LTIge1xuICBwYWRkaW5nLXRvcDogOHB4O1xuICBwYWRkaW5nLWJvdHRvbTogOHB4O1xufVxuXG4ucHktMyB7XG4gIHBhZGRpbmctdG9wOiAxMnB4O1xuICBwYWRkaW5nLWJvdHRvbTogMTJweDtcbn1cblxuLnB5LTQge1xuICBwYWRkaW5nLXRvcDogMTZweDtcbiAgcGFkZGluZy1ib3R0b206IDE2cHg7XG59XG5cbi5weS01IHtcbiAgcGFkZGluZy10b3A6IDIwcHg7XG4gIHBhZGRpbmctYm90dG9tOiAyMHB4O1xufVxuXG4ucHktNiB7XG4gIHBhZGRpbmctdG9wOiAyNHB4O1xuICBwYWRkaW5nLWJvdHRvbTogMjRweDtcbn1cblxuLnB5LTcge1xuICBwYWRkaW5nLXRvcDogMjhweDtcbiAgcGFkZGluZy1ib3R0b206IDI4cHg7XG59XG5cbi5weS04IHtcbiAgcGFkZGluZy10b3A6IDMycHg7XG4gIHBhZGRpbmctYm90dG9tOiAzMnB4O1xufVxuXG4ucHktOSB7XG4gIHBhZGRpbmctdG9wOiAzNnB4O1xuICBwYWRkaW5nLWJvdHRvbTogMzZweDtcbn1cblxuLnB5LTEwIHtcbiAgcGFkZGluZy10b3A6IDQwcHg7XG4gIHBhZGRpbmctYm90dG9tOiA0MHB4O1xufVxuXG4ucHktMTEge1xuICBwYWRkaW5nLXRvcDogNDRweDtcbiAgcGFkZGluZy1ib3R0b206IDQ0cHg7XG59XG5cbi5weS0xMiB7XG4gIHBhZGRpbmctdG9wOiA0OHB4O1xuICBwYWRkaW5nLWJvdHRvbTogNDhweDtcbn1cblxuLnB5LTEzIHtcbiAgcGFkZGluZy10b3A6IDUycHg7XG4gIHBhZGRpbmctYm90dG9tOiA1MnB4O1xufVxuXG4ucHktMTQge1xuICBwYWRkaW5nLXRvcDogNTZweDtcbiAgcGFkZGluZy1ib3R0b206IDU2cHg7XG59XG5cbi5weS0xNSB7XG4gIHBhZGRpbmctdG9wOiA2MHB4O1xuICBwYWRkaW5nLWJvdHRvbTogNjBweDtcbn1cblxuLnB5LTE2IHtcbiAgcGFkZGluZy10b3A6IDY0cHg7XG4gIHBhZGRpbmctYm90dG9tOiA2NHB4O1xufVxuXG4vKiBQYWRkaW5nIExlZnQgKi9cbi5wbC0wIHtcbiAgcGFkZGluZy1sZWZ0OiAwO1xufVxuXG4ucGwtMSB7XG4gIHBhZGRpbmctbGVmdDogNHB4O1xufVxuXG4ucGwtMiB7XG4gIHBhZGRpbmctbGVmdDogOHB4O1xufVxuXG4ucGwtMyB7XG4gIHBhZGRpbmctbGVmdDogMTJweDtcbn1cblxuLnBsLTQge1xuICBwYWRkaW5nLWxlZnQ6IDE2cHg7XG59XG5cbi5wbC01IHtcbiAgcGFkZGluZy1sZWZ0OiAyMHB4O1xufVxuXG4ucGwtNiB7XG4gIHBhZGRpbmctbGVmdDogMjRweDtcbn1cblxuLnBsLTcge1xuICBwYWRkaW5nLWxlZnQ6IDI4cHg7XG59XG5cbi5wbC04IHtcbiAgcGFkZGluZy1sZWZ0OiAzMnB4O1xufVxuXG4ucGwtOSB7XG4gIHBhZGRpbmctbGVmdDogMzZweDtcbn1cblxuLnBsLTEwIHtcbiAgcGFkZGluZy1sZWZ0OiA0MHB4O1xufVxuXG4ucGwtMTEge1xuICBwYWRkaW5nLWxlZnQ6IDQ0cHg7XG59XG5cbi5wbC0xMiB7XG4gIHBhZGRpbmctbGVmdDogNDhweDtcbn1cblxuLnBsLTEzIHtcbiAgcGFkZGluZy1sZWZ0OiA1MnB4O1xufVxuXG4ucGwtMTQge1xuICBwYWRkaW5nLWxlZnQ6IDU2cHg7XG59XG5cbi5wbC0xNSB7XG4gIHBhZGRpbmctbGVmdDogNjBweDtcbn1cblxuLnBsLTE2IHtcbiAgcGFkZGluZy1sZWZ0OiA2NHB4O1xufVxuXG4vKiBQYWRkaW5nIFJpZ2h0ICovXG4ucHItMCB7XG4gIHBhZGRpbmctcmlnaHQ6IDA7XG59XG5cbi5wci0xIHtcbiAgcGFkZGluZy1yaWdodDogNHB4O1xufVxuXG4ucHItMiB7XG4gIHBhZGRpbmctcmlnaHQ6IDhweDtcbn1cblxuLnByLTMge1xuICBwYWRkaW5nLXJpZ2h0OiAxMnB4O1xufVxuXG4ucHItNCB7XG4gIHBhZGRpbmctcmlnaHQ6IDE2cHg7XG59XG5cbi5wci01IHtcbiAgcGFkZGluZy1yaWdodDogMjBweDtcbn1cblxuLnByLTYge1xuICBwYWRkaW5nLXJpZ2h0OiAyNHB4O1xufVxuXG4ucHItNyB7XG4gIHBhZGRpbmctcmlnaHQ6IDI4cHg7XG59XG5cbi5wci04IHtcbiAgcGFkZGluZy1yaWdodDogMzJweDtcbn1cblxuLnByLTkge1xuICBwYWRkaW5nLXJpZ2h0OiAzNnB4O1xufVxuXG4ucHItMTAge1xuICBwYWRkaW5nLXJpZ2h0OiA0MHB4O1xufVxuXG4ucHItMTEge1xuICBwYWRkaW5nLXJpZ2h0OiA0NHB4O1xufVxuXG4ucHItMTIge1xuICBwYWRkaW5nLXJpZ2h0OiA0OHB4O1xufVxuXG4ucHItMTMge1xuICBwYWRkaW5nLXJpZ2h0OiA1MnB4O1xufVxuXG4ucHItMTQge1xuICBwYWRkaW5nLXJpZ2h0OiA1NnB4O1xufVxuXG4ucHItMTUge1xuICBwYWRkaW5nLXJpZ2h0OiA2MHB4O1xufVxuXG4ucHItMTYge1xuICBwYWRkaW5nLXJpZ2h0OiA2NHB4O1xufVxuXG4vKiBQYWRkaW5nIFRvcCAqL1xuLnB0LTAge1xuICBwYWRkaW5nLXRvcDogMDtcbn1cblxuLnB0LTEge1xuICBwYWRkaW5nLXRvcDogNHB4O1xufVxuXG4ucHQtMiB7XG4gIHBhZGRpbmctdG9wOiA4cHg7XG59XG5cbi5wdC0zIHtcbiAgcGFkZGluZy10b3A6IDEycHg7XG59XG5cbi5wdC00IHtcbiAgcGFkZGluZy10b3A6IDE2cHg7XG59XG5cbi5wdC01IHtcbiAgcGFkZGluZy10b3A6IDIwcHg7XG59XG5cbi5wdC02IHtcbiAgcGFkZGluZy10b3A6IDI0cHg7XG59XG5cbi5wdC03IHtcbiAgcGFkZGluZy10b3A6IDI4cHg7XG59XG5cbi5wdC04IHtcbiAgcGFkZGluZy10b3A6IDMycHg7XG59XG5cbi5wdC05IHtcbiAgcGFkZGluZy10b3A6IDM2cHg7XG59XG5cbi5wdC0xMCB7XG4gIHBhZGRpbmctdG9wOiA0MHB4O1xufVxuXG4ucHQtMTEge1xuICBwYWRkaW5nLXRvcDogNDRweDtcbn1cblxuLnB0LTEyIHtcbiAgcGFkZGluZy10b3A6IDQ4cHg7XG59XG5cbi5wdC0xMyB7XG4gIHBhZGRpbmctdG9wOiA1MnB4O1xufVxuXG4ucHQtMTQge1xuICBwYWRkaW5nLXRvcDogNTZweDtcbn1cblxuLnB0LTE1IHtcbiAgcGFkZGluZy10b3A6IDYwcHg7XG59XG5cbi5wdC0xNiB7XG4gIHBhZGRpbmctdG9wOiA2NHB4O1xufVxuXG4vKiBQYWRkaW5nIEJvdHRvbSAqL1xuLnBiLTAge1xuICBwYWRkaW5nLWJvdHRvbTogMDtcbn1cblxuLnBiLTEge1xuICBwYWRkaW5nLWJvdHRvbTogNHB4O1xufVxuXG4ucGItMiB7XG4gIHBhZGRpbmctYm90dG9tOiA4cHg7XG59XG5cbi5wYi0zIHtcbiAgcGFkZGluZy1ib3R0b206IDEycHg7XG59XG5cbi5wYi00IHtcbiAgcGFkZGluZy1ib3R0b206IDE2cHg7XG59XG5cbi5wYi01IHtcbiAgcGFkZGluZy1ib3R0b206IDIwcHg7XG59XG5cbi5wYi02IHtcbiAgcGFkZGluZy1ib3R0b206IDI0cHg7XG59XG5cbi5wYi03IHtcbiAgcGFkZGluZy1ib3R0b206IDI4cHg7XG59XG5cbi5wYi04IHtcbiAgcGFkZGluZy1ib3R0b206IDMycHg7XG59XG5cbi5wYi05IHtcbiAgcGFkZGluZy1ib3R0b206IDM2cHg7XG59XG5cbi5wYi0xMCB7XG4gIHBhZGRpbmctYm90dG9tOiA0MHB4O1xufVxuXG4ucGItMTEge1xuICBwYWRkaW5nLWJvdHRvbTogNDRweDtcbn1cblxuLnBiLTEyIHtcbiAgcGFkZGluZy1ib3R0b206IDQ4cHg7XG59XG5cbi5wYi0xMyB7XG4gIHBhZGRpbmctYm90dG9tOiA1MnB4O1xufVxuXG4ucGItMTQge1xuICBwYWRkaW5nLWJvdHRvbTogNTZweDtcbn1cblxuLnBiLTE1IHtcbiAgcGFkZGluZy1ib3R0b206IDYwcHg7XG59XG5cbi5wYi0xNiB7XG4gIHBhZGRpbmctYm90dG9tOiA2NHB4O1xufVxuXG4vKiBNYXJnaW4gQWxsIFNpZGVzICovXG4ubS0wIHtcbiAgbWFyZ2luOiAwO1xufVxuXG4ubS0xIHtcbiAgbWFyZ2luOiA0cHg7XG59XG5cbi5tLTIge1xuICBtYXJnaW46IDhweDtcbn1cblxuLm0tMyB7XG4gIG1hcmdpbjogMTJweDtcbn1cblxuLm0tNCB7XG4gIG1hcmdpbjogMTZweDtcbn1cblxuLm0tNSB7XG4gIG1hcmdpbjogMjBweDtcbn1cblxuLm0tNiB7XG4gIG1hcmdpbjogMjRweDtcbn1cblxuLm0tNyB7XG4gIG1hcmdpbjogMjhweDtcbn1cblxuLm0tOCB7XG4gIG1hcmdpbjogMzJweDtcbn1cblxuLm0tOSB7XG4gIG1hcmdpbjogMzZweDtcbn1cblxuLm0tMTAge1xuICBtYXJnaW46IDQwcHg7XG59XG5cbi5tLTExIHtcbiAgbWFyZ2luOiA0NHB4O1xufVxuXG4ubS0xMiB7XG4gIG1hcmdpbjogNDhweDtcbn1cblxuLm0tMTMge1xuICBtYXJnaW46IDUycHg7XG59XG5cbi5tLTE0IHtcbiAgbWFyZ2luOiA1NnB4O1xufVxuXG4ubS0xNSB7XG4gIG1hcmdpbjogNjBweDtcbn1cblxuLm0tMTYge1xuICBtYXJnaW46IDY0cHg7XG59XG5cbi8qIEhvcml6b250YWwgTWFyZ2luIChMZWZ0ICYgUmlnaHQpICovXG4ubXgtMCB7XG4gIG1hcmdpbi1sZWZ0OiAwO1xuICBtYXJnaW4tcmlnaHQ6IDA7XG59XG5cbi5teC0xIHtcbiAgbWFyZ2luLWxlZnQ6IDRweDtcbiAgbWFyZ2luLXJpZ2h0OiA0cHg7XG59XG5cbi5teC0yIHtcbiAgbWFyZ2luLWxlZnQ6IDhweDtcbiAgbWFyZ2luLXJpZ2h0OiA4cHg7XG59XG5cbi5teC0zIHtcbiAgbWFyZ2luLWxlZnQ6IDEycHg7XG4gIG1hcmdpbi1yaWdodDogMTJweDtcbn1cblxuLm14LTQge1xuICBtYXJnaW4tbGVmdDogMTZweDtcbiAgbWFyZ2luLXJpZ2h0OiAxNnB4O1xufVxuXG4ubXgtNSB7XG4gIG1hcmdpbi1sZWZ0OiAyMHB4O1xuICBtYXJnaW4tcmlnaHQ6IDIwcHg7XG59XG5cbi5teC02IHtcbiAgbWFyZ2luLWxlZnQ6IDI0cHg7XG4gIG1hcmdpbi1yaWdodDogMjRweDtcbn1cblxuLm14LTcge1xuICBtYXJnaW4tbGVmdDogMjhweDtcbiAgbWFyZ2luLXJpZ2h0OiAyOHB4O1xufVxuXG4ubXgtOCB7XG4gIG1hcmdpbi1sZWZ0OiAzMnB4O1xuICBtYXJnaW4tcmlnaHQ6IDMycHg7XG59XG5cbi5teC05IHtcbiAgbWFyZ2luLWxlZnQ6IDM2cHg7XG4gIG1hcmdpbi1yaWdodDogMzZweDtcbn1cblxuLm14LTEwIHtcbiAgbWFyZ2luLWxlZnQ6IDQwcHg7XG4gIG1hcmdpbi1yaWdodDogNDBweDtcbn1cblxuLm14LTExIHtcbiAgbWFyZ2luLWxlZnQ6IDQ0cHg7XG4gIG1hcmdpbi1yaWdodDogNDRweDtcbn1cblxuLm14LTEyIHtcbiAgbWFyZ2luLWxlZnQ6IDQ4cHg7XG4gIG1hcmdpbi1yaWdodDogNDhweDtcbn1cblxuLm14LTEzIHtcbiAgbWFyZ2luLWxlZnQ6IDUycHg7XG4gIG1hcmdpbi1yaWdodDogNTJweDtcbn1cblxuLm14LTE0IHtcbiAgbWFyZ2luLWxlZnQ6IDU2cHg7XG4gIG1hcmdpbi1yaWdodDogNTZweDtcbn1cblxuLm14LTE1IHtcbiAgbWFyZ2luLWxlZnQ6IDYwcHg7XG4gIG1hcmdpbi1yaWdodDogNjBweDtcbn1cblxuLm14LTE2IHtcbiAgbWFyZ2luLWxlZnQ6IDY0cHg7XG4gIG1hcmdpbi1yaWdodDogNjRweDtcbn1cblxuLyogVmVydGljYWwgTWFyZ2luIChUb3AgJiBCb3R0b20pICovXG4ubXktMCB7XG4gIG1hcmdpbi10b3A6IDA7XG4gIG1hcmdpbi1ib3R0b206IDA7XG59XG5cbi5teS0xIHtcbiAgbWFyZ2luLXRvcDogNHB4O1xuICBtYXJnaW4tYm90dG9tOiA0cHg7XG59XG5cbi5teS0yIHtcbiAgbWFyZ2luLXRvcDogOHB4O1xuICBtYXJnaW4tYm90dG9tOiA4cHg7XG59XG5cbi5teS0zIHtcbiAgbWFyZ2luLXRvcDogMTJweDtcbiAgbWFyZ2luLWJvdHRvbTogMTJweDtcbn1cblxuLm15LTQge1xuICBtYXJnaW4tdG9wOiAxNnB4O1xuICBtYXJnaW4tYm90dG9tOiAxNnB4O1xufVxuXG4ubXktNSB7XG4gIG1hcmdpbi10b3A6IDIwcHg7XG4gIG1hcmdpbi1ib3R0b206IDIwcHg7XG59XG5cbi5teS02IHtcbiAgbWFyZ2luLXRvcDogMjRweDtcbiAgbWFyZ2luLWJvdHRvbTogMjRweDtcbn1cblxuLm15LTcge1xuICBtYXJnaW4tdG9wOiAyOHB4O1xuICBtYXJnaW4tYm90dG9tOiAyOHB4O1xufVxuXG4ubXktOCB7XG4gIG1hcmdpbi10b3A6IDMycHg7XG4gIG1hcmdpbi1ib3R0b206IDMycHg7XG59XG5cbi5teS05IHtcbiAgbWFyZ2luLXRvcDogMzZweDtcbiAgbWFyZ2luLWJvdHRvbTogMzZweDtcbn1cblxuLm15LTEwIHtcbiAgbWFyZ2luLXRvcDogNDBweDtcbiAgbWFyZ2luLWJvdHRvbTogNDBweDtcbn1cblxuLm15LTExIHtcbiAgbWFyZ2luLXRvcDogNDRweDtcbiAgbWFyZ2luLWJvdHRvbTogNDRweDtcbn1cblxuLm15LTEyIHtcbiAgbWFyZ2luLXRvcDogNDhweDtcbiAgbWFyZ2luLWJvdHRvbTogNDhweDtcbn1cblxuLm15LTEzIHtcbiAgbWFyZ2luLXRvcDogNTJweDtcbiAgbWFyZ2luLWJvdHRvbTogNTJweDtcbn1cblxuLm15LTE0IHtcbiAgbWFyZ2luLXRvcDogNTZweDtcbiAgbWFyZ2luLWJvdHRvbTogNTZweDtcbn1cblxuLm15LTE1IHtcbiAgbWFyZ2luLXRvcDogNjBweDtcbiAgbWFyZ2luLWJvdHRvbTogNjBweDtcbn1cblxuLm15LTE2IHtcbiAgbWFyZ2luLXRvcDogNjRweDtcbiAgbWFyZ2luLWJvdHRvbTogNjRweDtcbn1cblxuLyogTWFyZ2luIExlZnQgKi9cbi5tbC0wIHtcbiAgbWFyZ2luLWxlZnQ6IDA7XG59XG5cbi5tbC0xIHtcbiAgbWFyZ2luLWxlZnQ6IDRweDtcbn1cblxuLm1sLTIge1xuICBtYXJnaW4tbGVmdDogOHB4O1xufVxuXG4ubWwtMyB7XG4gIG1hcmdpbi1sZWZ0OiAxMnB4O1xufVxuXG4ubWwtNCB7XG4gIG1hcmdpbi1sZWZ0OiAxNnB4O1xufVxuXG4ubWwtNSB7XG4gIG1hcmdpbi1sZWZ0OiAyMHB4O1xufVxuXG4ubWwtNiB7XG4gIG1hcmdpbi1sZWZ0OiAyNHB4O1xufVxuXG4ubWwtNyB7XG4gIG1hcmdpbi1sZWZ0OiAyOHB4O1xufVxuXG4ubWwtOCB7XG4gIG1hcmdpbi1sZWZ0OiAzMnB4O1xufVxuXG4ubWwtOSB7XG4gIG1hcmdpbi1sZWZ0OiAzNnB4O1xufVxuXG4ubWwtMTAge1xuICBtYXJnaW4tbGVmdDogNDBweDtcbn1cblxuLm1sLTExIHtcbiAgbWFyZ2luLWxlZnQ6IDQ0cHg7XG59XG5cbi5tbC0xMiB7XG4gIG1hcmdpbi1sZWZ0OiA0OHB4O1xufVxuXG4ubWwtMTMge1xuICBtYXJnaW4tbGVmdDogNTJweDtcbn1cblxuLm1sLTE0IHtcbiAgbWFyZ2luLWxlZnQ6IDU2cHg7XG59XG5cbi5tbC0xNSB7XG4gIG1hcmdpbi1sZWZ0OiA2MHB4O1xufVxuXG4ubWwtMTYge1xuICBtYXJnaW4tbGVmdDogNjRweDtcbn1cblxuLyogTWFyZ2luIFJpZ2h0ICovXG4ubXItMCB7XG4gIG1hcmdpbi1yaWdodDogMDtcbn1cblxuLm1yLTEge1xuICBtYXJnaW4tcmlnaHQ6IDRweDtcbn1cblxuLm1yLTIge1xuICBtYXJnaW4tcmlnaHQ6IDhweDtcbn1cblxuLm1yLTMge1xuICBtYXJnaW4tcmlnaHQ6IDEycHg7XG59XG5cbi5tci00IHtcbiAgbWFyZ2luLXJpZ2h0OiAxNnB4O1xufVxuXG4ubXItNSB7XG4gIG1hcmdpbi1yaWdodDogMjBweDtcbn1cblxuLm1yLTYge1xuICBtYXJnaW4tcmlnaHQ6IDI0cHg7XG59XG5cbi5tci03IHtcbiAgbWFyZ2luLXJpZ2h0OiAyOHB4O1xufVxuXG4ubXItOCB7XG4gIG1hcmdpbi1yaWdodDogMzJweDtcbn1cblxuLm1yLTkge1xuICBtYXJnaW4tcmlnaHQ6IDM2cHg7XG59XG5cbi5tci0xMCB7XG4gIG1hcmdpbi1yaWdodDogNDBweDtcbn1cblxuLm1yLTExIHtcbiAgbWFyZ2luLXJpZ2h0OiA0NHB4O1xufVxuXG4ubXItMTIge1xuICBtYXJnaW4tcmlnaHQ6IDQ4cHg7XG59XG5cbi5tci0xMyB7XG4gIG1hcmdpbi1yaWdodDogNTJweDtcbn1cblxuLm1yLTE0IHtcbiAgbWFyZ2luLXJpZ2h0OiA1NnB4O1xufVxuXG4ubXItMTUge1xuICBtYXJnaW4tcmlnaHQ6IDYwcHg7XG59XG5cbi5tci0xNiB7XG4gIG1hcmdpbi1yaWdodDogNjRweDtcbn1cblxuLyogTWFyZ2luIFRvcCAqL1xuLm10LTAge1xuICBtYXJnaW4tdG9wOiAwO1xufVxuXG4ubXQtMSB7XG4gIG1hcmdpbi10b3A6IDRweDtcbn1cblxuLm10LTIge1xuICBtYXJnaW4tdG9wOiA4cHg7XG59XG5cbi5tdC0zIHtcbiAgbWFyZ2luLXRvcDogMTJweDtcbn1cblxuLm10LTQge1xuICBtYXJnaW4tdG9wOiAxNnB4O1xufVxuXG4ubXQtNSB7XG4gIG1hcmdpbi10b3A6IDIwcHg7XG59XG5cbi5tdC02IHtcbiAgbWFyZ2luLXRvcDogMjRweDtcbn1cblxuLm10LTcge1xuICBtYXJnaW4tdG9wOiAyOHB4O1xufVxuXG4ubXQtOCB7XG4gIG1hcmdpbi10b3A6IDMycHg7XG59XG5cbi5tdC05IHtcbiAgbWFyZ2luLXRvcDogMzZweDtcbn1cblxuLm10LTEwIHtcbiAgbWFyZ2luLXRvcDogNDBweDtcbn1cblxuLm10LTExIHtcbiAgbWFyZ2luLXRvcDogNDRweDtcbn1cblxuLm10LTEyIHtcbiAgbWFyZ2luLXRvcDogNDhweDtcbn1cblxuLm10LTEzIHtcbiAgbWFyZ2luLXRvcDogNTJweDtcbn1cblxuLm10LTE0IHtcbiAgbWFyZ2luLXRvcDogNTZweDtcbn1cblxuLm10LTE1IHtcbiAgbWFyZ2luLXRvcDogNjBweDtcbn1cblxuLm10LTE2IHtcbiAgbWFyZ2luLXRvcDogNjRweDtcbn1cblxuLyogTWFyZ2luIEJvdHRvbSAqL1xuLm1iLTAge1xuICBtYXJnaW4tYm90dG9tOiAwO1xufVxuXG4ubWItMSB7XG4gIG1hcmdpbi1ib3R0b206IDRweDtcbn1cblxuLm1iLTIge1xuICBtYXJnaW4tYm90dG9tOiA4cHg7XG59XG5cbi5tYi0zIHtcbiAgbWFyZ2luLWJvdHRvbTogMTJweDtcbn1cblxuLm1iLTQge1xuICBtYXJnaW4tYm90dG9tOiAxNnB4O1xufVxuXG4ubWItNSB7XG4gIG1hcmdpbi1ib3R0b206IDIwcHg7XG59XG5cbi5tYi02IHtcbiAgbWFyZ2luLWJvdHRvbTogMjRweDtcbn1cblxuLm1iLTcge1xuICBtYXJnaW4tYm90dG9tOiAyOHB4O1xufVxuXG4ubWItOCB7XG4gIG1hcmdpbi1ib3R0b206IDMycHg7XG59XG5cbi5tYi05IHtcbiAgbWFyZ2luLWJvdHRvbTogMzZweDtcbn1cblxuLm1iLTEwIHtcbiAgbWFyZ2luLWJvdHRvbTogNDBweDtcbn1cblxuLm1iLTExIHtcbiAgbWFyZ2luLWJvdHRvbTogNDRweDtcbn1cblxuLm1iLTEyIHtcbiAgbWFyZ2luLWJvdHRvbTogNDhweDtcbn1cblxuLm1iLTEzIHtcbiAgbWFyZ2luLWJvdHRvbTogNTJweDtcbn1cblxuLm1iLTE0IHtcbiAgbWFyZ2luLWJvdHRvbTogNTZweDtcbn1cblxuLm1iLTE1IHtcbiAgbWFyZ2luLWJvdHRvbTogNjBweDtcbn1cblxuLm1iLTE2IHtcbiAgbWFyZ2luLWJvdHRvbTogNjRweDtcbn1cblxuLyogQm9yZGVyIFJhZGl1cyBBbGwgQ29ybmVycyAqL1xuLnJvdW5kZWQtMCB7XG4gIGJvcmRlci1yYWRpdXM6IDA7XG59XG5cbi5yb3VuZGVkLXNtIHtcbiAgYm9yZGVyLXJhZGl1czogNHB4O1xufVxuXG4ucm91bmRlZCB7XG4gIGJvcmRlci1yYWRpdXM6IDhweDtcbn1cblxuLnJvdW5kZWQtbWQge1xuICBib3JkZXItcmFkaXVzOiAxMnB4O1xufVxuXG4ucm91bmRlZC1sZyB7XG4gIGJvcmRlci1yYWRpdXM6IDE2cHg7XG59XG5cbi5yb3VuZGVkLXhsIHtcbiAgYm9yZGVyLXJhZGl1czogMjRweDtcbn1cblxuLnJvdW5kZWQtMnhsIHtcbiAgYm9yZGVyLXJhZGl1czogMzJweDtcbn1cblxuLnJvdW5kZWQtM3hsIHtcbiAgYm9yZGVyLXJhZGl1czogNDBweDtcbn1cblxuLnJvdW5kZWQtZnVsbCB7XG4gIGJvcmRlci1yYWRpdXM6IDk5OTlweDtcbn1cblxuLyogVG9wIENvcm5lcnMgKi9cbi5yb3VuZGVkLXQtMCB7XG4gIGJvcmRlci10b3AtbGVmdC1yYWRpdXM6IDA7XG4gIGJvcmRlci10b3AtcmlnaHQtcmFkaXVzOiAwO1xufVxuXG4ucm91bmRlZC10LXNtIHtcbiAgYm9yZGVyLXRvcC1sZWZ0LXJhZGl1czogNHB4O1xuICBib3JkZXItdG9wLXJpZ2h0LXJhZGl1czogNHB4O1xufVxuXG4ucm91bmRlZC10IHtcbiAgYm9yZGVyLXRvcC1sZWZ0LXJhZGl1czogOHB4O1xuICBib3JkZXItdG9wLXJpZ2h0LXJhZGl1czogOHB4O1xufVxuXG4ucm91bmRlZC10LW1kIHtcbiAgYm9yZGVyLXRvcC1sZWZ0LXJhZGl1czogMTJweDtcbiAgYm9yZGVyLXRvcC1yaWdodC1yYWRpdXM6IDEycHg7XG59XG5cbi5yb3VuZGVkLXQtbGcge1xuICBib3JkZXItdG9wLWxlZnQtcmFkaXVzOiAxNnB4O1xuICBib3JkZXItdG9wLXJpZ2h0LXJhZGl1czogMTZweDtcbn1cblxuLnJvdW5kZWQtdC14bCB7XG4gIGJvcmRlci10b3AtbGVmdC1yYWRpdXM6IDI0cHg7XG4gIGJvcmRlci10b3AtcmlnaHQtcmFkaXVzOiAyNHB4O1xufVxuXG4ucm91bmRlZC10LTJ4bCB7XG4gIGJvcmRlci10b3AtbGVmdC1yYWRpdXM6IDMycHg7XG4gIGJvcmRlci10b3AtcmlnaHQtcmFkaXVzOiAzMnB4O1xufVxuXG4ucm91bmRlZC10LTN4bCB7XG4gIGJvcmRlci10b3AtbGVmdC1yYWRpdXM6IDQwcHg7XG4gIGJvcmRlci10b3AtcmlnaHQtcmFkaXVzOiA0MHB4O1xufVxuXG4ucm91bmRlZC10LWZ1bGwge1xuICBib3JkZXItdG9wLWxlZnQtcmFkaXVzOiA5OTk5cHg7XG4gIGJvcmRlci10b3AtcmlnaHQtcmFkaXVzOiA5OTk5cHg7XG59XG5cbi8qIEJvdHRvbSBDb3JuZXJzICovXG4ucm91bmRlZC1iLTAge1xuICBib3JkZXItYm90dG9tLWxlZnQtcmFkaXVzOiAwO1xuICBib3JkZXItYm90dG9tLXJpZ2h0LXJhZGl1czogMDtcbn1cblxuLnJvdW5kZWQtYi1zbSB7XG4gIGJvcmRlci1ib3R0b20tbGVmdC1yYWRpdXM6IDRweDtcbiAgYm9yZGVyLWJvdHRvbS1yaWdodC1yYWRpdXM6IDRweDtcbn1cblxuLnJvdW5kZWQtYiB7XG4gIGJvcmRlci1ib3R0b20tbGVmdC1yYWRpdXM6IDhweDtcbiAgYm9yZGVyLWJvdHRvbS1yaWdodC1yYWRpdXM6IDhweDtcbn1cblxuLnJvdW5kZWQtYi1tZCB7XG4gIGJvcmRlci1ib3R0b20tbGVmdC1yYWRpdXM6IDEycHg7XG4gIGJvcmRlci1ib3R0b20tcmlnaHQtcmFkaXVzOiAxMnB4O1xufVxuXG4ucm91bmRlZC1iLWxnIHtcbiAgYm9yZGVyLWJvdHRvbS1sZWZ0LXJhZGl1czogMTZweDtcbiAgYm9yZGVyLWJvdHRvbS1yaWdodC1yYWRpdXM6IDE2cHg7XG59XG5cbi5yb3VuZGVkLWIteGwge1xuICBib3JkZXItYm90dG9tLWxlZnQtcmFkaXVzOiAyNHB4O1xuICBib3JkZXItYm90dG9tLXJpZ2h0LXJhZGl1czogMjRweDtcbn1cblxuLnJvdW5kZWQtYi0yeGwge1xuICBib3JkZXItYm90dG9tLWxlZnQtcmFkaXVzOiAzMnB4O1xuICBib3JkZXItYm90dG9tLXJpZ2h0LXJhZGl1czogMzJweDtcbn1cblxuLnJvdW5kZWQtYi0zeGwge1xuICBib3JkZXItYm90dG9tLWxlZnQtcmFkaXVzOiA0MHB4O1xuICBib3JkZXItYm90dG9tLXJpZ2h0LXJhZGl1czogNDBweDtcbn1cblxuLnJvdW5kZWQtYi1mdWxsIHtcbiAgYm9yZGVyLWJvdHRvbS1sZWZ0LXJhZGl1czogOTk5OXB4O1xuICBib3JkZXItYm90dG9tLXJpZ2h0LXJhZGl1czogOTk5OXB4O1xufVxuXG4vKiBMZWZ0IENvcm5lcnMgKi9cbi5yb3VuZGVkLWwtMCB7XG4gIGJvcmRlci10b3AtbGVmdC1yYWRpdXM6IDA7XG4gIGJvcmRlci1ib3R0b20tbGVmdC1yYWRpdXM6IDA7XG59XG5cbi5yb3VuZGVkLWwtc20ge1xuICBib3JkZXItdG9wLWxlZnQtcmFkaXVzOiA0cHg7XG4gIGJvcmRlci1ib3R0b20tbGVmdC1yYWRpdXM6IDRweDtcbn1cblxuLnJvdW5kZWQtbCB7XG4gIGJvcmRlci10b3AtbGVmdC1yYWRpdXM6IDhweDtcbiAgYm9yZGVyLWJvdHRvbS1sZWZ0LXJhZGl1czogOHB4O1xufVxuXG4ucm91bmRlZC1sLW1kIHtcbiAgYm9yZGVyLXRvcC1sZWZ0LXJhZGl1czogMTJweDtcbiAgYm9yZGVyLWJvdHRvbS1sZWZ0LXJhZGl1czogMTJweDtcbn1cblxuLnJvdW5kZWQtbC1sZyB7XG4gIGJvcmRlci10b3AtbGVmdC1yYWRpdXM6IDE2cHg7XG4gIGJvcmRlci1ib3R0b20tbGVmdC1yYWRpdXM6IDE2cHg7XG59XG5cbi5yb3VuZGVkLWwteGwge1xuICBib3JkZXItdG9wLWxlZnQtcmFkaXVzOiAyNHB4O1xuICBib3JkZXItYm90dG9tLWxlZnQtcmFkaXVzOiAyNHB4O1xufVxuXG4ucm91bmRlZC1sLTJ4bCB7XG4gIGJvcmRlci10b3AtbGVmdC1yYWRpdXM6IDMycHg7XG4gIGJvcmRlci1ib3R0b20tbGVmdC1yYWRpdXM6IDMycHg7XG59XG5cbi5yb3VuZGVkLWwtM3hsIHtcbiAgYm9yZGVyLXRvcC1sZWZ0LXJhZGl1czogNDBweDtcbiAgYm9yZGVyLWJvdHRvbS1sZWZ0LXJhZGl1czogNDBweDtcbn1cblxuLnJvdW5kZWQtbC1mdWxsIHtcbiAgYm9yZGVyLXRvcC1sZWZ0LXJhZGl1czogOTk5OXB4O1xuICBib3JkZXItYm90dG9tLWxlZnQtcmFkaXVzOiA5OTk5cHg7XG59XG5cbi8qIFJpZ2h0IENvcm5lcnMgKi9cbi5yb3VuZGVkLXItMCB7XG4gIGJvcmRlci10b3AtcmlnaHQtcmFkaXVzOiAwO1xuICBib3JkZXItYm90dG9tLXJpZ2h0LXJhZGl1czogMDtcbn1cblxuLnJvdW5kZWQtci1zbSB7XG4gIGJvcmRlci10b3AtcmlnaHQtcmFkaXVzOiA0cHg7XG4gIGJvcmRlci1ib3R0b20tcmlnaHQtcmFkaXVzOiA0cHg7XG59XG5cbi5yb3VuZGVkLXIge1xuICBib3JkZXItdG9wLXJpZ2h0LXJhZGl1czogOHB4O1xuICBib3JkZXItYm90dG9tLXJpZ2h0LXJhZGl1czogOHB4O1xufVxuXG4ucm91bmRlZC1yLW1kIHtcbiAgYm9yZGVyLXRvcC1yaWdodC1yYWRpdXM6IDEycHg7XG4gIGJvcmRlci1ib3R0b20tcmlnaHQtcmFkaXVzOiAxMnB4O1xufVxuXG4ucm91bmRlZC1yLWxnIHtcbiAgYm9yZGVyLXRvcC1yaWdodC1yYWRpdXM6IDE2cHg7XG4gIGJvcmRlci1ib3R0b20tcmlnaHQtcmFkaXVzOiAxNnB4O1xufVxuXG4ucm91bmRlZC1yLXhsIHtcbiAgYm9yZGVyLXRvcC1yaWdodC1yYWRpdXM6IDI0cHg7XG4gIGJvcmRlci1ib3R0b20tcmlnaHQtcmFkaXVzOiAyNHB4O1xufVxuXG4ucm91bmRlZC1yLTJ4bCB7XG4gIGJvcmRlci10b3AtcmlnaHQtcmFkaXVzOiAzMnB4O1xuICBib3JkZXItYm90dG9tLXJpZ2h0LXJhZGl1czogMzJweDtcbn1cblxuLnJvdW5kZWQtci0zeGwge1xuICBib3JkZXItdG9wLXJpZ2h0LXJhZGl1czogNDBweDtcbiAgYm9yZGVyLWJvdHRvbS1yaWdodC1yYWRpdXM6IDQwcHg7XG59XG5cbi5yb3VuZGVkLXItZnVsbCB7XG4gIGJvcmRlci10b3AtcmlnaHQtcmFkaXVzOiA5OTk5cHg7XG4gIGJvcmRlci1ib3R0b20tcmlnaHQtcmFkaXVzOiA5OTk5cHg7XG59XG5cbi8qIEluZGl2aWR1YWwgQ29ybmVycyAqL1xuLnJvdW5kZWQtdGwtMCB7XG4gIGJvcmRlci10b3AtbGVmdC1yYWRpdXM6IDA7XG59XG5cbi5yb3VuZGVkLXRsLXNtIHtcbiAgYm9yZGVyLXRvcC1sZWZ0LXJhZGl1czogNHB4O1xufVxuXG4ucm91bmRlZC10bCB7XG4gIGJvcmRlci10b3AtbGVmdC1yYWRpdXM6IDhweDtcbn1cblxuLnJvdW5kZWQtdGwtbWQge1xuICBib3JkZXItdG9wLWxlZnQtcmFkaXVzOiAxMnB4O1xufVxuXG4ucm91bmRlZC10bC1sZyB7XG4gIGJvcmRlci10b3AtbGVmdC1yYWRpdXM6IDE2cHg7XG59XG5cbi5yb3VuZGVkLXRsLXhsIHtcbiAgYm9yZGVyLXRvcC1sZWZ0LXJhZGl1czogMjRweDtcbn1cblxuLnJvdW5kZWQtdGwtMnhsIHtcbiAgYm9yZGVyLXRvcC1sZWZ0LXJhZGl1czogMzJweDtcbn1cblxuLnJvdW5kZWQtdGwtM3hsIHtcbiAgYm9yZGVyLXRvcC1sZWZ0LXJhZGl1czogNDBweDtcbn1cblxuLnJvdW5kZWQtdGwtZnVsbCB7XG4gIGJvcmRlci10b3AtbGVmdC1yYWRpdXM6IDk5OTlweDtcbn1cblxuLnJvdW5kZWQtdHItMCB7XG4gIGJvcmRlci10b3AtcmlnaHQtcmFkaXVzOiAwO1xufVxuXG4ucm91bmRlZC10ci1zbSB7XG4gIGJvcmRlci10b3AtcmlnaHQtcmFkaXVzOiA0cHg7XG59XG5cbi5yb3VuZGVkLXRyIHtcbiAgYm9yZGVyLXRvcC1yaWdodC1yYWRpdXM6IDhweDtcbn1cblxuLnJvdW5kZWQtdHItbWQge1xuICBib3JkZXItdG9wLXJpZ2h0LXJhZGl1czogMTJweDtcbn1cblxuLnJvdW5kZWQtdHItbGcge1xuICBib3JkZXItdG9wLXJpZ2h0LXJhZGl1czogMTZweDtcbn1cblxuLnJvdW5kZWQtdHIteGwge1xuICBib3JkZXItdG9wLXJpZ2h0LXJhZGl1czogMjRweDtcbn1cblxuLnJvdW5kZWQtdHItMnhsIHtcbiAgYm9yZGVyLXRvcC1yaWdodC1yYWRpdXM6IDMycHg7XG59XG5cbi5yb3VuZGVkLXRyLTN4bCB7XG4gIGJvcmRlci10b3AtcmlnaHQtcmFkaXVzOiA0MHB4O1xufVxuXG4ucm91bmRlZC10ci1mdWxsIHtcbiAgYm9yZGVyLXRvcC1yaWdodC1yYWRpdXM6IDk5OTlweDtcbn1cblxuLnJvdW5kZWQtYmwtMCB7XG4gIGJvcmRlci1ib3R0b20tbGVmdC1yYWRpdXM6IDA7XG59XG5cbi5yb3VuZGVkLWJsLXNtIHtcbiAgYm9yZGVyLWJvdHRvbS1sZWZ0LXJhZGl1czogNHB4O1xufVxuXG4ucm91bmRlZC1ibCB7XG4gIGJvcmRlci1ib3R0b20tbGVmdC1yYWRpdXM6IDhweDtcbn1cblxuLnJvdW5kZWQtYmwtbWQge1xuICBib3JkZXItYm90dG9tLWxlZnQtcmFkaXVzOiAxMnB4O1xufVxuXG4ucm91bmRlZC1ibC1sZyB7XG4gIGJvcmRlci1ib3R0b20tbGVmdC1yYWRpdXM6IDE2cHg7XG59XG5cbi5yb3VuZGVkLWJsLXhsIHtcbiAgYm9yZGVyLWJvdHRvbS1sZWZ0LXJhZGl1czogMjRweDtcbn1cblxuLnJvdW5kZWQtYmwtMnhsIHtcbiAgYm9yZGVyLWJvdHRvbS1sZWZ0LXJhZGl1czogMzJweDtcbn1cblxuLnJvdW5kZWQtYmwtM3hsIHtcbiAgYm9yZGVyLWJvdHRvbS1sZWZ0LXJhZGl1czogNDBweDtcbn1cblxuLnJvdW5kZWQtYmwtZnVsbCB7XG4gIGJvcmRlci1ib3R0b20tbGVmdC1yYWRpdXM6IDk5OTlweDtcbn1cblxuLnJvdW5kZWQtYnItMCB7XG4gIGJvcmRlci1ib3R0b20tcmlnaHQtcmFkaXVzOiAwO1xufVxuXG4ucm91bmRlZC1ici1zbSB7XG4gIGJvcmRlci1ib3R0b20tcmlnaHQtcmFkaXVzOiA0cHg7XG59XG5cbi5yb3VuZGVkLWJyIHtcbiAgYm9yZGVyLWJvdHRvbS1yaWdodC1yYWRpdXM6IDhweDtcbn1cblxuLnJvdW5kZWQtYnItbWQge1xuICBib3JkZXItYm90dG9tLXJpZ2h0LXJhZGl1czogMTJweDtcbn1cblxuLnJvdW5kZWQtYnItbGcge1xuICBib3JkZXItYm90dG9tLXJpZ2h0LXJhZGl1czogMTZweDtcbn1cblxuLnJvdW5kZWQtYnIteGwge1xuICBib3JkZXItYm90dG9tLXJpZ2h0LXJhZGl1czogMjRweDtcbn1cblxuLnJvdW5kZWQtYnItMnhsIHtcbiAgYm9yZGVyLWJvdHRvbS1yaWdodC1yYWRpdXM6IDMycHg7XG59XG5cbi5yb3VuZGVkLWJyLTN4bCB7XG4gIGJvcmRlci1ib3R0b20tcmlnaHQtcmFkaXVzOiA0MHB4O1xufVxuXG4ucm91bmRlZC1ici1mdWxsIHtcbiAgYm9yZGVyLWJvdHRvbS1yaWdodC1yYWRpdXM6IDk5OTlweDtcbn1cblxuLyogQmFja2dyb3VuZCBDb2xvcnMgKi9cbi5iZy1iZyB7XG4gIGJhY2tncm91bmQtY29sb3I6ICMyODI4Mjg7XG59XG5cbi5iZy1iZy1hbHQge1xuICBiYWNrZ3JvdW5kLWNvbG9yOiAjM2MzODM2O1xufVxuXG4uYmctYmctbWlkIHtcbiAgYmFja2dyb3VuZC1jb2xvcjogIzUwNDk0NTtcbn1cblxuLmJnLWJnLWxpZ2h0IHtcbiAgYmFja2dyb3VuZC1jb2xvcjogIzY2NWM1NDtcbn1cblxuLmJnLXRleHQge1xuICBiYWNrZ3JvdW5kLWNvbG9yOiAjYTg5OTg0O1xufVxuXG4uYmctdGV4dC1saWdodCB7XG4gIGJhY2tncm91bmQtY29sb3I6ICNlYmRiYjI7XG59XG5cbi5iZy10ZXh0LWhpZ2hsaWdodCB7XG4gIGJhY2tncm91bmQtY29sb3I6ICNmYmYxYzc7XG59XG5cbi5iZy1yZWQge1xuICBiYWNrZ3JvdW5kLWNvbG9yOiAjY2MyNDFkO1xufVxuXG4uYmctb3JhbmdlIHtcbiAgYmFja2dyb3VuZC1jb2xvcjogI2Q3OTkyMTtcbn1cblxuLmJnLXllbGxvdyB7XG4gIGJhY2tncm91bmQtY29sb3I6ICNmYWJkMmY7XG59XG5cbi5iZy1ncmVlbiB7XG4gIGJhY2tncm91bmQtY29sb3I6ICNiOGJiMjY7XG59XG5cbi5iZy1hcXVhIHtcbiAgYmFja2dyb3VuZC1jb2xvcjogIzhlYzA3Yztcbn1cblxuLmJnLWJsdWUge1xuICBiYWNrZ3JvdW5kLWNvbG9yOiAjODNhNTk4O1xufVxuXG4uYmctcHVycGxlIHtcbiAgYmFja2dyb3VuZC1jb2xvcjogI2IxNjI4Njtcbn1cblxuLmJnLWJyb3duIHtcbiAgYmFja2dyb3VuZC1jb2xvcjogI2Q2NWQwZTtcbn1cblxuLyogVGV4dCBDb2xvcnMgKi9cbi50ZXh0LWJnIHtcbiAgY29sb3I6ICMyODI4Mjg7XG59XG5cbi50ZXh0LWJnLWFsdCB7XG4gIGNvbG9yOiAjM2MzODM2O1xufVxuXG4udGV4dC1iZy1taWQge1xuICBjb2xvcjogIzUwNDk0NTtcbn1cblxuLnRleHQtYmctbGlnaHQge1xuICBjb2xvcjogIzY2NWM1NDtcbn1cblxuLnRleHQtbXV0ZWQge1xuICBjb2xvcjogIzkyODM3NDtcbn1cblxuLnRleHQtYmFzZSB7XG4gIGNvbG9yOiAjYTg5OTg0O1xufVxuXG4udGV4dC1saWdodCB7XG4gIGNvbG9yOiAjZWJkYmIyO1xufVxuXG4udGV4dC1oaWdobGlnaHQge1xuICBjb2xvcjogI2ZiZjFjNztcbn1cblxuLyogRm9udCBTaXplcyAqL1xuLnRleHQtYm9yZGVyIHtcbiAgZm9udC1zaXplOiAycHg7XG59XG5cbi50ZXh0LXh4cyB7XG4gIGZvbnQtc2l6ZTogNnB4O1xufVxuXG4udGV4dC14cyB7XG4gIGZvbnQtc2l6ZTogMTBweDtcbn1cblxuLnRleHQtc20ge1xuICBmb250LXNpemU6IDEycHg7XG59XG5cbi50ZXh0LWJhc2Uge1xuICBmb250LXNpemU6IDE0cHg7XG59XG5cbi50ZXh0LWxnIHtcbiAgZm9udC1zaXplOiAxNnB4O1xufVxuXG4udGV4dC14bCB7XG4gIGZvbnQtc2l6ZTogMThweDtcbn1cblxuLnRleHQtMnhsIHtcbiAgZm9udC1zaXplOiAyMHB4O1xufVxuXG4udGV4dC0zeGwge1xuICBmb250LXNpemU6IDI0cHg7XG59XG5cbi50ZXh0LTR4bCB7XG4gIGZvbnQtc2l6ZTogMzBweDtcbn1cblxuLnRleHQtNXhsIHtcbiAgZm9udC1zaXplOiAzNnB4O1xufVxuXG4udGV4dC02eGwge1xuICBmb250LXNpemU6IDQ4cHg7XG59XG5cbi8qIEZvbnQgVmFyaWFudHMgKi9cbi5mb250LXRoaW4ge1xuICBmb250LXdlaWdodDogMTAwO1xufVxuXG4uZm9udC1leHRyYWxpZ2h0IHtcbiAgZm9udC13ZWlnaHQ6IDIwMDtcbn1cblxuLmZvbnQtbGlnaHQge1xuICBmb250LXdlaWdodDogMzAwO1xufVxuXG4uZm9udC1ub3JtYWwge1xuICBmb250LXdlaWdodDogNDAwO1xufVxuXG4uZm9udC1tZWRpdW0ge1xuICBmb250LXdlaWdodDogNTAwO1xufVxuXG4uZm9udC1zZW1pYm9sZCB7XG4gIGZvbnQtd2VpZ2h0OiA2MDA7XG59XG5cbi5mb250LWJvbGQge1xuICBmb250LXdlaWdodDogNzAwO1xufVxuXG4uZm9udC1leHRyYWJvbGQge1xuICBmb250LXdlaWdodDogODAwO1xufVxuXG4uZm9udC1ibGFjayB7XG4gIGZvbnQtd2VpZ2h0OiA5MDA7XG59XG5cbi5pdGFsaWMge1xuICBmb250LXN0eWxlOiBpdGFsaWM7XG59XG5cbi5ub3QtaXRhbGljIHtcbiAgZm9udC1zdHlsZTogbm9ybWFsO1xufVxuXG4udW5kZXJsaW5lIHtcbiAgdGV4dC1kZWNvcmF0aW9uOiB1bmRlcmxpbmU7XG59XG5cbi5saW5lLXRocm91Z2gge1xuICB0ZXh0LWRlY29yYXRpb246IGxpbmUtdGhyb3VnaDtcbn1cblxuLm5vLXVuZGVybGluZSB7XG4gIHRleHQtZGVjb3JhdGlvbjogbm9uZTtcbn1cblxuLnRleHQtcmVkIHtcbiAgY29sb3I6ICNjYzI0MWQ7XG59XG5cbi50ZXh0LW9yYW5nZSB7XG4gIGNvbG9yOiAjZDc5OTIxO1xufVxuXG4udGV4dC15ZWxsb3cge1xuICBjb2xvcjogI2ZhYmQyZjtcbn1cblxuLnRleHQtZ3JlZW4ge1xuICBjb2xvcjogI2I4YmIyNjtcbn1cblxuLnRleHQtYXF1YSB7XG4gIGNvbG9yOiAjOGVjMDdjO1xufVxuXG4udGV4dC1ibHVlIHtcbiAgY29sb3I6ICM4M2E1OTg7XG59XG5cbi50ZXh0LXB1cnBsZSB7XG4gIGNvbG9yOiAjYjE2Mjg2O1xufVxuXG4udGV4dC1icm93biB7XG4gIGNvbG9yOiAjZDY1ZDBlO1xufVxuXG4vKiBCb3JkZXIgQ29sb3JzICovXG4uYm9yZGVyLWJnIHtcbiAgYm9yZGVyLWNvbG9yOiAjMjgyODI4O1xufVxuXG4uYm9yZGVyLWJnLWFsdCB7XG4gIGJvcmRlci1jb2xvcjogIzNjMzgzNjtcbn1cblxuLmJvcmRlci1iZy1taWQge1xuICBib3JkZXItY29sb3I6ICM1MDQ5NDU7XG59XG5cbi5ib3JkZXItYmctbGlnaHQge1xuICBib3JkZXItY29sb3I6ICM2NjVjNTQ7XG59XG5cbi5ib3JkZXItdGV4dCB7XG4gIGJvcmRlci1jb2xvcjogI2E4OTk4NDtcbn1cblxuLmJvcmRlci10ZXh0LWxpZ2h0IHtcbiAgYm9yZGVyLWNvbG9yOiAjZWJkYmIyO1xufVxuXG4uYm9yZGVyLXRleHQtaGlnaGxpZ2h0IHtcbiAgYm9yZGVyLWNvbG9yOiAjZmJmMWM3O1xufVxuXG4uYm9yZGVyLXJlZCB7XG4gIGJvcmRlci1jb2xvcjogI2NjMjQxZDtcbn1cblxuLmJvcmRlci1vcmFuZ2Uge1xuICBib3JkZXItY29sb3I6ICNkNzk5MjE7XG59XG5cbi5ib3JkZXIteWVsbG93IHtcbiAgYm9yZGVyLWNvbG9yOiAjZmFiZDJmO1xufVxuXG4uYm9yZGVyLWdyZWVuIHtcbiAgYm9yZGVyLWNvbG9yOiAjYjhiYjI2O1xufVxuXG4uYm9yZGVyLWFxdWEge1xuICBib3JkZXItY29sb3I6ICM4ZWMwN2M7XG59XG5cbi5ib3JkZXItYmx1ZSB7XG4gIGJvcmRlci1jb2xvcjogIzgzYTU5ODtcbn1cblxuLmJvcmRlci1wdXJwbGUge1xuICBib3JkZXItY29sb3I6ICNiMTYyODY7XG59XG5cbi5ib3JkZXItYnJvd24ge1xuICBib3JkZXItY29sb3I6ICNkNjVkMGU7XG59XG5cbi8qIEhvdmVyIFN0YXRlcyAqL1xuLmhvdmVyXFw6YmctcmVkOmhvdmVyIHtcbiAgYmFja2dyb3VuZC1jb2xvcjogI2NjMjQxZDtcbn1cblxuLmhvdmVyXFw6Ymctb3JhbmdlOmhvdmVyIHtcbiAgYmFja2dyb3VuZC1jb2xvcjogI2Q3OTkyMTtcbn1cblxuLmhvdmVyXFw6YmcteWVsbG93OmhvdmVyIHtcbiAgYmFja2dyb3VuZC1jb2xvcjogI2ZhYmQyZjtcbn1cblxuLmhvdmVyXFw6YmctZ3JlZW46aG92ZXIge1xuICBiYWNrZ3JvdW5kLWNvbG9yOiAjYjhiYjI2O1xufVxuXG4uaG92ZXJcXDpiZy1hcXVhOmhvdmVyIHtcbiAgYmFja2dyb3VuZC1jb2xvcjogIzhlYzA3Yztcbn1cblxuLmhvdmVyXFw6YmctYmx1ZTpob3ZlciB7XG4gIGJhY2tncm91bmQtY29sb3I6ICM4M2E1OTg7XG59XG5cbi5ob3ZlclxcOmJnLXB1cnBsZTpob3ZlciB7XG4gIGJhY2tncm91bmQtY29sb3I6ICNiMTYyODY7XG59XG5cbi5ob3ZlclxcOmJnLWJyb3duOmhvdmVyIHtcbiAgYmFja2dyb3VuZC1jb2xvcjogI2Q2NWQwZTtcbn1cblxuLyogTWluLUhlaWdodCBDbGFzc2VzICovXG4ubWluLWgtMCB7XG4gIG1pbi1oZWlnaHQ6IDA7XG59XG5cbi5taW4taC1weCB7XG4gIG1pbi1oZWlnaHQ6IDFweDtcbn1cblxuLm1pbi1oLTEge1xuICBtaW4taGVpZ2h0OiA0cHg7XG59XG5cbi5taW4taC0yIHtcbiAgbWluLWhlaWdodDogOHB4O1xufVxuXG4ubWluLWgtMyB7XG4gIG1pbi1oZWlnaHQ6IDEycHg7XG59XG5cbi5taW4taC00IHtcbiAgbWluLWhlaWdodDogMTZweDtcbn1cblxuLm1pbi1oLTUge1xuICBtaW4taGVpZ2h0OiAyMHB4O1xufVxuXG4ubWluLWgtNiB7XG4gIG1pbi1oZWlnaHQ6IDI0cHg7XG59XG5cbi5taW4taC04IHtcbiAgbWluLWhlaWdodDogMzJweDtcbn1cblxuLm1pbi1oLTEwIHtcbiAgbWluLWhlaWdodDogNDBweDtcbn1cblxuLm1pbi1oLTEyIHtcbiAgbWluLWhlaWdodDogNDhweDtcbn1cblxuLm1pbi1oLTE2IHtcbiAgbWluLWhlaWdodDogNjRweDtcbn1cblxuLm1pbi1oLTIwIHtcbiAgbWluLWhlaWdodDogODBweDtcbn1cblxuLm1pbi1oLTI0IHtcbiAgbWluLWhlaWdodDogOTZweDtcbn1cblxuLm1pbi1oLTMyIHtcbiAgbWluLWhlaWdodDogMTI4cHg7XG59XG5cbi5taW4taC00MCB7XG4gIG1pbi1oZWlnaHQ6IDE2MHB4O1xufVxuXG4ubWluLWgtNDgge1xuICBtaW4taGVpZ2h0OiAxOTJweDtcbn1cblxuLm1pbi1oLTY0IHtcbiAgbWluLWhlaWdodDogMjU2cHg7XG59XG5cbi8qIE1pbi1XaWR0aCBDbGFzc2VzICovXG4ubWluLXctMCB7XG4gIG1pbi13aWR0aDogMDtcbn1cblxuLm1pbi13LXB4IHtcbiAgbWluLXdpZHRoOiAxcHg7XG59XG5cbi5taW4tdy0xIHtcbiAgbWluLXdpZHRoOiA0cHg7XG59XG5cbi5taW4tdy0yIHtcbiAgbWluLXdpZHRoOiA4cHg7XG59XG5cbi5taW4tdy0zIHtcbiAgbWluLXdpZHRoOiAxMnB4O1xufVxuXG4ubWluLXctNCB7XG4gIG1pbi13aWR0aDogMTZweDtcbn1cblxuLm1pbi13LTUge1xuICBtaW4td2lkdGg6IDIwcHg7XG59XG5cbi5taW4tdy02IHtcbiAgbWluLXdpZHRoOiAyNHB4O1xufVxuXG4ubWluLXctOCB7XG4gIG1pbi13aWR0aDogMzJweDtcbn1cblxuLm1pbi13LTEwIHtcbiAgbWluLXdpZHRoOiA0MHB4O1xufVxuXG4ubWluLXctMTIge1xuICBtaW4td2lkdGg6IDQ4cHg7XG59XG5cbi5taW4tdy0xNiB7XG4gIG1pbi13aWR0aDogNjRweDtcbn1cblxuLm1pbi13LTIwIHtcbiAgbWluLXdpZHRoOiA4MHB4O1xufVxuXG4ubWluLXctMjQge1xuICBtaW4td2lkdGg6IDk2cHg7XG59XG5cbi5taW4tdy0zMiB7XG4gIG1pbi13aWR0aDogMTI4cHg7XG59XG5cbi5taW4tdy00MCB7XG4gIG1pbi13aWR0aDogMTYwcHg7XG59XG5cbi5taW4tdy00OCB7XG4gIG1pbi13aWR0aDogMTkycHg7XG59XG5cbi5taW4tdy02NCB7XG4gIG1pbi13aWR0aDogMjU2cHg7XG59IiwgImltcG9ydCBcIi4vb3ZlcnJpZGVzLmpzXCJcbmV4cG9ydCB7IGRlZmF1bHQgYXMgQXN0YWxJTyB9IGZyb20gXCJnaTovL0FzdGFsSU8/dmVyc2lvbj0wLjFcIlxuZXhwb3J0ICogZnJvbSBcIi4vcHJvY2Vzcy5qc1wiXG5leHBvcnQgKiBmcm9tIFwiLi90aW1lLmpzXCJcbmV4cG9ydCAqIGZyb20gXCIuL2ZpbGUuanNcIlxuZXhwb3J0ICogZnJvbSBcIi4vZ29iamVjdC5qc1wiXG5leHBvcnQgeyBCaW5kaW5nLCBiaW5kIH0gZnJvbSBcIi4vYmluZGluZy5qc1wiXG5leHBvcnQgeyBWYXJpYWJsZSwgZGVyaXZlIH0gZnJvbSBcIi4vdmFyaWFibGUuanNcIlxuIiwgImltcG9ydCBBc3RhbCBmcm9tIFwiZ2k6Ly9Bc3RhbElPXCJcbmltcG9ydCBHaW8gZnJvbSBcImdpOi8vR2lvP3ZlcnNpb249Mi4wXCJcblxuZXhwb3J0IHsgR2lvIH1cblxuZXhwb3J0IGZ1bmN0aW9uIHJlYWRGaWxlKHBhdGg6IHN0cmluZyk6IHN0cmluZyB7XG4gICAgcmV0dXJuIEFzdGFsLnJlYWRfZmlsZShwYXRoKSB8fCBcIlwiXG59XG5cbmV4cG9ydCBmdW5jdGlvbiByZWFkRmlsZUFzeW5jKHBhdGg6IHN0cmluZyk6IFByb21pc2U8c3RyaW5nPiB7XG4gICAgcmV0dXJuIG5ldyBQcm9taXNlKChyZXNvbHZlLCByZWplY3QpID0+IHtcbiAgICAgICAgQXN0YWwucmVhZF9maWxlX2FzeW5jKHBhdGgsIChfLCByZXMpID0+IHtcbiAgICAgICAgICAgIHRyeSB7XG4gICAgICAgICAgICAgICAgcmVzb2x2ZShBc3RhbC5yZWFkX2ZpbGVfZmluaXNoKHJlcykgfHwgXCJcIilcbiAgICAgICAgICAgIH0gY2F0Y2ggKGVycm9yKSB7XG4gICAgICAgICAgICAgICAgcmVqZWN0KGVycm9yKVxuICAgICAgICAgICAgfVxuICAgICAgICB9KVxuICAgIH0pXG59XG5cbmV4cG9ydCBmdW5jdGlvbiB3cml0ZUZpbGUocGF0aDogc3RyaW5nLCBjb250ZW50OiBzdHJpbmcpOiB2b2lkIHtcbiAgICBBc3RhbC53cml0ZV9maWxlKHBhdGgsIGNvbnRlbnQpXG59XG5cbmV4cG9ydCBmdW5jdGlvbiB3cml0ZUZpbGVBc3luYyhwYXRoOiBzdHJpbmcsIGNvbnRlbnQ6IHN0cmluZyk6IFByb21pc2U8dm9pZD4ge1xuICAgIHJldHVybiBuZXcgUHJvbWlzZSgocmVzb2x2ZSwgcmVqZWN0KSA9PiB7XG4gICAgICAgIEFzdGFsLndyaXRlX2ZpbGVfYXN5bmMocGF0aCwgY29udGVudCwgKF8sIHJlcykgPT4ge1xuICAgICAgICAgICAgdHJ5IHtcbiAgICAgICAgICAgICAgICByZXNvbHZlKEFzdGFsLndyaXRlX2ZpbGVfZmluaXNoKHJlcykpXG4gICAgICAgICAgICB9IGNhdGNoIChlcnJvcikge1xuICAgICAgICAgICAgICAgIHJlamVjdChlcnJvcilcbiAgICAgICAgICAgIH1cbiAgICAgICAgfSlcbiAgICB9KVxufVxuXG5leHBvcnQgZnVuY3Rpb24gbW9uaXRvckZpbGUoXG4gICAgcGF0aDogc3RyaW5nLFxuICAgIGNhbGxiYWNrOiAoZmlsZTogc3RyaW5nLCBldmVudDogR2lvLkZpbGVNb25pdG9yRXZlbnQpID0+IHZvaWQsXG4pOiBHaW8uRmlsZU1vbml0b3Ige1xuICAgIHJldHVybiBBc3RhbC5tb25pdG9yX2ZpbGUocGF0aCwgKGZpbGU6IHN0cmluZywgZXZlbnQ6IEdpby5GaWxlTW9uaXRvckV2ZW50KSA9PiB7XG4gICAgICAgIGNhbGxiYWNrKGZpbGUsIGV2ZW50KVxuICAgIH0pIVxufVxuIiwgImltcG9ydCBHT2JqZWN0IGZyb20gXCJnaTovL0dPYmplY3RcIlxuXG5leHBvcnQgeyBkZWZhdWx0IGFzIEdMaWIgfSBmcm9tIFwiZ2k6Ly9HTGliP3ZlcnNpb249Mi4wXCJcbmV4cG9ydCB7IEdPYmplY3QsIEdPYmplY3QgYXMgZGVmYXVsdCB9XG5cbmNvbnN0IG1ldGEgPSBTeW1ib2woXCJtZXRhXCIpXG5jb25zdCBwcml2ID0gU3ltYm9sKFwicHJpdlwiKVxuXG5jb25zdCB7IFBhcmFtU3BlYywgUGFyYW1GbGFncyB9ID0gR09iamVjdFxuXG5jb25zdCBrZWJhYmlmeSA9IChzdHI6IHN0cmluZykgPT4gc3RyXG4gICAgLnJlcGxhY2UoLyhbYS16XSkoW0EtWl0pL2csIFwiJDEtJDJcIilcbiAgICAucmVwbGFjZUFsbChcIl9cIiwgXCItXCIpXG4gICAgLnRvTG93ZXJDYXNlKClcblxudHlwZSBTaWduYWxEZWNsYXJhdGlvbiA9IHtcbiAgICBmbGFncz86IEdPYmplY3QuU2lnbmFsRmxhZ3NcbiAgICBhY2N1bXVsYXRvcj86IEdPYmplY3QuQWNjdW11bGF0b3JUeXBlXG4gICAgcmV0dXJuX3R5cGU/OiBHT2JqZWN0LkdUeXBlXG4gICAgcGFyYW1fdHlwZXM/OiBBcnJheTxHT2JqZWN0LkdUeXBlPlxufVxuXG50eXBlIFByb3BlcnR5RGVjbGFyYXRpb24gPVxuICAgIHwgSW5zdGFuY2VUeXBlPHR5cGVvZiBHT2JqZWN0LlBhcmFtU3BlYz5cbiAgICB8IHsgJGd0eXBlOiBHT2JqZWN0LkdUeXBlIH1cbiAgICB8IHR5cGVvZiBTdHJpbmdcbiAgICB8IHR5cGVvZiBOdW1iZXJcbiAgICB8IHR5cGVvZiBCb29sZWFuXG4gICAgfCB0eXBlb2YgT2JqZWN0XG5cbnR5cGUgR09iamVjdENvbnN0cnVjdG9yID0ge1xuICAgIFttZXRhXT86IHtcbiAgICAgICAgUHJvcGVydGllcz86IHsgW2tleTogc3RyaW5nXTogR09iamVjdC5QYXJhbVNwZWMgfVxuICAgICAgICBTaWduYWxzPzogeyBba2V5OiBzdHJpbmddOiBHT2JqZWN0LlNpZ25hbERlZmluaXRpb24gfVxuICAgIH1cbiAgICBuZXcoLi4uYXJnczogYW55W10pOiBhbnlcbn1cblxudHlwZSBNZXRhSW5mbyA9IEdPYmplY3QuTWV0YUluZm88bmV2ZXIsIEFycmF5PHsgJGd0eXBlOiBHT2JqZWN0LkdUeXBlIH0+LCBuZXZlcj5cblxuZXhwb3J0IGZ1bmN0aW9uIHJlZ2lzdGVyKG9wdGlvbnM6IE1ldGFJbmZvID0ge30pIHtcbiAgICByZXR1cm4gZnVuY3Rpb24gKGNsczogR09iamVjdENvbnN0cnVjdG9yKSB7XG4gICAgICAgIGNvbnN0IHQgPSBvcHRpb25zLlRlbXBsYXRlXG4gICAgICAgIGlmICh0eXBlb2YgdCA9PT0gXCJzdHJpbmdcIiAmJiAhdC5zdGFydHNXaXRoKFwicmVzb3VyY2U6Ly9cIikgJiYgIXQuc3RhcnRzV2l0aChcImZpbGU6Ly9cIikpIHtcbiAgICAgICAgICAgIC8vIGFzc3VtZSB4bWwgdGVtcGxhdGVcbiAgICAgICAgICAgIG9wdGlvbnMuVGVtcGxhdGUgPSBuZXcgVGV4dEVuY29kZXIoKS5lbmNvZGUodClcbiAgICAgICAgfVxuXG4gICAgICAgIEdPYmplY3QucmVnaXN0ZXJDbGFzcyh7XG4gICAgICAgICAgICBTaWduYWxzOiB7IC4uLmNsc1ttZXRhXT8uU2lnbmFscyB9LFxuICAgICAgICAgICAgUHJvcGVydGllczogeyAuLi5jbHNbbWV0YV0/LlByb3BlcnRpZXMgfSxcbiAgICAgICAgICAgIC4uLm9wdGlvbnMsXG4gICAgICAgIH0sIGNscylcblxuICAgICAgICBkZWxldGUgY2xzW21ldGFdXG4gICAgfVxufVxuXG5leHBvcnQgZnVuY3Rpb24gcHJvcGVydHkoZGVjbGFyYXRpb246IFByb3BlcnR5RGVjbGFyYXRpb24gPSBPYmplY3QpIHtcbiAgICByZXR1cm4gZnVuY3Rpb24gKHRhcmdldDogYW55LCBwcm9wOiBhbnksIGRlc2M/OiBQcm9wZXJ0eURlc2NyaXB0b3IpIHtcbiAgICAgICAgdGFyZ2V0LmNvbnN0cnVjdG9yW21ldGFdID8/PSB7fVxuICAgICAgICB0YXJnZXQuY29uc3RydWN0b3JbbWV0YV0uUHJvcGVydGllcyA/Pz0ge31cblxuICAgICAgICBjb25zdCBuYW1lID0ga2ViYWJpZnkocHJvcClcblxuICAgICAgICBpZiAoIWRlc2MpIHtcbiAgICAgICAgICAgIE9iamVjdC5kZWZpbmVQcm9wZXJ0eSh0YXJnZXQsIHByb3AsIHtcbiAgICAgICAgICAgICAgICBnZXQoKSB7XG4gICAgICAgICAgICAgICAgICAgIHJldHVybiB0aGlzW3ByaXZdPy5bcHJvcF0gPz8gZGVmYXVsdFZhbHVlKGRlY2xhcmF0aW9uKVxuICAgICAgICAgICAgICAgIH0sXG4gICAgICAgICAgICAgICAgc2V0KHY6IGFueSkge1xuICAgICAgICAgICAgICAgICAgICBpZiAodiAhPT0gdGhpc1twcm9wXSkge1xuICAgICAgICAgICAgICAgICAgICAgICAgdGhpc1twcml2XSA/Pz0ge31cbiAgICAgICAgICAgICAgICAgICAgICAgIHRoaXNbcHJpdl1bcHJvcF0gPSB2XG4gICAgICAgICAgICAgICAgICAgICAgICB0aGlzLm5vdGlmeShuYW1lKVxuICAgICAgICAgICAgICAgICAgICB9XG4gICAgICAgICAgICAgICAgfSxcbiAgICAgICAgICAgIH0pXG5cbiAgICAgICAgICAgIE9iamVjdC5kZWZpbmVQcm9wZXJ0eSh0YXJnZXQsIGBzZXRfJHtuYW1lLnJlcGxhY2UoXCItXCIsIFwiX1wiKX1gLCB7XG4gICAgICAgICAgICAgICAgdmFsdWUodjogYW55KSB7XG4gICAgICAgICAgICAgICAgICAgIHRoaXNbcHJvcF0gPSB2XG4gICAgICAgICAgICAgICAgfSxcbiAgICAgICAgICAgIH0pXG5cbiAgICAgICAgICAgIE9iamVjdC5kZWZpbmVQcm9wZXJ0eSh0YXJnZXQsIGBnZXRfJHtuYW1lLnJlcGxhY2UoXCItXCIsIFwiX1wiKX1gLCB7XG4gICAgICAgICAgICAgICAgdmFsdWUoKSB7XG4gICAgICAgICAgICAgICAgICAgIHJldHVybiB0aGlzW3Byb3BdXG4gICAgICAgICAgICAgICAgfSxcbiAgICAgICAgICAgIH0pXG5cbiAgICAgICAgICAgIHRhcmdldC5jb25zdHJ1Y3RvclttZXRhXS5Qcm9wZXJ0aWVzW2tlYmFiaWZ5KHByb3ApXSA9IHBzcGVjKG5hbWUsIFBhcmFtRmxhZ3MuUkVBRFdSSVRFLCBkZWNsYXJhdGlvbilcbiAgICAgICAgfSBlbHNlIHtcbiAgICAgICAgICAgIGxldCBmbGFncyA9IDBcbiAgICAgICAgICAgIGlmIChkZXNjLmdldCkgZmxhZ3MgfD0gUGFyYW1GbGFncy5SRUFEQUJMRVxuICAgICAgICAgICAgaWYgKGRlc2Muc2V0KSBmbGFncyB8PSBQYXJhbUZsYWdzLldSSVRBQkxFXG5cbiAgICAgICAgICAgIHRhcmdldC5jb25zdHJ1Y3RvclttZXRhXS5Qcm9wZXJ0aWVzW2tlYmFiaWZ5KHByb3ApXSA9IHBzcGVjKG5hbWUsIGZsYWdzLCBkZWNsYXJhdGlvbilcbiAgICAgICAgfVxuICAgIH1cbn1cblxuZXhwb3J0IGZ1bmN0aW9uIHNpZ25hbCguLi5wYXJhbXM6IEFycmF5PHsgJGd0eXBlOiBHT2JqZWN0LkdUeXBlIH0gfCB0eXBlb2YgT2JqZWN0Pik6XG4odGFyZ2V0OiBhbnksIHNpZ25hbDogYW55LCBkZXNjPzogUHJvcGVydHlEZXNjcmlwdG9yKSA9PiB2b2lkXG5cbmV4cG9ydCBmdW5jdGlvbiBzaWduYWwoZGVjbGFyYXRpb24/OiBTaWduYWxEZWNsYXJhdGlvbik6XG4odGFyZ2V0OiBhbnksIHNpZ25hbDogYW55LCBkZXNjPzogUHJvcGVydHlEZXNjcmlwdG9yKSA9PiB2b2lkXG5cbmV4cG9ydCBmdW5jdGlvbiBzaWduYWwoXG4gICAgZGVjbGFyYXRpb24/OiBTaWduYWxEZWNsYXJhdGlvbiB8IHsgJGd0eXBlOiBHT2JqZWN0LkdUeXBlIH0gfCB0eXBlb2YgT2JqZWN0LFxuICAgIC4uLnBhcmFtczogQXJyYXk8eyAkZ3R5cGU6IEdPYmplY3QuR1R5cGUgfSB8IHR5cGVvZiBPYmplY3Q+XG4pIHtcbiAgICByZXR1cm4gZnVuY3Rpb24gKHRhcmdldDogYW55LCBzaWduYWw6IGFueSwgZGVzYz86IFByb3BlcnR5RGVzY3JpcHRvcikge1xuICAgICAgICB0YXJnZXQuY29uc3RydWN0b3JbbWV0YV0gPz89IHt9XG4gICAgICAgIHRhcmdldC5jb25zdHJ1Y3RvclttZXRhXS5TaWduYWxzID8/PSB7fVxuXG4gICAgICAgIGNvbnN0IG5hbWUgPSBrZWJhYmlmeShzaWduYWwpXG5cbiAgICAgICAgaWYgKGRlY2xhcmF0aW9uIHx8IHBhcmFtcy5sZW5ndGggPiAwKSB7XG4gICAgICAgICAgICAvLyBAdHMtZXhwZWN0LWVycm9yIFRPRE86IHR5cGUgYXNzZXJ0XG4gICAgICAgICAgICBjb25zdCBhcnIgPSBbZGVjbGFyYXRpb24sIC4uLnBhcmFtc10ubWFwKHYgPT4gdi4kZ3R5cGUpXG4gICAgICAgICAgICB0YXJnZXQuY29uc3RydWN0b3JbbWV0YV0uU2lnbmFsc1tuYW1lXSA9IHtcbiAgICAgICAgICAgICAgICBwYXJhbV90eXBlczogYXJyLFxuICAgICAgICAgICAgfVxuICAgICAgICB9IGVsc2Uge1xuICAgICAgICAgICAgdGFyZ2V0LmNvbnN0cnVjdG9yW21ldGFdLlNpZ25hbHNbbmFtZV0gPSBkZWNsYXJhdGlvbiB8fCB7XG4gICAgICAgICAgICAgICAgcGFyYW1fdHlwZXM6IFtdLFxuICAgICAgICAgICAgfVxuICAgICAgICB9XG5cbiAgICAgICAgaWYgKCFkZXNjKSB7XG4gICAgICAgICAgICBPYmplY3QuZGVmaW5lUHJvcGVydHkodGFyZ2V0LCBzaWduYWwsIHtcbiAgICAgICAgICAgICAgICB2YWx1ZTogZnVuY3Rpb24gKC4uLmFyZ3M6IGFueVtdKSB7XG4gICAgICAgICAgICAgICAgICAgIHRoaXMuZW1pdChuYW1lLCAuLi5hcmdzKVxuICAgICAgICAgICAgICAgIH0sXG4gICAgICAgICAgICB9KVxuICAgICAgICB9IGVsc2Uge1xuICAgICAgICAgICAgY29uc3Qgb2c6ICgoLi4uYXJnczogYW55W10pID0+IHZvaWQpID0gZGVzYy52YWx1ZVxuICAgICAgICAgICAgZGVzYy52YWx1ZSA9IGZ1bmN0aW9uICguLi5hcmdzOiBhbnlbXSkge1xuICAgICAgICAgICAgICAgIC8vIEB0cy1leHBlY3QtZXJyb3Igbm90IHR5cGVkXG4gICAgICAgICAgICAgICAgdGhpcy5lbWl0KG5hbWUsIC4uLmFyZ3MpXG4gICAgICAgICAgICB9XG4gICAgICAgICAgICBPYmplY3QuZGVmaW5lUHJvcGVydHkodGFyZ2V0LCBgb25fJHtuYW1lLnJlcGxhY2UoXCItXCIsIFwiX1wiKX1gLCB7XG4gICAgICAgICAgICAgICAgdmFsdWU6IGZ1bmN0aW9uICguLi5hcmdzOiBhbnlbXSkge1xuICAgICAgICAgICAgICAgICAgICByZXR1cm4gb2coLi4uYXJncylcbiAgICAgICAgICAgICAgICB9LFxuICAgICAgICAgICAgfSlcbiAgICAgICAgfVxuICAgIH1cbn1cblxuZnVuY3Rpb24gcHNwZWMobmFtZTogc3RyaW5nLCBmbGFnczogbnVtYmVyLCBkZWNsYXJhdGlvbjogUHJvcGVydHlEZWNsYXJhdGlvbikge1xuICAgIGlmIChkZWNsYXJhdGlvbiBpbnN0YW5jZW9mIFBhcmFtU3BlYylcbiAgICAgICAgcmV0dXJuIGRlY2xhcmF0aW9uXG5cbiAgICBzd2l0Y2ggKGRlY2xhcmF0aW9uKSB7XG4gICAgICAgIGNhc2UgU3RyaW5nOlxuICAgICAgICAgICAgcmV0dXJuIFBhcmFtU3BlYy5zdHJpbmcobmFtZSwgXCJcIiwgXCJcIiwgZmxhZ3MsIFwiXCIpXG4gICAgICAgIGNhc2UgTnVtYmVyOlxuICAgICAgICAgICAgcmV0dXJuIFBhcmFtU3BlYy5kb3VibGUobmFtZSwgXCJcIiwgXCJcIiwgZmxhZ3MsIC1OdW1iZXIuTUFYX1ZBTFVFLCBOdW1iZXIuTUFYX1ZBTFVFLCAwKVxuICAgICAgICBjYXNlIEJvb2xlYW46XG4gICAgICAgICAgICByZXR1cm4gUGFyYW1TcGVjLmJvb2xlYW4obmFtZSwgXCJcIiwgXCJcIiwgZmxhZ3MsIGZhbHNlKVxuICAgICAgICBjYXNlIE9iamVjdDpcbiAgICAgICAgICAgIHJldHVybiBQYXJhbVNwZWMuanNvYmplY3QobmFtZSwgXCJcIiwgXCJcIiwgZmxhZ3MpXG4gICAgICAgIGRlZmF1bHQ6XG4gICAgICAgICAgICAvLyBAdHMtZXhwZWN0LWVycm9yIG1pc3N0eXBlZFxuICAgICAgICAgICAgcmV0dXJuIFBhcmFtU3BlYy5vYmplY3QobmFtZSwgXCJcIiwgXCJcIiwgZmxhZ3MsIGRlY2xhcmF0aW9uLiRndHlwZSlcbiAgICB9XG59XG5cbmZ1bmN0aW9uIGRlZmF1bHRWYWx1ZShkZWNsYXJhdGlvbjogUHJvcGVydHlEZWNsYXJhdGlvbikge1xuICAgIGlmIChkZWNsYXJhdGlvbiBpbnN0YW5jZW9mIFBhcmFtU3BlYylcbiAgICAgICAgcmV0dXJuIGRlY2xhcmF0aW9uLmdldF9kZWZhdWx0X3ZhbHVlKClcblxuICAgIHN3aXRjaCAoZGVjbGFyYXRpb24pIHtcbiAgICAgICAgY2FzZSBTdHJpbmc6XG4gICAgICAgICAgICByZXR1cm4gXCJcIlxuICAgICAgICBjYXNlIE51bWJlcjpcbiAgICAgICAgICAgIHJldHVybiAwXG4gICAgICAgIGNhc2UgQm9vbGVhbjpcbiAgICAgICAgICAgIHJldHVybiBmYWxzZVxuICAgICAgICBjYXNlIE9iamVjdDpcbiAgICAgICAgZGVmYXVsdDpcbiAgICAgICAgICAgIHJldHVybiBudWxsXG4gICAgfVxufVxuIiwgImltcG9ydCBHdGsgZnJvbSBcImdpOi8vR3RrP3ZlcnNpb249My4wXCJcbmltcG9ydCB7IHR5cGUgQmluZGFibGVDaGlsZCB9IGZyb20gXCIuL2FzdGFsaWZ5LmpzXCJcbmltcG9ydCB7IG1lcmdlQmluZGluZ3MsIGpzeCBhcyBfanN4IH0gZnJvbSBcIi4uL19hc3RhbC5qc1wiXG5pbXBvcnQgKiBhcyBXaWRnZXQgZnJvbSBcIi4vd2lkZ2V0LmpzXCJcblxuZXhwb3J0IGZ1bmN0aW9uIEZyYWdtZW50KHsgY2hpbGRyZW4gPSBbXSwgY2hpbGQgfToge1xuICAgIGNoaWxkPzogQmluZGFibGVDaGlsZFxuICAgIGNoaWxkcmVuPzogQXJyYXk8QmluZGFibGVDaGlsZD5cbn0pIHtcbiAgICBpZiAoY2hpbGQpIGNoaWxkcmVuLnB1c2goY2hpbGQpXG4gICAgcmV0dXJuIG1lcmdlQmluZGluZ3MoY2hpbGRyZW4pXG59XG5cbmV4cG9ydCBmdW5jdGlvbiBqc3goXG4gICAgY3Rvcjoga2V5b2YgdHlwZW9mIGN0b3JzIHwgdHlwZW9mIEd0ay5XaWRnZXQsXG4gICAgcHJvcHM6IGFueSxcbikge1xuICAgIHJldHVybiBfanN4KGN0b3JzLCBjdG9yIGFzIGFueSwgcHJvcHMpXG59XG5cbmNvbnN0IGN0b3JzID0ge1xuICAgIGJveDogV2lkZ2V0LkJveCxcbiAgICBidXR0b246IFdpZGdldC5CdXR0b24sXG4gICAgY2VudGVyYm94OiBXaWRnZXQuQ2VudGVyQm94LFxuICAgIGNpcmN1bGFycHJvZ3Jlc3M6IFdpZGdldC5DaXJjdWxhclByb2dyZXNzLFxuICAgIGRyYXdpbmdhcmVhOiBXaWRnZXQuRHJhd2luZ0FyZWEsXG4gICAgZW50cnk6IFdpZGdldC5FbnRyeSxcbiAgICBldmVudGJveDogV2lkZ2V0LkV2ZW50Qm94LFxuICAgIC8vIFRPRE86IGZpeGVkXG4gICAgLy8gVE9ETzogZmxvd2JveFxuICAgIGljb246IFdpZGdldC5JY29uLFxuICAgIGxhYmVsOiBXaWRnZXQuTGFiZWwsXG4gICAgbGV2ZWxiYXI6IFdpZGdldC5MZXZlbEJhcixcbiAgICAvLyBUT0RPOiBsaXN0Ym94XG4gICAgbWVudWJ1dHRvbjogV2lkZ2V0Lk1lbnVCdXR0b24sXG4gICAgb3ZlcmxheTogV2lkZ2V0Lk92ZXJsYXksXG4gICAgcmV2ZWFsZXI6IFdpZGdldC5SZXZlYWxlcixcbiAgICBzY3JvbGxhYmxlOiBXaWRnZXQuU2Nyb2xsYWJsZSxcbiAgICBzbGlkZXI6IFdpZGdldC5TbGlkZXIsXG4gICAgc3RhY2s6IFdpZGdldC5TdGFjayxcbiAgICBzd2l0Y2g6IFdpZGdldC5Td2l0Y2gsXG4gICAgd2luZG93OiBXaWRnZXQuV2luZG93LFxufVxuXG5kZWNsYXJlIGdsb2JhbCB7XG4gICAgLy8gZXNsaW50LWRpc2FibGUtbmV4dC1saW5lIEB0eXBlc2NyaXB0LWVzbGludC9uby1uYW1lc3BhY2VcbiAgICBuYW1lc3BhY2UgSlNYIHtcbiAgICAgICAgdHlwZSBFbGVtZW50ID0gR3RrLldpZGdldFxuICAgICAgICB0eXBlIEVsZW1lbnRDbGFzcyA9IEd0ay5XaWRnZXRcbiAgICAgICAgaW50ZXJmYWNlIEludHJpbnNpY0VsZW1lbnRzIHtcbiAgICAgICAgICAgIGJveDogV2lkZ2V0LkJveFByb3BzXG4gICAgICAgICAgICBidXR0b246IFdpZGdldC5CdXR0b25Qcm9wc1xuICAgICAgICAgICAgY2VudGVyYm94OiBXaWRnZXQuQ2VudGVyQm94UHJvcHNcbiAgICAgICAgICAgIGNpcmN1bGFycHJvZ3Jlc3M6IFdpZGdldC5DaXJjdWxhclByb2dyZXNzUHJvcHNcbiAgICAgICAgICAgIGRyYXdpbmdhcmVhOiBXaWRnZXQuRHJhd2luZ0FyZWFQcm9wc1xuICAgICAgICAgICAgZW50cnk6IFdpZGdldC5FbnRyeVByb3BzXG4gICAgICAgICAgICBldmVudGJveDogV2lkZ2V0LkV2ZW50Qm94UHJvcHNcbiAgICAgICAgICAgIC8vIFRPRE86IGZpeGVkXG4gICAgICAgICAgICAvLyBUT0RPOiBmbG93Ym94XG4gICAgICAgICAgICBpY29uOiBXaWRnZXQuSWNvblByb3BzXG4gICAgICAgICAgICBsYWJlbDogV2lkZ2V0LkxhYmVsUHJvcHNcbiAgICAgICAgICAgIGxldmVsYmFyOiBXaWRnZXQuTGV2ZWxCYXJQcm9wc1xuICAgICAgICAgICAgLy8gVE9ETzogbGlzdGJveFxuICAgICAgICAgICAgbWVudWJ1dHRvbjogV2lkZ2V0Lk1lbnVCdXR0b25Qcm9wc1xuICAgICAgICAgICAgb3ZlcmxheTogV2lkZ2V0Lk92ZXJsYXlQcm9wc1xuICAgICAgICAgICAgcmV2ZWFsZXI6IFdpZGdldC5SZXZlYWxlclByb3BzXG4gICAgICAgICAgICBzY3JvbGxhYmxlOiBXaWRnZXQuU2Nyb2xsYWJsZVByb3BzXG4gICAgICAgICAgICBzbGlkZXI6IFdpZGdldC5TbGlkZXJQcm9wc1xuICAgICAgICAgICAgc3RhY2s6IFdpZGdldC5TdGFja1Byb3BzXG4gICAgICAgICAgICBzd2l0Y2g6IFdpZGdldC5Td2l0Y2hQcm9wc1xuICAgICAgICAgICAgd2luZG93OiBXaWRnZXQuV2luZG93UHJvcHNcbiAgICAgICAgfVxuICAgIH1cbn1cblxuZXhwb3J0IGNvbnN0IGpzeHMgPSBqc3hcbiIsICJpbXBvcnQgeyBWYXJpYWJsZSB9IGZyb20gXCJhc3RhbFwiO1xuXG5jb25zdCBob3VyID0gVmFyaWFibGU8bnVtYmVyPigwKS5wb2xsKFxuICA1MDAsXG4gIFwiZGF0ZSArJyVIJ1wiLFxuICAob3V0OiBzdHJpbmcsIHByZXY6IG51bWJlcikgPT4gcGFyc2VJbnQob3V0KSxcbik7XG5jb25zdCBtaW51dGUgPSBWYXJpYWJsZTxudW1iZXI+KDApLnBvbGwoXG4gIDUwMCxcbiAgXCJkYXRlICsnJU0nXCIsXG4gIChvdXQ6IHN0cmluZywgcHJldjogbnVtYmVyKSA9PiBwYXJzZUludChvdXQpLFxuKTtcbmNvbnN0IGRtID0gVmFyaWFibGU8bnVtYmVyPigwKS5wb2xsKFxuICA1MDAsXG4gIFwiZGF0ZSArJyVkJW0nXCIsXG4gIChvdXQ6IHN0cmluZywgcHJldjogbnVtYmVyKSA9PiBwYXJzZUludChvdXQpLFxuKTtcbmNvbnN0IHllYXIgPSBWYXJpYWJsZTxudW1iZXI+KDApLnBvbGwoXG4gIDUwMCxcbiAgXCJkYXRlICsnJVknXCIsXG4gIChvdXQ6IHN0cmluZywgcHJldjogbnVtYmVyKSA9PiBwYXJzZUludChvdXQpLFxuKTtcblxuY29uc3QgdHJhbnNmb3JtID0gKHY6IG51bWJlcikgPT5cbiAgdi50b1N0cmluZygpLmxlbmd0aCAlIDIgPT0gMCA/IHYudG9TdHJpbmcoKSA6IFwiMFwiICsgdi50b1N0cmluZygpO1xuXG5leHBvcnQgZGVmYXVsdCBmdW5jdGlvbiBEYXRlKCkge1xuICByZXR1cm4gPGJveCB2ZXJ0aWNhbCBjbGFzc05hbWU9XCJiZy1iZyByb3VuZGVkIHAtMlwiPlxuICAgIDxsYWJlbCBjbGFzc05hbWU9XCJ0ZXh0LWxpZ2h0IGZvbnQtYm9sZCB0ZXh0LXh4c1wiIGxhYmVsPXtkbSh0cmFuc2Zvcm0pfSAvPlxuICAgIDxsYWJlbCBjbGFzc05hbWU9XCJ0ZXh0LWxpZ2h0IGZvbnQtc2VtaWJvbGRcIiBsYWJlbD17aG91cih0cmFuc2Zvcm0pfSAvPlxuICAgIDxsYWJlbCBjbGFzc05hbWU9XCJ0ZXh0LWxpZ2h0IGZvbnQtc2VtaWJvbGRcIiBsYWJlbD17bWludXRlKHRyYW5zZm9ybSl9IC8+XG4gICAgPGxhYmVsIGNsYXNzTmFtZT1cInRleHQtbGlnaHQgZm9udC1ib2xkIHRleHQteHhzXCIgbGFiZWw9e3llYXIodHJhbnNmb3JtKX0gLz5cbiAgPC9ib3g+XG59XG4iLCAiaW1wb3J0IHsgYmluZCwgVmFyaWFibGUgfSBmcm9tIFwiYXN0YWxcIjtcbmltcG9ydCB7IEFzdGFsIH0gZnJvbSBcImFzdGFsL2d0azNcIjtcbmltcG9ydCB7IEV2ZW50Qm94IH0gZnJvbSBcImFzdGFsL2d0azMvd2lkZ2V0XCI7XG5pbXBvcnQgQXN0YWxIeXBybGFuZCBmcm9tIFwiZ2k6Ly9Bc3RhbEh5cHJsYW5kP3ZlcnNpb249MC4xXCJcblxuY29uc3QgaHlwcmxhbmQgPSBBc3RhbEh5cHJsYW5kLmdldF9kZWZhdWx0KCk7XG5cbmV4cG9ydCBkZWZhdWx0IGZ1bmN0aW9uIFdvcmtzcGFjZXMoKSB7XG4gIGZ1bmN0aW9uIHNjcm9sbFdzKHNlbGY6IEV2ZW50Qm94LCBlOiBBc3RhbC5TY3JvbGxFdmVudCkge1xuICAgIGh5cHJsYW5kLmRpc3BhdGNoKFwid29ya3NwYWNlXCIsIGUuZGVsdGFfeSA+IDAgPyBcIisxXCIgOiBcIi0xXCIpO1xuICB9XG5cbiAgcmV0dXJuIDxldmVudGJveCBvblNjcm9sbD17c2Nyb2xsV3N9PlxuICAgIDxib3ggdmVydGljYWwgY2xhc3NOYW1lPVwiYmctYmcgcm91bmRlZCBweS0yXCI+XG4gICAgICB7Wy4uLkFycmF5KDEwKS5rZXlzKCldLm1hcCgoaWQpID0+IDxXb3Jrc3BhY2UgaWQ9e2lkICsgMX0gLz4pfVxuICAgIDwvYm94PlxuICA8L2V2ZW50Ym94PlxufVxuXG50eXBlIFdvcmtzcGFjZVByb3BzID0ge1xuICBpZDogbnVtYmVyXG59XG5cbmV4cG9ydCBmdW5jdGlvbiBXb3Jrc3BhY2UoeyBpZCB9OiBXb3Jrc3BhY2VQcm9wcykge1xuICBjb25zdCBjbGFzc05hbWUgPSBWYXJpYWJsZS5kZXJpdmUoW2JpbmQoaHlwcmxhbmQsICd3b3Jrc3BhY2VzJyksIGJpbmQoaHlwcmxhbmQsICdmb2N1c2VkV29ya3NwYWNlJyldLCAod29ya3NwYWNlcywgZm9jdXNlZCkgPT4ge1xuICAgIGNvbnN0IGFsbENsYXNzZXM6IHN0cmluZ1tdID0gW1widGV4dC1iZy1taWRcIl1cbiAgICBjb25zdCB3b3Jrc3BhY2UgPSB3b3Jrc3BhY2VzLmZpbmQoKHcpID0+IHcuaWQgPT09IGlkKVxuXG4gICAgaWYgKHdvcmtzcGFjZSkge1xuICAgICAgaWYgKHdvcmtzcGFjZS5nZXRfY2xpZW50cygpLmxlbmd0aCA+IDApIHtcbiAgICAgICAgYWxsQ2xhc3Nlcy5wdXNoKCd0ZXh0LWxpZ2h0JylcbiAgICAgIH1cblxuICAgICAgaWYgKGZvY3VzZWQuaWQgPT09IGlkKSB7XG4gICAgICAgIGFsbENsYXNzZXMucHVzaCgndGV4dC1ibHVlJylcbiAgICAgIH1cbiAgICB9XG5cbiAgICByZXR1cm4gYWxsQ2xhc3Nlcy5qb2luKFwiIFwiKVxuICB9KVxuICByZXR1cm4gPGJ1dHRvbiBjbGFzc05hbWU9e2NsYXNzTmFtZSgpfSBvbkNsaWNrPXsoKSA9PiBoeXBybGFuZC5kaXNwYXRjaChcIndvcmtzcGFjZVwiLCBgJHtpZH1gKX0+XG4gICAgPGxhYmVsIGxhYmVsPXtpZC50b1N0cmluZygpfSAvPlxuICA8L2J1dHRvbj5cbn1cbiIsICJpbXBvcnQgeyBiaW5kLCBWYXJpYWJsZSB9IGZyb20gXCJhc3RhbFwiO1xuaW1wb3J0IHsgR3RrIH0gZnJvbSBcImFzdGFsL2d0azNcIjtcbmltcG9ydCBBc3RhbEJhdHRlcnkgZnJvbSBcImdpOi8vQXN0YWxCYXR0ZXJ5P3ZlcnNpb249MC4xXCI7XG5cbmNvbnN0IGJhdHRlcnkgPSBBc3RhbEJhdHRlcnkuZ2V0X2RlZmF1bHQoKVxuXG5leHBvcnQgZGVmYXVsdCBmdW5jdGlvbiBCYXR0ZXJ5KCkge1xuICBjb25zdCBpY29uID0gYmluZChiYXR0ZXJ5LCAnaWNvbk5hbWUnKVxuICBjb25zdCBwZXJjZW50ID0gYmluZChiYXR0ZXJ5LCAncGVyY2VudGFnZScpXG4gIGNvbnN0IHN0YXRlID0gYmluZChiYXR0ZXJ5LCAnc3RhdGUnKVxuICBjb25zdCBjb2xvciA9IFZhcmlhYmxlLmRlcml2ZShbc3RhdGUsIHBlcmNlbnRdLCAoc3RhdGUsIHBlcmNlbnQpID0+IHtcbiAgICBpZiAoc3RhdGUgPT09IEFzdGFsQmF0dGVyeS5TdGF0ZS5DSEFSR0lORyB8fCBwZXJjZW50ID4gMC44KVxuICAgICAgcmV0dXJuIFwidGV4dC1ibHVlXCJcbiAgICBpZiAocGVyY2VudCA+IDAuNClcbiAgICAgIHJldHVybiBcInRleHQtbGlnaHRcIlxuICAgIGlmIChwZXJjZW50ID4gMC4yKVxuICAgICAgcmV0dXJuIFwidGV4dC15ZWxsb3dcIlxuICAgIHJldHVybiBcInRleHQtcmVkXCJcbiAgfSlcbiAgcmV0dXJuIDxib3ggY2xhc3NOYW1lPVwiYmctYmcgcm91bmRlZCBwLTIgbXQtMVwiIGhhbGlnbj17R3RrLkFsaWduLkNFTlRFUn0+XG4gICAgPGNpcmN1bGFycHJvZ3Jlc3MgaGFsaWduPXtHdGsuQWxpZ24uQ0VOVEVSfSB2YWxpZ249e0d0ay5BbGlnbi5DRU5URVJ9IHZhbHVlPXtwZXJjZW50fSByb3VuZGVkIGNsYXNzTmFtZT17Y29sb3IoKHYpID0+IGB0ZXh0LWJvcmRlciAke3Z9YCl9IHN0YXJ0QXQ9ezB9IGVuZEF0PXsxfSA+XG4gICAgICA8aWNvbiBpY29uPXtpY29ufSBjbGFzc05hbWU9XCJwLTIgYmctYmcgdGV4dC14cyB0ZXh0LWxpZ2h0XCIgLz5cbiAgICA8L2NpcmN1bGFycHJvZ3Jlc3M+XG4gIDwvYm94PlxufVxuIiwgImltcG9ydCB7IGJpbmQgfSBmcm9tIFwiYXN0YWxcIjtcbmltcG9ydCB7IEd0ayB9IGZyb20gXCJhc3RhbC9ndGszXCI7XG5pbXBvcnQgQXN0YWxXcCBmcm9tIFwiZ2k6Ly9Bc3RhbFdwP3ZlcnNpb249MC4xXCI7XG5cbmNvbnN0IHdwID0gQXN0YWxXcC5nZXRfZGVmYXVsdCgpXG5cbmV4cG9ydCBkZWZhdWx0IGZ1bmN0aW9uIFZvbHVtZSgpIHtcbiAgaWYgKCF3cCkgcmV0dXJuIDw+PC8+XG5cbiAgY29uc3QgeyBDRU5URVIgfSA9IEd0ay5BbGlnblxuXG4gIGNvbnN0IHNwZWFrZXIgPSBiaW5kKHdwLmF1ZGlvLCAnZGVmYXVsdF9zcGVha2VyJylcbiAgY29uc3Qgc3BlYWtlclZvbHVtZSA9IHNwZWFrZXIuYXMoKHMpID0+IHMudm9sdW1lIC8gMTAwKVxuICBjb25zdCBzcGVha2VySWNvbiA9IHNwZWFrZXIuYXMoKHMpID0+IHMuaWNvbiAmJiBzLmljb24ubGVuZ3RoID4gMCAmJiBzLmljb24gIT09IFwiYXVkaW8tY2FyZC1zeW1ib2xpY1wiID8gcy5pY29uIDogXCJhdWRpby1zcGVha2Vycy1zeW1ib2xpY1wiKVxuXG4gIGNvbnN0IG1pYyA9IGJpbmQod3AuYXVkaW8sICdkZWZhdWx0X21pY3JvcGhvbmUnKVxuICBjb25zdCBtaWNWb2x1bWUgPSBtaWMuYXMoKHMpID0+IHMudm9sdW1lIC8gMTAwKVxuICBjb25zdCBtaWNJY29uID0gbWljLmFzKChzKSA9PiBzLmljb24gJiYgcy5pY29uLmxlbmd0aCA+IDAgJiYgcy5pY29uICE9PSBcImF1ZGlvLWNhcmQtc3ltYm9saWNcIiA/IHMuaWNvbiA6IFwiYXVkaW8taW5wdXQtbWljcm9waG9uZS1zeW1ib2xpY1wiKVxuXG4gIHJldHVybiA8Ym94IHZlcnRpY2FsIGNsYXNzTmFtZT1cImJnLWJnIHJvdW5kZWQgcC0yIG10LTFcIiBoYWxpZ249e0d0ay5BbGlnbi5DRU5URVJ9PlxuICAgIDxjaXJjdWxhcnByb2dyZXNzIGhhbGlnbj17Q0VOVEVSfSB2YWxpZ249e0NFTlRFUn0gdmFsdWU9e3NwZWFrZXJWb2x1bWV9IHJvdW5kZWQgY2xhc3NOYW1lPSd0ZXh0LWJvcmRlcicgc3RhcnRBdD17MH0gZW5kQXQ9ezF9ID5cbiAgICAgIDxpY29uIGljb249e3NwZWFrZXJJY29ufSBjbGFzc05hbWU9XCJwLTIgYmctYmcgdGV4dC14cyB0ZXh0LWxpZ2h0XCIgLz5cbiAgICA8L2NpcmN1bGFycHJvZ3Jlc3M+XG4gICAgPGNpcmN1bGFycHJvZ3Jlc3MgaGFsaWduPXtDRU5URVJ9IHZhbGlnbj17Q0VOVEVSfSB2YWx1ZT17bWljVm9sdW1lfSByb3VuZGVkIGNsYXNzTmFtZT0ndGV4dC1ib3JkZXIgcHQtNCcgc3RhcnRBdD17MH0gZW5kQXQ9ezF9ID5cbiAgICAgIDxpY29uIGljb249e21pY0ljb259IGNsYXNzTmFtZT1cInAtMiBiZy1iZyB0ZXh0LXhzIHRleHQtbGlnaHRcIiAvPlxuICAgIDwvY2lyY3VsYXJwcm9ncmVzcz5cbiAgPC9ib3g+XG59XG4iLCAiaW1wb3J0IHsgYmluZCwgVmFyaWFibGUgfSBmcm9tIFwiYXN0YWxcIjtcbmltcG9ydCB7IEd0ayB9IGZyb20gXCJhc3RhbC9ndGszXCI7XG5pbXBvcnQgQXN0YWxUcmF5IGZyb20gXCJnaTovL0FzdGFsVHJheT92ZXJzaW9uPTAuMVwiO1xuXG5jb25zdCB0cmF5ID0gQXN0YWxUcmF5LmdldF9kZWZhdWx0KClcbmV4cG9ydCBjb25zdCBpc1RyYXlWaXNpYmxlID0gVmFyaWFibGUoZmFsc2UpXG5cbmV4cG9ydCBkZWZhdWx0IGZ1bmN0aW9uIFRyYXkoKSB7XG4gIGNvbnN0IHsgQ0VOVEVSIH0gPSBHdGsuQWxpZ25cblxuICBiaW5kKHRyYXksIFwiaXRlbXNcIikuYXMoaSA9PiB7XG4gICAgaXNUcmF5VmlzaWJsZS5zZXQoaS5sZW5ndGggIT0gMCk7XG4gIH0pXG5cbiAgcmV0dXJuIDxib3ggdmVydGljYWwgdmFsaWduPXtDRU5URVJ9IGhhbGlnbj17Q0VOVEVSfSBjbGFzc05hbWU9XCJiZy1iZyByb3VuZGVkIHB0LTIgcHgtNFwiPlxuICAgIHtiaW5kKHRyYXksIFwiaXRlbXNcIikuYXMoaXRlbXMgPT4gaXRlbXMubWFwKGl0ZW0gPT4gKFxuICAgICAgPG1lbnVidXR0b25cbiAgICAgICAgY2xhc3NOYW1lPVwicGItMlwiXG4gICAgICAgIHRvb2x0aXBNYXJrdXA9e2JpbmQoaXRlbSwgXCJ0b29sdGlwTWFya3VwXCIpfVxuICAgICAgICB1c2VQb3BvdmVyPXtmYWxzZX1cbiAgICAgICAgbWVudU1vZGVsPXtiaW5kKGl0ZW0sIFwibWVudV9tb2RlbFwiKX0+XG4gICAgICAgIDxpY29uIGdpY29uPXtiaW5kKGl0ZW0sIFwiZ2ljb25cIil9IC8+XG4gICAgICA8L21lbnVidXR0b24+XG4gICAgKSkpfVxuICA8L2JveD5cbn1cbiIsICJpbXBvcnQgeyBBcHAsIEFzdGFsLCBHZGssIEd0ayB9IGZyb20gXCJhc3RhbC9ndGszXCI7XG5pbXBvcnQgRGF0ZSBmcm9tIFwiLi4vd2lkZ2V0L0RhdGVcIjtcbmltcG9ydCBXb3Jrc3BhY2VzIGZyb20gXCIuLi93aWRnZXQvV29ya3NwYWNlXCI7XG5pbXBvcnQgQmF0dGVyeSBmcm9tIFwiLi4vd2lkZ2V0L0JhdHRlcnlcIjtcbmltcG9ydCBWb2x1bWUgZnJvbSBcIi4uL3dpZGdldC9Wb2x1bWVcIjtcbmltcG9ydCBUcmF5IGZyb20gXCIuLi93aWRnZXQvVHJheVwiO1xuXG5leHBvcnQgZGVmYXVsdCBmdW5jdGlvbiBEZXNrdG9wKG1vbml0b3I6IEdkay5Nb25pdG9yKSB7XG4gIGNvbnN0IHsgVE9QLCBMRUZULCBCT1RUT00gfSA9IEFzdGFsLldpbmRvd0FuY2hvclxuICBjb25zdCB7IEVORCwgQ0VOVEVSIH0gPSBHdGsuQWxpZ25cblxuICByZXR1cm4gPHdpbmRvd1xuICAgIGNsYXNzTmFtZT1cImJnLXRyYW5zcGFyZW50XCJcbiAgICBnZGttb25pdG9yPXttb25pdG9yfVxuICAgIGV4Y2x1c2l2aXR5PXtBc3RhbC5FeGNsdXNpdml0eS5FWENMVVNJVkV9XG4gICAgYW5jaG9yPXtUT1AgfCBMRUZUIHwgQk9UVE9NfVxuICAgIGxheWVyPXtBc3RhbC5MYXllci5CQUNLR1JPVU5EfVxuICAgIGFwcGxpY2F0aW9uPXtBcHB9XG4gID5cbiAgICA8Y2VudGVyYm94IGNsYXNzTmFtZT1cInBsLTEgcHktMyBcIiB2ZXJ0aWNhbCBoZXhwYW5kPlxuICAgICAgPGJveCB2ZXJ0aWNhbD5cbiAgICAgICAgPERhdGUgLz5cbiAgICAgICAgPEJhdHRlcnkgLz5cbiAgICAgICAgPFZvbHVtZSAvPlxuICAgICAgPC9ib3g+XG4gICAgICA8V29ya3NwYWNlcyAvPlxuICAgICAgPGJveCB2ZXJ0aWNhbCB2YWxpZ249e0VORH0+XG4gICAgICAgIDxUcmF5IC8+XG4gICAgICA8L2JveD5cbiAgICA8L2NlbnRlcmJveD5cbiAgPC93aW5kb3c+XG5cbn1cblxuIiwgImltcG9ydCB7IEFwcCB9IGZyb20gXCJhc3RhbC9ndGszXCJcbmltcG9ydCBzdHlsZSBmcm9tIFwiLi4vdGFpbHdpbmQuc2Nzc1wiXG5pbXBvcnQgRGVza3RvcCBmcm9tIFwiLi4vY29tcG9uZW50cy9EZXNrdG9wXCJcblxuQXBwLnN0YXJ0KHtcbiAgY3NzOiBzdHlsZSxcbiAgbWFpbigpIHtcbiAgICBBcHAuZ2V0X21vbml0b3JzKCkubWFwKERlc2t0b3ApXG4gIH0sXG59KVxuIl0sCiAgIm1hcHBpbmdzIjogIjtBQUFBLE9BQU9BLFlBQVc7QUFDbEIsT0FBT0MsVUFBUztBQUNoQixPQUFPLFNBQVM7OztBQ0ZoQixPQUFPQyxZQUFXOzs7QUNBWCxJQUFNLFdBQVcsQ0FBQyxRQUFnQixJQUNwQyxRQUFRLG1CQUFtQixPQUFPLEVBQ2xDLFdBQVcsS0FBSyxHQUFHLEVBQ25CLFlBQVk7QUFFVixJQUFNLFdBQVcsQ0FBQyxRQUFnQixJQUNwQyxRQUFRLG1CQUFtQixPQUFPLEVBQ2xDLFdBQVcsS0FBSyxHQUFHLEVBQ25CLFlBQVk7QUFjVixJQUFNLFVBQU4sTUFBTSxTQUFlO0FBQUEsRUFDaEIsY0FBYyxDQUFDLE1BQVc7QUFBQSxFQUVsQztBQUFBLEVBQ0E7QUFBQSxFQVNBLE9BQU8sS0FBSyxTQUFxQyxNQUFlO0FBQzVELFdBQU8sSUFBSSxTQUFRLFNBQVMsSUFBSTtBQUFBLEVBQ3BDO0FBQUEsRUFFUSxZQUFZLFNBQTRDLE1BQWU7QUFDM0UsU0FBSyxXQUFXO0FBQ2hCLFNBQUssUUFBUSxRQUFRLFNBQVMsSUFBSTtBQUFBLEVBQ3RDO0FBQUEsRUFFQSxXQUFXO0FBQ1AsV0FBTyxXQUFXLEtBQUssUUFBUSxHQUFHLEtBQUssUUFBUSxNQUFNLEtBQUssS0FBSyxNQUFNLEVBQUU7QUFBQSxFQUMzRTtBQUFBLEVBRUEsR0FBTSxJQUFpQztBQUNuQyxVQUFNQyxRQUFPLElBQUksU0FBUSxLQUFLLFVBQVUsS0FBSyxLQUFLO0FBQ2xELElBQUFBLE1BQUssY0FBYyxDQUFDLE1BQWEsR0FBRyxLQUFLLFlBQVksQ0FBQyxDQUFDO0FBQ3ZELFdBQU9BO0FBQUEsRUFDWDtBQUFBLEVBRUEsTUFBYTtBQUNULFFBQUksT0FBTyxLQUFLLFNBQVMsUUFBUTtBQUM3QixhQUFPLEtBQUssWUFBWSxLQUFLLFNBQVMsSUFBSSxDQUFDO0FBRS9DLFFBQUksT0FBTyxLQUFLLFVBQVUsVUFBVTtBQUNoQyxZQUFNLFNBQVMsT0FBTyxTQUFTLEtBQUssS0FBSyxDQUFDO0FBQzFDLFVBQUksT0FBTyxLQUFLLFNBQVMsTUFBTSxNQUFNO0FBQ2pDLGVBQU8sS0FBSyxZQUFZLEtBQUssU0FBUyxNQUFNLEVBQUUsQ0FBQztBQUVuRCxhQUFPLEtBQUssWUFBWSxLQUFLLFNBQVMsS0FBSyxLQUFLLENBQUM7QUFBQSxJQUNyRDtBQUVBLFVBQU0sTUFBTSw4QkFBOEI7QUFBQSxFQUM5QztBQUFBLEVBRUEsVUFBVSxVQUE4QztBQUNwRCxRQUFJLE9BQU8sS0FBSyxTQUFTLGNBQWMsWUFBWTtBQUMvQyxhQUFPLEtBQUssU0FBUyxVQUFVLE1BQU07QUFDakMsaUJBQVMsS0FBSyxJQUFJLENBQUM7QUFBQSxNQUN2QixDQUFDO0FBQUEsSUFDTCxXQUFXLE9BQU8sS0FBSyxTQUFTLFlBQVksWUFBWTtBQUNwRCxZQUFNLFNBQVMsV0FBVyxLQUFLLEtBQUs7QUFDcEMsWUFBTSxLQUFLLEtBQUssU0FBUyxRQUFRLFFBQVEsTUFBTTtBQUMzQyxpQkFBUyxLQUFLLElBQUksQ0FBQztBQUFBLE1BQ3ZCLENBQUM7QUFDRCxhQUFPLE1BQU07QUFDVCxRQUFDLEtBQUssU0FBUyxXQUF5QyxFQUFFO0FBQUEsTUFDOUQ7QUFBQSxJQUNKO0FBQ0EsVUFBTSxNQUFNLEdBQUcsS0FBSyxRQUFRLGtCQUFrQjtBQUFBLEVBQ2xEO0FBQ0o7QUFFTyxJQUFNLEVBQUUsS0FBSyxJQUFJO0FBQ3hCLElBQU8sa0JBQVE7OztBQ3hGZixPQUFPLFdBQVc7QUFHWCxJQUFNLE9BQU8sTUFBTTtBQUVuQixTQUFTLFNBQVNDLFdBQWtCLFVBQXVCO0FBQzlELFNBQU8sTUFBTSxLQUFLLFNBQVNBLFdBQVUsTUFBTSxLQUFLLFdBQVcsQ0FBQztBQUNoRTs7O0FDUEEsT0FBT0MsWUFBVztBQVNYLElBQU0sVUFBVUEsT0FBTTtBQVV0QixTQUFTLFdBQ1osV0FDQSxRQUFrQyxPQUNsQyxRQUFrQyxVQUNwQztBQUNFLFFBQU0sT0FBTyxNQUFNLFFBQVEsU0FBUyxLQUFLLE9BQU8sY0FBYztBQUM5RCxRQUFNLEVBQUUsS0FBSyxLQUFLLElBQUksSUFBSTtBQUFBLElBQ3RCLEtBQUssT0FBTyxZQUFZLFVBQVU7QUFBQSxJQUNsQyxLQUFLLE9BQU8sUUFBUSxVQUFVLE9BQU87QUFBQSxJQUNyQyxLQUFLLE9BQU8sUUFBUSxVQUFVLE9BQU87QUFBQSxFQUN6QztBQUVBLFFBQU0sT0FBTyxNQUFNLFFBQVEsR0FBRyxJQUN4QkEsT0FBTSxRQUFRLFlBQVksR0FBRyxJQUM3QkEsT0FBTSxRQUFRLFdBQVcsR0FBRztBQUVsQyxPQUFLLFFBQVEsVUFBVSxDQUFDLEdBQUcsV0FBbUIsSUFBSSxNQUFNLENBQUM7QUFDekQsT0FBSyxRQUFRLFVBQVUsQ0FBQyxHQUFHLFdBQW1CLElBQUksTUFBTSxDQUFDO0FBQ3pELFNBQU87QUFDWDtBQVNPLFNBQVMsVUFBVSxLQUF5QztBQUMvRCxTQUFPLElBQUksUUFBUSxDQUFDLFNBQVMsV0FBVztBQUNwQyxRQUFJLE1BQU0sUUFBUSxHQUFHLEdBQUc7QUFDcEIsTUFBQUMsT0FBTSxRQUFRLFlBQVksS0FBSyxDQUFDLEdBQUcsUUFBUTtBQUN2QyxZQUFJO0FBQ0Esa0JBQVFBLE9BQU0sUUFBUSxtQkFBbUIsR0FBRyxDQUFDO0FBQUEsUUFDakQsU0FBUyxPQUFPO0FBQ1osaUJBQU8sS0FBSztBQUFBLFFBQ2hCO0FBQUEsTUFDSixDQUFDO0FBQUEsSUFDTCxPQUFPO0FBQ0gsTUFBQUEsT0FBTSxRQUFRLFdBQVcsS0FBSyxDQUFDLEdBQUcsUUFBUTtBQUN0QyxZQUFJO0FBQ0Esa0JBQVFBLE9BQU0sUUFBUSxZQUFZLEdBQUcsQ0FBQztBQUFBLFFBQzFDLFNBQVMsT0FBTztBQUNaLGlCQUFPLEtBQUs7QUFBQSxRQUNoQjtBQUFBLE1BQ0osQ0FBQztBQUFBLElBQ0w7QUFBQSxFQUNKLENBQUM7QUFDTDs7O0FIOURBLElBQU0sa0JBQU4sY0FBaUMsU0FBUztBQUFBLEVBQzlCO0FBQUEsRUFDQSxhQUFjLFFBQVE7QUFBQSxFQUV0QjtBQUFBLEVBQ0E7QUFBQSxFQUNBO0FBQUEsRUFFQSxlQUFlO0FBQUEsRUFDZjtBQUFBLEVBQ0E7QUFBQSxFQUNBO0FBQUEsRUFFQTtBQUFBLEVBQ0E7QUFBQSxFQUVSLFlBQVksTUFBUztBQUNqQixVQUFNO0FBQ04sU0FBSyxTQUFTO0FBQ2QsU0FBSyxXQUFXLElBQUlDLE9BQU0sYUFBYTtBQUN2QyxTQUFLLFNBQVMsUUFBUSxXQUFXLE1BQU07QUFDbkMsV0FBSyxVQUFVO0FBQ2YsV0FBSyxTQUFTO0FBQUEsSUFDbEIsQ0FBQztBQUNELFNBQUssU0FBUyxRQUFRLFNBQVMsQ0FBQyxHQUFHLFFBQVEsS0FBSyxhQUFhLEdBQUcsQ0FBQztBQUNqRSxXQUFPLElBQUksTUFBTSxNQUFNO0FBQUEsTUFDbkIsT0FBTyxDQUFDLFFBQVEsR0FBRyxTQUFTLE9BQU8sTUFBTSxLQUFLLENBQUMsQ0FBQztBQUFBLElBQ3BELENBQUM7QUFBQSxFQUNMO0FBQUEsRUFFUSxNQUFhQyxZQUF5QztBQUMxRCxVQUFNLElBQUksZ0JBQVEsS0FBSyxJQUFJO0FBQzNCLFdBQU9BLGFBQVksRUFBRSxHQUFHQSxVQUFTLElBQUk7QUFBQSxFQUN6QztBQUFBLEVBRUEsV0FBVztBQUNQLFdBQU8sT0FBTyxZQUFZLEtBQUssSUFBSSxDQUFDLEdBQUc7QUFBQSxFQUMzQztBQUFBLEVBRUEsTUFBUztBQUFFLFdBQU8sS0FBSztBQUFBLEVBQU87QUFBQSxFQUM5QixJQUFJLE9BQVU7QUFDVixRQUFJLFVBQVUsS0FBSyxRQUFRO0FBQ3ZCLFdBQUssU0FBUztBQUNkLFdBQUssU0FBUyxLQUFLLFNBQVM7QUFBQSxJQUNoQztBQUFBLEVBQ0o7QUFBQSxFQUVBLFlBQVk7QUFDUixRQUFJLEtBQUs7QUFDTDtBQUVKLFFBQUksS0FBSyxRQUFRO0FBQ2IsV0FBSyxRQUFRLFNBQVMsS0FBSyxjQUFjLE1BQU07QUFDM0MsY0FBTSxJQUFJLEtBQUssT0FBUSxLQUFLLElBQUksQ0FBQztBQUNqQyxZQUFJLGFBQWEsU0FBUztBQUN0QixZQUFFLEtBQUssQ0FBQUMsT0FBSyxLQUFLLElBQUlBLEVBQUMsQ0FBQyxFQUNsQixNQUFNLFNBQU8sS0FBSyxTQUFTLEtBQUssU0FBUyxHQUFHLENBQUM7QUFBQSxRQUN0RCxPQUFPO0FBQ0gsZUFBSyxJQUFJLENBQUM7QUFBQSxRQUNkO0FBQUEsTUFDSixDQUFDO0FBQUEsSUFDTCxXQUFXLEtBQUssVUFBVTtBQUN0QixXQUFLLFFBQVEsU0FBUyxLQUFLLGNBQWMsTUFBTTtBQUMzQyxrQkFBVSxLQUFLLFFBQVMsRUFDbkIsS0FBSyxPQUFLLEtBQUssSUFBSSxLQUFLLGNBQWUsR0FBRyxLQUFLLElBQUksQ0FBQyxDQUFDLENBQUMsRUFDdEQsTUFBTSxTQUFPLEtBQUssU0FBUyxLQUFLLFNBQVMsR0FBRyxDQUFDO0FBQUEsTUFDdEQsQ0FBQztBQUFBLElBQ0w7QUFBQSxFQUNKO0FBQUEsRUFFQSxhQUFhO0FBQ1QsUUFBSSxLQUFLO0FBQ0w7QUFFSixTQUFLLFNBQVMsV0FBVztBQUFBLE1BQ3JCLEtBQUssS0FBSztBQUFBLE1BQ1YsS0FBSyxTQUFPLEtBQUssSUFBSSxLQUFLLGVBQWdCLEtBQUssS0FBSyxJQUFJLENBQUMsQ0FBQztBQUFBLE1BQzFELEtBQUssU0FBTyxLQUFLLFNBQVMsS0FBSyxTQUFTLEdBQUc7QUFBQSxJQUMvQyxDQUFDO0FBQUEsRUFDTDtBQUFBLEVBRUEsV0FBVztBQUNQLFNBQUssT0FBTyxPQUFPO0FBQ25CLFdBQU8sS0FBSztBQUFBLEVBQ2hCO0FBQUEsRUFFQSxZQUFZO0FBQ1IsU0FBSyxRQUFRLEtBQUs7QUFDbEIsV0FBTyxLQUFLO0FBQUEsRUFDaEI7QUFBQSxFQUVBLFlBQVk7QUFBRSxXQUFPLENBQUMsQ0FBQyxLQUFLO0FBQUEsRUFBTTtBQUFBLEVBQ2xDLGFBQWE7QUFBRSxXQUFPLENBQUMsQ0FBQyxLQUFLO0FBQUEsRUFBTztBQUFBLEVBRXBDLE9BQU87QUFDSCxTQUFLLFNBQVMsS0FBSyxTQUFTO0FBQUEsRUFDaEM7QUFBQSxFQUVBLFVBQVUsVUFBc0I7QUFDNUIsU0FBSyxTQUFTLFFBQVEsV0FBVyxRQUFRO0FBQ3pDLFdBQU87QUFBQSxFQUNYO0FBQUEsRUFFQSxRQUFRLFVBQWlDO0FBQ3JDLFdBQU8sS0FBSztBQUNaLFNBQUssU0FBUyxRQUFRLFNBQVMsQ0FBQyxHQUFHLFFBQVEsU0FBUyxHQUFHLENBQUM7QUFDeEQsV0FBTztBQUFBLEVBQ1g7QUFBQSxFQUVBLFVBQVUsVUFBOEI7QUFDcEMsVUFBTSxLQUFLLEtBQUssU0FBUyxRQUFRLFdBQVcsTUFBTTtBQUM5QyxlQUFTLEtBQUssSUFBSSxDQUFDO0FBQUEsSUFDdkIsQ0FBQztBQUNELFdBQU8sTUFBTSxLQUFLLFNBQVMsV0FBVyxFQUFFO0FBQUEsRUFDNUM7QUFBQSxFQWFBLEtBQ0lDLFdBQ0EsTUFDQUYsYUFBNEMsU0FBTyxLQUNyRDtBQUNFLFNBQUssU0FBUztBQUNkLFNBQUssZUFBZUU7QUFDcEIsU0FBSyxnQkFBZ0JGO0FBQ3JCLFFBQUksT0FBTyxTQUFTLFlBQVk7QUFDNUIsV0FBSyxTQUFTO0FBQ2QsYUFBTyxLQUFLO0FBQUEsSUFDaEIsT0FBTztBQUNILFdBQUssV0FBVztBQUNoQixhQUFPLEtBQUs7QUFBQSxJQUNoQjtBQUNBLFNBQUssVUFBVTtBQUNmLFdBQU87QUFBQSxFQUNYO0FBQUEsRUFFQSxNQUNJLE1BQ0FBLGFBQTRDLFNBQU8sS0FDckQ7QUFDRSxTQUFLLFVBQVU7QUFDZixTQUFLLFlBQVk7QUFDakIsU0FBSyxpQkFBaUJBO0FBQ3RCLFNBQUssV0FBVztBQUNoQixXQUFPO0FBQUEsRUFDWDtBQUFBLEVBYUEsUUFDSSxNQUNBLFNBQ0EsVUFDRjtBQUNFLFVBQU0sSUFBSSxPQUFPLFlBQVksYUFBYSxVQUFVLGFBQWEsTUFBTSxLQUFLLElBQUk7QUFDaEYsVUFBTSxNQUFNLENBQUMsUUFBcUIsU0FBZ0IsS0FBSyxJQUFJLEVBQUUsS0FBSyxHQUFHLElBQUksQ0FBQztBQUUxRSxRQUFJLE1BQU0sUUFBUSxJQUFJLEdBQUc7QUFDckIsaUJBQVcsT0FBTyxNQUFNO0FBQ3BCLGNBQU0sQ0FBQyxHQUFHLENBQUMsSUFBSTtBQUNmLGNBQU0sS0FBSyxFQUFFLFFBQVEsR0FBRyxHQUFHO0FBQzNCLGFBQUssVUFBVSxNQUFNLEVBQUUsV0FBVyxFQUFFLENBQUM7QUFBQSxNQUN6QztBQUFBLElBQ0osT0FBTztBQUNILFVBQUksT0FBTyxZQUFZLFVBQVU7QUFDN0IsY0FBTSxLQUFLLEtBQUssUUFBUSxTQUFTLEdBQUc7QUFDcEMsYUFBSyxVQUFVLE1BQU0sS0FBSyxXQUFXLEVBQUUsQ0FBQztBQUFBLE1BQzVDO0FBQUEsSUFDSjtBQUVBLFdBQU87QUFBQSxFQUNYO0FBQUEsRUFFQSxPQUFPLE9BTUwsTUFBWSxLQUEyQixJQUFJLFNBQVMsTUFBc0I7QUFDeEUsVUFBTSxTQUFTLE1BQU0sR0FBRyxHQUFHLEtBQUssSUFBSSxPQUFLLEVBQUUsSUFBSSxDQUFDLENBQVM7QUFDekQsVUFBTSxVQUFVLElBQUksU0FBUyxPQUFPLENBQUM7QUFDckMsVUFBTSxTQUFTLEtBQUssSUFBSSxTQUFPLElBQUksVUFBVSxNQUFNLFFBQVEsSUFBSSxPQUFPLENBQUMsQ0FBQyxDQUFDO0FBQ3pFLFlBQVEsVUFBVSxNQUFNLE9BQU8sSUFBSSxXQUFTLE1BQU0sQ0FBQyxDQUFDO0FBQ3BELFdBQU87QUFBQSxFQUNYO0FBQ0o7QUFPTyxJQUFNLFdBQVcsSUFBSSxNQUFNLGlCQUF3QjtBQUFBLEVBQ3RELE9BQU8sQ0FBQyxJQUFJLElBQUksU0FBUyxJQUFJLGdCQUFnQixLQUFLLENBQUMsQ0FBQztBQUN4RCxDQUFDO0FBTU0sSUFBTSxFQUFFLE9BQU8sSUFBSTtBQUMxQixJQUFPLG1CQUFROzs7QUk5TlIsSUFBTSxvQkFBb0IsT0FBTyx3QkFBd0I7QUFDekQsSUFBTSxjQUFjLE9BQU8sd0JBQXdCO0FBRW5ELFNBQVMsY0FBYyxPQUFjO0FBQ3hDLFdBQVMsYUFBYSxNQUFhO0FBQy9CLFFBQUksSUFBSTtBQUNSLFdBQU8sTUFBTTtBQUFBLE1BQUksV0FBUyxpQkFBaUIsa0JBQ3JDLEtBQUssR0FBRyxJQUNSO0FBQUEsSUFDTjtBQUFBLEVBQ0o7QUFFQSxRQUFNLFdBQVcsTUFBTSxPQUFPLE9BQUssYUFBYSxlQUFPO0FBRXZELE1BQUksU0FBUyxXQUFXO0FBQ3BCLFdBQU87QUFFWCxNQUFJLFNBQVMsV0FBVztBQUNwQixXQUFPLFNBQVMsQ0FBQyxFQUFFLEdBQUcsU0FBUztBQUVuQyxTQUFPLGlCQUFTLE9BQU8sVUFBVSxTQUFTLEVBQUU7QUFDaEQ7QUFFTyxTQUFTLFFBQVEsS0FBVSxNQUFjLE9BQVk7QUFDeEQsTUFBSTtBQUNBLFVBQU0sU0FBUyxPQUFPLFNBQVMsSUFBSSxDQUFDO0FBQ3BDLFFBQUksT0FBTyxJQUFJLE1BQU0sTUFBTTtBQUN2QixhQUFPLElBQUksTUFBTSxFQUFFLEtBQUs7QUFFNUIsV0FBUSxJQUFJLElBQUksSUFBSTtBQUFBLEVBQ3hCLFNBQVMsT0FBTztBQUNaLFlBQVEsTUFBTSwyQkFBMkIsSUFBSSxRQUFRLEdBQUcsS0FBSyxLQUFLO0FBQUEsRUFDdEU7QUFDSjtBQU1PLFNBQVMsS0FDWixRQUNBLFFBQ0Esa0JBQ0EsVUFDRjtBQUNFLE1BQUksT0FBTyxPQUFPLFlBQVksY0FBYyxVQUFVO0FBQ2xELFVBQU0sS0FBSyxPQUFPLFFBQVEsa0JBQWtCLENBQUMsTUFBVyxTQUFvQjtBQUN4RSxhQUFPLFNBQVMsUUFBUSxHQUFHLElBQUk7QUFBQSxJQUNuQyxDQUFDO0FBQ0QsV0FBTyxRQUFRLFdBQVcsTUFBTTtBQUM1QixNQUFDLE9BQU8sV0FBeUMsRUFBRTtBQUFBLElBQ3ZELENBQUM7QUFBQSxFQUNMLFdBQVcsT0FBTyxPQUFPLGNBQWMsY0FBYyxPQUFPLHFCQUFxQixZQUFZO0FBQ3pGLFVBQU0sUUFBUSxPQUFPLFVBQVUsSUFBSSxTQUFvQjtBQUNuRCx1QkFBaUIsUUFBUSxHQUFHLElBQUk7QUFBQSxJQUNwQyxDQUFDO0FBQ0QsV0FBTyxRQUFRLFdBQVcsS0FBSztBQUFBLEVBQ25DO0FBQ0o7QUFFTyxTQUFTLFVBQXFGLFFBQWdCLFFBQWE7QUFFOUgsTUFBSSxFQUFFLE9BQU8sT0FBTyxXQUFXLENBQUMsR0FBRyxHQUFHLE1BQU0sSUFBSTtBQUVoRCxNQUFJLG9CQUFvQixpQkFBUztBQUM3QixlQUFXLENBQUMsUUFBUTtBQUFBLEVBQ3hCO0FBRUEsTUFBSSxPQUFPO0FBQ1AsYUFBUyxRQUFRLEtBQUs7QUFBQSxFQUMxQjtBQUdBLGFBQVcsQ0FBQyxLQUFLLEtBQUssS0FBSyxPQUFPLFFBQVEsS0FBSyxHQUFHO0FBQzlDLFFBQUksVUFBVSxRQUFXO0FBQ3JCLGFBQU8sTUFBTSxHQUFHO0FBQUEsSUFDcEI7QUFBQSxFQUNKO0FBR0EsUUFBTSxXQUEwQyxPQUMzQyxLQUFLLEtBQUssRUFDVixPQUFPLENBQUMsS0FBVSxTQUFTO0FBQ3hCLFFBQUksTUFBTSxJQUFJLGFBQWEsaUJBQVM7QUFDaEMsWUFBTSxVQUFVLE1BQU0sSUFBSTtBQUMxQixhQUFPLE1BQU0sSUFBSTtBQUNqQixhQUFPLENBQUMsR0FBRyxLQUFLLENBQUMsTUFBTSxPQUFPLENBQUM7QUFBQSxJQUNuQztBQUNBLFdBQU87QUFBQSxFQUNYLEdBQUcsQ0FBQyxDQUFDO0FBR1QsUUFBTSxhQUF3RCxPQUN6RCxLQUFLLEtBQUssRUFDVixPQUFPLENBQUMsS0FBVSxRQUFRO0FBQ3ZCLFFBQUksSUFBSSxXQUFXLElBQUksR0FBRztBQUN0QixZQUFNLE1BQU0sU0FBUyxHQUFHLEVBQUUsTUFBTSxHQUFHLEVBQUUsTUFBTSxDQUFDLEVBQUUsS0FBSyxHQUFHO0FBQ3RELFlBQU0sVUFBVSxNQUFNLEdBQUc7QUFDekIsYUFBTyxNQUFNLEdBQUc7QUFDaEIsYUFBTyxDQUFDLEdBQUcsS0FBSyxDQUFDLEtBQUssT0FBTyxDQUFDO0FBQUEsSUFDbEM7QUFDQSxXQUFPO0FBQUEsRUFDWCxHQUFHLENBQUMsQ0FBQztBQUdULFFBQU0saUJBQWlCLGNBQWMsU0FBUyxLQUFLLFFBQVEsQ0FBQztBQUM1RCxNQUFJLDBCQUEwQixpQkFBUztBQUNuQyxXQUFPLFdBQVcsRUFBRSxlQUFlLElBQUksQ0FBQztBQUN4QyxXQUFPLFFBQVEsV0FBVyxlQUFlLFVBQVUsQ0FBQyxNQUFNO0FBQ3RELGFBQU8sV0FBVyxFQUFFLENBQUM7QUFBQSxJQUN6QixDQUFDLENBQUM7QUFBQSxFQUNOLE9BQU87QUFDSCxRQUFJLGVBQWUsU0FBUyxHQUFHO0FBQzNCLGFBQU8sV0FBVyxFQUFFLGNBQWM7QUFBQSxJQUN0QztBQUFBLEVBQ0o7QUFHQSxhQUFXLENBQUMsUUFBUSxRQUFRLEtBQUssWUFBWTtBQUN6QyxVQUFNLE1BQU0sT0FBTyxXQUFXLFFBQVEsSUFDaEMsT0FBTyxRQUFRLEtBQUssSUFBSSxJQUN4QjtBQUVOLFFBQUksT0FBTyxhQUFhLFlBQVk7QUFDaEMsYUFBTyxRQUFRLEtBQUssUUFBUTtBQUFBLElBQ2hDLE9BQU87QUFDSCxhQUFPLFFBQVEsS0FBSyxNQUFNLFVBQVUsUUFBUSxFQUN2QyxLQUFLLEtBQUssRUFBRSxNQUFNLFFBQVEsS0FBSyxDQUFDO0FBQUEsSUFDekM7QUFBQSxFQUNKO0FBR0EsYUFBVyxDQUFDLE1BQU0sT0FBTyxLQUFLLFVBQVU7QUFDcEMsUUFBSSxTQUFTLFdBQVcsU0FBUyxZQUFZO0FBQ3pDLGFBQU8sUUFBUSxXQUFXLFFBQVEsVUFBVSxDQUFDLE1BQVc7QUFDcEQsZUFBTyxXQUFXLEVBQUUsQ0FBQztBQUFBLE1BQ3pCLENBQUMsQ0FBQztBQUFBLElBQ047QUFDQSxXQUFPLFFBQVEsV0FBVyxRQUFRLFVBQVUsQ0FBQyxNQUFXO0FBQ3BELGNBQVEsUUFBUSxNQUFNLENBQUM7QUFBQSxJQUMzQixDQUFDLENBQUM7QUFDRixZQUFRLFFBQVEsTUFBTSxRQUFRLElBQUksQ0FBQztBQUFBLEVBQ3ZDO0FBR0EsYUFBVyxDQUFDLEtBQUssS0FBSyxLQUFLLE9BQU8sUUFBUSxLQUFLLEdBQUc7QUFDOUMsUUFBSSxVQUFVLFFBQVc7QUFDckIsYUFBTyxNQUFNLEdBQUc7QUFBQSxJQUNwQjtBQUFBLEVBQ0o7QUFFQSxTQUFPLE9BQU8sUUFBUSxLQUFLO0FBQzNCLFVBQVEsTUFBTTtBQUNkLFNBQU87QUFDWDtBQUVBLFNBQVMsZ0JBQWdCLE1BQXVDO0FBQzVELFNBQU8sQ0FBQyxPQUFPLE9BQU8sTUFBTSxXQUFXO0FBQzNDO0FBRU8sU0FBUyxJQUNaRyxRQUNBLE1BQ0EsRUFBRSxVQUFVLEdBQUcsTUFBTSxHQUN2QjtBQUNFLGVBQWEsQ0FBQztBQUVkLE1BQUksQ0FBQyxNQUFNLFFBQVEsUUFBUTtBQUN2QixlQUFXLENBQUMsUUFBUTtBQUV4QixhQUFXLFNBQVMsT0FBTyxPQUFPO0FBRWxDLE1BQUksU0FBUyxXQUFXO0FBQ3BCLFVBQU0sUUFBUSxTQUFTLENBQUM7QUFBQSxXQUNuQixTQUFTLFNBQVM7QUFDdkIsVUFBTSxXQUFXO0FBRXJCLE1BQUksT0FBTyxTQUFTLFVBQVU7QUFDMUIsUUFBSSxnQkFBZ0JBLE9BQU0sSUFBSSxDQUFDO0FBQzNCLGFBQU9BLE9BQU0sSUFBSSxFQUFFLEtBQUs7QUFFNUIsV0FBTyxJQUFJQSxPQUFNLElBQUksRUFBRSxLQUFLO0FBQUEsRUFDaEM7QUFFQSxNQUFJLGdCQUFnQixJQUFJO0FBQ3BCLFdBQU8sS0FBSyxLQUFLO0FBRXJCLFNBQU8sSUFBSSxLQUFLLEtBQUs7QUFDekI7OztBQy9MQSxPQUFPQyxZQUFXO0FBQ2xCLE9BQU8sU0FBUztBQUVoQixPQUFPLGFBQWE7QUFNTCxTQUFSLFNBRUwsS0FBUSxVQUFVLElBQUksTUFBTTtBQUFBLEVBQzFCLE1BQU0sZUFBZSxJQUFJO0FBQUEsSUFDckIsSUFBSSxNQUFjO0FBQUUsYUFBT0MsT0FBTSxlQUFlLElBQUk7QUFBQSxJQUFFO0FBQUEsSUFDdEQsSUFBSSxJQUFJLEtBQWE7QUFBRSxNQUFBQSxPQUFNLGVBQWUsTUFBTSxHQUFHO0FBQUEsSUFBRTtBQUFBLElBQ3ZELFVBQWtCO0FBQUUsYUFBTyxLQUFLO0FBQUEsSUFBSTtBQUFBLElBQ3BDLFFBQVEsS0FBYTtBQUFFLFdBQUssTUFBTTtBQUFBLElBQUk7QUFBQSxJQUV0QyxJQUFJLFlBQW9CO0FBQUUsYUFBT0EsT0FBTSx1QkFBdUIsSUFBSSxFQUFFLEtBQUssR0FBRztBQUFBLElBQUU7QUFBQSxJQUM5RSxJQUFJLFVBQVUsV0FBbUI7QUFBRSxNQUFBQSxPQUFNLHVCQUF1QixNQUFNLFVBQVUsTUFBTSxLQUFLLENBQUM7QUFBQSxJQUFFO0FBQUEsSUFDOUYsaUJBQXlCO0FBQUUsYUFBTyxLQUFLO0FBQUEsSUFBVTtBQUFBLElBQ2pELGVBQWUsV0FBbUI7QUFBRSxXQUFLLFlBQVk7QUFBQSxJQUFVO0FBQUEsSUFFL0QsSUFBSSxTQUFpQjtBQUFFLGFBQU9BLE9BQU0sa0JBQWtCLElBQUk7QUFBQSxJQUFZO0FBQUEsSUFDdEUsSUFBSSxPQUFPLFFBQWdCO0FBQUUsTUFBQUEsT0FBTSxrQkFBa0IsTUFBTSxNQUFNO0FBQUEsSUFBRTtBQUFBLElBQ25FLGFBQXFCO0FBQUUsYUFBTyxLQUFLO0FBQUEsSUFBTztBQUFBLElBQzFDLFdBQVcsUUFBZ0I7QUFBRSxXQUFLLFNBQVM7QUFBQSxJQUFPO0FBQUEsSUFFbEQsSUFBSSxlQUF3QjtBQUFFLGFBQU9BLE9BQU0seUJBQXlCLElBQUk7QUFBQSxJQUFFO0FBQUEsSUFDMUUsSUFBSSxhQUFhLGNBQXVCO0FBQUUsTUFBQUEsT0FBTSx5QkFBeUIsTUFBTSxZQUFZO0FBQUEsSUFBRTtBQUFBLElBQzdGLG9CQUE2QjtBQUFFLGFBQU8sS0FBSztBQUFBLElBQWE7QUFBQSxJQUN4RCxrQkFBa0IsY0FBdUI7QUFBRSxXQUFLLGVBQWU7QUFBQSxJQUFhO0FBQUEsSUFHNUUsSUFBSSxvQkFBNkI7QUFBRSxhQUFPLEtBQUssaUJBQWlCO0FBQUEsSUFBRTtBQUFBLElBQ2xFLElBQUksa0JBQWtCLE9BQWdCO0FBQUUsV0FBSyxpQkFBaUIsSUFBSTtBQUFBLElBQU07QUFBQSxJQUV4RSxJQUFJLFlBQVksQ0FBQyxRQUFRLEtBQUssR0FBZ0I7QUFBRSxXQUFLLG9CQUFvQixRQUFRLEtBQUs7QUFBQSxJQUFFO0FBQUEsSUFDeEYsaUJBQWlCLGFBQTBCO0FBQUUsV0FBSyxjQUFjO0FBQUEsSUFBWTtBQUFBLElBRWxFLGNBQWlDO0FBQ3ZDLFVBQUksZ0JBQWdCLElBQUksS0FBSztBQUN6QixlQUFPLEtBQUssVUFBVSxJQUFJLENBQUMsS0FBSyxVQUFVLENBQUUsSUFBSSxDQUFDO0FBQUEsTUFDckQsV0FBVyxnQkFBZ0IsSUFBSSxXQUFXO0FBQ3RDLGVBQU8sS0FBSyxhQUFhO0FBQUEsTUFDN0I7QUFDQSxhQUFPLENBQUM7QUFBQSxJQUNaO0FBQUEsSUFFVSxZQUFZLFVBQWlCO0FBQ25DLGlCQUFXLFNBQVMsS0FBSyxRQUFRLEVBQUUsSUFBSSxRQUFNLGNBQWMsSUFBSSxTQUN6RCxLQUNBLElBQUksSUFBSSxNQUFNLEVBQUUsU0FBUyxNQUFNLE9BQU8sT0FBTyxFQUFFLEVBQUUsQ0FBQyxDQUFDO0FBRXpELFVBQUksZ0JBQWdCLElBQUksV0FBVztBQUMvQixtQkFBVyxNQUFNO0FBQ2IsZUFBSyxJQUFJLEVBQUU7QUFBQSxNQUNuQixPQUFPO0FBQ0gsY0FBTSxNQUFNLDJCQUEyQixLQUFLLFlBQVksSUFBSSxFQUFFO0FBQUEsTUFDbEU7QUFBQSxJQUNKO0FBQUEsSUFFQSxDQUFDLFdBQVcsRUFBRSxVQUFpQjtBQUUzQixVQUFJLGdCQUFnQixJQUFJLFdBQVc7QUFDL0IsbUJBQVcsTUFBTSxLQUFLLFlBQVksR0FBRztBQUNqQyxlQUFLLE9BQU8sRUFBRTtBQUNkLGNBQUksQ0FBQyxTQUFTLFNBQVMsRUFBRSxLQUFLLENBQUMsS0FBSztBQUNoQyxnQkFBSSxRQUFRO0FBQUEsUUFDcEI7QUFBQSxNQUNKO0FBR0EsV0FBSyxZQUFZLFFBQVE7QUFBQSxJQUM3QjtBQUFBLElBRUEsZ0JBQWdCLElBQVksT0FBTyxNQUFNO0FBQ3JDLE1BQUFBLE9BQU0seUJBQXlCLE1BQU0sSUFBSSxJQUFJO0FBQUEsSUFDakQ7QUFBQSxJQVdBLEtBQ0ksUUFDQSxrQkFDQSxVQUNGO0FBQ0UsV0FBSyxNQUFNLFFBQVEsa0JBQWtCLFFBQVE7QUFDN0MsYUFBTztBQUFBLElBQ1g7QUFBQSxJQUVBLGVBQWUsUUFBZTtBQUMxQixZQUFNO0FBQ04sWUFBTSxRQUFRLE9BQU8sQ0FBQyxLQUFLLENBQUM7QUFDNUIsWUFBTSxZQUFZO0FBQ2xCLGdCQUFVLE1BQU0sS0FBSztBQUFBLElBQ3pCO0FBQUEsRUFDSjtBQUVBLFVBQVEsY0FBYztBQUFBLElBQ2xCLFdBQVcsU0FBUyxPQUFPO0FBQUEsSUFDM0IsWUFBWTtBQUFBLE1BQ1IsY0FBYyxRQUFRLFVBQVU7QUFBQSxRQUM1QjtBQUFBLFFBQWM7QUFBQSxRQUFJO0FBQUEsUUFBSSxRQUFRLFdBQVc7QUFBQSxRQUFXO0FBQUEsTUFDeEQ7QUFBQSxNQUNBLE9BQU8sUUFBUSxVQUFVO0FBQUEsUUFDckI7QUFBQSxRQUFPO0FBQUEsUUFBSTtBQUFBLFFBQUksUUFBUSxXQUFXO0FBQUEsUUFBVztBQUFBLE1BQ2pEO0FBQUEsTUFDQSxVQUFVLFFBQVEsVUFBVTtBQUFBLFFBQ3hCO0FBQUEsUUFBVTtBQUFBLFFBQUk7QUFBQSxRQUFJLFFBQVEsV0FBVztBQUFBLFFBQVc7QUFBQSxNQUNwRDtBQUFBLE1BQ0EsaUJBQWlCLFFBQVEsVUFBVTtBQUFBLFFBQy9CO0FBQUEsUUFBaUI7QUFBQSxRQUFJO0FBQUEsUUFBSSxRQUFRLFdBQVc7QUFBQSxRQUFXO0FBQUEsTUFDM0Q7QUFBQSxNQUNBLHVCQUF1QixRQUFRLFVBQVU7QUFBQSxRQUNyQztBQUFBLFFBQXVCO0FBQUEsUUFBSTtBQUFBLFFBQUksUUFBUSxXQUFXO0FBQUEsUUFBVztBQUFBLE1BQ2pFO0FBQUEsSUFDSjtBQUFBLEVBQ0osR0FBRyxNQUFNO0FBRVQsU0FBTztBQUNYOzs7QUNqSUEsT0FBT0MsVUFBUztBQUNoQixPQUFPQyxZQUFXOzs7QUNLbEIsSUFBTUMsWUFBVyxDQUFDLFFBQWdCLElBQzdCLFFBQVEsbUJBQW1CLE9BQU8sRUFDbEMsV0FBVyxLQUFLLEdBQUcsRUFDbkIsWUFBWTtBQUVqQixlQUFlLFNBQVksS0FBOEJDLFFBQXVCO0FBQzVFLFNBQU8sSUFBSSxLQUFLLE9BQUtBLE9BQU0sRUFBRSxPQUFPLENBQUMsRUFBRSxNQUFNLE1BQU0sTUFBTTtBQUM3RDtBQUVBLFNBQVMsTUFBd0IsT0FBVSxNQUFnQztBQUN2RSxTQUFPLGVBQWUsT0FBTyxNQUFNO0FBQUEsSUFDL0IsTUFBTTtBQUFFLGFBQU8sS0FBSyxPQUFPRCxVQUFTLElBQUksQ0FBQyxFQUFFLEVBQUU7QUFBQSxJQUFFO0FBQUEsRUFDbkQsQ0FBQztBQUNMO0FBRUEsTUFBTSxTQUFTLE9BQU8sZ0JBQWdCLEdBQUcsQ0FBQyxFQUFFLE1BQU0sWUFBWSxNQUFNO0FBQ2hFLFFBQU0sS0FBSyxXQUFXLE1BQU07QUFDNUIsUUFBTSxZQUFZLFdBQVcsVUFBVTtBQUN2QyxRQUFNLFlBQVksV0FBVyxZQUFZO0FBQzdDLENBQUM7QUFFRCxNQUFNLFNBQVMsT0FBTyxtQkFBbUIsR0FBRyxDQUFDLEVBQUUsT0FBTyxNQUFNO0FBQ3hELFFBQU0sT0FBTyxXQUFXLFNBQVM7QUFDckMsQ0FBQztBQUVELE1BQU0sU0FBUyxPQUFPLHFCQUFxQixHQUFHLENBQUMsRUFBRSxTQUFTLFdBQVcsT0FBTyxNQUFNO0FBQzlFLFFBQU0sUUFBUSxXQUFXLE9BQU87QUFDaEMsUUFBTSxVQUFVLFdBQVcsVUFBVTtBQUNyQyxRQUFNLFVBQVUsV0FBVyxTQUFTO0FBQ3BDLFFBQU0sT0FBTyxXQUFXLE9BQU87QUFDbkMsQ0FBQztBQUVELE1BQU0sU0FBUyxPQUFPLG9CQUFvQixHQUFHLENBQUMsRUFBRSxVQUFVLFNBQVMsV0FBQUUsV0FBVSxNQUFNO0FBQy9FLFFBQU0sU0FBUyxXQUFXLFVBQVU7QUFDcEMsUUFBTSxTQUFTLFdBQVcsWUFBWTtBQUN0QyxRQUFNLFNBQVMsV0FBVyxTQUFTO0FBQ25DLFFBQU0sUUFBUSxXQUFXLGdCQUFnQjtBQUN6QyxRQUFNLFFBQVEsV0FBVyxpQkFBaUI7QUFDMUMsUUFBTUEsV0FBVSxXQUFXLFNBQVM7QUFDeEMsQ0FBQztBQUVELE1BQU0sU0FBUyxPQUFPLGlCQUFpQixHQUFHLENBQUMsRUFBRSxPQUFPLE9BQU8sTUFBTTtBQUM3RCxRQUFNLE1BQU0sV0FBVyxTQUFTO0FBQ2hDLFFBQU0sT0FBTyxXQUFXLHVCQUF1QjtBQUMvQyxRQUFNLE9BQU8sV0FBVyxxQkFBcUI7QUFDN0MsUUFBTSxPQUFPLFdBQVcsc0JBQXNCO0FBQzlDLFFBQU0sT0FBTyxXQUFXLG9CQUFvQjtBQUM1QyxRQUFNLE9BQU8sV0FBVyxVQUFVO0FBQ3RDLENBQUM7QUFFRCxNQUFNLFNBQVMsT0FBTyxtQkFBbUIsR0FBRyxDQUFDLEVBQUUsS0FBSyxNQUFNO0FBQ3RELFFBQU0sS0FBSyxXQUFXLGVBQWU7QUFDckMsUUFBTSxLQUFLLFdBQVcsY0FBYztBQUN4QyxDQUFDO0FBRUQsTUFBTSxTQUFTLE9BQU8sa0JBQWtCLEdBQUcsQ0FBQyxFQUFFLFFBQVEsYUFBYSxNQUFNO0FBQ3JFLFFBQU0sT0FBTyxXQUFXLGVBQWU7QUFDdkMsUUFBTSxhQUFhLFdBQVcsU0FBUztBQUMzQyxDQUFDO0FBRUQsTUFBTSxTQUFTLE9BQU8seUJBQXlCLEdBQUcsQ0FBQyxFQUFFLGNBQWMsTUFBTTtBQUNyRSxRQUFNLGNBQWMsV0FBVyxTQUFTO0FBQzVDLENBQUM7QUFFRCxNQUFNLFNBQVMsT0FBTyxjQUFjLEdBQUcsQ0FBQyxFQUFFLElBQUksT0FBTyxNQUFNLE1BQU07QUFDN0QsUUFBTSxHQUFHLFdBQVcsV0FBVztBQUMvQixRQUFNLEdBQUcsV0FBVyxTQUFTO0FBQzdCLFFBQU0sTUFBTSxXQUFXLFNBQVM7QUFDaEMsUUFBTSxNQUFNLFdBQVcsV0FBVztBQUNsQyxRQUFNLE1BQU0sV0FBVyxhQUFhO0FBQ3BDLFFBQU0sTUFBTSxXQUFXLFVBQVU7QUFDakMsUUFBTSxNQUFNLFdBQVcsU0FBUztBQUNoQyxRQUFNLE1BQU0sV0FBVyxTQUFTO0FBQ2hDLFFBQU0sTUFBTSxXQUFXLFdBQVc7QUFDbEMsUUFBTSxNQUFNLFdBQVcsT0FBTztBQUM5QixRQUFNLE1BQU0sV0FBVyxTQUFTO0FBQ2hDLFFBQU0sTUFBTSxXQUFXLFNBQVM7QUFDcEMsQ0FBQzs7O0FDbEZELFNBQVMsMkJBQTJCO0FBQ3BDLFNBQVMsTUFBTSxtQkFBbUI7QUFDbEMsT0FBTyxRQUFRO0FBQ2YsT0FBT0MsY0FBYTtBQXdDYixTQUFTLE1BQU0sS0FBa0I7QUFDcEMsU0FBTyxJQUFLLE1BQU0sZ0JBQWdCLElBQUk7QUFBQSxJQUNsQyxPQUFPO0FBQUUsTUFBQUEsU0FBUSxjQUFjLEVBQUUsV0FBVyxVQUFVLEdBQUcsSUFBVztBQUFBLElBQUU7QUFBQSxJQUV0RSxLQUFLLE1BQTRCO0FBQzdCLGFBQU8sSUFBSSxRQUFRLENBQUMsS0FBSyxRQUFRO0FBQzdCLFlBQUk7QUFDQSxnQkFBTSxLQUFLLFNBQVM7QUFBQSwwQkFDZCxLQUFLLFNBQVMsR0FBRyxJQUFJLE9BQU8sVUFBVSxJQUFJLEdBQUc7QUFBQSx1QkFDaEQ7QUFDSCxhQUFHLEVBQUUsRUFBRSxLQUFLLEdBQUcsRUFBRSxNQUFNLEdBQUc7QUFBQSxRQUM5QixTQUFTLE9BQU87QUFDWixjQUFJLEtBQUs7QUFBQSxRQUNiO0FBQUEsTUFDSixDQUFDO0FBQUEsSUFDTDtBQUFBLElBRUE7QUFBQSxJQUVBLGNBQWMsS0FBYSxNQUFrQztBQUN6RCxVQUFJLE9BQU8sS0FBSyxtQkFBbUIsWUFBWTtBQUMzQyxhQUFLLGVBQWUsS0FBSyxDQUFDLGFBQWE7QUFDbkMsYUFBRztBQUFBLFlBQVc7QUFBQSxZQUFNLE9BQU8sUUFBUTtBQUFBLFlBQUcsQ0FBQyxHQUFHLFFBQ3RDLEdBQUcsa0JBQWtCLEdBQUc7QUFBQSxVQUM1QjtBQUFBLFFBQ0osQ0FBQztBQUFBLE1BQ0wsT0FBTztBQUNILGNBQU0sY0FBYyxLQUFLLElBQUk7QUFBQSxNQUNqQztBQUFBLElBQ0o7QUFBQSxJQUVBLFVBQVUsT0FBZSxRQUFRLE9BQU87QUFDcEMsWUFBTSxVQUFVLE9BQU8sS0FBSztBQUFBLElBQ2hDO0FBQUEsSUFFQSxLQUFLLE1BQXFCO0FBQ3RCLFlBQU0sS0FBSztBQUNYLFdBQUssUUFBUSxDQUFDO0FBQUEsSUFDbEI7QUFBQSxJQUVBLE1BQU0sRUFBRSxnQkFBZ0IsS0FBSyxNQUFNLE1BQU0sUUFBUSxPQUFPLEdBQUcsSUFBSSxJQUFZLENBQUMsR0FBRztBQUMzRSxZQUFNLE1BQU07QUFFWixpQkFBVyxNQUFNO0FBQ2IsY0FBTSxtQkFBbUIsSUFBSSxZQUFZLG1CQUFtQjtBQUM1RCxhQUFLLENBQUM7QUFBQSxNQUNWO0FBRUEsYUFBTyxPQUFPLE1BQU0sR0FBRztBQUN2QiwwQkFBb0IsSUFBSSxZQUFZO0FBRXBDLFdBQUssaUJBQWlCO0FBQ3RCLFVBQUksUUFBUSxZQUFZLE1BQU07QUFDMUIsZUFBTyxHQUFHLFdBQVc7QUFBQSxNQUN6QixDQUFDO0FBRUQsVUFBSTtBQUNBLFlBQUksZUFBZTtBQUFBLE1BQ3ZCLFNBQVMsT0FBTztBQUNaLGVBQU8sT0FBTyxTQUFPLEdBQUcsYUFBYSxJQUFJLGNBQWMsR0FBRyxHQUFJLEdBQUcsV0FBVztBQUFBLE1BQ2hGO0FBRUEsVUFBSTtBQUNBLGFBQUssVUFBVSxLQUFLLEtBQUs7QUFFN0IsVUFBSTtBQUNBLFlBQUksVUFBVSxLQUFLO0FBRXZCLGVBQVM7QUFDVCxVQUFJO0FBQ0EsWUFBSSxLQUFLO0FBRWIsVUFBSSxTQUFTLENBQUMsQ0FBQztBQUFBLElBQ25CO0FBQUEsRUFDSjtBQUNKOzs7QUZuSEFDLEtBQUksS0FBSyxJQUFJO0FBRWIsSUFBTyxjQUFRLE1BQU1DLE9BQU0sV0FBVzs7O0FHTHRDLE9BQU9DLFlBQVc7QUFDbEIsT0FBT0MsVUFBUztBQUNoQixPQUFPQyxjQUFhO0FBR3BCLFNBQVMsT0FBTyxVQUFpQjtBQUM3QixTQUFPLFNBQVMsS0FBSyxRQUFRLEVBQUUsSUFBSSxRQUFNLGNBQWNDLEtBQUksU0FDckQsS0FDQSxJQUFJQSxLQUFJLE1BQU0sRUFBRSxTQUFTLE1BQU0sT0FBTyxPQUFPLEVBQUUsRUFBRSxDQUFDLENBQUM7QUFDN0Q7QUFHQSxPQUFPLGVBQWVDLE9BQU0sSUFBSSxXQUFXLFlBQVk7QUFBQSxFQUNuRCxNQUFNO0FBQUUsV0FBTyxLQUFLLGFBQWE7QUFBQSxFQUFFO0FBQUEsRUFDbkMsSUFBSSxHQUFHO0FBQUUsU0FBSyxhQUFhLENBQUM7QUFBQSxFQUFFO0FBQ2xDLENBQUM7QUFHTSxJQUFNLE1BQU4sY0FBa0IsU0FBU0EsT0FBTSxHQUFHLEVBQUU7QUFBQSxFQUN6QyxPQUFPO0FBQUUsSUFBQUMsU0FBUSxjQUFjLEVBQUUsV0FBVyxNQUFNLEdBQUcsSUFBSTtBQUFBLEVBQUU7QUFBQSxFQUMzRCxZQUFZLFVBQXFCLFVBQWdDO0FBQUUsVUFBTSxFQUFFLFVBQVUsR0FBRyxNQUFNLENBQVE7QUFBQSxFQUFFO0FBQUEsRUFDOUYsWUFBWSxVQUF1QjtBQUFFLFNBQUssYUFBYSxPQUFPLFFBQVEsQ0FBQztBQUFBLEVBQUU7QUFDdkY7QUFXTyxJQUFNLFNBQU4sY0FBcUIsU0FBU0QsT0FBTSxNQUFNLEVBQUU7QUFBQSxFQUMvQyxPQUFPO0FBQUUsSUFBQUMsU0FBUSxjQUFjLEVBQUUsV0FBVyxTQUFTLEdBQUcsSUFBSTtBQUFBLEVBQUU7QUFBQSxFQUM5RCxZQUFZLE9BQXFCLE9BQXVCO0FBQUUsVUFBTSxFQUFFLE9BQU8sR0FBRyxNQUFNLENBQVE7QUFBQSxFQUFFO0FBQ2hHO0FBSU8sSUFBTSxZQUFOLGNBQXdCLFNBQVNELE9BQU0sU0FBUyxFQUFFO0FBQUEsRUFDckQsT0FBTztBQUFFLElBQUFDLFNBQVEsY0FBYyxFQUFFLFdBQVcsWUFBWSxHQUFHLElBQUk7QUFBQSxFQUFFO0FBQUEsRUFDakUsWUFBWSxVQUEyQixVQUFnQztBQUFFLFVBQU0sRUFBRSxVQUFVLEdBQUcsTUFBTSxDQUFRO0FBQUEsRUFBRTtBQUFBLEVBQ3BHLFlBQVksVUFBdUI7QUFDekMsVUFBTSxLQUFLLE9BQU8sUUFBUTtBQUMxQixTQUFLLGNBQWMsR0FBRyxDQUFDLEtBQUssSUFBSUYsS0FBSTtBQUNwQyxTQUFLLGVBQWUsR0FBRyxDQUFDLEtBQUssSUFBSUEsS0FBSTtBQUNyQyxTQUFLLFlBQVksR0FBRyxDQUFDLEtBQUssSUFBSUEsS0FBSTtBQUFBLEVBQ3RDO0FBQ0o7QUFJTyxJQUFNLG1CQUFOLGNBQStCLFNBQVNDLE9BQU0sZ0JBQWdCLEVBQUU7QUFBQSxFQUNuRSxPQUFPO0FBQUUsSUFBQUMsU0FBUSxjQUFjLEVBQUUsV0FBVyxtQkFBbUIsR0FBRyxJQUFJO0FBQUEsRUFBRTtBQUFBLEVBQ3hFLFlBQVksT0FBK0IsT0FBdUI7QUFBRSxVQUFNLEVBQUUsT0FBTyxHQUFHLE1BQU0sQ0FBUTtBQUFBLEVBQUU7QUFDMUc7QUFNTyxJQUFNLGNBQU4sY0FBMEIsU0FBU0YsS0FBSSxXQUFXLEVBQUU7QUFBQSxFQUN2RCxPQUFPO0FBQUUsSUFBQUUsU0FBUSxjQUFjLEVBQUUsV0FBVyxjQUFjLEdBQUcsSUFBSTtBQUFBLEVBQUU7QUFBQSxFQUNuRSxZQUFZLE9BQTBCO0FBQUUsVUFBTSxLQUFZO0FBQUEsRUFBRTtBQUNoRTtBQU9PLElBQU0sUUFBTixjQUFvQixTQUFTRixLQUFJLEtBQUssRUFBRTtBQUFBLEVBQzNDLE9BQU87QUFBRSxJQUFBRSxTQUFRLGNBQWMsRUFBRSxXQUFXLFFBQVEsR0FBRyxJQUFJO0FBQUEsRUFBRTtBQUFBLEVBQzdELFlBQVksT0FBb0I7QUFBRSxVQUFNLEtBQVk7QUFBQSxFQUFFO0FBQzFEO0FBVU8sSUFBTSxXQUFOLGNBQXVCLFNBQVNELE9BQU0sUUFBUSxFQUFFO0FBQUEsRUFDbkQsT0FBTztBQUFFLElBQUFDLFNBQVEsY0FBYyxFQUFFLFdBQVcsV0FBVyxHQUFHLElBQUk7QUFBQSxFQUFFO0FBQUEsRUFDaEUsWUFBWSxPQUF1QixPQUF1QjtBQUFFLFVBQU0sRUFBRSxPQUFPLEdBQUcsTUFBTSxDQUFRO0FBQUEsRUFBRTtBQUNsRztBQU9PLElBQU0sT0FBTixjQUFtQixTQUFTRCxPQUFNLElBQUksRUFBRTtBQUFBLEVBQzNDLE9BQU87QUFBRSxJQUFBQyxTQUFRLGNBQWMsRUFBRSxXQUFXLE9BQU8sR0FBRyxJQUFJO0FBQUEsRUFBRTtBQUFBLEVBQzVELFlBQVksT0FBbUI7QUFBRSxVQUFNLEtBQVk7QUFBQSxFQUFFO0FBQ3pEO0FBSU8sSUFBTSxRQUFOLGNBQW9CLFNBQVNELE9BQU0sS0FBSyxFQUFFO0FBQUEsRUFDN0MsT0FBTztBQUFFLElBQUFDLFNBQVEsY0FBYyxFQUFFLFdBQVcsUUFBUSxHQUFHLElBQUk7QUFBQSxFQUFFO0FBQUEsRUFDN0QsWUFBWSxPQUFvQjtBQUFFLFVBQU0sS0FBWTtBQUFBLEVBQUU7QUFBQSxFQUM1QyxZQUFZLFVBQXVCO0FBQUUsU0FBSyxRQUFRLE9BQU8sUUFBUTtBQUFBLEVBQUU7QUFDakY7QUFJTyxJQUFNLFdBQU4sY0FBdUIsU0FBU0QsT0FBTSxRQUFRLEVBQUU7QUFBQSxFQUNuRCxPQUFPO0FBQUUsSUFBQUMsU0FBUSxjQUFjLEVBQUUsV0FBVyxXQUFXLEdBQUcsSUFBSTtBQUFBLEVBQUU7QUFBQSxFQUNoRSxZQUFZLE9BQXVCO0FBQUUsVUFBTSxLQUFZO0FBQUEsRUFBRTtBQUM3RDtBQU1PLElBQU0sYUFBTixjQUF5QixTQUFTRixLQUFJLFVBQVUsRUFBRTtBQUFBLEVBQ3JELE9BQU87QUFBRSxJQUFBRSxTQUFRLGNBQWMsRUFBRSxXQUFXLGFBQWEsR0FBRyxJQUFJO0FBQUEsRUFBRTtBQUFBLEVBQ2xFLFlBQVksT0FBeUIsT0FBdUI7QUFBRSxVQUFNLEVBQUUsT0FBTyxHQUFHLE1BQU0sQ0FBUTtBQUFBLEVBQUU7QUFDcEc7QUFHQSxPQUFPLGVBQWVELE9BQU0sUUFBUSxXQUFXLFlBQVk7QUFBQSxFQUN2RCxNQUFNO0FBQUUsV0FBTyxLQUFLLGFBQWE7QUFBQSxFQUFFO0FBQUEsRUFDbkMsSUFBSSxHQUFHO0FBQUUsU0FBSyxhQUFhLENBQUM7QUFBQSxFQUFFO0FBQ2xDLENBQUM7QUFHTSxJQUFNLFVBQU4sY0FBc0IsU0FBU0EsT0FBTSxPQUFPLEVBQUU7QUFBQSxFQUNqRCxPQUFPO0FBQUUsSUFBQUMsU0FBUSxjQUFjLEVBQUUsV0FBVyxVQUFVLEdBQUcsSUFBSTtBQUFBLEVBQUU7QUFBQSxFQUMvRCxZQUFZLFVBQXlCLFVBQWdDO0FBQUUsVUFBTSxFQUFFLFVBQVUsR0FBRyxNQUFNLENBQVE7QUFBQSxFQUFFO0FBQUEsRUFDbEcsWUFBWSxVQUF1QjtBQUN6QyxVQUFNLENBQUMsT0FBTyxHQUFHLFFBQVEsSUFBSSxPQUFPLFFBQVE7QUFDNUMsU0FBSyxVQUFVLEtBQUs7QUFDcEIsU0FBSyxhQUFhLFFBQVE7QUFBQSxFQUM5QjtBQUNKO0FBSU8sSUFBTSxXQUFOLGNBQXVCLFNBQVNGLEtBQUksUUFBUSxFQUFFO0FBQUEsRUFDakQsT0FBTztBQUFFLElBQUFFLFNBQVEsY0FBYyxFQUFFLFdBQVcsV0FBVyxHQUFHLElBQUk7QUFBQSxFQUFFO0FBQUEsRUFDaEUsWUFBWSxPQUF1QixPQUF1QjtBQUFFLFVBQU0sRUFBRSxPQUFPLEdBQUcsTUFBTSxDQUFRO0FBQUEsRUFBRTtBQUNsRztBQUlPLElBQU0sYUFBTixjQUF5QixTQUFTRCxPQUFNLFVBQVUsRUFBRTtBQUFBLEVBQ3ZELE9BQU87QUFBRSxJQUFBQyxTQUFRLGNBQWMsRUFBRSxXQUFXLGFBQWEsR0FBRyxJQUFJO0FBQUEsRUFBRTtBQUFBLEVBQ2xFLFlBQVksT0FBeUIsT0FBdUI7QUFBRSxVQUFNLEVBQUUsT0FBTyxHQUFHLE1BQU0sQ0FBUTtBQUFBLEVBQUU7QUFDcEc7QUFNTyxJQUFNLFNBQU4sY0FBcUIsU0FBU0QsT0FBTSxNQUFNLEVBQUU7QUFBQSxFQUMvQyxPQUFPO0FBQUUsSUFBQUMsU0FBUSxjQUFjLEVBQUUsV0FBVyxTQUFTLEdBQUcsSUFBSTtBQUFBLEVBQUU7QUFBQSxFQUM5RCxZQUFZLE9BQXFCO0FBQUUsVUFBTSxLQUFZO0FBQUEsRUFBRTtBQUMzRDtBQUlPLElBQU0sUUFBTixjQUFvQixTQUFTRCxPQUFNLEtBQUssRUFBRTtBQUFBLEVBQzdDLE9BQU87QUFBRSxJQUFBQyxTQUFRLGNBQWMsRUFBRSxXQUFXLFFBQVEsR0FBRyxJQUFJO0FBQUEsRUFBRTtBQUFBLEVBQzdELFlBQVksVUFBdUIsVUFBZ0M7QUFBRSxVQUFNLEVBQUUsVUFBVSxHQUFHLE1BQU0sQ0FBUTtBQUFBLEVBQUU7QUFBQSxFQUNoRyxZQUFZLFVBQXVCO0FBQUUsU0FBSyxhQUFhLE9BQU8sUUFBUSxDQUFDO0FBQUEsRUFBRTtBQUN2RjtBQUlPLElBQU0sU0FBTixjQUFxQixTQUFTRixLQUFJLE1BQU0sRUFBRTtBQUFBLEVBQzdDLE9BQU87QUFBRSxJQUFBRSxTQUFRLGNBQWMsRUFBRSxXQUFXLFNBQVMsR0FBRyxJQUFJO0FBQUEsRUFBRTtBQUFBLEVBQzlELFlBQVksT0FBcUI7QUFBRSxVQUFNLEtBQVk7QUFBQSxFQUFFO0FBQzNEO0FBSU8sSUFBTSxTQUFOLGNBQXFCLFNBQVNELE9BQU0sTUFBTSxFQUFFO0FBQUEsRUFDL0MsT0FBTztBQUFFLElBQUFDLFNBQVEsY0FBYyxFQUFFLFdBQVcsU0FBUyxHQUFHLElBQUk7QUFBQSxFQUFFO0FBQUEsRUFDOUQsWUFBWSxPQUFxQixPQUF1QjtBQUFFLFVBQU0sRUFBRSxPQUFPLEdBQUcsTUFBTSxDQUFRO0FBQUEsRUFBRTtBQUNoRzs7O0FDekxBOzs7QUNDQSxTQUFvQixXQUFYQyxnQkFBMEI7OztBQ0RuQyxPQUFPQyxZQUFXO0FBQ2xCLE9BQU8sU0FBUzs7O0FDRGhCLE9BQU9DLGNBQWE7QUFFcEIsU0FBb0IsV0FBWEMsZ0JBQXVCO0FBR2hDLElBQU0sT0FBTyxPQUFPLE1BQU07QUFDMUIsSUFBTSxPQUFPLE9BQU8sTUFBTTtBQUUxQixJQUFNLEVBQUUsV0FBVyxXQUFXLElBQUlDOzs7QUNIM0IsU0FBUyxTQUFTLEVBQUUsV0FBVyxDQUFDLEdBQUcsTUFBTSxHQUc3QztBQUNDLE1BQUksTUFBTyxVQUFTLEtBQUssS0FBSztBQUM5QixTQUFPLGNBQWMsUUFBUTtBQUNqQztBQUVPLFNBQVNDLEtBQ1osTUFDQSxPQUNGO0FBQ0UsU0FBTyxJQUFLLE9BQU8sTUFBYSxLQUFLO0FBQ3pDO0FBRUEsSUFBTSxRQUFRO0FBQUEsRUFDVixLQUFZO0FBQUEsRUFDWixRQUFlO0FBQUEsRUFDZixXQUFrQjtBQUFBLEVBQ2xCLGtCQUF5QjtBQUFBLEVBQ3pCLGFBQW9CO0FBQUEsRUFDcEIsT0FBYztBQUFBLEVBQ2QsVUFBaUI7QUFBQTtBQUFBO0FBQUEsRUFHakIsTUFBYTtBQUFBLEVBQ2IsT0FBYztBQUFBLEVBQ2QsVUFBaUI7QUFBQTtBQUFBLEVBRWpCLFlBQW1CO0FBQUEsRUFDbkIsU0FBZ0I7QUFBQSxFQUNoQixVQUFpQjtBQUFBLEVBQ2pCLFlBQW1CO0FBQUEsRUFDbkIsUUFBZTtBQUFBLEVBQ2YsT0FBYztBQUFBLEVBQ2QsUUFBZTtBQUFBLEVBQ2YsUUFBZTtBQUNuQjtBQWlDTyxJQUFNLE9BQU9BOzs7QUN6RXBCLElBQU0sT0FBTyxTQUFpQixDQUFDLEVBQUU7QUFBQSxFQUMvQjtBQUFBLEVBQ0E7QUFBQSxFQUNBLENBQUMsS0FBYSxTQUFpQixTQUFTLEdBQUc7QUFDN0M7QUFDQSxJQUFNLFNBQVMsU0FBaUIsQ0FBQyxFQUFFO0FBQUEsRUFDakM7QUFBQSxFQUNBO0FBQUEsRUFDQSxDQUFDLEtBQWEsU0FBaUIsU0FBUyxHQUFHO0FBQzdDO0FBQ0EsSUFBTSxLQUFLLFNBQWlCLENBQUMsRUFBRTtBQUFBLEVBQzdCO0FBQUEsRUFDQTtBQUFBLEVBQ0EsQ0FBQyxLQUFhLFNBQWlCLFNBQVMsR0FBRztBQUM3QztBQUNBLElBQU0sT0FBTyxTQUFpQixDQUFDLEVBQUU7QUFBQSxFQUMvQjtBQUFBLEVBQ0E7QUFBQSxFQUNBLENBQUMsS0FBYSxTQUFpQixTQUFTLEdBQUc7QUFDN0M7QUFFQSxJQUFNLFlBQVksQ0FBQyxNQUNqQixFQUFFLFNBQVMsRUFBRSxTQUFTLEtBQUssSUFBSSxFQUFFLFNBQVMsSUFBSSxNQUFNLEVBQUUsU0FBUztBQUVsRCxTQUFSLE9BQXdCO0FBQzdCLFNBQU8scUJBQUMsU0FBSSxVQUFRLE1BQUMsV0FBVSxxQkFDN0I7QUFBQSxvQkFBQUMsS0FBQyxXQUFNLFdBQVUsaUNBQWdDLE9BQU8sR0FBRyxTQUFTLEdBQUc7QUFBQSxJQUN2RSxnQkFBQUEsS0FBQyxXQUFNLFdBQVUsNEJBQTJCLE9BQU8sS0FBSyxTQUFTLEdBQUc7QUFBQSxJQUNwRSxnQkFBQUEsS0FBQyxXQUFNLFdBQVUsNEJBQTJCLE9BQU8sT0FBTyxTQUFTLEdBQUc7QUFBQSxJQUN0RSxnQkFBQUEsS0FBQyxXQUFNLFdBQVUsaUNBQWdDLE9BQU8sS0FBSyxTQUFTLEdBQUc7QUFBQSxLQUMzRTtBQUNGOzs7QUM5QkEsT0FBTyxtQkFBbUI7QUFFMUIsSUFBTSxXQUFXLGNBQWMsWUFBWTtBQUU1QixTQUFSLGFBQThCO0FBQ25DLFdBQVMsU0FBUyxNQUFnQixHQUFzQjtBQUN0RCxhQUFTLFNBQVMsYUFBYSxFQUFFLFVBQVUsSUFBSSxPQUFPLElBQUk7QUFBQSxFQUM1RDtBQUVBLFNBQU8sZ0JBQUFDLEtBQUMsY0FBUyxVQUFVLFVBQ3pCLDBCQUFBQSxLQUFDLFNBQUksVUFBUSxNQUFDLFdBQVUsc0JBQ3JCLFdBQUMsR0FBRyxNQUFNLEVBQUUsRUFBRSxLQUFLLENBQUMsRUFBRSxJQUFJLENBQUMsT0FBTyxnQkFBQUEsS0FBQyxhQUFVLElBQUksS0FBSyxHQUFHLENBQUUsR0FDOUQsR0FDRjtBQUNGO0FBTU8sU0FBUyxVQUFVLEVBQUUsR0FBRyxHQUFtQjtBQUNoRCxRQUFNLFlBQVksU0FBUyxPQUFPLENBQUMsS0FBSyxVQUFVLFlBQVksR0FBRyxLQUFLLFVBQVUsa0JBQWtCLENBQUMsR0FBRyxDQUFDLFlBQVksWUFBWTtBQUM3SCxVQUFNLGFBQXVCLENBQUMsYUFBYTtBQUMzQyxVQUFNLFlBQVksV0FBVyxLQUFLLENBQUMsTUFBTSxFQUFFLE9BQU8sRUFBRTtBQUVwRCxRQUFJLFdBQVc7QUFDYixVQUFJLFVBQVUsWUFBWSxFQUFFLFNBQVMsR0FBRztBQUN0QyxtQkFBVyxLQUFLLFlBQVk7QUFBQSxNQUM5QjtBQUVBLFVBQUksUUFBUSxPQUFPLElBQUk7QUFDckIsbUJBQVcsS0FBSyxXQUFXO0FBQUEsTUFDN0I7QUFBQSxJQUNGO0FBRUEsV0FBTyxXQUFXLEtBQUssR0FBRztBQUFBLEVBQzVCLENBQUM7QUFDRCxTQUFPLGdCQUFBQSxLQUFDLFlBQU8sV0FBVyxVQUFVLEdBQUcsU0FBUyxNQUFNLFNBQVMsU0FBUyxhQUFhLEdBQUcsRUFBRSxFQUFFLEdBQzFGLDBCQUFBQSxLQUFDLFdBQU0sT0FBTyxHQUFHLFNBQVMsR0FBRyxHQUMvQjtBQUNGOzs7QUN6Q0EsT0FBTyxrQkFBa0I7QUFFekIsSUFBTSxVQUFVLGFBQWEsWUFBWTtBQUUxQixTQUFSLFVBQTJCO0FBQ2hDLFFBQU0sT0FBTyxLQUFLLFNBQVMsVUFBVTtBQUNyQyxRQUFNLFVBQVUsS0FBSyxTQUFTLFlBQVk7QUFDMUMsUUFBTSxRQUFRLEtBQUssU0FBUyxPQUFPO0FBQ25DLFFBQU0sUUFBUSxTQUFTLE9BQU8sQ0FBQyxPQUFPLE9BQU8sR0FBRyxDQUFDQyxRQUFPQyxhQUFZO0FBQ2xFLFFBQUlELFdBQVUsYUFBYSxNQUFNLFlBQVlDLFdBQVU7QUFDckQsYUFBTztBQUNULFFBQUlBLFdBQVU7QUFDWixhQUFPO0FBQ1QsUUFBSUEsV0FBVTtBQUNaLGFBQU87QUFDVCxXQUFPO0FBQUEsRUFDVCxDQUFDO0FBQ0QsU0FBTyxnQkFBQUMsS0FBQyxTQUFJLFdBQVUsMEJBQXlCLFFBQVFDLEtBQUksTUFBTSxRQUMvRCwwQkFBQUQsS0FBQyxzQkFBaUIsUUFBUUMsS0FBSSxNQUFNLFFBQVEsUUFBUUEsS0FBSSxNQUFNLFFBQVEsT0FBTyxTQUFTLFNBQU8sTUFBQyxXQUFXLE1BQU0sQ0FBQyxNQUFNLGVBQWUsQ0FBQyxFQUFFLEdBQUcsU0FBUyxHQUFHLE9BQU8sR0FDNUosMEJBQUFELEtBQUMsVUFBSyxNQUFZLFdBQVUsZ0NBQStCLEdBQzdELEdBQ0Y7QUFDRjs7O0FDdEJBLE9BQU8sYUFBYTtBQUVwQixJQUFNLEtBQUssUUFBUSxZQUFZO0FBRWhCLFNBQVIsU0FBMEI7QUFDL0IsTUFBSSxDQUFDLEdBQUksUUFBTyxnQkFBQUUsS0FBQSxZQUFFO0FBRWxCLFFBQU0sRUFBRSxPQUFPLElBQUlDLEtBQUk7QUFFdkIsUUFBTSxVQUFVLEtBQUssR0FBRyxPQUFPLGlCQUFpQjtBQUNoRCxRQUFNLGdCQUFnQixRQUFRLEdBQUcsQ0FBQyxNQUFNLEVBQUUsU0FBUyxHQUFHO0FBQ3RELFFBQU0sY0FBYyxRQUFRLEdBQUcsQ0FBQyxNQUFNLEVBQUUsUUFBUSxFQUFFLEtBQUssU0FBUyxLQUFLLEVBQUUsU0FBUyx3QkFBd0IsRUFBRSxPQUFPLHlCQUF5QjtBQUUxSSxRQUFNLE1BQU0sS0FBSyxHQUFHLE9BQU8sb0JBQW9CO0FBQy9DLFFBQU0sWUFBWSxJQUFJLEdBQUcsQ0FBQyxNQUFNLEVBQUUsU0FBUyxHQUFHO0FBQzlDLFFBQU0sVUFBVSxJQUFJLEdBQUcsQ0FBQyxNQUFNLEVBQUUsUUFBUSxFQUFFLEtBQUssU0FBUyxLQUFLLEVBQUUsU0FBUyx3QkFBd0IsRUFBRSxPQUFPLGlDQUFpQztBQUUxSSxTQUFPLHFCQUFDLFNBQUksVUFBUSxNQUFDLFdBQVUsMEJBQXlCLFFBQVFBLEtBQUksTUFBTSxRQUN4RTtBQUFBLG9CQUFBRCxLQUFDLHNCQUFpQixRQUFRLFFBQVEsUUFBUSxRQUFRLE9BQU8sZUFBZSxTQUFPLE1BQUMsV0FBVSxlQUFjLFNBQVMsR0FBRyxPQUFPLEdBQ3pILDBCQUFBQSxLQUFDLFVBQUssTUFBTSxhQUFhLFdBQVUsZ0NBQStCLEdBQ3BFO0FBQUEsSUFDQSxnQkFBQUEsS0FBQyxzQkFBaUIsUUFBUSxRQUFRLFFBQVEsUUFBUSxPQUFPLFdBQVcsU0FBTyxNQUFDLFdBQVUsb0JBQW1CLFNBQVMsR0FBRyxPQUFPLEdBQzFILDBCQUFBQSxLQUFDLFVBQUssTUFBTSxTQUFTLFdBQVUsZ0NBQStCLEdBQ2hFO0FBQUEsS0FDRjtBQUNGOzs7QUN6QkEsT0FBTyxlQUFlO0FBRXRCLElBQU0sT0FBTyxVQUFVLFlBQVk7QUFDNUIsSUFBTSxnQkFBZ0IsU0FBUyxLQUFLO0FBRTVCLFNBQVIsT0FBd0I7QUFDN0IsUUFBTSxFQUFFLE9BQU8sSUFBSUUsS0FBSTtBQUV2QixPQUFLLE1BQU0sT0FBTyxFQUFFLEdBQUcsT0FBSztBQUMxQixrQkFBYyxJQUFJLEVBQUUsVUFBVSxDQUFDO0FBQUEsRUFDakMsQ0FBQztBQUVELFNBQU8sZ0JBQUFDLEtBQUMsU0FBSSxVQUFRLE1BQUMsUUFBUSxRQUFRLFFBQVEsUUFBUSxXQUFVLDJCQUM1RCxlQUFLLE1BQU0sT0FBTyxFQUFFLEdBQUcsV0FBUyxNQUFNLElBQUksVUFDekMsZ0JBQUFBO0FBQUEsSUFBQztBQUFBO0FBQUEsTUFDQyxXQUFVO0FBQUEsTUFDVixlQUFlLEtBQUssTUFBTSxlQUFlO0FBQUEsTUFDekMsWUFBWTtBQUFBLE1BQ1osV0FBVyxLQUFLLE1BQU0sWUFBWTtBQUFBLE1BQ2xDLDBCQUFBQSxLQUFDLFVBQUssT0FBTyxLQUFLLE1BQU0sT0FBTyxHQUFHO0FBQUE7QUFBQSxFQUNwQyxDQUNELENBQUMsR0FDSjtBQUNGOzs7QUNsQmUsU0FBUixRQUF5QixTQUFzQjtBQUNwRCxRQUFNLEVBQUUsS0FBSyxNQUFNLE9BQU8sSUFBSUMsT0FBTTtBQUNwQyxRQUFNLEVBQUUsS0FBSyxPQUFPLElBQUlDLEtBQUk7QUFFNUIsU0FBTyxnQkFBQUM7QUFBQSxJQUFDO0FBQUE7QUFBQSxNQUNOLFdBQVU7QUFBQSxNQUNWLFlBQVk7QUFBQSxNQUNaLGFBQWFGLE9BQU0sWUFBWTtBQUFBLE1BQy9CLFFBQVEsTUFBTSxPQUFPO0FBQUEsTUFDckIsT0FBT0EsT0FBTSxNQUFNO0FBQUEsTUFDbkIsYUFBYTtBQUFBLE1BRWIsK0JBQUMsZUFBVSxXQUFVLGNBQWEsVUFBUSxNQUFDLFNBQU8sTUFDaEQ7QUFBQSw2QkFBQyxTQUFJLFVBQVEsTUFDWDtBQUFBLDBCQUFBRSxLQUFDLFFBQUs7QUFBQSxVQUNOLGdCQUFBQSxLQUFDLFdBQVE7QUFBQSxVQUNULGdCQUFBQSxLQUFDLFVBQU87QUFBQSxXQUNWO0FBQUEsUUFDQSxnQkFBQUEsS0FBQyxjQUFXO0FBQUEsUUFDWixnQkFBQUEsS0FBQyxTQUFJLFVBQVEsTUFBQyxRQUFRLEtBQ3BCLDBCQUFBQSxLQUFDLFFBQUssR0FDUjtBQUFBLFNBQ0Y7QUFBQTtBQUFBLEVBQ0Y7QUFFRjs7O0FDNUJBLFlBQUksTUFBTTtBQUFBLEVBQ1IsS0FBSztBQUFBLEVBQ0wsT0FBTztBQUNMLGdCQUFJLGFBQWEsRUFBRSxJQUFJLE9BQU87QUFBQSxFQUNoQztBQUNGLENBQUM7IiwKICAibmFtZXMiOiBbIkFzdGFsIiwgIkd0ayIsICJBc3RhbCIsICJiaW5kIiwgImludGVydmFsIiwgIkFzdGFsIiwgIkFzdGFsIiwgIkFzdGFsIiwgInRyYW5zZm9ybSIsICJ2IiwgImludGVydmFsIiwgImN0b3JzIiwgIkFzdGFsIiwgIkFzdGFsIiwgIkd0ayIsICJBc3RhbCIsICJzbmFrZWlmeSIsICJwYXRjaCIsICJXb3Jrc3BhY2UiLCAiR09iamVjdCIsICJHdGsiLCAiQXN0YWwiLCAiQXN0YWwiLCAiR3RrIiwgIkdPYmplY3QiLCAiR3RrIiwgIkFzdGFsIiwgIkdPYmplY3QiLCAiZGVmYXVsdCIsICJBc3RhbCIsICJHT2JqZWN0IiwgImRlZmF1bHQiLCAiR09iamVjdCIsICJqc3giLCAianN4IiwgImpzeCIsICJzdGF0ZSIsICJwZXJjZW50IiwgImpzeCIsICJHdGsiLCAianN4IiwgIkd0ayIsICJHdGsiLCAianN4IiwgIkFzdGFsIiwgIkd0ayIsICJqc3giXQp9Cg==
