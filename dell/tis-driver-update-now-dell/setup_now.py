# -*- coding: utf-8 -*-
from setuphelpers import *
import subprocess, os, logging

logger = logging.getLogger('wapt')

DELL_CLI = r'C:\Program Files\Dell\CommandUpdate\dcu-cli.exe'
LOG_DIR  = r'C:\Logs\wapt-drivers'

def install():
    os.makedirs(LOG_DIR, exist_ok=True)
    log = os.path.join(LOG_DIR, 'dell_update_now.log')

    if not os.path.exists(DELL_CLI):
        logger.error('dcu-cli.exe introuvable : %s — tis-dell-command-update-uwp est-il deploye ?', DELL_CLI)
        return

    logger.info('Lancement Dell Command Update...')
    with open(log, 'w') as lf:
        result = subprocess.call([
            DELL_CLI,
            '/applyUpdates',
            '-reboot=disable'
        ], stdout=lf, stderr=lf)

    logger.info('Dell termine. Code retour : %d. Log : %s', result, log)

    # Codes retour connus
    codes = {
        0:   'Aucune MAJ necessaire',
        1:   'MAJ installees avec succes',
        2:   'Redemarrage requis',
        102: 'Redemarrage en attente - relancer apres redemarrage'
    }
    logger.info('Statut : %s', codes.get(result, 'Code inattendu : {}'.format(result)))

def uninstall():
    pass

def is_installed():
    return False
