# service ML de recommandation de psy.
# compare le profil patient et le profil psy avec TF-IDF + cosinus
# pas dans Eureka, la gateway route direct vers /recommendations/**
# et on rappelle user-service via la gateway aussi

from typing import Optional

from fastapi import FastAPI, Header, HTTPException, Query

from app import config
from app.recommender import rank_psychologists
from app.schemas import PsychologistRecommendation, RecommendationResponse
from app.user_service_client import (
    PatientNotFoundError,
    UserServiceUnavailableError,
    fetch_patient_profile,
    fetch_psychologists,
)

app = FastAPI(
    title="PsyConnect ML Service",
    description="Recommandation de psychologues par filtrage de contenu (TF-IDF + cosinus).",
    version="1.0.0",
)


@app.get("/health")
async def health() -> dict:
    return {"status": "ok", "service": "ml-service"}


@app.get("/recommendations/{patient_id}", response_model=RecommendationResponse)
async def get_recommendations(
    patient_id: int,
    top_n: int = Query(
        default=config.DEFAULT_TOP_N,
        ge=1,
        le=config.MAX_TOP_N,
        description="nombre max de psy a retourner",
    ),
    authorization: Optional[str] = Header(
        default=None,
        description="jeton JWT du patient (ex: 'Bearer <token>'), relayé tel quel vers user-service",
    ),
) -> RecommendationResponse:

    try:
        patient = await fetch_patient_profile(patient_id, authorization)
        psychologists = await fetch_psychologists(authorization)
    except PatientNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except UserServiceUnavailableError as exc:
        raise HTTPException(
            status_code=502,
            detail=f"user-service indisponible : {exc}",
        ) from exc

    ranked = rank_psychologists(
        patient,
        psychologists,
        top_n=top_n,
        content_weight=config.CONTENT_WEIGHT,
        rating_weight=config.RATING_WEIGHT,
    )

    return RecommendationResponse(
        patientId=patient_id,
        count=len(ranked),
        recommendations=[PsychologistRecommendation(**item) for item in ranked],
    )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app.main:app", host="0.0.0.0", port=config.SERVICE_PORT, reload=False)
