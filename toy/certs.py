"""Toy CV truthfulness check: does a tailored CV claim a certification the
person's own source CV never mentions?

LEXICON is matched against normalised text, where "-" has become " ".
So every entry must be stored hyphen-free. Store one entry with a hyphen and
that certification can never match: a fake claim of it goes uncaught.
That one-character bug is the mutation the tests must catch.
"""

LEXICON = ["pmi acp", "aws saa", "cka"]


def normalise(text: str) -> str:
    return " ".join(text.lower().replace("-", " ").split())


def certs_named(text: str) -> set[str]:
    t = normalise(text)
    return {cert for cert in LEXICON if cert in t}


def unsupported_claims(tailored_cv: str, source_cv: str) -> set[str]:
    """Certifications the tailored CV claims that the source CV does not."""
    return certs_named(tailored_cv) - certs_named(source_cv)
