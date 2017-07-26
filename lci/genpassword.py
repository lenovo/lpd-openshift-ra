#!/usr/bin/env python
import base64
import os
import sys

def complexityPasses(password):
    if filter(str.isalnum, password) == password:
        return False
    if len(filter(str.isdigit, password)) == 0:
        return False
    if len(filter(str.islower, password)) == 0:
        return False
    if len(filter(str.isupper, password)) == 0:
        return False
    return True

tmppassword = base64.b64encode(os.urandom(15)).replace('/', '!')
while not complexityPasses(tmppassword):
    tmppassword = base64.b64encode(os.urandom(15)).replace('/', '!')
sys.stdout.write(tmppassword)
