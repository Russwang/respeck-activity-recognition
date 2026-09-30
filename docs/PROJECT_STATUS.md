# Validation and remaining gaps

Review date: 30 September 2026. This revision prepares the existing course project for a public engineering portfolio; historical evaluation reports are preserved.

## Changes

- Selected the saved six-channel physical/signal models and their accompanying ordered label mappings; synchronized Dart and Python preprocessing.
- Added model manifests with hashes and runtime tensor/type validation.
- Separated stable class identities from changing confidence text.
- Replaced history timing with millisecond accumulation, midnight splitting, uncertain-result exclusion and gap/session handling. Preserved legacy stored data separately.
- Guarded missing BLE devices, malformed packets and disconnected recording; clear buffers between sessions.
- Added model disposal, mounted checks, QR-cancel handling and storage error handling.
- Replaced machine-specific Python dependencies with a maintained pinned list; added training CLI, missing-data errors, export manifests and output-overwrite protection.
- Replaced the irrelevant counter test with targeted regression tests; added CI checks and an Android debug-build job.
- Excluded participant CSVs, build/cache directories, local environment paths, original local backups and signing material from publication.
- Added English portfolio documentation, Chinese source guide and course attribution/scope notes.

## Local checks

| Check | Result |
| --- | --- |
| Flutter 3.35.5 / Dart 3.9.2 static analysis | PASS: no issues |
| Flutter unit/widget tests | PASS: 9 tests |
| Python preprocessing/loader tests | PASS: 4 tests |
| Bundled model checks | PASS: SHA-256, labels, float32 tensors and two synthetic inference windows for each model |
| Synthetic training pipeline | PASS: both scripts completed 2-fold evaluation, final training and TFLite/manifest export on generated data |
| Android debug APK build | BLOCKED: configured local Android SDK directory does not exist |
| Live BLE sensor / Android device session | Not performed |
| Full-data training or historical accuracy reproduction | Not performed: original dataset missing |

Synthetic windows establish that preprocessing and model execution work. They do not measure human activity recognition accuracy. The existing local `build/` folder contains an old November 2025 APK; it is not a validated APK of this revision and is excluded from Git.

CI configuration is included; GitHub Actions results must be checked separately from these local checks.

## Missing files or evidence

1. **Original training recordings:** expected `RESpeckData_Updated/daily_activity/` and `RESpeckData_Updated/social_signal/`, or equivalent class-organized CSVs. Needed for retraining and independent accuracy evaluation; do not publish participant data without appropriate permission.
2. **Data preparation history:** cleaning, class merging and assignment of recordings to each class, including how six course social signals became the four-class task.
3. **Original final report, demo slides/video and training-run logs:** needed to establish exact individual/team contributions, model lineage and the report-to-binary relationship. The course outline supplies context but cannot substitute for these artifacts.
4. **Upstream scaffold source/license:** the supplied course app's origin is acknowledged, but its original repository URL and license were not in the folder.
5. **Android SDK and test hardware:** needed to build locally and validate the revised app on a phone with RESpeck. Configure a real SDK path instead of the stale `android/local.properties` value.
6. **Device performance evidence:** no verified latency, battery, CPU, RAM measurements or screenshots of the revised app. No such claims are made.

## Remaining limitations

- Models cover 11 physical classes and four signal classes, not the full course label set. Sitting and standing are merged; talking/singing/laughing/eating are not separately recognized.
- Signal inference currently runs regardless of physical posture.
- Cross-validation groups recordings, not participants. Internal signal-model validation also uses a window-level split.
- Inference runs synchronously in the BLE callback; a background isolate and device profiling would be useful follow-up work.
- Reconnection is manual; Android BLE permissions, packet timing and long recording sessions need hardware testing.
- History is a best-effort estimate of observed intervals, not a clinical measurement or a continuous background tracker.
- The course-provided scaffold and third-party dependencies have not been relicensed by this repository.
