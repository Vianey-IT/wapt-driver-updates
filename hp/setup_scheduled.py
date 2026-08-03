# -*- coding: utf-8 -*-
from setuphelpers import *
import subprocess, os, shutil, logging, winreg

logger = logging.getLogger('wapt')

TASK_NAME  = 'WAPT-DriverUpdate-HP'
SCRIPT_DST = r'C:\Scripts\wapt\run_driver_updates_hp.ps1'

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
    logger.info('=== Installation tache planifiee HP ===')
    logger.info('CWD : %s', os.getcwd())

    script_src      = find_file('run_driver_updates_hp.ps1')
    create_task_src = find_file('create_task_hp.ps1')

    if not script_src:
        raise FileNotFoundError('run_driver_updates_hp.ps1 introuvable dans le paquet')
    if not create_task_src:
        raise FileNotFoundError('create_task_hp.ps1 introuvable dans le paquet')

    os.makedirs(os.path.dirname(SCRIPT_DST), exist_ok=True)
    shutil.copy2(script_src, SCRIPT_DST)
    logger.info('Script copie vers : %s', SCRIPT_DST)

    proc = subprocess.run([
        'powershell.exe',
        '-NonInteractive',
        '-ExecutionPolicy', 'Bypass',
        '-File', create_task_src
    ], capture_output=True, text=True)

    logger.info('>>> PowerShell stdout : %s', proc.stdout.strip())
    logger.info('>>> PowerShell stderr : %s', proc.stderr.strip())
    logger.info('>>> Code retour       : %d', proc.returncode)

    if proc.returncode == 0:
        logger.info('Tache "%s" creee avec succes.', TASK_NAME)
    else:
        logger.error('Echec creation tache (code %d).', proc.returncode)

def uninstall():
    logger.info('=== Suppression tache planifiee HP ===')
    subprocess.call([
        'powershell.exe', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
        '-Command', 'Unregister-ScheduledTask -TaskName "{}" -Confirm:$false -ErrorAction SilentlyContinue'.format(TASK_NAME)
    ])
    if os.path.exists(SCRIPT_DST):
        os.remove(SCRIPT_DST)
        logger.info('Script supprime : %s', SCRIPT_DST)

def is_installed():
    result = subprocess.call([
        'powershell.exe', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
        '-Command', 'Get-ScheduledTask -TaskName "{}" -ErrorAction SilentlyContinue'.format(TASK_NAME)
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return result == 0

def audit():
    try:
        result = subprocess.call([
            'powershell.exe', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
            '-Command', 'Get-ScheduledTask -TaskName "{}" -ErrorAction SilentlyContinue'.format(TASK_NAME)
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        if result != 0:
            print('ERROR : Tache {} absente'.format(TASK_NAME))
            return 'ERROR'

        key = winreg.OpenKey(
            winreg.HKEY_LOCAL_MACHINE,
            r'SOFTWARE\WAPT\DriverUpdate',
            0,
            winreg.KEY_READ | winreg.KEY_WOW64_64KEY
        )

        last_run  = winreg.QueryValueEx(key, 'LastRun')[0]
        status    = winreg.QueryValueEx(key, 'LastStatus')[0]
        exit_code = int(winreg.QueryValueEx(key, 'LastExitCode')[0])
        winreg.CloseKey(key)

        if exit_code in (0, 1, 2, 256, 257, 3010, 3020):
            print('OK : Tache presente - {} - {}'.format(last_run, status))
            return 'OK'
        else:
            print('ERROR : Tache presente mais derniere MAJ en erreur (code {})'.format(exit_code))
            return 'ERROR'

    except FileNotFoundError:
        print('WARNING : Tache presente mais aucune execution detectee')
        return 'WARNING'
    except Exception as e:
        print('ERROR : {}'.format(str(e)))
        return 'ERROR'
