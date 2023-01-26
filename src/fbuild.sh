#!/bin/bash


#
# fbuild.sh
#
# Copyright (c) 2023 Neruthes. Published with GNU AGPL 3.0.
# This program is part of the autowflib project.
#


#
# Building workflow:
#
# def_check                 Check whether the defdir is malformed.
# workdir_prepare           Prepare a clean workdir.
# src_fetch                 Download source (tar/zip).
# src_verify                Verify against the existing hash.
# src_extract               Untar or unzip.
# src_build                 Convert OTF/TTF to WOFF2.
# webfont_collect           Collect the WOFF2 files.
# css_generate              Generate CSS for the WOFF2 files.
# artifacts_install         Install the artifacts to distdir.
# workdir_cleanup           Delete everything in workdir.
#








####################################################
# Initialization
####################################################

export REPODIR="$PWD"
export TARGET_ID="$(dirname "$1")/$(basename "$1")"     # E.g. 'fonts/serif-trans/c059'

export workdir="workdir/$TARGET_ID"
export download_path="cachedir/$TARGET_ID.dld"

echo "**  debug:  TARGET_ID=$TARGET_ID"
echo "**  debug:  workdir=$workdir"
echo "**  debug:  download_path=$download_path"



# exit 0      # Debugging only




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
    log INFO "def_check:  Not implemented yet"
}

function workdir_prepare() {
    find "$workdir" -delete
    mkdir -pv "$workdir"/{build,output}
}

function src_fetch() {
    if [[ "$USE_CACHED_SRC" == y ]] && [[ -e "$download_path" ]]; then
        log INFO "Using cached src file '$download_path'"
        return 0
    fi
    mkdir -pv "$(dirname "$download_path")"
    http_user_agent_str='User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/109.0'
    log INFO wget --header="User-Agent: $http_user_agent_str" "$download" -O "$download_path"
    wget --header="User-Agent: $http_user_agent_str" "$download" -O "$download_path"
}

function src_verify() {
    actual_hash="$(sha256sum "$download_path" | cut -d' ' -f1)"
    log INFO "Downloaded file is    $actual_hash"
    log INFO "Expecting to get      $sha256"
    if [[ "$actual_hash" == "$sha256" ]]; then
        log INFO "Verification success."
    else
        die "SHA-256 hash mismatch. Cannot proceed. Please check the downloaded file at '$download_path'"
    fi
}

function src_extract() {
    log INFO "Defined format is '$format'."
    case $format in
        zip)
            cd "$workdir/build"
            unzip "$REPODIR/$download_path"
            ;;
    esac
}

function src_build() {
    tree "$workdir"
    ### Preprocess file naming
    case $convert_from in
        skip)
            log INFO "This font does not require any conversion."
        return 0
            ;;
        otf|ttf)
            IFS=$'\n'
            for fn in $(find "$workdir/build" -name "*.$convert_from") $(find "$workdir/build" -name "*.${convert_from^^}"); do
                mv -v "$fn" "$workdir/build/$(fc-scan "$fn" | grep postscriptname | cut -d'"' -f2).$convert_from"
            done
            ;;
        *)
            log INFO "Sorry, we cannot process this data format for now."
            ;;
    esac

    ### Finally compress
    for fn in $(find "$workdir/build" -name "*.$convert_from"); do
        log INFO "Converting '$fn'..."
        woff2_compress "$fn"
    done
}

function webfont_collect() {
    function collect_woff2_file() {
        woffid="$(basename "$fn" | sed 's|.woff2$||')"
        if [[ -z "$(grep ":$woffid$" <<< "$weight_map")" ]]; then
            echo "**  debug:  There is no weight_map entry for this file '$woffid'" >&2
            return 0
        fi
        mv -v "$fn" "$workdir/output/$(basename "$fn")"
    }
    for fn in $(find "$workdir/build" -name "*.woff2"); do
        collect_woff2_file
    done
    log INFO "Current workdir:"
    tree "$workdir"
}

function css_generate() {
    csspath="$workdir/output/$id.css"
    echo "/* This CSS is generated by AutoWFLib, and is published with the MIT License. */" > "$csspath"

    ### The following code may be migrated to an independent function or script in future
    function gen_src_list() {
        prefix_list_length="$(wc -l <(echo "$CDN_PREFIX_LIST"))"
        for prefix in $CDN_PREFIX_LIST; do
            log INFO "Using prefix: $prefix" >&2
            printf ", url('$prefix/awfl-cdn/$TARGET_ID/$1.woff2') format('woff2')"
        done
    }
    function gen_fontface_list() {
        for woff in "$workdir/output"/*.woff2; do
            woffid="$(sed 's|.woff2$||' <<< $(basename "$woff"))"       # E.g. C059-Roman
            echo "**  debug:  woffid=$woffid" >&2
            this_woff_font_style="normal"
            if [[ -z "$(grep ":$woffid$" <<< "$weight_map")" ]]; then
                echo "**  debug:  There is no weight_map entry for this file!" >&2
                return 0
            fi
            grep -qs "i:$woffid$" <<< "$weight_map" && this_woff_font_style="italic"


            ### Warning: Cursed indentation
            echo "@font-face {
                font-family: '$family';
                font-weight: $(grep ":$woffid$" <<< "$weight_map" | cut -c1-3);
                font-style: $this_woff_font_style;
                font-display: swap;
                src: $(gen_src_list "$woffid" | cut -c3-);
            }
            " >> "$csspath"
        done
    }
    gen_fontface_list

    log INFO cat "$csspath"
    cat "$csspath"
}

function artifacts_install() {
    distdir="distdir/$TARGET_ID"

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
src_verify
src_extract
src_build
webfont_collect
css_generate
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
