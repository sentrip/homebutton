#!/usr/bin/env python3
import os, shutil

if __name__ == '__main__':
    prefix = ''
    if os.getcwd().endswith('android'):
        prefix = '../'
    shutil.copy(prefix + 'door.py', prefix + 'android/app/src/main/res/raw/door.py')
    shutil.copy(prefix + 'door.sh', prefix + 'android/app/src/main/res/raw/run_door.sh')
