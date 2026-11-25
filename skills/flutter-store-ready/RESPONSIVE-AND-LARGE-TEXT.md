# Responsive layouts and large text

People set their phone's font size to 200% (Android 14+) or the largest iOS accessibility sizes (~310%). The app must show **bigger text** and **no broken pages**.

Reference: `templates/starter_app/lib/core/responsive/`, `lib/app.dart`, `test/responsive_test.dart`, `test/large_text_test.dart`.

## How the app must behave

| Situation | Behavior |
|---|---|
| System font 200% | body text renders 2× (`MediaQuery.textScalerOf(context).scale(14) / 14 == 2`) |
| iOS largest accessibility size | up to 3× (cap at 3, never lower than 2) |
| In-app "Text size" setting | multiplied with the system size (keeps Android's nonlinear curve) |
| Large text on a tablet | layout decided by width ÷ text scale: 2× text on 1024 dp → phone layout (list instead of grid, bottom bar instead of rail) |
| Navigation bars, app bar title | capped at ~1.3× like Material/iOS; labels available via tooltip / long press |
| Card heights | grow with text: `textScaler.scale(100) + 48` |
| Forms, error/empty states, dialogs | scrollable; dialogs `scrollable: true` |

```dart
// app.dart — MaterialApp.builder
final media = MediaQuery.of(context);
return MediaQuery(
  data: media.copyWith(textScaler: TextScaling.combine(media.textScaler, settings.textScale)), // ×app factor, clamp(max: 3)
  child: child!,
);

// breakpoints.dart
static WindowSize of(BuildContext c) =>
    fromWidth(MediaQuery.sizeOf(c).width / max(1, TextScaling.factorOf(c))); // <600 compact, <840 medium, else expanded
```

Use `scale(14) / 14` for the effective factor — `textScaleFactor` is deprecated and wrong with nonlinear scaling.

## Rules for every screen

1. No fixed height around text. If a height is needed, compute it from `textScaler.scale(x)`.
2. Everything that can overflow scrolls (forms with keyboard open, landscape phones, error/empty views).
3. Text in a `Row` is wrapped in `Expanded`/`Flexible`; single-line text uses `maxLines` + `TextOverflow.ellipsis`.
4. Groups of chips/buttons use `Wrap`, not `Row`.
   - A title with an action next to it ("Inventory" + "Add" button): use `Wrap`, or put the button under the title. In a `Row` the button wins and the title wraps letter by letter at large text.
   - Never make buttons full-width in the **theme** (`minimumSize: Size.fromHeight(48)` or `Size(double.infinity, 48)`): every button inside a `Row` then takes the whole row. Keep the theme at `Size(64, 48)` and widen a button where it is used.
   - Short labels that must stay on one line (tab names, an amount or badge at the end of a row): `FittedBox(fit: BoxFit.scaleDown)` so they shrink instead of overflowing; the main text gets the `Expanded`.
5. Content width capped (720 dp reading, 440 dp forms) and centered (`ResponsiveCenter`).
6. `SafeArea`; `windowSoftInputMode=adjustResize`; keyboard dismiss on drag.
7. Tap targets ≥ 48 dp, tooltips on icon buttons, `Semantics(liveRegion: true)` for errors, colors from `colorScheme.onX`, light and dark themes.
8. Never `TextScaler.noScaling`, never `textScaleFactor: 1`, never cap below 2×.

## Tests (required)

```dart
const sizes = {Size(320, 568), Size(390, 844), Size(844, 390), Size(673, 841), Size(1024, 1366)};
const textScales = [1.0, 1.5, 2.0, 3.0];
// for each size × scale × locale: pump the app, visit every screen,
// expect(tester.takeException(), isNull);   // RenderFlex overflow fails the test
```

Also assert that text really grows: `tester.renderObject<RenderParagraph>(find.text(...)).textScaler.scale(14) / 14 ≈ 2` at 200%, and run once with `FakeAccessibilityFeatures(boldText: true)` at 3× on 320×568.

## Manual check on a device

- Android: Settings → Display → Font size and style → largest; also Display size → largest.
- iOS: Settings → Accessibility → Display & Text Size → Larger Text → enable Larger Accessibility Sizes → slider to max; try Bold Text.
- Every screen in portrait, landscape, with keyboard open, dark mode.
