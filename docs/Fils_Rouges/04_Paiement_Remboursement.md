# 04 — Le patient paie, le psy encaisse, le patient annule

Ce fil suit l'argent : de la recharge du solde du patient jusqu'au revenu net du psychologue, en passant
par la commission de la plateforme et le remboursement. Trois services y participent : `payment-service`,
`user-service` (qui tient le solde du patient) et `appointment-service`.

Vérifié dans le code le 24/09/2026. **Tout paiement est simulé** : aucune somme réelle ne circule.

---

## En une phrase

Le patient paie un rendez-vous confirmé depuis son Solde PsyConnect ; payment-service débite le solde via
user-service, enregistre le paiement, et recrédite automatiquement si l'enregistrement échoue.

## Étape 0 — Recharger le solde

Écran de recharge : le patient choisit Wave ou Orange Money et un montant. Appel
`POST /patients/{id}/wallet/deposit` → `PatientProfileServiceImpl.depositToWallet` (ligne 260).

- Vérifie que le montant est positif et que le profil appartient à l'appelant (`findOwnedPatientProfile`).
- Ajoute le montant au solde, enregistre un mouvement `DEPOSIT` dans l'historique, notifie le patient.

**Rien n'est prélevé chez Wave ou Orange Money** : l'opérateur est juste un libellé. C'est le « paiement
simulé » assumé dans le mémoire.

## Étape 1 — Le rendez-vous doit être confirmé

On ne paie pas une demande : on paie un rendez-vous que le psychologue a **accepté** (statut `CONFIRMED`).
Voir le fil 03 pour la réservation.

## Étape 2 — L'application envoie le paiement

`frontend/psyconnect/lib/features/patient/screens/appointments_tab.dart`, ligne 210 : l'application envoie
`POST /payments` avec l'identifiant du rendez-vous et `amount: price`, le tarif affiché du psychologue.

**Le serveur n'utilise pas ce montant.** Depuis le 24/09/2026, payment-service va lire lui-même le tarif du
psychologue dans user-service (`OwnershipResolver.getConsultationPrice`, `GET /psychologists/{id}`) et
débite ce tarif-là. Si le tarif n'est pas renseigné, le paiement est refusé avant tout débit. C'est
l'application directe de « le client déclare, le serveur prouve ».

## Étape 3 — payment-service vérifie (`PaymentServiceImpl.createPayment`, ligne 93)

1. **Il récupère le rendez-vous** auprès d'appointment-service (ligne 97) : statut, patient, psychologue.
2. **L'appelant est bien le patient de ce rendez-vous** (ligne 99) : rôle PATIENT, et son identité
   résolue depuis le jeton (`OwnershipResolver.resolveOwnPatientId()`) égale le `patientId` du rendez-vous.
3. **Le rendez-vous n'est ni annulé ni refusé** (ligne 106).
4. **Il est confirmé** (ligne 113) : sinon « doit d'abord être confirmé par le psychologue ».
5. **Il n'est pas déjà payé** (ligne 121) : un seul paiement `COMPLETED` par rendez-vous.

## Étape 4 — Débiter, puis enregistrer : la compensation

C'est le passage le plus important du fil (lignes 131 à 187).

```java
walletClient.debit(appointment.getPatientId(), amount);   // 1. user-service retire l'argent
try {
    Payment payment = ... COMPLETED ...;
    paymentRepository.save(payment);                      // 2. payment-service enregistre
    sendPaymentNotification(appointment);                 // 3. notifications (non bloquantes)
} catch (RuntimeException ex) {
    walletClient.credit(appointment.getPatientId(), amount);  // 4. si 2 échoue : on rend l'argent
    throw ex;
}
```

Le problème : le solde est dans la base de user-service, le paiement dans celle de payment-service. **Une
transaction de base de données ne peut pas couvrir deux bases.** Si le débit réussit et que
l'enregistrement échoue, le patient a perdu de l'argent pour rien.

La réponse : une **compensation**. On annule l'effet de l'étape 1 par une opération inverse (le recrédit).
C'est le principe du patron *Saga*, appliqué ici à la main sur deux étapes, sans orchestrateur.

Détail à savoir dire : **l'échec d'une notification ne déclenche pas la compensation** (lignes 158-169).
Le paiement est valide même si personne n'a été prévenu.

Le débit lui-même (`PatientProfileServiceImpl.debitWallet`, ligne 328) refuse si le solde est insuffisant :
« Rechargez votre solde avant de payer ce rendez-vous. »

## Étape 5 — Les notifications (`sendPaymentNotification`, ligne 395)

Deux notifications `PAYMENT` : « Paiement confirmé » au patient, « Paiement reçu » au psychologue.

## Étape 6 — Le revenu du psychologue et la commission

`getPsychologistRevenue` (ligne 222) additionne les paiements `COMPLETED` du psychologue, puis applique la
commission de la plateforme (`applyCommission`, ligne 376) :

```
net = brut − brut × taux / 100
```

Le taux est dans `PlatformSettings` : **20 % par défaut**, réglable par l'admin
(`PUT /admin/platform-settings/commission-rate`). Sur une séance à 15 000 F : 3 000 F pour la plateforme,
12 000 F pour le psychologue.

