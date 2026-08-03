# -*- coding: utf-8 -*-
from setuphelpers import *
import logging, winreg, os
from datetime import datetime

logger = logging.getLogger('wapt')

SEUIL_JOURS = 30
NB_LIGNES_LOG = 50  # nombre de dernières lignes du log à afficher

def audit():
    try:
        key = winreg.OpenKey(
            winreg.HKEY_LOCAL_MACHINE,
            r'SOFTWARE\WAPT\DriverUpdate',
            0,
            winreg.KEY_READ | winreg.KEY_WOW64_64KEY
        )

        last_run  = winreg.QueryValueEx(key, 'LastRun')[0]
        status    = winreg.QueryValueEx(key, 'LastStatus')[0]
        exit_code = int(winreg.QueryValueEx(key, 'LastExitCode')[0])
        detail    = winreg.QueryValueEx(key, 'LastDetail')[0]
        log_file  = winreg.QueryValueEx(key, 'LastLogFile')[0]
        manufact  = winreg.QueryValueEx(key, 'Manufacturer')[0]
        winreg.CloseKey(key)

        try:
            last_run_dt = datetime.strptime(last_run, "%Y-%m-%d %H:%M")
            age_jours   = (datetime.now() - last_run_dt).days
            age_str     = "{} jour(s)".format(age_jours)
        except Exception:
            age_jours = 999
            age_str   = "inconnue"

        # Lecture des dernières lignes du log
        log_extract = ""
        if log_file and os.path.exists(log_file):
            try:
                with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
                    lines = f.readlines()
                    last_lines = lines[-NB_LIGNES_LOG:] if len(lines) > NB_LIGNES_LOG else lines
                    log_extract = ''.join(last_lines).strip()
            except Exception as e:
                log_extract = "Impossible de lire le log : {}".format(e)
        else:
            log_extract = "Fichier log introuvable : {}".format(log_file)

        codes_ok = (0, 1, 2, 102, 256, 257, 500, 3010, 3020)

        if not manufact:
            print('WARNING : Fabricant inconnu - aucune MAJ applicable')
            return 'WARNING'

        if age_jours > SEUIL_JOURS:
            print('WARNING : {} | {} | Derniere execution il y a {} | {}\n--- Extrait log ---\n{}'.format(
                manufact, status, age_str, detail, log_extract))
            return 'WARNING'

        if exit_code not in codes_ok:
            print('ERROR : {} | Code {} | {} | {}\n--- Extrait log ---\n{}'.format(
                manufact, exit_code, status, detail, log_extract))
            return 'ERROR'

        print('OK : {} | {} | Derniere execution il y a {} | {}\n--- Extrait log ---\n{}'.format(
            manufact, status, age_str, detail, log_extract))
        return 'OK'

    except FileNotFoundError:
        print('WARNING : Aucune execution detectee - cle registre introuvable')
        return 'WARNING'
    except Exception as e:
        print('ERROR : {}'.format(str(e)))
        return 'ERROR'

def install():
    pass

def uninstall():
    pass

def is_installed():
    return True
