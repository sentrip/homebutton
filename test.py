import asyncio
import json
import os
import pytest
from door import Door, DoorMessage


@pytest.fixture
def msg():
    return lambda s: DoorMessage('test', 'test', s)


@pytest.fixture
def invalid_msg():
    return lambda s: DoorMessage('test', '', s)


@pytest.fixture
def door():
    info = {'open': [], 'close': []}
    d = Door({'test': 'test'},
             on_open=lambda u: info['open'].append(u),
             on_close=lambda: info['close'].append(''),
             auto_close_after=0.002)
    d.info = info
    d.handle = d._handle_message
    d.close = d._close
    return d


@pytest.fixture
def users_file():
    name = 'users.json'
    users = {'test': 'test'}
    with open(name, 'w') as f:
        json.dump(users, f)
    yield name
    os.remove(name)


@pytest.mark.asyncio
async def test_door_opens_for_authenticated_user(door, msg):
    result = await door.handle(msg(DoorMessage.OPEN))
    assert result == '1'
    assert door.state == 1
    assert len(door.info['open']) == 1
    assert len(door.info['close']) == 0
    await door.close()


@pytest.mark.asyncio
async def test_door_closes_for_authenticated_user(door, msg):
    await door.handle(msg(DoorMessage.OPEN))
    assert door.state == 1

    result = await door.handle(msg(DoorMessage.CLOSE))
    assert result == '0'
    assert door.state == 0
    assert len(door.info['open']) == 1
    assert len(door.info['close']) == 1

    await door.close()


@pytest.mark.asyncio
async def test_door_does_not_open_for_unauthenticated_user(door, invalid_msg):
    with pytest.raises(RuntimeError):
        await door.handle(invalid_msg(DoorMessage.OPEN))
    assert door.state == 0
    assert len(door.info['open']) == 0
    assert len(door.info['close']) == 0
    await door.close()


@pytest.mark.asyncio
async def test_door_automatically_closes(door, msg):
    await door.handle(msg(DoorMessage.OPEN))
    await asyncio.sleep(door.auto_close_duration / 2)
    assert door.state == 1
    assert len(door.info['open']) == 1
    assert len(door.info['close']) == 0
    await asyncio.sleep(door.auto_close_duration/2)
    assert len(door.info['open']) == 1
    assert len(door.info['close']) == 1
    assert door.state == 0
    await door.close()


@pytest.mark.asyncio
async def test_pairing_mode_successful(door, msg):
    door.pair(0.1)
    result = await door.handle(DoorMessage('new', 'pwd', DoorMessage.PAIR))
    assert result == '1'
    assert door.users['new'] == 'pwd'
    await door.close()


@pytest.mark.asyncio
async def test_pairing_mode_unsuccessful(door, msg):
    with pytest.raises(RuntimeError):
        await door.handle(DoorMessage('new', 'pwd', DoorMessage.PAIR))
    assert 'new' not in door.users
    await door.close()


@pytest.mark.asyncio
async def test_pairing_mode_lasts_fixed_duration(door, msg):
    door.pair(0.01)
    await door.handle(DoorMessage('new', 'pwd', DoorMessage.PAIR))
    assert door.users['new'] == 'pwd'
    await asyncio.sleep(0.03)
    with pytest.raises(RuntimeError):
        await door.handle(DoorMessage('bad', 'pwd', DoorMessage.PAIR))
    await door.close()


@pytest.mark.asyncio
async def test_door_loads_authenticated_users_from_file(door, msg, invalid_msg, users_file):
    door.users = users_file

    result = await door.handle(msg(DoorMessage.OPEN))
    assert result == '1'
    assert door.state == 1

    with pytest.raises(RuntimeError):
        await door.handle(invalid_msg(DoorMessage.CLOSE))
    assert door.state == 1

    await door.close()


@pytest.mark.asyncio
async def test_door_saves_paired_users_to_file(door, users_file):
    door.users = users_file
    door.pair(0.1)
    result = await door.handle(DoorMessage('new', 'pwd', DoorMessage.PAIR))
    assert result == '1'
    with open(users_file) as f:
        data = json.load(f)
        assert data['test'] == 'test'
        assert data['new'] == 'pwd'
    await door.close()


@pytest.mark.asyncio
async def test_door_server_client_set_state(door, msg):
    host = 'localhost'
    port = 6000

    asyncio.ensure_future(door._run(host, port))
    await door.ready

    result = await Door.set_state_async('test', 'test', DoorMessage.OPEN, host=host, port=port)
    assert result == b'1'
    assert door.state == 1
    assert len(door.info['open']) == 1
    assert len(door.info['close']) == 0

    result = await Door.set_state_async('test', 'test', DoorMessage.CLOSE, host=host, port=port)
    assert result == b'0'
    assert door.state == 0
    assert len(door.info['open']) == 1
    assert len(door.info['close']) == 1

    door.stop()

    await door.closed


@pytest.mark.asyncio
async def test_door_server_closes_on_kill_event(door, msg):
    asyncio.ensure_future(door._run('localhost', 6000))
    await door.ready
    with open('kill', 'w') as f:
        pass
    await door.closed
    assert not os.path.exists('kill')


@pytest.mark.asyncio
async def test_door_server_pairs_on_pair_event(door, msg):
    asyncio.ensure_future(door._run('localhost', 6000))
    await door.ready
    with open('pair', 'w') as f:
        pass
    await asyncio.sleep(0.1)
    assert door.time_to_stop_pairing > 0.0
    with open('kill', 'w') as f:
        pass
    await door.closed
    assert not os.path.exists('kill')
