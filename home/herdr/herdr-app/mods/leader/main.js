// WezTerm-style leader (cmd-a in keys.json): the next key runs a binding from TABLES.
// A `mode` binding switches to a sticky table (WezTerm's one_shot = false key tables),
// which stays until escape / enter. Inspired by SimonBystromTableCheck/herdr-mods leader.
import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { props, closeOverlay, theme, run, settings, spaces } from "herdr";

const TIMEOUT = 5000;
const MODIFIERS = new Set(["shift", "control", "alt", "platform", "function", "capslock", "cmd", "ctrl"]);

// Moves the shown tab by d places, clamped to its space.
const moveTab = (d) => () => {
  const tabs = spaces().find(s => s.active)?.tabs ?? [];
  const tab = tabs.find(t => t.active);
  return tab && { id: tab.id, index: Math.min(tabs.length, Math.max(1, tab.index + d)) };
};

const dirs = (label, run, args) => [["h", "left"], ["j", "down"], ["k", "up"], ["l", "right"]].flatMap(([k, d]) => [
  { key: k, label: `${label} ${d}`, run, args: args(d) },
  { key: d, run, args: args(d), hidden: true },
]);

const TABLES = {
  leader: { title: "cmd-a", bindings: [
    { key: "t", label: "New tab", run: "tab.new" },
    { key: "[", label: "Previous tab", run: "tab.prev" },
    { key: "]", label: "Next tab", run: "tab.next" },
    { key: "r", label: "Rename tab", run: "tab.rename" },
    { key: "n", label: "Find tab", run: "mod.open", args: { name: "picker" } },
    ...[1, 2, 3, 4, 5, 6, 7, 8, 9].map(i => ({ key: String(i), label: "Go to tab 1-9", run: "tab.select", args: { index: i }, hidden: i > 1 })),
    { key: "-", label: "Split down", run: "pane.split", args: { direction: "down" } },
    { key: "\\", label: "Split right", run: "pane.split", args: { direction: "right" } },
    { key: "z", label: "Zoom pane", run: "pane.zoom" },
    { key: "w", label: "Find space", run: "mod.open", args: { name: "picker" } },
    { key: "W", label: "New space", run: "space.new" },
    { key: "p", label: "Pane mode…", mode: "pane" },
    { key: "m", label: "Move tab mode…", mode: "move" },
  ] },
  pane: { title: "pane", bindings: [
    ...dirs("Go", "pane.go", d => ({ direction: d })),
    ...dirs("Swap", "pane.swap", d => ({ direction: d })).map(b => ({ ...b, key: b.key.length > 1 ? `shift-${b.key}` : b.key.toUpperCase() })),
    { key: "-", label: "Split down", run: "pane.split", args: { direction: "down" } },
    { key: "\\", label: "Split right", run: "pane.split", args: { direction: "right" } },
    { key: "z", label: "Zoom pane", run: "pane.zoom" },
    { key: "q", label: "Close pane", run: "pane.close" },
  ] },
  move: { title: "move tab", bindings: [
    { key: "h", label: "Move left", run: "tab.move", args: moveTab(-1) },
    { key: "l", label: "Move right", run: "tab.move", args: moveTab(1) },
    ...["left", "j", "down"].map(key => ({ key, run: "tab.move", args: moveTab(-1), hidden: true })),
    ...["right", "k", "up"].map(key => ({ key, run: "tab.move", args: moveTab(1), hidden: true })),
  ] },
};

// "ctrl-h" / "shift-left" with modifiers, else the typed character ("W", "\\") or the key name.
function keyOf(e) {
  const m = e.modifiers ?? {};
  if (m.control || m.platform || m.alt) return e.keystroke;
  if (["enter", "escape", "tab", "space", "up", "down", "left", "right", "backspace"].includes(e.key)) return e.keystroke;
  return e.key_char ?? e.key;
}

export default class Leader extends View {
  init(_props, cx) {
    this.mode = "leader";
    this.handle = cx.focus_handle();
    this.grab(cx);
    this.timeout = cx.timer.after(TIMEOUT, () => this.close());
  }

  // The popup takes the keyboard a moment after it opens, and a command can take it away.
  grab(cx) {
    this.handle.focus();
    cx.timer.after(30, () => this.handle.focus());
    cx.timer.after(250, () => this.handle.focus());
  }

  close() { closeOverlay(props().overlay); }

  press(k, cx) {
    const sticky = this.mode !== "leader";
    if (k === "escape" || k === "cmd-a" || (sticky && k === "enter")) return this.close();
    const b = TABLES[this.mode].bindings.find(x => x.key === k);
    if (!b) { this.miss = k; return cx.notify(); }
    this.miss = null;
    if (b.mode) {
      this.timeout.cancel();
      this.mode = b.mode;
      return cx.notify();
    }
    const args = typeof b.args === "function" ? b.args() : (b.args ?? {});
    if (!args) return;
    if (!sticky) this.close();
    run(b.run, args);
    if (sticky) { this.grab(cx); cx.notify(); }
  }

  render() {
    const t = theme(), mono = settings().font_family ?? "JetBrains Mono";
    const table = TABLES[this.mode], sticky = this.mode !== "leader";
    return v_flex().id("leader").size_full().p(14).gap(10).bg(t.popover).text_color(t.foreground).text_size(12.5)
      .track_focus(this.handle)
      .on_key_down((e, cx) => { if (MODIFIERS.has(e.key)) return; cx.stop_propagation(); this.press(keyOf(e), cx); })
      .child(h_flex().gap(8).items_center()
        .child(div().px(6).py(1).rounded(5).bg(t.accent).text_color(t.accent_foreground).font_family(mono).text_size(11.5).child(table.title))
        .child(div().flex_1().text_color(this.miss ? t.ansi1 : t.dim).child(this.miss ? `Nothing on "${this.miss}"` : sticky ? "Sticky mode" : "Press a key"))
        .child(div().text_size(11).text_color(t.dim).child(sticky ? "esc / enter exit" : "esc cancel")))
      .child(h_flex().flex_wrap().gap_y(3).children(table.bindings.filter(b => !b.hidden).map(b => h_flex().w(176).gap(8).items_center()
        .child(div().w(52).flex_none().font_family(mono).text_color(t.accent).child(b.key === "1" ? "1-9" : b.key))
        .child(div().flex_1().min_w(0).truncate().child(b.label)))));
  }
}
