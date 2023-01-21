#!/bin/bash

source .env
source .localenv



if [[ -e $1/info ]]; then
    exec bash src/fbuild.sh $1 full
fi



case $1 in
    cdn)
        bash $0 cf
        ;;
    cf)
        wrangler pages publish cdndist --project-name=autowflibcdn --commit-dirty=true --branch=master
        ;;
esac
