#!/bin/sh
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

./promote-puppet.sh

if ! ./wait_for_review.py --repository puppet-openstack-integration; then
    
    n=0
    
    ./bisect.py < list > totest
    
    while [ -s before ]; do
        ./promote-puppet.sh $(cat totest)
        ./wait_for_review.py --repository puppet-openstack-integration
        ret=$?
        
        mkdir iter$n
        mv totest before after iter$n/
        
        if [ $ret = 0 ]; then
            echo "SUCCESS with $(cat iter$n/totest)"
            ./bisect.py < iter$n/after > totest
        else
            echo "FAILURE with $(cat iter$n/totest)"
            ./bisect.py < iter$n/before > totest
        fi
    done
fi

# bisector.sh ends here
