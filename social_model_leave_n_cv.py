from training_utils import training_args, window_features, write_manifest
import os
import glob
import json
import numpy as np
import pandas as pd
import tensorflow as tf

from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import (
    Conv1D, MaxPooling1D, Dense, Dropout,
    BatchNormalization, GlobalAveragePooling1D
)

from sklearn.model_selection import GroupKFold
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.utils.class_weight import compute_class_weight


# ============================================================
# Social Signal Model (CNN) - GroupKFold CV (by recording file)
# - Uses per-window standardization
# - Uses GroupKFold with configurable folds to avoid leakage across windows
# - Produces CV artifacts for report + trains final deployment model
# ============================================================

def load_files_from_folder(folder_path: str):
    """Return sorted list of CSV file paths in a folder."""
    file_paths = []
    for file_name in os.listdir(folder_path):
        if file_name.endswith(".csv"):
            file_paths.append(os.path.join(folder_path, file_name))
    file_paths.sort()
    return file_paths


def load_and_apply_sliding_windows(file_paths, window_size, step_size, label):
    """
    Turn a list of recording files into (windows, labels, groups).
    groups = file_path for each window (so CV splits by file).
    """
    windows = []
    labels = []
    groups = []

    for file_path in file_paths:
        data = pd.read_csv(file_path, usecols=["accelX", "accelY", "accelZ"]).to_numpy()
        num_samples = data.shape[0]

        # skip too-short recordings
        if num_samples < window_size:
            continue

        for i in range(0, num_samples - window_size + 1, step_size):
            window = data[i : i + window_size]

            window = window_features(window)

            windows.append(window)
            labels.append(label)
            groups.append(file_path)

    return np.array(windows, dtype=np.float32), np.array(labels, dtype=np.int32), np.array(groups)


def build_cnn_social_model(input_shape, num_classes):
    model = Sequential()

    # ---- Conv Block 1 ----
    model.add(Conv1D(
        filters=32,
        kernel_size=7,
        activation="relu",
        padding="same",
        input_shape=input_shape
    ))
    model.add(BatchNormalization())
    model.add(MaxPooling1D(pool_size=2))

    # ---- Conv Block 2 ----
    model.add(Conv1D(
        filters=64,
        kernel_size=7,
        activation="relu",
        padding="same"
    ))
    model.add(BatchNormalization())
    model.add(MaxPooling1D(pool_size=2))

    # ---- Conv Block 3 ----
    model.add(Conv1D(
        filters=64,
        kernel_size=5,
        activation="relu",
        padding="same"
    ))
    model.add(BatchNormalization())
    model.add(MaxPooling1D(pool_size=2))

    # ---- Global pooling ----
    model.add(GlobalAveragePooling1D())

    # ---- Dense ----
    model.add(Dense(64, activation="relu"))
    model.add(Dropout(0.25))

    # ---- Output ----
    model.add(Dense(num_classes, activation="softmax"))

    model.compile(optimizer="adam", loss="categorical_crossentropy", metrics=["accuracy"])
    return model


