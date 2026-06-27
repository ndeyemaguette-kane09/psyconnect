"""Client HTTP vers user-service, via l'API Gateway.

Le service ML n'étant pas enregistré dans Eureka, il ne peut pas résoudre
`USER-SERVICE` côté client comme le font les services Spring Boot
(@LoadBalanced RestTemplate). Il passe donc systématiquement par la même
porte d'entrée que le frontend Flutter : l'API Gateway (GATEWAY_URL).
"""

from typing import Any, Dict, List, Optional

import httpx

from app import config


class PatientNotFoundError(Exception):
    """Le profil patient demandé n'existe pas (404 côté user-service)."""


class UserServiceUnavailableError(Exception):
    """user-service (via la gateway) n'a pas répondu correctement."""


def _auth_headers(authorization: Optional[str]) -> Dict[str, str]:
    """`GET /patients/{id}` exige un JWT côté user-service (`.authenticated()`).

    Le service ML n'a pas de compte/jeton propre : il relaie simplement le
    en-tête Authorization du patient qui a initié l'appel (transmis par le
    frontend, ou par Postman dans les tests), exactement comme le ferait
    n'importe quel autre appel passant par la gateway.
    """

    if not authorization:
        return {}
    return {"Authorization": authorization}


async def fetch_patient_profile(
    patient_id: int, authorization: Optional[str] = None
) -> Dict[str, Any]:
    url = f"{config.GATEWAY_URL}/patients/{patient_id}"

    try:
        async with httpx.AsyncClient(timeout=config.HTTP_TIMEOUT_SECONDS) as client:
            response = await client.get(url, headers=_auth_headers(authorization))
    except httpx.HTTPError as exc:
        raise UserServiceUnavailableError(str(exc)) from exc

    if response.status_code == 404:
        raise PatientNotFoundError(f"Patient {patient_id} non trouvé")

    if response.status_code != 200:
        raise UserServiceUnavailableError(
            f"Réponse inattendue de user-service ({response.status_code})"
        )

    return response.json()


async def fetch_psychologists(authorization: Optional[str] = None) -> List[Dict[str, Any]]:
    # GET /psychologists est public côté user-service (permitAll), mais on
    # relaie aussi le jeton ici par cohérence : ça ne change rien au résultat.
    url = f"{config.GATEWAY_URL}/psychologists"

    try:
        async with httpx.AsyncClient(timeout=config.HTTP_TIMEOUT_SECONDS) as client:
            response = await client.get(url, headers=_auth_headers(authorization))
    except httpx.HTTPError as exc:
        raise UserServiceUnavailableError(str(exc)) from exc

    if response.status_code != 200:
        raise UserServiceUnavailableError(
            f"Réponse inattendue de user-service ({response.status_code})"
        )

    return response.json()
