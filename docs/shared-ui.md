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
