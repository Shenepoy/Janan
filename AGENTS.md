# Agent instructions

## PolyScreen emulator interaction

For emulator/device UI interaction and validation, use `polyscreen-mcp` according
to the inherited `Projects/AGENTS.md` rule:

- Discover the exact device with `mobile_devices_list` and the logical display
  with `mobile_displays_list`; pass that display ID to launch, UI, input, and
  capture operations.
- Prefer semantic PolyScreen UI tools: `mobile_app_launch`,
  `mobile_ui_find`/`mobile_ui_wait`, `mobile_input_tap`, `mobile_input_swipe`,
  `mobile_input_text`, and `mobile_screen_capture`.
- Use raw `adb` for build/install, diagnostics, or unsupported capabilities. If
  ADB performs UI interaction, record the fallback in validation notes.
