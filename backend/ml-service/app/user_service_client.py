# client HTTP vers user-service, via la gateway.
# le service ML est pas dans Eureka, donc il passe par la gateway
# comme Flutter, pas par un appel direct entre services

from typing import Any, Dict, List, Optional

import httpx

from app import config


class PatientNotFoundError(Exception):
    # profil patient pas trouvé (404 cote user-service)
    pass


class UserServiceUnavailableError(Exception):
    # user-service (via la gateway) a pas répondu correctement
    pass


def _auth_headers(authorization: Optional[str]) -> Dict[str, str]:
    # GET /patients/{id} exige un JWT. le service ML a pas son propre jeton,
    # donc on relaie juste celui du patient qui a appelé

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
    # GET /psychologists est public, mais on relaie le jeton quand meme.
    # verifiedOnly=true : un psy pas encore approuve (ou refuse) par l'admin
    # ne doit jamais etre recommande a un patient, meme via le scoring ML
    url = f"{config.GATEWAY_URL}/psychologists?verifiedOnly=true"

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
