import tempfile
import unittest
from pathlib import Path

import numpy as np
import pandas as pd

from training_utils import window_features


class PreprocessingTest(unittest.TestCase):
    def test_constant_preserves_posture_and_has_no_nan(self):
        out = window_features(np.tile([1., -2., 3.], (120, 1)))
        self.assertEqual(out.shape, (120, 6))
        np.testing.assert_array_equal(out[:, :3], 0)
        np.testing.assert_array_equal(out[:, 3:], np.tile([1., -2., 3.], (120, 1)))

    def test_population_std_and_channel_order(self):
        out = window_features([[1, 2, 3], [3, 4, 5]])
        expected = [[-1 / 1.000001] * 3 + [2, 3, 4], [1 / 1.000001] * 3 + [2, 3, 4]]
        np.testing.assert_allclose(out, expected, rtol=1e-6)

    def test_invalid_input(self):
        for data in ([], [[1, 2]], [[1, float('nan'), 3]]):
            with self.assertRaises(ValueError):
                window_features(data)

    def test_both_training_loaders_keep_file_groups_and_exact_windows(self):
        from physical_model_leave_n_cv import load_and_apply_sliding_windows as physical
        from social_model_leave_n_cv import load_and_apply_sliding_windows as social
        with tempfile.TemporaryDirectory() as folder:
            long = Path(folder) / 'long.csv'
            short = Path(folder) / 'short.csv'
            data = np.arange(450).reshape(150, 3)
            pd.DataFrame(data, columns=['accelX', 'accelY', 'accelZ']).to_csv(long, index=False)
            pd.DataFrame(data[:20], columns=['accelX', 'accelY', 'accelZ']).to_csv(short, index=False)
            for loader in (physical, social):
                x, y, groups = loader([str(long), str(short)], 120, 30, 2)
                self.assertEqual(x.shape, (2, 120, 6))
                np.testing.assert_array_equal(y, [2, 2])
                np.testing.assert_array_equal(groups, [str(long), str(long)])
                np.testing.assert_allclose(x[1], window_features(data[30:150]))


if __name__ == '__main__':
    unittest.main()
