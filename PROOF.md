# PROOF

One entry per change to `toy/`: the mutation you applied, and the test you saw fail.
The push gate refuses a code change that has no entry here.

## unsupported_claims catches a fake PMI-ACP claim
- mutation: `s/^LEXICON = \["pmi acp"/LEXICON = ["pmi-acp"/` on `toy/certs.py`
- observed: `test_fake_pmi_acp_claim_is_caught` failed (`mutate.sh` exit 0, KILLED)
