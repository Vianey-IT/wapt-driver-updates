# -*- coding: utf-8 -*-
from setuphelpers import *
import subprocess, logging

logger = logging.getLogger('wapt')

def install():
    logger.info('=== Installation LSUClient ===')

    # Installer NuGet en premier
    logger.info('Installation du fournisseur NuGet...')
    proc = subprocess.run([
        'powershell.exe', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
        '-Command',
        '[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; '
        'Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers'
    ], capture_output=True, text=True)
    logger.info('>>> NuGet stdout : %s', proc.stdout.strip())
    logger.info('>>> NuGet stderr : %s', proc.stderr.strip())
    logger.info('>>> NuGet code retour : %d', proc.returncode)

    # Installer LSUClient
    logger.info('Installation de LSUClient...')
    proc = subprocess.run([
        'powershell.exe', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
        '-Command',
        '[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; '
        'Install-Module -Name LSUClient -Force -Scope AllUsers -SkipPublisherCheck'
    ], capture_output=True, text=True)
    logger.info('>>> stdout : %s', proc.stdout.strip())
    logger.info('>>> stderr : %s', proc.stderr.strip())
    logger.info('>>> Code retour : %d', proc.returncode)

    if proc.returncode != 0:
        raise Exception('Echec installation LSUClient : {}'.format(proc.stderr.strip()))
    logger.info('LSUClient installe.')

def uninstall():
    logger.info('=== Desinstallation LSUClient ===')
    subprocess.call([
        'powershell.exe', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
        '-Command', 'Uninstall-Module -Name LSUClient -AllVersions -Force -ErrorAction SilentlyContinue'
    ])
    logger.info('LSUClient desinstalle.')

def is_installed():
    result = subprocess.call([
        'powershell.exe', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
        '-Command', 'if (Get-Module -ListAvailable -Name LSUClient) { exit 0 } else { exit 1 }'
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return result == 0
