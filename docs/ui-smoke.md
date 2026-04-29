# UI Smoke Harness

Run the lightweight UI smoke harness after changing popover wiring:

```sh
cd menubar
make ui-smoke
```

The harness builds the Release app, launches it in a test-only smoke window, seeds an isolated fixture index, verifies a real search result appears, verifies index status text is visible, and verifies punctuation-only search shows no results.

This is intended for local/manual QA. It uses macOS System Events, so the invoking terminal needs Accessibility permission in System Settings.
