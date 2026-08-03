# -*- coding: utf-8 -*-
from setuphelpers import *
import subprocess, os, shutil, logging

logger = logging.getLogger('wapt')

TASK_NAME  = 'WAPT-DriverUpdate-HP-Now'
SCRIPT_DST = r'C:\Scripts\wapt\run_driver_updates_hp_now.ps1'

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
    logger.info('=== Lancement mise a jour drivers + BIOS HP (HPCMSL) ===')
    logger.info('CWD : %s', os.getcwd())

    script_src      = find_file('run_driver_updates_hp_now.ps1')
    create_task_src = find_file('create_task_hp_now.ps1')

    if not script_src:
        raise FileNotFoundError('run_driver_updates_hp_now.ps1 introuvable dans le paquet')
    if not create_task_src:
        raise FileNotFoundError('create_task_hp_now.ps1 introuvable dans le paquet')

    os.makedirs(os.path.dirname(SCRIPT_DST), exist_ok=True)
    shutil.copy2(script_src, SCRIPT_DST)
    logger.info('Script copie vers : %s', SCRIPT_DST)

    proc = subprocess.run([
        'powershell.exe', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
        '-File', create_task_src
    ], capture_output=True, text=True)

    logger.info('>>> stdout : %s', proc.stdout.strip())
    logger.info('>>> stderr : %s', proc.stderr.strip())
    logger.info('>>> Code retour : %d', proc.returncode)

    if proc.returncode != 0:
        logger.error('Echec creation/execution tache (code %d).', proc.returncode)
        return

    ps_wait = (
        'do {{ Start-Sleep -Seconds 10; '
        '$state = (Get-ScheduledTask -TaskName "{name}").State }} '
        'while ($state -eq "Running"); '
        'Write-Output "Etat final : $state"'
    ).format(name=TASK_NAME)

    proc_wait = subprocess.run([
        'powershell.exe', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
        '-Command', ps_wait
    ], capture_output=True, text=True)

    logger.info('>>> Attente : %s', proc_wait.stdout.strip())

    subprocess.call([
        'powershell.exe', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
        '-Command', 'Unregister-ScheduledTask -TaskName "{}" -Confirm:$false -ErrorAction SilentlyContinue'.format(TASK_NAME)
    ])
    logger.info('Tache temporaire supprimee.')

    if os.path.exists(SCRIPT_DST):
        os.remove(SCRIPT_DST)
        logger.info('Script supprime : %s', SCRIPT_DST)

def uninstall():
    pass

def is_installed():
    return False
