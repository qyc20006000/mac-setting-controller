# Project: MacOS Settings Controller (macOS Menu Bar)

This project is a lightweight macOS app that enables controls on some system settings from the menu bar, such as switch default browser using drop down selection from menu bar at ease.

## Tech Spec

- UI: SwiftUI
- Backend: Swift
- Communication: macOS native APIs
- Persistence: UserDefaults

## Strategy

1. Write plan with success criteria for each phase to be checked off. Include project scaffolding, including .gitignore, and rigorous unit testing.
2. Execute the plan ensuring all critiera are met
3. Carry out extensive integration testing with Playwright or similar, fixing defects
4. Only complete when the MVP is finished and tested, with the server running and ready for the user

## Coding Guidelines & Agent Context

- Use latest versions of libraries and idiomatic approaches as of today
- **Keep it simple** NEVER over-engineer, ALWAYS simplify, NO unnecessary defensive programming. No extra features - focus on simplicity.
- **Be concise** Keep README minimal. IMPORTANT: no emojis ever
- **Keep it Self-Contained:** Avoid introducing heavy dependencies; utilize python standard libraries where possible.
- **Local Time Awareness:** The current user context is set in macOS. When working on time offsets (e.g. countdown formatting), ensure standard local timezone offsets are accurately tracked.
