import unittest
from backend.app.core.curriculum_data import LEVEL_TOPICS

# Documented affordance-tag vocabulary (docs/topic-skill-affordance-v6.md).
VALID_TAGS = {
    "naming", "describing", "routine", "preference", "past_event",
    "present_action", "future_plan", "opinion", "narrative", "comparison",
    "hypothetical", "abstract", "explanation", "argumentation", "any",
}

# Expected affordance sets per topic, verbatim from docs/topic-skill-affordance-v6.md.
# Keyed by backend LEVEL_TOPICS key -> shortName (the doc's "Label"). The doc's
# levels A1..C2 map to backend keys A0..C1 respectively.
EXPECTED = {
    # doc A1
    "A0": {
        "My Name": ["naming", "describing"],
        "My Family": ["naming", "describing", "preference"],
        "School": ["describing", "routine", "preference", "present_action"],
        "Food": ["naming", "preference", "describing"],
        "Routine": ["routine", "describing", "present_action"],
        "Liking": ["preference"],
        "Animals": ["naming", "describing", "preference"],
        "Colours": ["naming"],
        "Home": ["naming", "describing", "present_action"],
        "Sports": ["preference", "present_action", "describing"],
        "Festivals": ["describing", "preference", "naming"],
        "Favourite Show": ["preference", "describing", "naming"],
        "Break Time": ["present_action", "describing", "preference"],
        "Birthday": ["describing", "preference", "naming"],
        "Things I Can Do": ["describing", "preference", "present_action"],
        "My Bag": ["naming", "describing", "present_action"],
    },
    # doc A2
    "A1": {
        "Hobbies": ["preference", "describing", "routine", "past_event", "future_plan"],
        "Friends": ["describing", "past_event", "narrative", "preference"],
        "My Week": ["routine", "describing", "past_event", "future_plan"],
        "Shopping": ["describing", "preference", "past_event"],
        "Eating Out": ["preference", "describing", "comparison", "opinion"],
        "My City": ["describing", "comparison", "opinion"],
        "Weather": ["describing", "comparison", "routine", "opinion"],
        "Travel": ["describing", "preference", "past_event"],
        "Trips": ["past_event", "narrative", "describing", "future_plan"],
        "Films & TV": ["preference", "opinion", "narrative", "describing"],
        "Celebrations": ["past_event", "narrative", "describing"],
        "Subjects": ["preference", "opinion", "comparison", "future_plan", "narrative"],
        "Holiday Plans": ["future_plan", "preference", "narrative"],
        "Dream Place": ["future_plan", "describing", "preference"],
        "Learning Next": ["future_plan", "preference", "opinion"],
        "Someone I Admire": ["describing", "opinion", "narrative"],
    },
    # doc B1
    "A2": {
        "Ambitions": ["future_plan", "opinion", "hypothetical"],
        "Who I Am": ["describing", "opinion", "abstract"],
        "Education": ["opinion", "comparison", "explanation", "past_event", "hypothetical"],
        "Social Media": ["opinion", "comparison", "explanation", "hypothetical"],
        "City vs Village": ["comparison", "opinion", "describing", "past_event"],
        "Traditions": ["narrative", "describing", "past_event"],
        "Environment": ["opinion", "explanation", "abstract", "hypothetical"],
        "Health": ["opinion", "comparison", "explanation", "past_event", "hypothetical"],
        "Cinema & Music": ["preference", "opinion", "narrative", "describing"],
        "Friendship": ["abstract", "opinion", "narrative"],
        "The News": ["opinion", "explanation", "narrative", "describing"],
        "Cricket & Sport": ["preference", "narrative", "opinion", "comparison"],
        "Growing Up": ["past_event", "routine", "narrative", "comparison"],
        "Hard Choices": ["past_event", "narrative", "opinion", "hypothetical"],
        "My Rules": ["hypothetical", "opinion", "argumentation"],
        "Mix-Ups": ["past_event", "narrative", "explanation"],
        "My Family": ["describing", "narrative", "opinion"],
        "Food": ["preference", "describing", "narrative"],
    },
    # doc B2
    "B1": {
        "Culture": ["abstract", "opinion", "narrative"],
        "Gender Equality": ["opinion", "argumentation", "abstract", "explanation"],
        "Success": ["opinion", "abstract", "comparison", "hypothetical"],
        "AI & Work": ["abstract", "opinion", "hypothetical", "explanation", "argumentation"],
        "Youth & Mind": ["opinion", "explanation", "abstract"],
        "Climate & India": ["argumentation", "explanation", "abstract"],
        "Migration": ["abstract", "opinion", "narrative"],
        "Old vs New": ["comparison", "abstract", "opinion", "hypothetical", "argumentation"],
        "Fake News": ["opinion", "explanation", "argumentation"],
        "Startups": ["narrative", "opinion", "explanation"],
        "Indian Stories": ["abstract", "narrative", "opinion"],
        "Privilege": ["abstract", "argumentation", "opinion", "explanation"],
        "Changed My Mind": ["narrative", "past_event", "opinion", "abstract"],
        "India 2075": ["hypothetical", "abstract", "opinion"],
        "Breaking Rules": ["hypothetical", "argumentation", "abstract"],
        "Big Decisions": ["past_event", "narrative", "hypothetical", "opinion"],
        "Sports": ["opinion", "narrative", "comparison", "hypothetical"],
        "Music": ["preference", "opinion", "narrative"],
        "My Family": ["describing", "narrative", "opinion", "abstract"],
        "Food": ["preference", "narrative", "opinion", "comparison"],
    },
    # doc C1
    "B2": {
        "Being Indian": ["abstract", "opinion", "narrative", "hypothetical"],
        "Moral Dilemmas": ["hypothetical", "argumentation", "abstract"],
        "AI Ethics": ["abstract", "argumentation", "hypothetical"],
        "Caste & Class": ["abstract", "argumentation", "opinion"],
        "Sustainability": ["argumentation", "comparison", "abstract"],
        "Mental Health": ["abstract", "opinion", "explanation"],
        "Youth & Democracy": ["abstract", "argumentation", "opinion"],
        "English in India": ["abstract", "argumentation", "opinion"],
        "Art & Society": ["abstract", "opinion", "explanation"],
        "What Is Success?": ["abstract", "opinion", "narrative", "hypothetical"],
        "India & World": ["abstract", "argumentation", "explanation"],
        "Science vs Belief": ["abstract", "argumentation", "opinion"],
        "Creativity": ["abstract", "opinion", "explanation"],
        "Rethink History": ["argumentation", "abstract", "comparison", "hypothetical"],
        "Privacy vs Safety": ["argumentation", "abstract", "hypothetical"],
        "Meaning of Home": ["abstract", "opinion", "narrative", "hypothetical"],
        "Sports": ["opinion", "narrative", "abstract", "argumentation"],
        "Music": ["opinion", "abstract", "narrative"],
        "My Family": ["abstract", "narrative", "opinion"],
        "Food": ["abstract", "opinion", "narrative", "comparison"],
    },
    # doc C2
    "C1": {
        "Language & Thought": ["abstract", "explanation", "opinion"],
        "Justice": ["abstract", "argumentation", "opinion"],
        "Knowledge": ["abstract", "explanation", "opinion"],
        "Being Human": ["abstract", "argumentation", "hypothetical"],
        "Power & Story": ["abstract", "argumentation", "opinion"],
        "Future Democracy": ["abstract", "argumentation", "hypothetical"],
        "Gene Ethics": ["abstract", "argumentation", "hypothetical"],
        "Purpose of Art": ["abstract", "opinion", "explanation"],
        "The Self": ["abstract", "opinion", "explanation"],
        "Globalisation": ["abstract", "argumentation", "comparison"],
        "Limits of Freedom": ["abstract", "argumentation", "hypothetical"],
        "Future Generations": ["abstract", "argumentation", "hypothetical"],
        "Moral Truth": ["abstract", "argumentation", "opinion"],
        "Right to Forget": ["abstract", "hypothetical", "opinion"],
        "Broken Systems": ["abstract", "argumentation", "hypothetical"],
        "Power of Humour": ["abstract", "opinion", "argumentation"],
        "Sports": ["abstract", "opinion", "argumentation"],
        "Music": ["abstract", "opinion", "explanation"],
        "My Family": ["abstract", "opinion", "narrative"],
        "Food": ["abstract", "narrative", "opinion"],
    },
}


