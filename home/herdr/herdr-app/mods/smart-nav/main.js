// smart-splits for Herdr: ctrl-hjkl (keys.json) go to Neovim, which calls pane.go at its edge
// (at_edge in smart-splits.nvim); elsewhere they move between panes.
// Lives in a 0px block of the layout: <mod>.<command> reaches shown copies only.
import { View, div } from "gpui-kit";
import { focused, panes, run, hc, nextCommand } from "herdr";

const NAV = { left: "ctrl+h", down: "ctrl+j", up: "ctrl+k", right: "ctrl+l" };

export default class SmartNav extends View {
  init(_props, cx) {
    cx.spawn(async (cx) => {
      for (;;) {
        const c = await nextCommand();
        if (!NAV[c]) continue;
        const f = focused();
        if (panes().find(p => p.terminal && p.terminal === f?.terminal)?.program.key === "nvim") hc(["keys", f.terminal, NAV[c]]).catch(() => null);
        else run("pane.go", { direction: c });
      }
    });
  }

  render() { return div(); }
}
