#!/usr/bin/env python3
"""Exercise prompted role operations against a disposable superuser test database."""
import os
from pathlib import Path
import re
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[1]
PREFIX = 'dba_test_' + uuid.uuid4().hex[:10]
BASE = ['psql', '-X', '-v', 'ON_ERROR_STOP=1', '-At']
ADMIN = os.environ | {'PGUSER': 'postgres', 'PGDATABASE': 'test'}


def sql(text):
    result = subprocess.run(BASE + ['-c', text], env=ADMIN, capture_output=True, text=True)
    if result.returncode:
        raise AssertionError('Administrative assertion query failed')
    return result.stdout.strip()


def literal(text):
    return "'" + text.replace("'", "''") + "'"


def report(action, name, superuser, login, success=True):
    result = subprocess.run(BASE + ['-f', str(ROOT / 'roles' / f'{action}_user_with_random_password.psql')],
                            input=f'{name}\n{superuser}\n{login}\n', env=ADMIN,
                            capture_output=True, text=True)
    if not success:
        assert result.returncode != 0, 'Invalid input was accepted'
        return None
    assert result.returncode == 0, f'{action} failed (credential-bearing output suppressed)'
    password = re.search(r'password: ([a-f0-9]{32})\s*$', result.stderr, re.MULTILINE)
    assert password, 'Password not visible at default message level'
    return password.group(1)


def authenticate(name, password, success=True):
    env = ADMIN | {'PGUSER': name, 'PGPASSWORD': password}
    result = subprocess.run(BASE + ['-c', 'select current_user'], env=env, capture_output=True, text=True)
    assert (result.returncode == 0) == success, 'Unexpected authentication result'
    if success:
        assert result.stdout.strip() == name
    else:
        assert 'password authentication failed' in result.stderr or 'is not permitted to log in' in result.stderr


names = [PREFIX + "_'quoted;--", PREFIX + '_invalid']
try:
    name = names[0]
    initial = report('create', name, '1', '1')
    assert sql(f'select rolsuper, rolcanlogin from pg_roles where rolname={literal(name)}') == 't|t'
    authenticate(name, initial)
    disabled = report('alter', name, '0', '0')
    assert sql(f'select rolsuper, rolcanlogin from pg_roles where rolname={literal(name)}') == 'f|f'
    authenticate(name, disabled, False)
    rotated = report('alter', name, '0', '1')
    assert len({initial, disabled, rotated}) == 3
    authenticate(name, rotated)
    authenticate(name, initial, False)
    authenticate(name, disabled, False)
    report('create', names[1], 'typo', '1', False)
    assert sql(f'select count(*) from pg_roles where rolname={literal(names[1])}') == '0'
    report('alter', name, 'typo', '1', False)
    assert sql(f'select rolsuper, rolcanlogin from pg_roles where rolname={literal(name)}') == 'f|t'
    authenticate(name, rotated)
    menu = subprocess.run(BASE + ['-f', str(ROOT / 'start.psql')], input="'\n0\n\nq\n",
                          env=ADMIN, capture_output=True, text=True, timeout=30)
    assert menu.returncode == 0, 'Quoted menu input caused an SQL error'
    assert 'Unknown option' in menu.stdout and 'Bye!' in menu.stdout and 'Primary' in menu.stdout
    print('PASS: quoted names, cryptographic password format, role flags, rotation, login, invalid-input atomicity')
finally:
    for name in names:
        sql('drop role if exists "' + name.replace('"', '""') + '"')
