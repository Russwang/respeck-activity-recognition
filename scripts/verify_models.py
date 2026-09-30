"""Check bundled model hashes, labels, tensors and real CPU inference.

Run from the repository root: python scripts/verify_models.py
Synthetic samples validate execution, not recognition accuracy.
"""
import hashlib
import json
from pathlib import Path
import sys

import numpy as np
import tensorflow as tf

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from training_utils import window_features


def verify():
    for task in ('physical', 'social'):
        manifest = json.loads((ROOT / f'pdiot_har_example/assets/{task}.json').read_text())
        model = ROOT / 'pdiot_har_example' / manifest['asset']
        assert hashlib.sha256(model.read_bytes()).hexdigest() == manifest['sha256']
        mapping = json.loads((ROOT / manifest['source_directory'] / 'label_mapping.json').read_text())
        assert manifest['labels'] == sorted(mapping, key=mapping.get)
        interpreter = tf.lite.Interpreter(model_path=str(model))
        interpreter.allocate_tensors()
        inp, = interpreter.get_input_details()
        out, = interpreter.get_output_details()
        assert inp['shape'].tolist() == manifest['input_shape']
        assert out['shape'].tolist() == manifest['output_shape']
        assert inp['dtype'] == out['dtype'] == np.float32
        for samples in (np.tile([0., 0., 1.], (120, 1)),
                        np.random.default_rng(42).normal(size=(120, 3))):
            interpreter.set_tensor(inp['index'], window_features(samples)[None])
            interpreter.invoke()
            result = interpreter.get_tensor(out['index'])
            assert np.isfinite(result).all()
            np.testing.assert_allclose(result.sum(), 1., atol=1e-5)
        print(f'{task}: SHA-256, labels, float32 tensors and two inference windows PASS')


if __name__ == '__main__':
    verify()
