#!/bin/bash
#
# Copyright (C) 2016 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

CONSISTENT_URL=http://trunk.rdoproject.org/centos7/consistent/versions.csv
#BASE_URL=https://trunk.rdoproject.org/centos7
BASE_URL=http://46.231.133.253/delorean

if [ -n "$1" ]; then
    CONSISTENT_URL=$BASE_URL/$1/versions.csv
fi

ts=0
for current in $(curl -s $CONSISTENT_URL); do
    val=$(echo $current|cut -d, -f7)
    if [[ "$val" != 'Last Success Timestamp' ]] && [[ "$val" -gt "$ts" ]]; then
        ts=$val
        line=$current
    fi
done

if [ $ts = 0 ]; then
    echo "something went wrong aborting" 1>&2
    exit 1
fi

sha1=$(echo $line|cut -d, -f3)
psha1=$(echo $line|cut -d, -f5|sed 's/\(........\).*/\1/')

url=$BASE_URL/$(echo $sha1|sed 's/\(..\).*/\1/')/$(echo $sha1|sed 's/..\(..\).*/\1/')/${sha1}_${psha1}/

date=$(date -u --date="1970-01-01 $ts sec GMT" '+%F %R')

chid=$(cat chid 2> /dev/null)

[ -d puppet-openstack-integration ] || git clone git@github.com:openstack/puppet-openstack-integration.git

sed -i "s@\(.* => \)'http.*\(centos7\|delorean\).*',@\1'$url',@" puppet-openstack-integration/manifests/repos.pp

cd puppet-openstack-integration

if [ -n "$chid" ]; then
    opt=--amend
    git commit $opt -F- manifests/repos.pp <<EOF
[WIP] Bump RDO repo to $date (bisect)

Trunk Updating RDO repo to $sha1.

Change-Id: $chid
EOF
else
    git review -s
    git commit $opt -F- manifests/repos.pp <<EOF
Bump RDO repo to $date

Trunk Updating RDO repo to $sha1.
EOF
fi

git show|grep Change-Id:|sed 's/\s*Change-Id:\s*\(.*\)/\1/' > ../chid

git review -t bump/rdo

git show

# promote-puppet.sh ends here
