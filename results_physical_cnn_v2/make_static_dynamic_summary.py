import os
import json
import pandas as pd
import numpy as np

STATIC_LABELS = [2, 3, 4, 5, 10]    # lyingBack, lyingLeft, lyingRight, lyingStomach, sittingStanding
DYNAMIC_LABELS = [0, 1, 6, 7, 8, 9] # ascending, descending, miscMovement, normalWalking, running, shuffleWalking


def safe_div(a, b):
    return float(a) / float(b) if b else 0.0


def main():
    results_dir = os.path.dirname(os.path.abspath(__file__))

    cm_path = os.path.join(results_dir, "cv_confusion_matrix_sum.csv")
    map_path = os.path.join(results_dir, "label_mapping.json")

    if not os.path.exists(cm_path):
        raise FileNotFoundError(f"Missing {cm_path}")
    if not os.path.exists(map_path):
        raise FileNotFoundError(f"Missing {map_path}")

    # ✅ FIX: read CSV WITH header
    cm = pd.read_csv(cm_path).to_numpy(dtype=np.int64)

    with open(map_path, "r") as f:
        label_map = json.load(f)
    id_to_name = {int(v): k for k, v in label_map.items()}

    def per_class_stats(label_id):
        tp = int(cm[label_id, label_id])
        support = int(cm[label_id, :].sum())
        recall = safe_div(tp, support)
        return tp, support, recall

    def group_summary(label_ids, group_name):
        rows = []
        tps, supports, recalls = [], [], []

        for i in label_ids:
            tp, sup, rec = per_class_stats(i)
            rows.append({
                "group": group_name,
                "label_id": i,
                "class_name": id_to_name[i],
                "support": sup,
                "tp": tp,
                "recall": rec,
            })
            tps.append(tp)
            supports.append(sup)
            recalls.append(rec)

        summary = {
            "group": group_name,
            "n_classes": len(label_ids),
            "total_windows": int(sum(supports)),
            "macro_mean_per_class_accuracy": float(np.mean(recalls)),
            "weighted_accuracy": safe_div(sum(tps), sum(supports)),
        }

        return summary, pd.DataFrame(rows).sort_values("recall")

    static_summary, static_details = group_summary(STATIC_LABELS, "static")
    dynamic_summary, dynamic_details = group_summary(DYNAMIC_LABELS, "dynamic")

    summary_df = pd.DataFrame([static_summary, dynamic_summary])
    details_df = pd.concat([static_details, dynamic_details], ignore_index=True)

    summary_df.to_csv(os.path.join(results_dir, "static_dynamic_summary.csv"), index=False)
    details_df.to_csv(os.path.join(results_dir, "static_dynamic_details.csv"), index=False)

    print("\n=== Static vs Dynamic Summary (FIXED) ===")
    print(summary_df.to_string(index=False))

    print("\n=== Lowest recall classes ===")
    print(details_df.sort_values("recall").head(6).to_string(index=False))


if __name__ == "__main__":
    main()
