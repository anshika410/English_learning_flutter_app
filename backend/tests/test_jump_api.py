import asyncio
import unittest
from unittest.mock import AsyncMock, MagicMock
from fastapi import HTTPException

try:
    from app.routers.admin import jump_user_to_level, JumpRequest
except ImportError:
    from backend.app.routers.admin import jump_user_to_level, JumpRequest


class JumpAPITests(unittest.TestCase):
    def setUp(self):
        self.mock_db = AsyncMock()
        self.mock_user = MagicMock()
        self.mock_user.id = "usr-uuid-123"
        self.mock_user.device_id = "dev-uuid-456"
        self.mock_user.email = "student@navgurukul.org"
        self.mock_user.name = "Aarav"
        self.mock_user.level = "A0"
        self.mock_user.level_label = "First Words"
        self.mock_user.due_next = {"primary": ["U1-VOC-01"]}
        self.mock_user.skills_progress = {"owned": ["U1-VOC-01"]}

    def test_jump_by_email_success(self):
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = self.mock_user
        self.mock_db.execute.return_value = mock_result

        body = JumpRequest(email="student@navgurukul.org", level="B1", reset_progress=True)
        res = asyncio.run(jump_user_to_level(body=body, _=None, db=self.mock_db))

        self.assertEqual(res["status"], "ok")
        self.assertEqual(res["level"], "B1")
        self.assertEqual(res["level_label"], "Expressing Myself")
        self.assertEqual(self.mock_user.level, "B1")
        self.assertEqual(self.mock_user.level_label, "Expressing Myself")
        self.assertEqual(self.mock_user.due_next, {})
        self.assertEqual(self.mock_user.skills_progress["owned"], [])

    def test_jump_by_user_id_success(self):
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = self.mock_user
        self.mock_db.execute.return_value = mock_result

        body = JumpRequest(email="usr-uuid-123", level="A2", reset_progress=False)
        res = asyncio.run(jump_user_to_level(body=body, _=None, db=self.mock_db))

        self.assertEqual(res["status"], "ok")
        self.assertEqual(res["level"], "A2")
        self.assertEqual(res["level_label"], "Building Confidence")
        self.assertEqual(self.mock_user.level, "A2")
        self.assertEqual(self.mock_user.level_label, "Building Confidence")

    def test_jump_invalid_level_fails(self):
        body = JumpRequest(email="student@navgurukul.org", level="Z9")
        with self.assertRaises(HTTPException) as ctx:
            asyncio.run(jump_user_to_level(body=body, _=None, db=self.mock_db))
        self.assertEqual(ctx.exception.status_code, 400)

    def test_jump_user_not_found(self):
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        self.mock_db.execute.return_value = mock_result

        body = JumpRequest(email="unknown@example.com", level="A1")
        with self.assertRaises(HTTPException) as ctx:
            asyncio.run(jump_user_to_level(body=body, _=None, db=self.mock_db))
        self.assertEqual(ctx.exception.status_code, 404)


if __name__ == "__main__":
    unittest.main()