class AffordanceTagsTests(unittest.TestCase):
    """Guards that topic affordance tags stay in sync with
    docs/topic-skill-affordance-v6.md. Sets are compared so tag ordering
    never causes a false failure."""

    def test_every_topic_matches_doc(self):
        for level, topics in LEVEL_TOPICS.items():
            expected_level = EXPECTED.get(level, {})
            for topic in topics:
                label = topic["shortName"]
                with self.subTest(level=level, label=label):
                    self.assertIn(
                        label, expected_level,
                        f"[{level}] {label!r}: no expected entry (label mismatch?)",
                    )
                    self.assertEqual(
                        set(topic["affordances"]), set(expected_level[label]),
                        f"[{level}] {label}: affordances "
                        f"{topic['affordances']} != doc {expected_level[label]}",
                    )

    def test_no_missing_or_orphan_topics(self):
        self.assertEqual(set(EXPECTED), set(LEVEL_TOPICS))
        for level, expected_level in EXPECTED.items():
            backend_labels = {t["shortName"] for t in LEVEL_TOPICS[level]}
            self.assertEqual(
                set(expected_level), backend_labels,
                f"[{level}] label set differs between doc and backend",
            )

    def test_only_valid_tags_used(self):
        for level, topics in LEVEL_TOPICS.items():
            for topic in topics:
                for tag in topic["affordances"]:
                    with self.subTest(level=level, label=topic["shortName"], tag=tag):
                        self.assertIn(tag, VALID_TAGS, f"unknown tag {tag!r}")


if __name__ == "__main__":
    unittest.main()
