import unittest

from backend.app.core.curriculum_data import (
    UNITS,
    active_step,
    apply_merge,
    bucket_of,
    make_due_next,
    public_progress_for_level,
    unit_progress_key,
    validate_due_next,
    targets_list_for,
)


class ProgressScopingTests(unittest.TestCase):
    def test_same_public_unit_id_is_independent_at_each_level(self):
        progress, _ = apply_merge(
            {},
            [
                {
                    "id": "U1-VOC-01",
                    "confidence": 0.9,
                    "prompted": False,
                    "evidence": "blue",
                }
            ],
            "A0",
        )

        self.assertEqual(
            bucket_of(progress, "U1-VOC-01", "A0"),
            "emerging",
        )
        self.assertEqual(
            bucket_of(progress, "U1-VOC-01", "A1"),
            "locked",
        )
        self.assertIn("A0:U1-VOC-01", progress["emerging"])

    def test_legacy_bare_unit_progress_is_not_applied_to_a_level(self):
        legacy = {"owned": ["U2-GRA-01"], "emerging": []}
        self.assertEqual(bucket_of(legacy, "U2-GRA-01", "A0"), "locked")
        self.assertEqual(bucket_of(legacy, "U2-GRA-01", "A1"), "locked")

    def test_due_target_requires_an_exact_level_match(self):
        due = make_due_next(["U2-GRA-01"], "A0")
        self.assertEqual(
            validate_due_next(due, "A0")["primary"],
            "U2-GRA-01",
        )
        self.assertEqual(validate_due_next(due, "A1"), {})
        self.assertEqual(
            validate_due_next({"primary": "U2-GRA-01"}, "A0"),
            {},
        )

    def test_public_progress_hides_internal_scope(self):
        progress = {
            "owned": ["A0:U1-VOC-01", "A1:U1-VOC-01"],
            "emerging": [],
            "sightings": {
                "A0:U1-VOC-01": 3,
                "A1:U1-VOC-01": 1,
            },
        }
        a0 = public_progress_for_level(progress, "A0")
        self.assertEqual(a0["owned"], ["U1-VOC-01"])
        self.assertEqual(a0["sightings"], {"U1-VOC-01": 3})

    def test_finishing_a0_does_not_finish_a1(self):
        progress = {
            "owned": [
                unit_progress_key("A0", skill["id"])
                for unit in UNITS["A0"]
                for skill in unit["skills"]
            ],
            "emerging": [],
        }
        self.assertIsNone(active_step(progress, "A0"))
        self.assertEqual(active_step(progress, "A1")["step"], "1")

    def test_failed_attempts_incremented_on_failure(self):
        progress, _ = apply_merge(
            {},
            [{"id": "U1-VOC-01", "confidence": 0.3, "prompted": False, "evidence": ""}],
            "A0",
        )
        self.assertEqual(progress.get("failed_attempts", {}).get("A0:U1-VOC-01"), 1)

        progress2, _ = apply_merge(
            progress,
            [{"id": "U1-VOC-01", "confidence": 0.2, "prompted": False, "evidence": ""}],
            "A0",
        )
        self.assertEqual(progress2.get("failed_attempts", {}).get("A0:U1-VOC-01"), 2)

    def test_failed_attempts_reset_on_success(self):
        initial = {"failed_attempts": {"A0:U1-VOC-01": 2}}
        progress, _ = apply_merge(
            initial,
            [{"id": "U1-VOC-01", "confidence": 0.9, "prompted": False, "evidence": "red"}],
            "A0",
        )
        self.assertEqual(progress.get("failed_attempts", {}).get("A0:U1-VOC-01", 0), 0)

    def test_stuck_target_is_rotated(self):
        progress = {"failed_attempts": {"A0:U1-VOC-01": 2}}
        targets = targets_list_for(progress, "unit", "A0")
        self.assertNotEqual(targets[0], "U1-VOC-01")
        self.assertEqual(targets[-1], "U1-VOC-01")


if __name__ == "__main__":
    unittest.main()
