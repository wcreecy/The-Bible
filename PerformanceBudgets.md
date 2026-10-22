# Performance budgets

These are release targets measured on a representative, real device with a release build. They are guardrails for user-perceived responsiveness, not averages from a simulator.

| Interaction | Budget | Start | Complete |
|---|---:|---|---|
| Interactive cold launch | Under 1.5 seconds | Tapping the app icon | The Home screen can receive input |
| Navigation | Under 250 milliseconds | A person taps a destination, or an in-app route is requested | The destination's primary content is visible and interactive |
| Search first result | Under 300 milliseconds | The existing typing debounce finishes | The first matching result, empty state, or direct-reference result is visible |

## How to use these budgets

- Use the `Performance` signposts in Instruments for release-build measurements.
- Run each scenario at least five times after a fresh install and record the median and slowest result. Investigate any median that misses its budget.
- Measure the same device class and OS version when comparing releases. Simulators are useful for regressions, but do not decide release readiness.
- `SearchFirstResult` deliberately excludes the 300 millisecond typing debounce. It represents search work, rather than the pause that prevents a query on every keystroke.

The `SearchFirstResult` signpost emits a debug warning if a lookup exceeds its budget. Launch and navigation stay as manual release checks because their true completion is visual and device-dependent; Xcode's application-launch and navigation metrics provide the appropriate end-to-end measurement.
