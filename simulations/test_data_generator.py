import unittest
from pathlib import Path

import numpy as np
from sklearn.datasets import load_wine
from sklearn.ensemble import RandomForestClassifier

from data_generator import WineDataGenerator


class WineDataGeneratorTest(unittest.TestCase):
    def test_all_scenarios_match_training_inputs(self):
        wine = load_wine()
        model = RandomForestClassifier(n_estimators=5, random_state=42)
        model.fit(wine.data, wine.target)
        generator = WineDataGenerator(Path(__file__).with_name("config.yaml"))

        for scenario in generator.config["scenarios"]:
            with self.subTest(scenario=scenario):
                samples = generator.generate_batch(20, scenario)
                for sample in samples:
                    self.assertEqual(list(sample), wine.feature_names)
                values = np.array([list(sample.values()) for sample in samples])
                self.assertEqual(values.shape, (20, 13))
                self.assertTrue(np.isfinite(values).all())
                self.assertTrue((values >= wine.data.min(axis=0)).all())
                self.assertTrue((values <= wine.data.max(axis=0)).all())
                self.assertEqual(model.predict(values).shape, (20,))


if __name__ == "__main__":
    unittest.main()
