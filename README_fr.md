# ARCenal Bridge pour YunoHost

ARCenal Bridge est le composant d’administration de la liaison entre ARCenal Portail et le module ARCenal QSSE dans Dolibarr.

## Rôle

Il sélectionne les deux applications installées, vérifie que l’adresse de passerelle appartient bien à l’instance Dolibarr choisie, crée une permission YunoHost limitée à cette seule route, échange le code temporaire créé par le module, puis écrit la configuration du portail.

Le portail ne modifie jamais Dolibarr. Dolibarr ne rend jamais son interface générale accessible aux équipiers.

## Parcours administrateur

1. Installer ARCenal Portail et choisir le groupe LDAP des équipiers.
2. Dans Dolibarr, créer un code temporaire depuis ARCenal QSSE.
3. Installer ARCenal Bridge, choisir le portail et Dolibarr, puis saisir l’URL et le code affichés.
4. Utiliser le bouton « Vérifier la liaison » dans la configuration de Bridge.

Le code est consommé une seule fois. Pour reconnecter le portail, créer un nouveau code dans Dolibarr et le saisir dans Bridge.

## Statut

Cette branche constitue la nouvelle base d’architecture. Elle doit être qualifiée sur une instance YunoHost 12.1 de recette avant toute publication dans le catalogue ARCenal.
