#!/usr/bin/env python3
import asyncio
import base64
import json
import os
import time

import websockets


class Pi(object):
    """
    Basic raspberry-pi api abstraction
    """
    def __init__(self, mock: bool = False):
        self.mock = mock
        self.pins = {}
        self.modes = {}
        self.is_setup = False

    def cleanup(self):
        if not self.mock and self.is_setup:
            for pin, state in self.pins.items():
                if state:
                    self.set_pin(pin, False)
            import RPi.GPIO as GPIO
            GPIO.cleanup()

    def pin(self, pin: int):
        return self.pins[pin]

    def set_pin(self, pin: int, state: bool):
        if not self.mock:
            import RPi.GPIO as GPIO

            if not self.is_setup:
                self.is_setup = True
                GPIO.setmode(GPIO.BCM)

            if pin not in self.modes:
                self.modes[pin] = GPIO.OUT
                GPIO.setup(pin, GPIO.OUT)

            GPIO.output(pin, GPIO.HIGH if state else GPIO.LOW)

        self.pins[pin] = state


class DoorMessage(object):
    CLOSE = 0
    OPEN = 1
    PAIR = 2

    def __init__(self, user, pwd, state):
        self.user = user
        self.pwd = pwd
        self.state = state

    def to_bytes(self):
        return base64.b64encode((self.user + ',' + self.pwd + ',' + str(self.state)).encode())

    @staticmethod
    def from_bytes(b):
        decoded = base64.b64decode(b).decode('utf-8')
        u, p, s = decoded.split(',')
        return DoorMessage(u, p, int(s))


class FileEvent(object):
    """Class that is similar to 'threading.Event' but it is set by the presence of a file with the given name"""
    def __init__(self, name):
        self.name = name
        self._set = False

    def reset(self):
        self._set = False

    def is_set(self):
        if self._set:
            return True

        if os.path.exists(self.name):
            os.remove(self.name)
            self._set = True
            return True

        return False

    def __del__(self):
        if os.path.exists(self.name):
            os.remove(self.name)


