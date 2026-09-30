"""Shared training/deployment contract; no device recordings are bundled."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent


def window_features(window):
    window = np.asarray(window, dtype=np.float64)
    if window.ndim != 2 or window.shape[1] != 3 or not len(window):
        raise ValueError('Expected a non-empty [time, 3] acceleration window')
    if not np.isfinite(window).all():
        raise ValueError('Acceleration contains missing or non-finite values')
    mean = window.mean(axis=0)
    normalized = (window - mean) / (window.std(axis=0) + 1e-6)
    return np.concatenate([normalized, np.tile(mean, (len(window), 1))], axis=1).astype(np.float32)


def training_args(task, folds, epochs_cv, epochs_final):
    parser = argparse.ArgumentParser(description=f'Train the {task} six-channel CNN')
    folder = 'daily_activity' if task == 'physical' else 'social_signal'
    parser.add_argument('--data-dir', type=Path, default=ROOT / 'RESpeckData_Updated' / folder)
    parser.add_argument('--output-dir', type=Path, default=ROOT / 'training_outputs' / task)
    parser.add_argument('--folds', type=int, default=folds)
    parser.add_argument('--epochs-cv', type=int, default=epochs_cv)
    parser.add_argument('--epochs-final', type=int, default=epochs_final)
    parser.add_argument('--seed', type=int, default=42)
    args = parser.parse_args()
    if not args.data_dir.is_dir():
        parser.error(f'Dataset missing: {args.data_dir}. Supply --data-dir with class subdirectories containing CSV recordings.')
    if args.folds < 2 or min(args.epochs_cv, args.epochs_final) < 1:
        parser.error('Use at least two folds and positive epoch counts')
    if args.output_dir.exists() and any(args.output_dir.iterdir()):
        parser.error('Output directory is not empty; choose a new --output-dir to preserve previous runs')
    return args


def write_manifest(tflite_path, labels, window_size, args):
    path = Path(tflite_path)
    manifest = {
        'asset': f'assets/{path.name}',
        'input_shape': [1, window_size, 6],
        'output_shape': [1, len(labels)],
        'dtype': 'float32',
        'preprocessing': 'window_standardize_plus_mean',
        'epsilon': 1e-6,
        'labels': sorted(labels, key=labels.get),
        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        'seed': args.seed,
        'folds': args.folds,
        'grouping': 'recording_file_not_participant',
    }
    path.with_suffix('.json').write_text(json.dumps(manifest, indent=2) + '\n')
