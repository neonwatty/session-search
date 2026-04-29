# Manual QA Checklist

Use this after installing a local build with `cd menubar && make install`.

## Search

- Open the menu bar popover and confirm the search field is focused.
- Search for a single known term and confirm matching snippets are highlighted.
- Search for two non-adjacent terms from a known session and confirm results still appear.
- Enter only punctuation such as `* | ()` and confirm the app shows no results without an error.

## Filters

- Use the project menu to narrow results to one project.
- Use each date filter: Any time, Past day, Past week, Past month.
- Rebuild the index and confirm filters still show valid project choices.

## Resume Commands

- Add `--model opus` as an enabled flag preset.
- Confirm the command preview shows `--model opus`.
- Single-click a result and confirm the copied command includes active flags.
- Double-click a result and confirm the selected terminal opens the resumed Claude session.

## Index State

- Confirm the footer shows when the index was last refreshed.
- Open Settings and confirm project/session counts plus last-indexed time update after Rebuild.
- Temporarily move or empty a test Claude projects directory, rebuild, and confirm stale results disappear.

## Terminal Errors

- Select a terminal app that is not available or deny Automation permission.
- Double-click a result and confirm a visible launch error appears in the popover.