Le psychologue peut retirer son solde disponible (`withdraw`, ligne 299) : revenu net total moins ce qu'il a
déjà retiré. Retrait simulé, lui aussi.

Point d'architecture : le paiement **recopie** `psychologistId`, `patientId` et l'heure du rendez-vous
(lignes 150-154). Ainsi le calcul des revenus ne fait aucun appel à appointment-service. C'est une
**dénormalisation volontaire** : un peu de duplication contre de l'indépendance entre services.

## Étape 7 — L'annulation et la règle des 48 heures

`AppointmentServiceImpl`, lignes 297 à 323 :

- **seul le patient peut annuler** (ligne 297) ;
- si le rendez-vous est à **48 heures ou plus**, appointment-service demande le remboursement à
  payment-service (`PaymentClient.refundCompletedPayments`, protégé par `@Retry` et `@CircuitBreaker`) ;
- sinon, annulation sans remboursement, et le message le dit au patient.

Côté payment-service (`refundCompletedPayments`) : **trois contrôles d'abord** (ajoutés le 24/09/2026),
puis chaque paiement `COMPLETED` passe en `REFUNDED` et le total est recrédité sur le solde du patient.

1. l'appelant est un patient, et c'est **le patient de ce rendez-vous** (identité résolue depuis le jeton) ;
2. le rendez-vous est bien **`CANCELLED`** ;
3. il commence **dans 48 heures ou plus**.

Pour que le contrôle 2 fonctionne, appointment-service **enregistre l'annulation avant** d'appeler le
remboursement (l'ordre a été inversé dans `updateAppointmentStatus`). Les contrôles ne font pas confiance
à appointment-service : ils sont refaits là où l'argent bouge.

Si payment-service est injoignable, la méthode de repli journalise « Un remboursement manuel est
nécessaire » : l'annulation reste valide, le remboursement devient une tâche humaine.

---

## Ce que ce fil démontre

| Notion | Où |
|---|---|
| Base de données par service | solde dans user-service, paiements dans payment-service |
| Cohérence sans transaction distribuée | compensation après débit (étape 4) |
| Contrôle de propriété côté serveur | `createPayment`, étape 3 point 2 ; `refundCompletedPayments` |
| Le serveur ne croit pas le montant du client | `getConsultationPrice`, étape 2 |
| Règle métier | 48 heures, un seul paiement par rendez-vous |
| Dénormalisation assumée | champs recopiés dans `Payment` |
| Tolérance aux pannes | notifications non bloquantes, repli du remboursement |

## Limites et failles à connaître

Ces points ont été trouvés en relisant le code pour ce fil. Ils ne figurent pas dans `Audit_Securite.md`.

1. **Corrigé le 24/09/2026 — le montant venait de l'application.** Un patient qui modifiait la requête
   pouvait payer 1 F une séance à 15 000 F. payment-service relit maintenant le tarif dans user-service.
2. **Corrigé le 24/09/2026 — le remboursement pouvait être appelé directement**, sans règle des 48 heures
   ni vérification du patient. Les trois contrôles sont maintenant faits dans payment-service.
3. **La commission est rétroactive.** Le revenu net est recalculé à chaque consultation avec le taux
   actuel. Si l'admin passe de 20 % à 25 %, le revenu des séances passées change. Correctif : enregistrer
   le taux, ou le montant net, dans chaque `Payment` au moment du paiement.
4. **Le débit du solde n'est pas protégé contre deux paiements simultanés** : lecture du solde, calcul,
   écriture, sans verrou. Deux requêtes en même temps pourraient passer avec un solde qui n'en couvre
   qu'une.
5. **La compensation elle-même peut échouer** (lignes 177-185) : dans ce cas, on journalise et l'argent
   reste débité. Une vraie Saga aurait une file de reprise.

À dire en soutenance, formulé comme une démarche : « En traçant le parcours de l'argent, j'ai trouvé deux
contrôles qui manquaient côté serveur, sur le montant et sur le remboursement. Je les ai corrigés : le
serveur relit le tarif lui-même, et le remboursement revérifie le patient, l'annulation et le délai de 48
heures. Des tests unitaires couvrent les deux cas. »

## Questions probables du jury

**« Pourquoi pas une transaction distribuée (2PC) ? »**
Le protocole à deux phases bloque les ressources et suppose que toutes les bases le supportent. Dans une
architecture microservices, on préfère la cohérence à terme avec compensation. Ici la compensation est
écrite à la main, sur deux étapes ; au-delà, on passerait à une Saga orchestrée.

**« Pourquoi le solde est-il dans user-service et pas dans payment-service ? »**
Parce que le solde appartient au patient et a d'abord été construit avec son profil. Le paiement a ensuite
été sorti dans un service dédié. C'est défendable, mais c'est aussi ce qui oblige à la compensation : si le
solde et les paiements étaient dans la même base, une seule transaction suffirait.

**« Et les vrais paiements ? »**
Hors périmètre : il faudrait un agrégateur de paiement (API Wave ou Orange Money), des webhooks de
confirmation et une réconciliation. L'écran de recharge est prêt à recevoir cette intégration.
