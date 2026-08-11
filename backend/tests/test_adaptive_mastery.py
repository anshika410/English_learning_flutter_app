import unittest
from backend.app.core.curriculum_data import apply_merge, targets_list_for, bucket_of

class AdaptiveMasteryTests(unittest.TestCase):
    def setUp(self):
        # Fresh user progress starting at A1
        self.base_progress = {
            "level": "A1",
            "owned": [],
            "emerging": [],
            "sightings": {},
            "evidence": {},
            "mastery": {},
            "evidence_count": {},
            "context_diversity": {},
            "recent_primary_history": []
        }

    def test_continuous_mastery_progression(self):
        # 1. First successful chat (evidence = 0.85)
        scores = [{"id": "U1-GRA-01", "confidence": 0.85, "prompted": True, "evidence": "He is coding."}]
        p1, changes = apply_merge(self.base_progress, scores, "A1", topic="Shopping and markets")
        
        # Verify it transitions from locked -> emerging (since mastery >= 0.25)
        self.assertEqual(bucket_of(p1, "U1-GRA-01", "A1"), "emerging")
        self.assertAlmostEqual(p1["mastery"]["A1:U1-GRA-01"], 0.34) # 0.0 + 0.40 * 0.85 * 1.0 = 0.34
        self.assertEqual(p1["evidence_count"]["A1:U1-GRA-01"], 1)
        self.assertEqual(p1["context_diversity"]["A1:U1-GRA-01"], ["Shopping and markets"])

        # 2. Second successful chat on a different topic (evidence = 0.90)
        scores = [{"id": "U1-GRA-01", "confidence": 0.90, "prompted": True, "evidence": "She is running."}]
        p2, changes = apply_merge(p1, scores, "A1", topic="Celebrations")
        
        # Verify it is still emerging (mastery = 0.34 + 0.4 * 0.9 * 0.66 = 0.5776, not yet >= 0.75)
        self.assertEqual(bucket_of(p2, "U1-GRA-01", "A1"), "emerging")
        self.assertAlmostEqual(p2["mastery"]["A1:U1-GRA-01"], 0.5776, places=4)
        self.assertEqual(p2["evidence_count"]["A1:U1-GRA-01"], 2)
        self.assertEqual(set(p2["context_diversity"]["A1:U1-GRA-01"]), {"Shopping and markets", "Celebrations"})

        # 3. Third successful chat on a third topic (evidence = 0.80)
        scores = [{"id": "U1-GRA-01", "confidence": 0.80, "prompted": True, "evidence": "They are playing."}]
        p3, changes = apply_merge(p2, scores, "A1", topic="Eating Out")
        
        # Verify it is now EMERGING (mastery = 0.7128 < 0.75)
        self.assertEqual(bucket_of(p3, "U1-GRA-01", "A1"), "emerging")
        
        # 4. Fourth successful chat (evidence = 0.95)
        scores = [{"id": "U1-GRA-01", "confidence": 0.95, "prompted": True, "evidence": "I am eating."}]
        p4, changes = apply_merge(p3, scores, "A1", topic="Travel")
        
        # Now mastery is: 0.8219 >= 0.75.
        # Also evidence_count (4) >= 2, and context_diversity (4) >= 2.
        # So it must transition to owned!
        self.assertEqual(bucket_of(p4, "U1-GRA-01", "A1"), "owned")

    def test_dynamic_priority_fatigue_rotation(self):
        # Get starting targets. For A1 Unit 1, the unowned skills are U1-VOC-01, U1-GRA-01, and U1-FLU-01.
        # Initially, U1-VOC-01 (Vocabulary) is first because of curriculum order priority.
        targets1 = targets_list_for(self.base_progress, "unit", "A1")
        self.assertEqual(targets1[0], "U1-VOC-01")
        self.assertEqual(targets1[1], "U1-GRA-01")
        self.assertEqual(targets1[2], "U1-FLU-01")

        # Now, simulate that U1-VOC-01 was the primary target for 3 consecutive sessions.
        progress_fatigued = {
            **self.base_progress,
            "recent_primary_history": ["A1:U1-VOC-01", "A1:U1-VOC-01", "A1:U1-VOC-01"]
        }

        # Check targets again. The fatigue penalty on U1-VOC-01 should cause it to drop priority,
        # making U1-GRA-01 the new primary target!
        targets2 = targets_list_for(progress_fatigued, "unit", "A1")
        self.assertEqual(targets2[0], "U1-GRA-01")
        self.assertEqual(targets2[1], "U1-FLU-01")
        self.assertEqual(targets2[2], "U1-VOC-01")


if __name__ == "__main__":
    unittest.main()
