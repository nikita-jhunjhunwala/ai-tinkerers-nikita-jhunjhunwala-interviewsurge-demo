import unittest

from certs import unsupported_claims


class TestUnsupportedClaims(unittest.TestCase):
    def test_fake_pmi_acp_claim_is_caught(self) -> None:
        tailored = "Agile lead. Certified PMI-ACP practitioner."
        source = "Agile lead, 6 years of Scrum."
        self.assertEqual(unsupported_claims(tailored, source), {"pmi acp"})

    def test_held_certification_is_not_flagged(self) -> None:
        tailored = "Cloud engineer, AWS SAA."
        source = "Passed aws-saa in 2024."
        self.assertEqual(unsupported_claims(tailored, source), set())

    def test_cv_with_no_certifications_has_no_claims(self) -> None:
        self.assertEqual(unsupported_claims("Product manager.", "Product manager."), set())


if __name__ == "__main__":
    unittest.main()
