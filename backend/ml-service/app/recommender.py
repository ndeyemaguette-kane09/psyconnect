"""Moteur de recommandation par filtrage de contenu (content-based filtering).

PsyConnect (mémoire M2 SIR) recommande des psychologues à un patient en
comparant le "contenu" du profil patient (langue préférée + motif/historique)
à celui de chaque psychologue (spécialité + bio + langues parlées), via une
représentation TF-IDF et une similarité cosinus.

Implémentation volontairement "maison" (numpy + bibliothèque standard,
sans scikit-learn) : cela permet de tester le moteur dans un environnement
sans accès réseau pour installer des dépendances, et documente explicitement
la formule mathématique utilisée pour le mémoire.
"""

from __future__ import annotations

import math
import re
import unicodedata
from typing import Any, Dict, List, Sequence, Tuple

import numpy as np

# Mots vides français très fréquents : on les retire avant de construire le
# vocabulaire pour qu'ils ne polluent pas la similarité (ils apparaîtraient
# dans presque tous les documents et n'apportent aucune information).
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
    """Minuscule + suppression des accents (ex: 'Anxiété' -> 'anxiete')."""

    if not text:
        return ""

    text = text.lower()
    text = unicodedata.normalize("NFKD", text)
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    return text


def tokenize(text: str) -> List[str]:
    """Découpe un texte normalisé en mots (lettres/chiffres uniquement)."""

    normalized = normalize_text(text)
    tokens = re.findall(r"[a-z0-9]+", normalized)
    return [t for t in tokens if t not in FRENCH_STOPWORDS and len(t) > 1]


def build_tfidf_matrix(documents: Sequence[str]) -> Tuple[np.ndarray, List[str]]:
    """Construit une matrice TF-IDF (documents x vocabulaire).

    - TF : fréquence du terme dans le document, normalisée par la longueur
      du document (pour ne pas avantager les documents les plus longs).
    - IDF : variante "smooth" (comme scikit-learn) :
      idf(t) = ln((1 + N) / (1 + df(t))) + 1
      où N = nombre de documents et df(t) = nombre de documents contenant t.
    """

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
    """Similarité cosinus entre deux vecteurs ; 0.0 si un des deux est nul."""

    norm_a = np.linalg.norm(vector_a)
    norm_b = np.linalg.norm(vector_b)

    if norm_a == 0.0 or norm_b == 0.0:
        return 0.0

    similarity = float(np.dot(vector_a, vector_b) / (norm_a * norm_b))

    # Par construction (TF-IDF non négatif), la similarité est dans [0, 1],
    # mais on protège contre d'éventuelles imprécisions flottantes.
    return max(0.0, min(1.0, similarity))


def build_psychologist_content(psychologist: Dict[str, Any]) -> str:
    """Texte représentant le profil du psychologue pour le TF-IDF."""

    parts = [
        psychologist.get("specialty") or "",
        psychologist.get("bio") or "",
        psychologist.get("languages") or "",
    ]
    return " ".join(parts)


def build_patient_query(patient: Dict[str, Any]) -> str:
    """Texte représentant ce que recherche le patient pour le TF-IDF."""

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
    """Classe les psychologues disponibles pour un patient donné.

    score = content_weight * similarité_cosinus + rating_weight * (note / 5)

    Si le patient n'a renseigné ni langue préférée ni historique (aucun
    contenu textuel), la similarité cosinus de tous les psychologues vaut 0
    et le classement retombe naturellement sur le second terme : les
    psychologues les mieux notés sont alors recommandés en priorité. Ce repli
    est une conséquence directe de la formule, pas un cas particulier codé
    à part.
    """

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
