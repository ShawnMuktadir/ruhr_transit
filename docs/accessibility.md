# Accessibility

## Checked automatically

`test/accessibility/accessibility_test.dart` pumps every screen on a
phone-sized display, in light and dark, at normal and 200 % font size, and
checks:

- no layout overflow (an overflow fails the test),
- tap targets of at least 48 × 48 dp (`androidTapTargetGuideline`),
- a label on everything tappable (`labeledTapTargetGuideline`),
- text contrast to WCAG AA (`textContrastGuideline`).

Screens: start screen with and without favourites, departure board (live and
outdated), nearby stops (approximate location, permission denied for good),
trip form, trip results, journey details. Add new screens to the map at the
top of the test.

Behaviour that the guidelines cannot see has its own widget tests:

- a favourite can be removed with a TalkBack action, not only by swiping;
- the undo snack bar does not time out;
- "Not updated – departures as of …" is a live region, so TalkBack announces
  it;
- departure rows and trip cards are read as one sentence each, in a fixed
  order ("Train RE16, Essen Hauptbahnhof, 17:13, 12 min late, Platform 3");
- departure rows stack line and time above the destination from 1.5× text.

## Before a release, by hand

The home-screen widget is native and not covered by Flutter tests.

```sh
# Largest font size, then check every screen and the widget
adb shell settings put system font_scale 2.0
adb shell settings put system font_scale 1.0   # back to normal

# What TalkBack would read on the current screen (Git Bash: set
# MSYS_NO_PATHCONV=1 first)
adb shell uiautomator dump /sdcard/ui.xml && adb shell cat /sdcard/ui.xml
```

Then, on a real phone with TalkBack on: open a board, remove a favourite
through the actions menu and undo it, plan a trip and open its details.

## Known limits

- The legally required VRR attribution stays visible at the bottom of every
  screen; at 200 % font size it takes four lines.
- The widget reads its rows field by field; RemoteViews rows are not grouped
  for TalkBack.
- Delays are shown in red **and** with a "+" sign, so they do not rely on
  colour alone; there is no further colour-blindness check.
