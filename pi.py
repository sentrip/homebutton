#!/usr/bin/env python3
import os
import door

DOOR_RUN_SCRIPT = 'door.sh'

if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(description='homebutton dev tools')
    parser.add_argument('-c', '--copy', help='copy server files to raspberry over network', action="store_true")
    parser.add_argument('-k', '--kill', help='kill raspberry server (if running)', action="store_true")
    parser.add_argument('-r', '--run', help='run raspberry server', action="store_true")
    parser.add_argument('-p', '--pair', help='activate pairing mode', action="store_true")
    parser.add_argument('-s', '--set-state', nargs='+', help='set the state of the door (username, password, state)')
    parser.add_argument('-u', '--user', default='pi', help='name of the user account on the raspberry pi')
    parser.add_argument('-a', '--address', default='192.168.0.244', help='IP address of raspberry pi on the network')
    parser.add_argument('--dev', action='store_true', help='Dev mode for testing')
    parser.add_argument('--dir', help='path where server files are stored on the raspberry pi '
                                      '(default: /home/{user}/homebutton')
    args = parser.parse_args()

    if args.dev:
        args.address = 'localhost'

    if args.set_state and len(args.set_state) == 1:
        args.set_state = ['admin', 'admin'] + args.set_state

    pi_address = f'{args.user}@{args.address}'
    door_directory = f'/home/{args.user}/homebutton'

    def write_address():
        os.system(f'ssh {pi_address} "echo \'{args.address}\' > {door_directory}/.host_name"')

    if not args.dev:
        if args.copy:
            write_address()
            os.system(f'scp door.py {DOOR_RUN_SCRIPT} {pi_address}:{door_directory}')
        if args.kill:
            os.system(f'ssh {pi_address} "echo "" > {door_directory}/kill"')
        if args.run:
            write_address()
            os.system(f'ssh {pi_address} "cd {door_directory}; sh {DOOR_RUN_SCRIPT}" &')
        if args.pair:
            os.system(f'ssh {pi_address} "echo "" > {door_directory}/pair"')
    else:
        if args.kill:
            os.system(f'echo "" > kill')
        if args.run:
            os.system('python door.py --dev')
        if args.pair:
            os.system(f'echo "" > pair')
    if args.set_state:
        door.Door.set_state(*args.set_state, host=args.address)

    if not args.copy and not args.kill and not args.run and not args.pair and not args.set_state:
        parser.print_help()
