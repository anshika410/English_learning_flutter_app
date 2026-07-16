import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
BACKEND_PROMPTS = REPO_ROOT / "backend" / "app" / "prompts"
FRONTEND_PROMPTS = REPO_ROOT / "frontend" / "assets" / "prompts"


class PromptContractTests(unittest.TestCase):
    def test_frontend_prompt_mirror_matches_backend(self):
        for backend_path in BACKEND_PROMPTS.glob("*.md"):
            frontend_path = FRONTEND_PROMPTS / backend_path.name
            self.assertTrue(frontend_path.exists(), backend_path.name)
            self.assertEqual(
                backend_path.read_bytes(),
                frontend_path.read_bytes(),
                backend_path.name,
            )

    def test_a0_profile_prohibits_forced_imitation(self):
        profile = (BACKEND_PROMPTS / "profile-A0.md").read_text()
        self.assertIn('Never use an imperative "Say..." or "Repeat..."', profile)
        self.assertIn("patterns, not scripts", profile)
        self.assertIn("When one word fully answers", profile)
        self.assertIn("Build a truthful first sentence", profile)

    def test_conversation_shell_contains_all_three_layers(self):
        shell = (BACKEND_PROMPTS / "conversation-prompt.md").read_text()
        self.assertIn("{{BASE_BLOCK}}", shell)
        self.assertIn("{{LEVEL_BLOCK}}", shell)
        self.assertIn("{{UNIT_BLOCK}}", shell)

    def test_placement_inherits_base_rules(self):
        placement = (BACKEND_PROMPTS / "placement-check-prompt.md").read_text()
        service = (
            REPO_ROOT / "backend" / "app" / "services" / "llm_service.py"
        ).read_text()
        self.assertIn("{{BASE_BLOCK}}", placement)
        self.assertIn('.replace("{{BASE_BLOCK}}", base_block)', service)

    def test_qa_judge_receives_base_and_level_rubrics(self):
        judge = (BACKEND_PROMPTS / "zoe-judge-prompt.md").read_text()
        self.assertIn("{{BASE_BLOCK}}", judge)
        self.assertIn("{{LEVEL_BLOCK}}", judge)
        self.assertIn("untrusted quoted data", judge)

    def test_deterministic_closing_removes_new_question(self):
        service = (
            REPO_ROOT / "backend" / "app" / "services" / "llm_service.py"
        ).read_text()
        self.assertIn("def _closing_without_question", service)
        self.assertIn("if current_turn >= 6:", service)
        self.assertIn("reply = _closing_without_question(reply)", service)

    def test_flutter_reads_backend_session_id_and_starter(self):
        api_service = (
            REPO_ROOT / "frontend" / "lib" / "services" / "api_service.dart"
        ).read_text()
        chat_provider = (
            REPO_ROOT / "frontend" / "lib" / "providers" / "chat_provider.dart"
        ).read_text()
        self.assertIn("data['session_id'] ?? data['id']", api_service)
        self.assertIn("'session_id': conversationId", api_service)
        self.assertIn("'unit_label': levelLabel", api_service)
        self.assertIn("createdSession?.starter", chat_provider)


if __name__ == "__main__":
    unittest.main()
