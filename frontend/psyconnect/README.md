# Application mobile PsyConnect

Application Flutter de PsyConnect, avec trois interfaces selon le rôle de l'utilisateur : patient, psychologue et administrateur.

## Lancer

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<adresse-du-mac>:8080
```

Sans `API_BASE_URL`, l'application utilise `localhost:8080` (simulateur iOS, web) ou `10.0.2.2:8080` (émulateur Android). Sur un téléphone physique, il faut indiquer l'adresse du Mac qui fait tourner le back-end.

## Organisation

- `lib/core` : thème, composants communs, client HTTP, adresses de l'API
- `lib/features` : un dossier par domaine (auth, home, patient, psychologist, admin, payment, call, companion, journal, messaging)
- `test` : tests des modèles et tests de widgets

## Tests

```bash
flutter test
```
