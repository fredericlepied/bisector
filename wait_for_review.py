#!/usr/bin/env python
# Licensed under the Apache License, Version 2.0
#
# Wait for Jenkins CI vote

import os
import argparse
import subprocess
import time
import json
import re
import sys

_SSH_URL_REGEXP = re.compile('ssh://([^:]+):(\d+)/')


def execute(cmd):
    #sys.stderr.write(cmd + '\n')
    p = subprocess.Popen(cmd.split(), stdout=subprocess.PIPE)
    if p.wait():
        fail(p.stdout.read())
    return p.stdout.read()


def fail(msg):
    sys.stderr.write("%s\n" % msg)
    exit(1)


def get_ci_verify_vote(json_object):
    if (u'currentPatchSet' not in json_object or
            u'approvals' not in json_object[u'currentPatchSet']):
        print 'None'
        return None
    for a in json_object[u'currentPatchSet'][u'approvals']:
        if a[u'by'][u'name'] == 'Jenkins' and a[u"type"] == "Verified":
            return int(a[u'value'])
    print 'nothing'
    return None


def wait_for_merge(query, retry):
    while retry > 0:
        if "MERGED" in execute(query):
            return
        retry -= 1
        time.sleep(1)
    fail("Change dind't merged: %s" % execute(query))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository", default=os.getcwd())
    parser.add_argument("--delay", type=int, default=3600)
    parser.add_argument("--sleep", type=int, default=10)
    args = parser.parse_args()
    os.chdir(args.repository)

    sha = open(".git/refs/heads/master").read()

    # Give Jenkins some time to start test
    time.sleep(2)

    # extract info from the gerrit url
    fetch_line = execute('git remote show -n gerrit').split('\n')[1]
    res = _SSH_URL_REGEXP.search(fetch_line)

    if not res:
        sys.stderr.write('Unable to parse gerrit info from:\n%s\n' %
                         fetch_line)
        sys.exit(1)

    ghost = res.group(1)
    gport = res.group(2)

    cmd = "ssh -p %s %s gerrit" % (gport, ghost)

    query = "query --format JSON --current-patch-set %s" % sha
    retry = args.delay / args.sleep
    while retry > 0:
        q = execute("%s %s" % (cmd, query))
        # Get Jenkins CI Verify vote
        result = json.loads(q.split('\n')[0])
        ci_note = get_ci_verify_vote(result)
        print ci_note, result
        if ci_note > 0:
            if args.failure:
                fail("Jenkins CI voted %d in --failure mode")
            if (args.approve and ci_note == 2) or not args.approve:
                if args.approve:
                    # Wait until status:MERGED when approved
                    wait_for_merge("%s %s" % (cmd, query), retry)
                # Jenkins CI voted +1/+2
                exit(0)
        elif ci_note is not None and ci_note < 0:
            fail("Jenkins CI voted %d" % ci_note)
        retry -= 1
        time.sleep(args.sleep)
    if args.approve and ci_note == 1:
        fail("Jenkins CI didn't +2 approved change")
    if ci_note is None:
        fail("Jenkins CI didn't vote")
    fail("Jenkins CI vote 0")

main()