class Door(object):
    """
    A websocket-based door that manages a shared boolean variable for a number of authenticated users
    """
    def __init__(self,
                 users=None,
                 *,
                 on_open=lambda u: None,
                 on_close=lambda: None,
                 auto_close_after=5.0):
        """
        Create a Door

        :param users: dictionary of users and passwords or name of users json file where the dictionary is stored
        :param on_open: function to handle a user opening a door
        :param on_close: function to handle a user closing a door (also called on auto-close)
        :param auto_close_after: Number of seconds after which to close the door if a close signal has not been sent
        """
        self.state = False
        self.users = users
        self.on_open = on_open
        self.on_close = on_close
        self.auto_close_duration = auto_close_after
        self.time_to_stop_pairing = 0.0
        self.time_to_close = 0.0
        self.last_to_open = None
        self.connected = set()
        self.ready = asyncio.Future()
        self.closed = asyncio.Future()
        self._close_task = None
        self._pair_task = None
        self._running = True
        self._kill_event = FileEvent('kill')
        self._pair_event = FileEvent('pair')

    def pair(self, duration=30.0):
        """
        Activate pairing mode - all messages with state=DoorMessage.PAIR will have their username and password added
        to the dictionary of authenticated users. If self.users is a string, then the paired user will be saved to disk
        :param duration: float: duration in seconds until paring is deactivated
        """
        if self.time_to_stop_pairing == 0.0:
            self._run_task('_pair_task', self._pair())
        self.time_to_stop_pairing = duration

    def run(self, host='localhost', port=6000):
        """
        Run the door server on the given host and port
        """
        asyncio.get_event_loop().run_until_complete(self._run(host, port))

    def stop(self):
        self._running = False

    @staticmethod
    def set_state(user, pwd, state, *, host='localhost', port=6000):
        """
        Attempt to set the state of the door over the network and block until the response has arrived
        See 'set_state_async'
        """
        return asyncio.get_event_loop().run_until_complete(Door.set_state_async(user, pwd, state, host=host, port=port))

    @staticmethod
    async def set_state_async(user, pwd, state, *, host='localhost', port=6000):
        """
        Attempt to set the state of the door over the network asynchronously
        :param user: str: username
        :param pwd: str: password
        :param state: bool: desired state of the door
        :param host: str: hostname of door server
        :param port: int: port number of door server
        :return: int: state of the door after processing the request
        """
        async with websockets.connect(f'ws://{host}:{port}') as websocket:
            await websocket.send(DoorMessage(user, pwd, state).to_bytes())
            result = await websocket.recv()
        return result

    # region Private

    async def _run(self, host, port):
        async with websockets.serve(self._serve, host, port):
            self.ready.set_result(True)

            while self._running and not self._kill_event.is_set():
                if self._pair_event.is_set():
                    self.pair()
                await asyncio.sleep(0.01)

            await self._close()
        self._cancel_tasks()
        self.closed.set_result(True)

    async def _serve(self, websocket, path):
        self.connected.add(websocket)
        msg = await websocket.recv()
        try:
            result = await self._handle_message(DoorMessage.from_bytes(msg))
            await websocket.send(result)
        finally:
            self.connected.remove(websocket)

    async def _handle_message(self, msg):
        if msg.state == DoorMessage.PAIR and self.time_to_stop_pairing > 0.0:
            await self._handle_pair(msg)
            return '1'
        else:
            await self._handle_set_state(msg)
            return '1' if self.state else '0'

    async def _handle_pair(self, msg):
        if isinstance(self.users, str):
            users = self._get_users()
            users[msg.user] = msg.pwd
            with open(self.users, 'w') as f:
                json.dump(users, f)
        elif self.users is not None:
            self.users[msg.user] = msg.pwd

    async def _handle_set_state(self, msg):
        if self.users is not None and self._get_users().get(msg.user, None) != msg.pwd:
            raise RuntimeError

        if msg.state == DoorMessage.OPEN:
            self.time_to_close = self.auto_close_duration

            if not self.state:
                self.state = True
                self.last_to_open = msg.user
                self.on_open(msg.user)
                self._run_task('_close_task', self._close_after())

        elif msg.state == DoorMessage.CLOSE and self.state:
            await self._close()

    def _run_task(self, attr, coro):
        if getattr(self, attr) is not None:
            getattr(self, attr.cancel())
        task = asyncio.ensure_future(coro)
        task.add_done_callback(lambda *a: setattr(self, attr, None))
        setattr(self, attr, task)

    def _cancel_tasks(self):
        if self._close_task:
            self._close_task.cancel()
            self._close_task = None
        if self._pair_task:
            self._pair_task.cancel()
            self._pair_task = None

    async def _close_after(self):
        await asyncio.sleep(self.time_to_close)
        await self._close()

    async def _close(self):
        if self.state:
            self.state = False
            self.on_close()
            if self.connected:
                await asyncio.wait([c.send(0) for c in self.connected])
        self._close_task = None

    async def _pair(self):
        now = time.time()
        while self.time_to_stop_pairing > 0.0:
            dt = now - time.time()
            now = time.time()
            self.time_to_stop_pairing += dt
            await asyncio.sleep(0.1)
        self._pair_task = None

    def _get_users(self):
        # We load the user list every time we check to allow for
        # modifications to the user list without having to restart the server
        if isinstance(self.users, str):
            if os.path.exists(self.users):
                try:
                    with open(self.users) as f:
                        return json.load(f)
                except json.JSONDecodeError:
                    return {}
                except Exception as e:
                    print('Bizarre error: ', repr(e))
                    return {}
            else:
                return {}
        return self.users

    # endregion


def parse_args():
    import argparse

    parser = argparse.ArgumentParser(description='Run homebutton raspberry-pi door controller server')
    parser.add_argument('--host', default='localhost', type=str,
                        help='Hostname to use when running the server')
    parser.add_argument('--port', default=6000, type=int,
                        help='Port number to use when running the server')
    parser.add_argument('--users', default='users.json', type=str,
                        help='File where authenticated user dictionary is stored')
    parser.add_argument('--auto-close', default=5.0, type=float,
                        help='Number of seconds after which the door is automatically closed')
    parser.add_argument('--pin', default=18, type=int,
                        help='Raspberry-pi pin number to use for door output')
    parser.add_argument('--dev', action='store_true',
                        help='Dev mode prints the names of users that open/close the door')

    return parser.parse_args()


def cli_main(args):
    pi = Pi(mock=args.dev)

    if args.dev:
        args.users = {'admin': 'admin'}
        server = Door(args.users,
                      on_open=lambda u: print(f'open {u}'),
                      on_close=lambda: print('close'),
                      auto_close_after=args.auto_close)

    else:
        server = Door(args.users,
                      on_open=lambda u: pi.set_pin(args.pin, True),
                      on_close=lambda: pi.set_pin(args.pin, False),
                      auto_close_after=args.auto_close)

    server.run(args.host, args.port)
    pi.cleanup()


if __name__ == '__main__':
    cli_main(parse_args())
