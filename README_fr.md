# ARCenal Bridge pour YunoHost

ARCenal Bridge est le connecteur administré entre ARCenal Portail et le module
Dolibarr ARCenal QSSE.

Il porte la seule opération inter-applications : la permission YunoHost protégée
de la passerelle QSSE signée. Il ne modifie jamais la permission principale de
Dolibarr et ne donne aucun accès Dolibarr aux équipiers.

## Ordre d’installation

1. Activer ARCenal QSSE dans Dolibarr et générer la clé d’appairage.
2. Installer ARCenal Portail pour le groupe `equipiers`.
3. Installer ARCenal Bridge, sélectionner les applications Portail et Dolibarr,
   puis renseigner l’URL HTTPS de passerelle et la clé d’appairage.
4. Vérifier l’état de la liaison depuis le panneau ARCenal Bridge.

## Garantie de fonctionnement

Le portail et le bridge ont des cycles de mise à jour séparés. Une mise à jour
d’ARCenal Portail ne change jamais une permission Dolibarr. ARCenal Bridge est
le seul paquet autorisé à créer, vérifier ou supprimer la permission limitée à
la passerelle.