def main():
    args = training_args('social', 3, 12, 30)
    tf.keras.utils.set_random_seed(args.seed)
    your_dataset_path = str(args.data_dir)
    window_size, step_size = 120, 30
    n_splits = args.folds
    epochs_cv, epochs_final = args.epochs_cv, args.epochs_final
    batch_size = 32
    out_dir = str(args.output_dir)
    os.makedirs(out_dir, exist_ok=True)

    # ====== Build label mapping (deterministic) ======
    activity_paths = [p for p in glob.glob(os.path.join(your_dataset_path, "*")) if os.path.isdir(p)]
    activity_names = sorted([os.path.basename(p) for p in activity_paths])
    activities = {activity: i for i, activity in enumerate(activity_names)}
    num_classes = len(activities)
    if num_classes < 2:
        raise ValueError('Dataset must contain at least two class directories')

    print("Social Signal -> Label mapping:")
    print(json.dumps(activities, indent=2))

    with open(os.path.join(out_dir, "label_mapping.json"), "w") as f:
        json.dump(activities, f, indent=2)

    # ====== Load all windows across all classes ======
    X_list, y_list, g_list = [], [], []

    for activity, label in activities.items():
        folder_path = os.path.join(your_dataset_path, activity)
        file_list = load_files_from_folder(folder_path)

        X_a, y_a, g_a = load_and_apply_sliding_windows(
            file_list, window_size=window_size, step_size=step_size, label=label
        )

        if len(X_a) == 0:
            print(f"[WARN] No windows produced for class '{activity}'. Check data/params.")
            continue

        X_list.append(X_a)
        y_list.append(y_a)
        g_list.append(g_a)

    if not X_list or len(X_list) != num_classes:
        raise ValueError('Every class needs at least one valid window; check CSV files and window length')
    X_all = np.concatenate(X_list, axis=0)
    y_all = np.concatenate(y_list, axis=0)
    groups_all = np.concatenate(g_list, axis=0)

    n_groups = len(np.unique(groups_all))
    print(f"\nX_all: {X_all.shape}, y_all: {y_all.shape}, groups_all: {groups_all.shape}")
    print(f"Unique recording files (groups): {n_groups}")

    if n_groups < n_splits:
        raise ValueError(
            f"Not enough unique files/groups ({n_groups}) for {n_splits}-fold GroupKFold. "
            f"Reduce n_splits or provide more recording files."
        )

    # ====== GroupKFold CV (by recording file) ======
    gkf = GroupKFold(n_splits=n_splits)

    fold_accs = []
    cm_total = np.zeros((num_classes, num_classes), dtype=np.int64)

    all_y_true = []
    all_y_pred = []

    fold_rows = []

    print(f"\n===== Group {n_splits}-fold CV (by file) =====")
    for fold_idx, (train_idx, test_idx) in enumerate(gkf.split(X_all, y_all, groups_all), start=1):
        X_train, X_test = X_all[train_idx], X_all[test_idx]
        y_train, y_test = y_all[train_idx], y_all[test_idx]

        # fixed one-hot dimension
        y_train_oh = tf.keras.utils.to_categorical(y_train, num_classes=num_classes)
        y_test_oh = tf.keras.utils.to_categorical(y_test, num_classes=num_classes)

        # per-fold class weights
        classes_in_train = np.unique(y_train)
        class_weights_array = compute_class_weight(
            class_weight="balanced", classes=classes_in_train, y=y_train
        )
        class_weights = dict(zip(classes_in_train.tolist(), class_weights_array.tolist()))

        # train fresh model per fold
        model = build_cnn_social_model((X_train.shape[1], X_train.shape[2]), num_classes=num_classes)

        # Early stopping: keep it simple + robust
        early_stop = tf.keras.callbacks.EarlyStopping(
            monitor="val_loss", patience=2, restore_best_weights=True
        )

        model.fit(
            X_train, y_train_oh,
            epochs=epochs_cv,
            batch_size=batch_size,
            verbose=0,
            class_weight=class_weights,
            validation_split=0.1,
            callbacks=[early_stop]
        )

        y_pred = np.argmax(model.predict(X_test, verbose=0), axis=1)
        acc = float(np.mean(y_pred == y_test))
        fold_accs.append(acc)

        cm_total += confusion_matrix(y_test, y_pred, labels=list(range(num_classes)))

        all_y_true.append(y_test)
        all_y_pred.append(y_pred)

        n_test_groups = len(set(groups_all[test_idx]))
        print(f"[Fold {fold_idx}/{n_splits}] test_files={n_test_groups}  acc={acc:.4f}")

        fold_rows.append(
            {"fold": fold_idx, "test_files": n_test_groups, "n_test_windows": len(test_idx), "acc": acc}
        )

    all_y_true = np.concatenate(all_y_true)
    all_y_pred = np.concatenate(all_y_pred)

    mean_acc = float(np.mean(fold_accs))
    std_acc = float(np.std(fold_accs))

    print("\n===== CV Summary =====")
    print(f"Fold accuracies: {fold_accs}")
    print(f"Mean acc: {mean_acc:.4f}  Std: {std_acc:.4f}")

    report_str = classification_report(all_y_true, all_y_pred, labels=list(range(num_classes)), digits=4, zero_division=0)
    print("\nClassification report (aggregated across folds):")
    print(report_str)

    print("\nConfusion matrix (summed over folds):")
    print(cm_total)

    # save CV artifacts for report
    pd.DataFrame(fold_rows).to_csv(os.path.join(out_dir, "cv_fold_metrics.csv"), index=False)
    pd.DataFrame(cm_total).to_csv(os.path.join(out_dir, "cv_confusion_matrix_sum.csv"), index=False)

    with open(os.path.join(out_dir, "cv_classification_report.txt"), "w") as f:
        f.write(f"===== Group {n_splits}-fold CV (by file) =====\n")
        f.write(f"Mean acc: {mean_acc:.4f}  Std: {std_acc:.4f}\n\n")
        f.write("Fold accuracies:\n")
        f.write(str(fold_accs) + "\n\n")
        f.write("Classification report (aggregated across folds):\n")
        f.write(report_str + "\n")

    # ====== Train FINAL deployment model on ALL data, then export TFLite ======
    print("\n===== Training FINAL model on ALL data for deployment =====")
    y_all_oh = tf.keras.utils.to_categorical(y_all, num_classes=num_classes)

    classes_all = np.unique(y_all)
    class_weights_array = compute_class_weight(class_weight="balanced", classes=classes_all, y=y_all)
    class_weights_final = dict(zip(classes_all.tolist(), class_weights_array.tolist()))

    model_final = build_cnn_social_model((X_all.shape[1], X_all.shape[2]), num_classes=num_classes)

    early_stop_final = tf.keras.callbacks.EarlyStopping(
        monitor="loss", patience=3, restore_best_weights=True
    )

    model_final.fit(
        X_all, y_all_oh,
        epochs=epochs_final,
        batch_size=batch_size,
        verbose=1,
        class_weight=class_weights_final,
        callbacks=[early_stop_final]
    )

    saved_model_dir = os.path.join(out_dir, "saved_model_cnn_social")
    tflite_path = os.path.join(out_dir, "model-social-cnn.tflite")

    model_final.export(saved_model_dir)

    # Convert to TFLite (CNN only -> builtins are enough)
    converter = tf.lite.TFLiteConverter.from_saved_model(saved_model_dir)
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
    converter.experimental_enable_resource_variables = True

    tflite_model = converter.convert()

    with open(tflite_path, "wb") as f:
        f.write(tflite_model)

    write_manifest(tflite_path, activities, window_size, args)

    print(f"\nFinal model exported to: {tflite_path}")
    print(f"All CV artifacts saved under: {out_dir}")


if __name__ == "__main__":
    main()
