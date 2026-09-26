import asyncio
import unittest
from unittest.mock import AsyncMock, MagicMock

from app.services.llm_service import is_placeholder_recap
from app.routers.llm import _generate_placement_recap
from app.routers.users import _get_last_time_recap


class RecapSanitizationTests(unittest.TestCase):
    def test_placeholder_detector(self):
        # Leaked template strings
        self.assertTrue(is_placeholder_recap("A warm recap of something the learner shared. Max 100 characters."))
        self.assertTrue(is_placeholder_recap("A warm personal sentence referencing their answer (max 100 chars)."))
        self.assertTrue(is_placeholder_recap("<warm specific recap, max 120 characters>"))
        self.assertTrue(is_placeholder_recap("A warm, accurate sentence the learner may see."))
        self.assertTrue(is_placeholder_recap("One concise sentence summarizing the assessed language skills."))
        self.assertTrue(is_placeholder_recap("<something>"))
        self.assertTrue(is_placeholder_recap(""))
        self.assertTrue(is_placeholder_recap(None))

        # Real student recaps
        self.assertFalse(is_placeholder_recap("You told me you love cricket and drawing!"))
        self.assertFalse(is_placeholder_recap("You shared that your favorite food is pizza."))
        self.assertFalse(is_placeholder_recap("Great chatting with you about your puppy!"))
        self.assertFalse(is_placeholder_recap("You practiced talking about your daily routine."))

    def test_generate_placement_recap_with_interests(self):
        result = {"interests": ["cricket", "video games"]}
        self.assertEqual(_generate_placement_recap(result), "You told me you like cricket and video games!")

        result_single = {"interests": ["music"]}
        self.assertEqual(_generate_placement_recap(result_single), "You told me you like music!")

    def test_generate_placement_recap_with_name(self):
        result = {"interests": []}
        self.assertEqual(_generate_placement_recap(result, name="Aarav Sharma"), "Great meeting you, Aarav! Ready for our first chat?")

    def test_generate_placement_recap_generic_fallback(self):
        result = {}
        self.assertEqual(_generate_placement_recap(result), "Great to meet you! Ready for our first chat?")

    def test_get_last_time_recap_rejects_stored_placeholder_and_uses_user_fallback(self):
        mock_db = AsyncMock()
        mock_db.execute.return_value.scalar_one_or_none.return_value = None

        mock_user = MagicMock()
        mock_user.id = "test-user-1"
        mock_user.name = "Priya"
        mock_user.interests = "reading,drawing"

        mock_placement = MagicMock()
        mock_placement.created_at = 1000
        mock_placement.highlight = "A warm recap of something the learner shared. Max 100 characters."
        mock_user.placements = [mock_placement]

        recap = asyncio.run(_get_last_time_recap(mock_user.id, mock_db, mock_user))
        self.assertEqual(recap, "You told me you like reading and drawing!")


if __name__ == "__main__":
    unittest.main()
