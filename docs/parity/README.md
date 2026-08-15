# Parity Evidence Harness

This folder contains documentation and tests for verifying that the Flutter application strictly matches the visual specifications of the Capacitor reference implementation (`avdelag1/swipess`).

## Golden Tests
We use [golden_toolkit](https://pub.dev/packages/golden_toolkit) to run deterministic visual regressions tests against our key screens (Access Gate, Welcome, Auth, Dashboard, and Swipe Deck).

The tests run on two distinct sizes:
- `mobile` (390x844)
- `desktop` (1440x900)

Animations are disabled during the test run, and network images are intercepted and replaced with a transparent mock by `network_image_mock`.

### Generating / Updating Baselines
If you need to update the goldens after making a legitimate visual change to match Capacitor, run:

```bash
flutter test test/parity/parity_harness_test.dart --update-goldens
```

### Reviewing Baselines
The generated PNG files are stored in `test/parity/goldens/`. You should manually review these files to ensure they perfectly match the Capacitor reference.

## Capacitor Reference
The reference repository is cloned at `/tmp/swipess`. 
**Commit Hash**: `acaa2965889e99395aaa816ab64eb7f359a0fbed`

> **Note**: Automated Capacitor screenshots are currently blocked. The isolated test environment running this harness lacks `npm`, meaning we cannot programmatically build, serve, and snapshot the Capacitor web app. Instead, compare the Flutter goldens against manual captures or the live production web app.
