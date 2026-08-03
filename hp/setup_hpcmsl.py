# -*- coding: utf-8 -*-
from setuphelpers import *
import subprocess, os, logging

logger = logging.getLogger('wapt')

HPCMSL_INSTALL_DIR = r'C:\Program Files\WindowsPowerShell\Modules\HP.Softpaq'
UNINSTALLER        = r'C:\Program Files\WindowsPowerShell\HP.CMSL.UninstallerData\unins000.exe'

def find_file(filename):
    cwd = os.getcwd()
    for root, dirs, files in os.walk(cwd):
        if filename in files:
            found = os.path.join(root, filename)
            logger.info('Fichier trouve : %s', found)
            return found
    logger.error('Fichier introuvable : %s (depuis %s)', filename, cwd)
    return None

def install():
    logger.info('=== Installation HPCMSL ===')
    installer = find_file('hp-cmsl-1.8.6.exe')
    if not installer:
        raise FileNotFoundError('hp-cmsl-1.8.6.exe introuvable dans le paquet')

    proc = subprocess.run([
        installer, '/VERYSILENT', '/NORESTART', '/SUPPRESSMSGBOXES'
    ], capture_output=True, text=True)

    logger.info('>>> Code retour : %d', proc.returncode)
    logger.info('>>> stdout : %s', proc.stdout.strip())
    logger.info('>>> stderr : %s', proc.stderr.strip())

    if not os.path.exists(HPCMSL_INSTALL_DIR):
        raise Exception('HPCMSL absent apres installation')
    logger.info('HPCMSL installe avec succes.')

def uninstall():
    logger.info('=== Desinstallation HPCMSL ===')
    if os.path.exists(UNINSTALLER):
        subprocess.call([UNINSTALLER, '/VERYSILENT', '/NORESTART', '/SUPPRESSMSGBOXES'])
        logger.info('HPCMSL desinstalle.')
    else:
        logger.warning('Desinstalleur introuvable : %s', UNINSTALLER)

def is_installed():
    return os.path.exists(HPCMSL_INSTALL_DIR)
