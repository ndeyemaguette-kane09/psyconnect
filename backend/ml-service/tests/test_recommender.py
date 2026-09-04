# tests du moteur de reco (app.recommender).
# dependent que de numpy, pas besoin de FastAPI/httpx pour les lancer
# lancement : python3 -m tests.test_recommender (depuis backend/ml-service)

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.recommender import (  # noqa: E402
    build_patient_query,
    build_psychologist_content,
    cosine_similarity,
    rank_psychologists,
    same_city_bonus,
    tokenize,
)


def test_tokenize_normalizes_accents_and_case():
    tokens = tokenize("Anxiété ET Stress, Dépression !")
    assert "anxiete" in tokens
    assert "stress" in tokens
    assert "depression" in tokens
    # mots vides / ponctuation retirés
    assert "et" not in tokens


def test_cosine_similarity_identical_vectors_is_one():
    import numpy as np

    vector = np.array([1.0, 2.0, 3.0])
    assert abs(cosine_similarity(vector, vector) - 1.0) < 1e-9


def test_cosine_similarity_zero_vector_is_zero():
    import numpy as np

    zero = np.zeros(3)
    other = np.array([1.0, 0.0, 0.0])
    assert cosine_similarity(zero, other) == 0.0


PSYCHOLOGISTS = [
    {
        "id": 1,
        "specialty": "Anxiété et stress",
        "bio": "Spécialiste de la gestion du stress et des troubles anxieux.",
        "languages": "Français, Wolof",
        "rating": 4.0,
        "available": True,
    },
    {
        "id": 2,
        "specialty": "Thérapie de couple",
        "bio": "Accompagnement des couples et des familles.",
        "languages": "Français, Anglais",
        "rating": 5.0,
        "available": True,
    },
    {
        "id": 3,
        "specialty": "Addictologie",
        "bio": "Prise en charge des addictions et dépendances.",
        "languages": "Français",
        "rating": 4.8,
        "available": False,  # ne doit jamais apparaître dans les résultats
    },
]


def test_unavailable_psychologists_are_excluded():
    patient = {"preferredLanguage": "Français", "medicalHistory": "anxiété"}
    results = rank_psychologists(patient, PSYCHOLOGISTS, top_n=10)
    ids = [r["id"] for r in results]
    assert 3 not in ids
    assert set(ids) == {1, 2}


def test_content_match_outranks_lower_rated_but_relevant_psychologist():
    # le motif du patient correspond au psy 1, pas au 2
    # meme si le psy 2 a une meilleure note
    patient = {
        "preferredLanguage": "Français",
        "medicalHistory": "Je ressens beaucoup d'anxiété et de stress au travail",
    }

    results = rank_psychologists(patient, PSYCHOLOGISTS, top_n=10)

    assert results[0]["id"] == 1
    assert results[0]["contentSimilarity"] > results[1]["contentSimilarity"]


def test_empty_patient_query_falls_back_to_rating_ranking():
    patient = {"preferredLanguage": None, "medicalHistory": None}

    results = rank_psychologists(patient, PSYCHOLOGISTS, top_n=10)

    # toutes les similarités sont a zero
    assert all(r["contentSimilarity"] == 0.0 for r in results)

    # le classement retombe sur la note : psy 2 avant psy 1
    assert [r["id"] for r in results] == [2, 1]


def test_top_n_truncates_results():
    patient = {"preferredLanguage": "Français", "medicalHistory": "anxiété"}
    results = rank_psychologists(patient, PSYCHOLOGISTS, top_n=1)
    assert len(results) == 1


def test_no_available_psychologists_returns_empty_list():
    all_unavailable = [{**p, "available": False} for p in PSYCHOLOGISTS]
    patient = {"preferredLanguage": "Français", "medicalHistory": "anxiété"}
    assert rank_psychologists(patient, all_unavailable, top_n=5) == []


def test_build_psychologist_content_and_patient_query_are_strings():
    content = build_psychologist_content(PSYCHOLOGISTS[0])
    query = build_patient_query({"preferredLanguage": "Français", "medicalHistory": "stress"})
    assert isinstance(content, str) and "Anxiété" in content
    assert isinstance(query, str) and "stress" in query


CITY_PSYCHOLOGISTS = [
    {
        "id": 10,
        "specialty": "Anxiété",
        "bio": "Gestion de l'anxiété.",
        "languages": "Français",
        "city": "Dakar",
        "rating": 4.0,
        "available": True,
    },
    {
        "id": 11,
        "specialty": "Anxiété",
        "bio": "Gestion de l'anxiété.",
        "languages": "Français",
        "city": "Thiès",
        "rating": 4.0,
        "available": True,
    },
]


def test_same_city_bonus_ignores_case_and_accents():
    assert same_city_bonus({"city": "dakar"}, {"city": "Dakar"}) == 1.0
    assert same_city_bonus({"city": "Thiès"}, {"city": "thies"}) == 1.0
    assert same_city_bonus({"city": "Dakar"}, {"city": "Saint-Louis"}) == 0.0
    assert same_city_bonus({}, {"city": "Dakar"}) == 0.0


def test_same_city_breaks_the_tie_between_identical_psychologists():
    # profils identiques : seule la ville doit les départager
    patient = {
        "preferredLanguage": "Français",
        "medicalHistory": "anxiété",
        "city": "dakar",
    }
    results = rank_psychologists(patient, CITY_PSYCHOLOGISTS, top_n=10)
    assert results[0]["id"] == 10
    assert results[0]["cityMatch"] == 1.0
    assert results[1]["cityMatch"] == 0.0
    assert results[0]["score"] > results[1]["score"]


def test_missing_patient_city_penalizes_nobody():
    # sans ville côté patient, le terme vaut 0 pour tout le monde
    patient = {"preferredLanguage": "Français", "medicalHistory": "anxiété"}
    results = rank_psychologists(patient, CITY_PSYCHOLOGISTS, top_n=10)
    assert all(r["cityMatch"] == 0.0 for r in results)
    assert results[0]["score"] == results[1]["score"]


def _run_all_tests():
    # lance tous les tests du module sans dependre de pytest

    test_functions = [
        obj
        for name, obj in globals().items()
        if name.startswith("test_") and callable(obj)
    ]

    passed = 0
    failed = 0

    for test_function in test_functions:
        try:
            test_function()
            passed += 1
            print(f"PASS  {test_function.__name__}")
        except AssertionError as exc:
            failed += 1
            print(f"FAIL  {test_function.__name__}: {exc}")

    print(f"\n{passed} passés, {failed} échoués sur {len(test_functions)} tests")

    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    _run_all_tests()
