import asyncio
import unittest
from unittest.mock import AsyncMock, MagicMock, patch

try:
    from app.routers.llm import placement_v2_turn
    from app.schemas.llm import PlacementV2TurnRequest, MessageIn
except ImportError:
    from backend.app.routers.llm import placement_v2_turn
    from backend.app.schemas.llm import PlacementV2TurnRequest, MessageIn


class PlacementV2Tests(unittest.TestCase):
    def setUp(self):
        self.mock_db = AsyncMock()
        self.mock_user = MagicMock()
        self.mock_user.id = "usr-uuid-123"
        self.mock_user.email = "student@navgurukul.org"
        self.mock_user.name = "Narendra"
        self.mock_user.age = "12"
        self.mock_user.level = None
        self.mock_user.unit_label = None
        self.mock_user.due_next = {}
        self.mock_user.skills_progress = {}
        self.mock_user.first_session_done = False

    def test_turn_0_asks_first_question(self):
        body = PlacementV2TurnRequest(
            name="Narendra",
            age=12,
            self_reported_level="I can have short conversations",
            messages=[]
        )
        res = asyncio.run(placement_v2_turn(body=body, user=self.mock_user, db=self.mock_db))

        self.assertFalse(res.is_complete)
        self.assertEqual(res.reply, "What do you want to improve in your English?")

    def test_turn_1_asks_second_question(self):
        body = PlacementV2TurnRequest(
            name="Narendra",
            age=12,
            self_reported_level="I can have short conversations",
            messages=[
                MessageIn(role="assistant", content="What do you want to improve in your English?"),
                MessageIn(role="user", content="I want to improve my vocabulary.")
            ]
        )
        res = asyncio.run(placement_v2_turn(body=body, user=self.mock_user, db=self.mock_db))

        self.assertFalse(res.is_complete)
        self.assertEqual(res.reply, "Tell me something about yourself?")

    @patch("app.services.llm_service._chat_completion")
    def test_turn_2_completes_placement_with_llm(self, mock_chat):
        mock_chat.return_value = '''
        {
            "level": "A2",
            "level_number": 3,
            "unit_name": "Lv. 3 Everyday Talk",
            "level_description": "You can have short conversations and describe everyday things.",
            "confidence": "high",
            "evidence_summary": "Connected sentences with basic past tense and sports vocabulary.",
            "zoe_recap": "You like playing cricket and want to speak better!",
            "interests": ["cricket", "sports"]
        }
        '''
        body = PlacementV2TurnRequest(
            name="Narendra",
            age=12,
            self_reported_level="I can have short conversations",
            messages=[
                MessageIn(role="assistant", content="What do you want to improve in your English?"),
                MessageIn(role="user", content="I want to improve my vocabulary and speak with friends."),
                MessageIn(role="assistant", content="Tell me something about yourself?"),
                MessageIn(role="user", content="I am Narendra and I love playing cricket after school.")
            ]
        )
        res = asyncio.run(placement_v2_turn(body=body, user=self.mock_user, db=self.mock_db))

        self.assertTrue(res.is_complete)
        self.assertEqual(res.level, "A2")
        self.assertEqual(res.level_number, 3)
        self.assertEqual(res.unit_name, "Lv. 3 Everyday Talk")
        self.assertEqual(res.interests, ["cricket", "sports"])
        self.assertEqual(self.mock_user.level, "A2")
        self.assertEqual(self.mock_user.unit_label, "Lv. 3 Everyday Talk")
        self.assertTrue(self.mock_user.first_session_done)
        # Verify backfill for A0 and A1 skills
        self.assertIn("owned", self.mock_user.skills_progress)
        self.assertTrue(len(self.mock_user.skills_progress["owned"]) > 0)

    def test_cancellation(self):
        body = PlacementV2TurnRequest(
            name="Narendra",
            age=12,
            cancel=True,
            messages=[]
        )
        res = asyncio.run(placement_v2_turn(body=body, user=self.mock_user, db=self.mock_db))

        self.assertTrue(res.is_complete)
        self.assertIsNone(res.level)
        self.assertIn("cancelled", res.level_description.lower())

    @patch("app.services.llm_service._chat_completion")
    def test_turn_2_sanitizes_placeholder_recap(self, mock_chat):
        mock_chat.return_value = '''
        {
            "level": "A2",
            "level_number": 3,
            "unit_name": "Lv. 3 Everyday Talk",
            "level_description": "You can have short conversations and describe everyday things.",
            "confidence": "high",
            "evidence_summary": "Connected sentences with basic past tense and sports vocabulary.",
            "zoe_recap": "A warm recap of something the learner shared. Max 100 characters.",
            "interests": ["drawing"]
        }
        '''
        body = PlacementV2TurnRequest(
            name="Narendra",
            age=12,
            self_reported_level="I can have short conversations",
            messages=[
                MessageIn(role="assistant", content="What do you want to improve in your English?"),
                MessageIn(role="user", content="I want to improve my drawing stories."),
                MessageIn(role="assistant", content="Tell me something about yourself?"),
                MessageIn(role="user", content="I like drawing pictures.")
            ]
        )
        res = asyncio.run(placement_v2_turn(body=body, user=self.mock_user, db=self.mock_db))

        self.assertTrue(res.is_complete)
        self.assertNotIn("Max 100", res.zoe_recap)
        self.assertNotIn("warm recap", res.zoe_recap)
        self.assertEqual(res.zoe_recap, "You told me you like drawing!")


if __name__ == "__main__":
    unittest.main()
