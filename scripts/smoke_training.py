"""Exercise both train/evaluate/export entry points on synthetic data only.

Not an accuracy benchmark. All generated recordings and models use a temporary
folder and are removed when the check completes.
"""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]


def main():
    with tempfile.TemporaryDirectory(prefix='pdiot-smoke-') as tmp:
        tmp = Path(tmp)
        rng = np.random.default_rng(42)
        for label in range(2):
            folder = tmp / 'data' / f'class{label}'
            folder.mkdir(parents=True)
            for recording in range(4):
                values = rng.normal(label, 0.2, (300, 3))
                pd.DataFrame(values, columns=['accelX', 'accelY', 'accelZ']).to_csv(
                    folder / f'{recording}.csv', index=False)
        env = dict(os.environ, TF_NUM_INTEROP_THREADS='1', TF_NUM_INTRAOP_THREADS='1', OMP_NUM_THREADS='1')
        for task in ('physical', 'social'):
            subprocess.run([
                sys.executable, str(ROOT / f'{task}_model_leave_n_cv.py'),
                '--data-dir', str(tmp / 'data'), '--output-dir', str(tmp / task),
                '--folds', '2', '--epochs-cv', '1', '--epochs-final', '1',
            ], check=True, env=env)
            assert list((tmp / task).glob('*.tflite'))
            assert len(list((tmp / task).glob('*.json'))) == 2
            print(f'{task}: synthetic training/evaluation/export PASS', flush=True)


if __name__ == '__main__':
    main()
