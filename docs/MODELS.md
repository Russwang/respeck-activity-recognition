# Model contract and provenance

## Deployed contract

Both models take one `float32 [1, 120, 6]` window:

```text
[normalized_x, normalized_y, normalized_z, mean_x, mean_y, mean_z]
normalized_axis = (sample_axis - window_mean_axis) / (population_std_axis + 1e-6)
```

Means are repeated at every timestep. Dart `meanFeatures` and Python `window_features` implement this contract and have matching arithmetic test cases. Tensor shapes were inspected from the actual TFLite files and checked with TensorFlow Lite CPU inference.

| App asset | Source artifact | Output |
| --- | --- | --- |
| `assets/physical.tflite` | `results_physical_cnn_v2/model-physical.tflite` | `[1, 11]` |
| `assets/social.tflite` | `results_social_cnn_v3/model-social-cnn.tflite` | `[1, 4]` |

Adjacent `physical.json` and `social.json` contain ordered labels, preprocessing name, dimensions and SHA-256. The app validates tensor shapes and types at initialization; `scripts/verify_models.py` additionally checks hashes and historical label mappings.

Physical label order: `ascending`, `descending`, `lyingBack`, `lyingLeft`, `lyingRight`, `lyingStomach`, `miscMovement`, `normalWalking`, `running`, `shuffleWalking`, `sittingStanding`.

Signal label order: `breathingNormally`, `coughing`, `hyperventilation`, `other`.

## Why deployment changed

The old app loaded a `[1,120,3]` physical model and `[1,80,3]` signal model. Their original training sources and label manifests were unavailable; their hashes differed from the saved result models. The old physical hardcoded label order also differed from the saved result mapping.

This revision explicitly selects the six-channel result artifacts and their accompanying mappings, makes preprocessing consistent with the available training scripts, and validates the resulting interface. It does **not** infer that the old app's labels were necessarily wrong for its old binary. Those original binaries and source snapshots remain in ignored local backups, not in the published app bundle.

The result directory, mapping, observed model shape and current preprocessing are consistent evidence, but not a complete provenance chain. Without original recordings, final report and run metadata, the reported historical accuracy cannot be re-evaluated or independently attributed to the current binaries. The revision does not retrain the models or claim a new accuracy result.

## Training and replacement

Training scripts use 120 samples, stride 30 and six-channel inputs. Physical defaults to five recording-grouped folds; signal defaults to three. Participant-level generalization is not established by these splits. The signal model's internal `validation_split` is also not grouped by participant or recording.

When deploying a newly trained model:

1. Retain that run's mapping, `.tflite`, JSON manifest and evaluation reports together.
2. Copy the model into app assets and update the corresponding app JSON, including its asset path and ordered labels. Never reuse a different run's label order.
3. Keep the supported float32, six-channel preprocessing contract, or deliberately update preprocessing and tests together.
4. Validate binary SHA-256, input/output shapes, labels and an inference window. The verification script's source-directory lookup is specific to the currently bundled historical models and must be updated for new artifacts.
5. Run Flutter checks, build Android, then validate live sensor behavior and accuracy on independent labelled recordings.

CSV collection labels are not automatically the same as model output classes. A separate, documented data-preparation step is needed to produce the intended class directories; its original implementation is missing.
