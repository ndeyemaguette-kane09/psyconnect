FROM python:3.12-slim
WORKDIR /app

# installer les dépendances d'abord (layer cachée si requirements.txt ne change pas)
COPY requirements.txt .
RUN pip install --no-cache-dir --timeout=120 --retries=5 -r requirements.txt

# copier le code applicatif
COPY app app

EXPOSE 8000
CMD ["python", "-m", "app.main"]
