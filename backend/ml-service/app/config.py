"""Configuration du service ML, lue depuis les variables d'environnement.

Choix volontaire de ne pas dépendre de pydantic-settings (pour limiter le
nombre de dépendances du service) : un simple module avec des constantes
suffit pour un service MVP.
"""

import os

# Le service ML n'est pas enregistré dans Eureka (contrairement aux services
# Spring Boot) : il appelle user-service via l'API Gateway, en HTTP simple,
# plutôt que via la découverte de service côté client (lb://...).
GATEWAY_URL: str = os.getenv("GATEWAY_URL", "http://localhost:8080")

SERVICE_PORT: int = int(os.getenv("ML_SERVICE_PORT", "8000"))

HTTP_TIMEOUT_SECONDS: float = float(os.getenv("HTTP_TIMEOUT_SECONDS", "5"))

DEFAULT_TOP_N: int = int(os.getenv("DEFAULT_TOP_N", "5"))
MAX_TOP_N: int = int(os.getenv("MAX_TOP_N", "20"))

# Pondération du score final : score = CONTENT_WEIGHT * similarité_cosinus
#                                       + RATING_WEIGHT * (note / 5)
CONTENT_WEIGHT: float = float(os.getenv("CONTENT_WEIGHT", "0.7"))
RATING_WEIGHT: float = float(os.getenv("RATING_WEIGHT", "0.3"))
