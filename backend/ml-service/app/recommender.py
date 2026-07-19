# compare le profil patient et celui de chaque psy avec TF-IDF + cosinus.
# fait a la main avec numpy, pas scikit-learn

from __future__ import annotations

import math
import re
import unicodedata
from typing import Any, Dict, List, Sequence, Tuple

import numpy as np

# mots vides FR a virer, sinon ils faussent la similarité
FRENCH_STOPWORDS = frozenset(
    {
        "le", "la", "les", "un", "une", "des", "de", "du", "et", "en",
        "je", "tu", "il", "elle", "on", "nous", "vous", "ils", "elles",
        "ce", "cet", "cette", "ces", "mon", "ma", "mes", "ton", "ta",
        "tes", "son", "sa", "ses", "au", "aux", "avec", "sans", "pour",
        "par", "sur", "dans", "est", "sont", "etre", "avoir", "que",
        "qui", "quoi", "ne", "pas", "plus", "tres", "tres", "se", "sa",
        "ai", "as", "a", "ont", "suis", "es", "etais", "etait", "me",
        "te", "lui", "leur", "y", "d", "l", "j", "n", "qu", "s",
    }
)


def normalize_text(text: str) -> str:
    # minuscule + retire les accents (ex: "Anxiete" -> "anxiete")

    if not text:
        return ""

    text = text.lower()
    text = unicodedata.normalize("NFKD", text)
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    return text


def tokenize(text: str) -> List[str]:
    # decoupe le texte normalisé en mots (que lettres/chiffres)

    normalized = normalize_text(text)
    tokens = re.findall(r"[a-z0-9]+", normalized)
    return [t for t in tokens if t not in FRENCH_STOPWORDS and len(t) > 1]


def build_tfidf_matrix(documents: Sequence[str]) -> Tuple[np.ndarray, List[str]]:
    # matrice TF-IDF (documents x vocabulaire).
    # TF = freq du mot, normalisée par la taille du texte
    # IDF = formule smooth, comme scikit-learn

    tokenized_docs = [tokenize(doc) for doc in documents]

    vocabulary = sorted({token for doc in tokenized_docs for token in doc})
    vocab_index = {term: idx for idx, term in enumerate(vocabulary)}

    n_docs = len(documents)
    n_terms = len(vocabulary)

    tf = np.zeros((n_docs, n_terms), dtype=float)

    for doc_idx, tokens in enumerate(tokenized_docs):
        if not tokens:
            continue
        for token in tokens:
            tf[doc_idx, vocab_index[token]] += 1.0
        tf[doc_idx] /= len(tokens)

    if n_terms == 0:
        return tf, vocabulary

    document_frequency = np.count_nonzero(tf > 0, axis=0)
    idf = np.log((1.0 + n_docs) / (1.0 + document_frequency)) + 1.0

    tfidf = tf * idf
    return tfidf, vocabulary


def cosine_similarity(vector_a: np.ndarray, vector_b: np.ndarray) -> float:
    # similarité cosinus entre 2 vecteurs, 0.0 si un des deux est nul

    norm_a = np.linalg.norm(vector_a)
    norm_b = np.linalg.norm(vector_b)

    if norm_a == 0.0 or norm_b == 0.0:
        return 0.0

    similarity = float(np.dot(vector_a, vector_b) / (norm_a * norm_b))

    # normalement deja entre 0 et 1, mais on securise au cas ou
    return max(0.0, min(1.0, similarity))


def build_psychologist_content(psychologist: Dict[str, Any]) -> str:
    # texte du profil psy pour le TF-IDF

    parts = [
        psychologist.get("specialty") or "",
        psychologist.get("bio") or "",
        psychologist.get("languages") or "",
    ]
    return " ".join(parts)


def build_patient_query(patient: Dict[str, Any]) -> str:
    # texte de ce que recherche le patient pour le TF-IDF

    parts = [
        patient.get("preferredLanguage") or "",
        patient.get("medicalHistory") or "",
    ]
    return " ".join(parts)


def rank_psychologists(
    patient: Dict[str, Any],
    psychologists: Sequence[Dict[str, Any]],
    top_n: int = 5,
    content_weight: float = 0.7,
    rating_weight: float = 0.3,
) -> List[Dict[str, Any]]:
    # classe les psy dispos pour un patient.
    # score = content_weight * similarité + rating_weight * (note/5)
    # si le patient a rien renseigné, la similarité vaut 0 partout
    # et ca retombe juste sur la note, les mieux notés en premier

    available_psychologists = [
        p for p in psychologists if p.get("available", True)
    ]

    if not available_psychologists:
        return []

    patient_query = build_patient_query(patient)
    documents = [patient_query] + [
        build_psychologist_content(p) for p in available_psychologists
    ]

    tfidf_matrix, _vocabulary = build_tfidf_matrix(documents)
    patient_vector = tfidf_matrix[0]

    ranked: List[Dict[str, Any]] = []

    for offset, psychologist in enumerate(available_psychologists, start=1):
        similarity = cosine_similarity(patient_vector, tfidf_matrix[offset])

        rating = psychologist.get("rating") or 0.0
        rating_normalized = max(0.0, min(rating / 5.0, 1.0))

        score = (
            content_weight * similarity
            + rating_weight * rating_normalized
        )

        ranked.append(
            {
                **psychologist,
                "contentSimilarity": round(similarity, 4),
                "score": round(score, 4),
            }
        )

    ranked.sort(key=lambda item: item["score"], reverse=True)

    return ranked[: max(0, top_n)]
