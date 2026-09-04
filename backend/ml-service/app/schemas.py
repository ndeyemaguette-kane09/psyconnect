# modeles pydantic pour les reponses du service ML

from typing import List, Optional

from pydantic import BaseModel


class PsychologistRecommendation(BaseModel):
    id: int
    firstName: Optional[str] = None
    lastName: Optional[str] = None
    profilePicture: Optional[str] = None
    specialty: Optional[str] = None
    bio: Optional[str] = None
    languages: Optional[str] = None
    city: Optional[str] = None
    yearsOfExperience: Optional[int] = None
    consultationPrice: Optional[int] = None
    rating: Optional[float] = None
    totalReviews: Optional[int] = None
    available: Optional[bool] = None

    # champs calculés par le moteur de reco
    contentSimilarity: float
    cityMatch: float
    score: float


class RecommendationResponse(BaseModel):
    patientId: int
    count: int
    recommendations: List[PsychologistRecommendation]
