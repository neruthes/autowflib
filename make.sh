#!/bin/bash

source .env
source .localenv

REPODIR="$PWD"



if [[ -e $1/info ]]; then
    id="$(basename $1)"
    TARGET_ID="$(dirname $1)/$id"
    bash src/fbuild.sh $TARGET_ID full
    echo "-----------------------------------"
    echo "Run this command to upload:"
    echo "$ " bash $0 cdndist/awfl-cdn/css/$id.css cdndist/awfl-cdn/$TARGET_ID/*
    echo "-----------------------------------"
    if [[ $IMPLICIT_UPLOADING == y ]]; then
        bash $0 cdndist/awfl-cdn/css/$id.css cdndist/awfl-cdn/$TARGET_ID/*
    fi
    exit 0
fi

if [[ -e $2 ]]; then
    for i in "$@"; do
        bash "$0" "$i"
    done
    exit 0
fi



function db_find() {
    fn="$1"
    echo "SELECT time FROM 'FnTimeMap' WHERE fn == '$fn';" | sqlite3 wwwextra/r2uploadtime.db
}
function db_insert() {
    fn="$1"
    echo "INSERT INTO 'FnTimeMap'(fn,time)
        VALUES('$fn',$(date +%s)) ON CONFLICT(fn) DO UPDATE SET time=excluded.time;" | sqlite3 wwwextra/r2uploadtime.db
}


case $1 in
    cdn)
        wrangler pages publish cdndist --project-name=autowflibcdn --commit-dirty=true --branch=main
        ;;
    cf)
        wrangler pages publish wwwdist --project-name=autowflib --commit-dirty=true --branch=main
        ;;
    www_catalog)
        printf ''
        ### Target: categories-list
        ls fonts > wwwsrc/categories-list.txt
        ### Target: font-family-datamap
        outfn="wwwsrc/font-family-datamap.txt"
        printf '' > $outfn
        distdir_families="$(ls distdir/fonts/*-*/)"
        echo "distdir_families=$distdir_families"
        for id in $distdir_families; do
            cat="$(find fonts -type d -name $id | cut -d/ -f2)"
            echo "@family|$id|$(grep '^family=' fonts/$cat/$id/info | cut -d= -f2 | tr -d \'\")|$cat" >> $outfn
            echo "@list|$(ls distdir/fonts/$cat/$id | grep 'woff2$' | tr '\n' '|')" >> $outfn
        done
        sed -i 's/|$//g' $outfn
        cat $outfn
        ;;
    wwwdist | wwwdist/)
        bash $0 www_catalog
        cat cdndist/awfl-cdn/css/*.css > wwwsrc/full.css
        rsync -av --delete wwwsrc/ wwwdist/
        rsync -av wwwextra/ wwwdist/
        du -xhd2 wwwdist
        ;;
    pkgdist | pkgdist/)
        cd $REPODIR/cdndist && tar --xz -cf $REPODIR/pkgdist/cdn-mirror.tar.xz awfl-cdn
        tar --xz -cf $REPODIR/pkgdist/definitions.tar.xz $REPODIR/fonts
        tar --xz -cf $REPODIR/pkgdist/definitions.tar.xz $REPODIR/fonts
        du -xh $REPODIR/pkgdist/*
        ;;
    pkgdist/*.*)
        wrangler r2 object put "autowflibcdn/$1" --file $1
        if [[ $IMPLICIT_UPLOADING == y ]]; then
            cfoss $1
            minoss $1
        fi
        ;;
    cdndist/awfl-cdn/*.woff2 | cdndist/awfl-cdn/*.css)
        ### Smartly upload
        last_push_time="$(db_find "$1")"
        file_change_time="$(date -r "$1" +%s)"
        if [[ "$last_push_time" -gt "$file_change_time" ]] && [[ "$FORCE_UPLOAD" != y ]]; then
            delta_sec=$((last_push_time-file_change_time))
            delta_min=$((delta_sec/60))
            echo "[INFO] The file '$1' was already uploaded ($delta_min min after change). Set FORCE_UPLOAD=y to ignore date."
            exit 0
        fi
        smallfn="$(cut -d/ -f2- <<< "$1")"
        wrangler r2 object put "autowflibcdn/$smallfn" --file "$1" && db_insert "$1"
        ;;
    r2)
        for i in $(find cdndist/awfl-cdn -type f); do
            bash $0 $i
        done
        ;;
    initdb)
        rm wwwextra/r2uploadtime.db
        echo "create table FnTimeMap(fn TEXT PRIMARY KEY, time INT)" | sqlite3 wwwextra/r2uploadtime.db
        ;;
    *)
        echo "[ERROR] No rule to make '$1'. Stop."
        ;;
esac
