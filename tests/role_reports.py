#!/usr/bin/env python3
"""Exercise prompted role operations against a disposable superuser test database."""
import os
from pathlib import Path
import re
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[1]
PREFIX = 'dba_test_' + uuid.uuid4().hex[:10]
MANAGER_PASSWORD = uuid.uuid4().hex
BASE = ['psql', '-X', '-v', 'ON_ERROR_STOP=1', '-At']
ADMIN = os.environ | {'PGUSER': 'postgres', 'PGDATABASE': 'test'}


def sql(text):
    result = subprocess.run(BASE + ['-c', text], env=ADMIN, capture_output=True, text=True)
    if result.returncode:
        raise AssertionError('Administrative assertion query failed')
    return result.stdout.strip()


def literal(text):
    return "'" + text.replace("'", "''") + "'"


def report(action, name, superuser, login, success=True, actor='postgres'):
    result = subprocess.run(BASE + ['-f', str(ROOT / 'roles' / f'{action}_user_with_random_password.psql')],
                            input=f'{name}\n{superuser}\n{login}\n', env=ADMIN | {'PGUSER': actor, 'PGPASSWORD': ADMIN.get('PGPASSWORD', '') if actor == 'postgres' else MANAGER_PASSWORD},
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


names = [PREFIX + "_'quoted;--", PREFIX + '_invalid', PREFIX + '_managed', PREFIX + '_manager', PREFIX + '_blank']
try:
    blank_password = report('create', names[4], '', '')
    assert sql(f'select rolsuper, rolcanlogin from pg_roles where rolname={literal(names[4])}') == 'f|f'
    authenticate(names[4], blank_password, False)
    report('create', '', '0', '1', False)
    report('alter', '', '0', '1', False)
    name = names[0]
    initial = report('create', name, '1', '1')
    assert sql(f'select rolsuper, rolcanlogin from pg_roles where rolname={literal(name)}') == 't|t'
    authenticate(name, initial)
    unchanged = report('alter', name, '', '')
    assert sql(f'select rolsuper, rolcanlogin from pg_roles where rolname={literal(name)}') == 't|t'
    authenticate(name, unchanged)
    authenticate(name, initial, False)
    disabled = report('alter', name, '0', '0')
    assert sql(f'select rolsuper, rolcanlogin from pg_roles where rolname={literal(name)}') == 'f|f'
    authenticate(name, disabled, False)
    rotated = report('alter', name, '0', '1')
    assert len({initial, disabled, rotated}) == 3
    authenticate(name, rotated)
    promoted = report('alter', name, '1', '1')
    assert sql(f'select rolsuper from pg_roles where rolname={literal(name)}') == 't'
    rotated = report('alter', name, '0', '1')
    authenticate(name, rotated)
    authenticate(name, promoted, False)
    authenticate(name, initial, False)
    authenticate(name, disabled, False)
    report('create', names[1], 'typo', '1', False)
    assert sql(f'select count(*) from pg_roles where rolname={literal(names[1])}') == '0'
    report('alter', name, 'typo', '1', False)
    assert sql(f'select rolsuper, rolcanlogin from pg_roles where rolname={literal(name)}') == 'f|t'
    authenticate(name, rotated)
    manager = names[3]
    sql('create role "' + manager + '" login createrole password ' + literal(MANAGER_PASSWORD))
    managed = names[2]
    report('create', names[1], '1', '1', False, actor=manager)
    assert sql(f'select count(*) from pg_roles where rolname={literal(names[1])}') == '0'
    managed_initial = report('create', managed, '0', '1', actor=manager)
    authenticate(managed, managed_initial)
    managed_rotated = report('alter', managed, '0', '1', actor=manager)
    authenticate(managed, managed_rotated)
    report('alter', managed, '1', '1', False, actor=manager)
    assert sql(f'select rolsuper from pg_roles where rolname={literal(managed)}') == 'f'
    authenticate(managed, managed_rotated)
    authenticate(managed, managed_initial, False)
    menu = subprocess.run(BASE + ['-f', str(ROOT / 'start.psql')], input="'\n0\n\nq\n",
                          env=ADMIN, capture_output=True, text=True, timeout=30)
    assert menu.returncode == 0, 'Quoted menu input caused an SQL error'
    assert 'Unknown option' in menu.stdout and 'Bye!' in menu.stdout and 'Primary' in menu.stdout
    print('PASS: quoted names, cryptographic password format, role flags, rotation, login, invalid-input atomicity')
finally:
    active_error = sys.exc_info()[0] is not None
    cleanup_failed = False
    for name in names:
        try:
            sql('drop role if exists "' + name.replace('"', '""') + '"')
        except AssertionError:
            cleanup_failed = True
            print('Cleanup failed for a disposable test role', file=sys.stderr)
    if cleanup_failed and not active_error:
        raise AssertionError('Test role cleanup failed')
