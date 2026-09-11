import asyncio
import unittest
from unittest.mock import MagicMock

try:
    from app.routers.users import get_user_garden
except ImportError:
    from backend.app.routers.users import get_user_garden


class PreviousGardenEvidenceTests(unittest.TestCase):
    def test_previous_garden_preserves_earned_evidence(self):
        user = MagicMock()
        user.level = "A1"
        user.due_next = {}
        user.placements = []
        user.skills_progress = {
            "evidence": {
                "A0:U1-VOC-01": [
                    {
                        "evidence": "My friend is tall and happy.",
                        "confidence": 0.95,
                        "prompted": True,
                        "topic": "My friends",
                        "created_at": "2026-07-10T09:42:10+00:00",
                    }
                ]
            }
        }

        res = asyncio.run(get_user_garden(user=user, view_level="A0"))
        
        # Verify level
        level = res["level"] if isinstance(res, dict) else res.level
        self.assertEqual(level, "A0")

        units = res["units"] if isinstance(res, dict) else res.units
        u1_voc_01 = None
        u1_gra_01 = None

        for unit in units:
            unit_dict = unit if isinstance(unit, dict) else unit.model_dump()
            for skill in unit_dict["skills"]:
                if skill["id"] == "U1-VOC-01":
                    u1_voc_01 = skill
                elif skill["id"] == "U1-GRA-01":
                    u1_gra_01 = skill

        self.assertIsNotNone(u1_voc_01, "U1-VOC-01 skill should exist in A0 garden")
        self.assertEqual(u1_voc_01["status"], "owned")
        self.assertEqual(len(u1_voc_01["evidence"]), 1)
        self.assertEqual(u1_voc_01["evidence"][0]["evidence"], "My friend is tall and happy.")
        self.assertEqual(u1_voc_01["evidence"][0]["confidence"], 0.95)
        self.assertEqual(u1_voc_01["evidence"][0]["topic"], "My friends")

        # Verify that an unearned / bypassed skill on that previous level has empty evidence
        self.assertIsNotNone(u1_gra_01, "U1-GRA-01 skill should exist in A0 garden")
        self.assertEqual(u1_gra_01["status"], "owned")
        self.assertEqual(u1_gra_01["evidence"], [])


if __name__ == "__main__":
    unittest.main()

