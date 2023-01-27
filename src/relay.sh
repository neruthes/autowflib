#!/bin/bash

#
# relay.sh
#
# Copyright (c) 2023 Neruthes. Published with GNU AGPL 3.0.
# This program is part of the autowflib project.
#


#
# Building workflow:
#
# def_check                 Check whether the defdir is malformed.
# workdir_prepare           Prepare a clean workdir.
# src_fetch                 Download source CSS and WOFF2.
# src_build                 Convert OTF/TTF to WOFF2.
# webfont_collect           Collect the WOFF2 files.
# artifacts_install         Install the artifacts to distdir.
# workdir_cleanup           Delete everything in workdir.
#





####################################################
# Initialization
####################################################

export REPODIR="$PWD"
export TARGET_ID="$(dirname "$1")/$(basename "$1")"     # E.g. 'fonts/serif-trans/c059'

export workdir="workdir/${TARGET_ID/relay/fonts}"

echo "**  debug:  TARGET_ID=$TARGET_ID"
echo "**  debug:  workdir=$workdir"





####################################################
# Helper Functions
####################################################
function log() {
    verb=$1
    shift
    echo "[${verb^^}]  $@"
}
function log2() {
    verb=$1
    shift
    echo "[${verb^^}]  $@" >/dev/stderr
}
function die() {
    echo "[FATAL]  $@"
    exit 1
}








####################################################
# Phase Functions
####################################################

function def_check() {
    printf ""
}

function workdir_prepare() {
    find "$workdir" -delete
    mkdir -pv "$workdir"/{build,output}
}

function src_fetch() {
    export css_download_path="cachedir/$TARGET_ID/$id.css"
    if [[ "$USE_CACHED_SRC" == y ]] && [[ -e "$css_download_path" ]]; then
        log INFO "Using cached src file '$css_download_path'"
        return 0
    fi
    mkdir -pv "$(dirname "$css_download_path")"
    http_user_agent_str='User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/109.0'
    log INFO wget --header="User-Agent: $http_user_agent_str" "$css_url" -O "$css_download_path"
    wget --header="User-Agent: $http_user_agent_str" "$css_url" -O "$css_download_path"
}

function src_build() {
    ### Process CSS
    cp -av "$css_download_path" "$workdir/build/$id.css"
    ### WOFF2 files
    mkdir -p "$workdir/build/woff2_files"
    url_list="$workdir/build/url_list.txt"
    touch "$url_list"
    grep -Eo 'url\('"'?"'[^ ]+?'"'?"'\)' $css_download_path | cut -c5- | tr -d ')' > "$url_list"
    cat "$url_list"
    IFS=$'\n'
    for woff2_url in $(cat "$url_list"); do
        fn_id="$(sha256sum <<< "$woff2_url" | cut -c1-16)"
        fn_ext="$(grep -Eo '.[0-9a-zA-Z]+$' <<< "$woff2_url")"
        truefn="${fn_id}${fn_ext}"
        woff2_download_path="$workdir/build/woff2_files/$truefn"
        serve_path="$(head -n1 <<< "$CDN_PREFIX_LIST" | cut -d' ' -f1)/awfl-cdn/fonts/$cat/$id/$truefn"
        sed -i "s|('?$woff2_url'?)|('$serve_path')|" "$workdir/build/$id.css"
        if [[ ! -e "$woff2_download_path" ]]; then
            log INFO wget --header="User-Agent: $http_user_agent_str" "$woff2_url" -O "$woff2_download_path"
            wget --header="User-Agent: $http_user_agent_str" "$woff2_url" -O "$woff2_download_path"
            sleep 1
        fi
    done
}

function webfont_collect() {
    IFS=$'\n'
    for woff2_fn in $(find "$workdir/build/woff2_files/"*); do
        cp -av "$woff2_fn" "$workdir/output/"
    done
    cp -av "$workdir/build/$id.css" "$workdir/output/$id.css" 
}

function artifacts_install() {
    distdir="distdir/${TARGET_ID/relay/fonts}"

    ### Clean old files in distdir
    find "$distdir" -mindepth 1 -delete

    ### Write into distdir
    mkdir -pv distdir/css
    cat "$workdir/output/$id.css" > "distdir/css/$id.css"
    rsync -av --delete --mkpath "$workdir/output/" "$distdir/"
}

function workdir_cleanup() {
    [[ $NO_CLEANUP == y ]] && return 0
    rm -rv "$workdir"
}







####################################################
# Read Target Definition
####################################################

source "$TARGET_ID/info"
[[ -e "$TARGET_ID/build.sh" ]] && source "$TARGET_ID/build.sh"








####################################################
# Start building
####################################################

phases_list="
def_check
workdir_prepare
src_fetch
src_build
webfont_collect
artifacts_install
workdir_cleanup
"

subcmd="$2"
[[ -z "$subcmd" ]] && subcmd=full
if [[ $subcmd == full ]]; then
    for phase_name in $phases_list; do
        cd "$REPODIR"
        printf '\n\n'
        log INFO "[fbuild.sh]  Entering phase '$phase_name'."
        $phase_name
    done
    log INFO "[fbuild.sh]  My job is done. Good bye."
else
    $subcmd
fi
