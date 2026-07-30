import unittest

from backend.app.core.elicitation import (
    get_elicitation_plan_for,
    resolve_skill_text,
)


class ElicitationMappingTests(unittest.TestCase):
    def test_a0_step_two_is_present_identity_not_past(self):
        plan = get_elicitation_plan_for("U2-GRA-01", "A0")
        self.assertTrue(plan["valid"])
        self.assertEqual(plan["fn"], "identity_state")

    def test_a0_step_four_is_ability_not_future(self):
        plan = get_elicitation_plan_for("U4-GRA-01", "A0")
        self.assertEqual(plan["fn"], "ability")

    def test_same_unit_id_resolves_by_level(self):
        a0_text = resolve_skill_text("U2-GRA-01", "A0")
        a1_text = resolve_skill_text("U2-GRA-01", "A1")
        self.assertIn("I am", a0_text)
        self.assertIn("past simple", a1_text)
        self.assertNotEqual(a0_text, a1_text)

    def test_reported_speech_has_its_own_plan(self):
        plan = get_elicitation_plan_for("U2-GRA-02", "B1")
        self.assertEqual(plan["fn"], "reported_speech")

    def test_receptive_skill_uses_comprehension_plan(self):
        plan = get_elicitation_plan_for("A0-FLU-03", "A0")
        self.assertEqual(plan["fn"], "listening_comprehension")

    def test_a0_present_simple_uses_a_real_routine(self):
        plan = get_elicitation_plan_for("A0-GRA-03", "A0")
        self.assertEqual(plan["fn"], "routine")

    def test_conversation_management_is_not_a_generic_grammar_task(self):
        plan = get_elicitation_plan_for("A1-FLU-03", "A1")
        self.assertEqual(plan["fn"], "interaction")

    def test_tone_comprehension_uses_a_listening_plan(self):
        plan = get_elicitation_plan_for("B1-FLU-05", "B1")
        self.assertEqual(plan["fn"], "listening_comprehension")

    def test_recovering_from_mistakes_uses_repair_plan(self):
        plan = get_elicitation_plan_for("B1-FLU-06", "B1")
        self.assertEqual(plan["fn"], "repair_comprehension")

    def test_unknown_or_mismatched_target_is_invalid(self):
        self.assertIsNone(resolve_skill_text("U2-GRA-01", "C9"))
        plan = get_elicitation_plan_for("NOT-A-SKILL", "A0")
        self.assertFalse(plan["valid"])


if __name__ == "__main__":
    unittest.main()
