// valeurs partagees par l'inscription et l'edition du profil patient

class ProfileConstants {
  ProfileConstants._();

  // la langue alimente la recommandation, on la demande des l'inscription
  static const List<String> languages = ['Français', 'Wolof', 'Anglais'];

  // plateforme deployee au Senegal : pre-rempli, modifiable dans le profil
  static const String defaultCountry = 'Sénégal';
}
