# Shared UI ownership

Janan uses the published Safaeh and Edadat packages. Local path overrides are
development tools and are not part of a release dependency resolution.

| Behavior | Owner |
| --- | --- |
| Native camera bounds and orientation freshness | Safaeh `SafaehDeviceCutoutScope` |
| Camera exclusion bands and floating-control placement | Safaeh `SafaehDisplayCutoutLayout` and `SafaehCutoutAwareFabLocation` |
| Navigation rail geometry, edge attachment, and camera avoidance | Safaeh sidenav |
| Anchored modal placement and moving trigger tracking | Safaeh anchored popout |
| Wide sheet horizontal safe-area handling | Safaeh adaptive sheet |
| Animated cycle action | Safaeh `SafaehCycleButton` |
| Section expansion and latest-request navigation coordination | Edadat `SettingsSectionNavigation` |
| Measurable bounded section catalog | Edadat `SettingsSectionList` |
| Chart types, datasets, filters, persistence, and excluding duplicate charts | Janan |
| Top chrome clearance, compact landscape rules, and app destinations | Janan |
| Floating editor save bar for reminders, medicines, and readings | Janan `FormBottomAction` |

The shell wraps its content in the cutout scope. Janan supplies its navigation
and app-bar clearances to floating controls rather than hard-coding these
dimensions into the package. Domain records and chart calculations stay here.

Settings marks section layout changes before navigation, holds the requested
index selection while the coordinator is navigating, and resumes its scroll
spy when navigation settles. Manual list dragging cancels pending navigation.
The eager section list is for a bounded settings catalog, not an unbounded
measurement list.

Package tests exercise the shared interfaces. Janan's Home, Settings, shell,
and sheet-helper tests verify the application integration, including rotation,
camera placement, chart uniqueness, and rapid section selection.

Medicine and measurement entry use full editor pages with a titled top app bar,
a back button, and the same floating save action as reminder entry. The save bar
stays above the keyboard; scrolling forms reserve its clearance, including the
bottom safe area. These editor headers remain at the top regardless of the
legacy bottom-app-bar setting. Medicine pickers and Bluetooth import still use
the existing form controls. Reading edits retain their discard confirmation.

The editor update passed 793 tests and all seven golden checks. Layout tests
cover medicine and blood-pressure forms in English/Arabic, portrait/landscape,
with 1.5× text and keyboard insets. The debug build was installed and both pages
were reviewed using PolyScreen on `emulator-5554`, logical display `0`.

Medicine and note editors offer an inline color palette with accessible names,
48 dp touch targets and a selection ring. The label, choices, and More colors
action share one row, adapting the number of choices to the available width
and retaining saved custom colors. More colors opens the
shared Safaeh palette; notes also offer No color. Other settings retain the
compact list-tile picker. English and Arabic color names are included.

The color selector update passed 795 tests and seven golden checks, with no new
analyzer findings. PolyScreen validation on `emulator-5554`, display `0`, covered
medicine and reading forms, immediate preview updates, clearing note colors,
and opening/dismissing the full palette. No raw ADB UI fallback was used.

The single-row refinement passed 28 focused selector and editor tests, including
English/Arabic portrait and landscape layouts with enlarged text and keyboard
insets.
