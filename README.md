## Présentation
Ce script PowerShell permet de remettre à zéro l’inscription d’un appareil dans Azure AD / Entra ID et Intune, notamment lorsqu’un poste rencontre des erreurs d’inscription MDM, des problèmes de clés, ou des conflits liés à l’authentification.
Il est particulièrement utile dans les situations suivantes :

- Erreur MDM 0x8018000b
- Messages du type “Le jeu de clés n’existe pas”
- Échecs d’inscription MMP-C
- Clés TPM corrompues ou introuvables
- Conflits entre Azure AD Join, Workplace Join et MDM
- Appareil bloqué dans un état d’inscription incohérent
- Nettoyage après suppression de l’appareil dans Intune / Azure AD

L’objectif est de repartir sur une base propre avant une nouvelle inscription.

## Ce que fait le script

Le script exécute les opérations suivantes :
- Affiche l’état actuel de l’inscription (dsregcmd /status)
- Permet de quitter Azure AD / MDM (dsregcmd /leave)
-	Supprime les clés de registre liées à l’inscription MDM/Intune
-	Nettoie les comptes OMADM résiduels
-	Supprime les certificats d’accès organisationnel liés à Intune
-	Affiche un rappel concernant le TPM si nécessaire
-	Propose des options pour sauter certaines étapes (utile en production)
  
Chaque section est expliquée et peut être validée manuellement à l’exécution.

## Prérequis

-	Le script doit être exécuté en tant qu’administrateur.
-	Vérifiez que BitLocker n’utilise pas le TPM avant d’envisager un “TPM Clear”.
-	Pensez à sauvegarder les données critiques si vous travaillez sur un poste sensible.

## Utilisation
- Télécharger le script :
  
  				Clonez le repository ou récupérez directement le fichier .ps1
  
- Lancer Powershell en mode administrateur :
  
  				Start-Process powershell -Verb RunAs
  
- Exécuter le script :
  			
  				.\Clean-DeviceAADMDM.ps1
  
Vous pouvez utiliser les paramètres disponibles
  
  				-SkipDsregleave => Ignore l'étape dsregcmd /leave
  				-SkipRegCleanup => Ignore le nettoyage des clés de registre MDM
  				-SkipCertCleanup => Ignore la suppression des certificats organisation

Le script pose quelques questions avant d’exécuter certaines actions sensibles (comme la commande dsregcmd /leave).

## Après exécution 
Une fois le nettoyage terminé : 
- Redémarrez la machine.
- Reprennez l'inscription :
  	-	Azure AD Join
  	-	Hybrid Join
  	-	ou Intune MDM auto-enrollment (selon votre environement)
- Vérifiez l'état avec:
  dsregcmd /status

	
