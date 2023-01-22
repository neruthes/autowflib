#!/bin/bash

source .env
source .localenv

REPODIR="$PWD"



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
    fonts/*)
        if [[ -e $1/info ]]; then
            id="$(basename $1)"
            TARGET_ID="$(dirname $1)/$id"
            (bash src/fbuild.sh $TARGET_ID full || exit 1) | tee buildlog.txt
            # echo "-----------------------------------"
            # echo "Run this command to upload:"
            # echo "$ " bash $0 "cdndist/awfl-cdn/css/$id.css" "cdndist/awfl-cdn/$TARGET_ID/*"
            # echo "-----------------------------------"
            id="$id" bash $0 thumbnail
        fi
        ;;
    thumbnail)
        echo "[INFO] Generating thumbnail for '$id'..."
        source "$(find fonts -mindepth 2 -maxdepth 2 -name "$id" | head -n1)/info"
        mkdir -p $REPODIR/.testdir/thumbnail.$id
        cd $REPODIR/.testdir/thumbnail.$id
        fileID="$(grep "^400:" <<< "$weight_map" | cut -d: -f2)"
        cp -a $REPODIR/distdir/fonts/$cat/$id/$fileID.woff2 ./$fileID.woff2
        woff2_decompress $fileID.woff2
        convert -size 3000x1500 xc:white -font "@$fileID.ttf" -pointsize 100 -fill black -annotate +100+100 "$family" -trim -bordercolor "#FFF" -border 5 +repage -resize x80 $REPODIR/.testdir/thumbnail.$id/$id.png
        cd $REPODIR
        mkdir -p wwwsrc/fontname-thumbnail/${id:0:1}
        cp .testdir/thumbnail.$id/$id.png wwwsrc/fontname-thumbnail/${id:0:1}/$id.png
        rm -r .testdir/thumbnail.$id
        ;;
    tag)
        echo "$ git tag snapshot-$(TZ=UTC date +%Y%m%d)"
        echo "$ git push origin snapshot-$(TZ=UTC date +%Y%m%d)"
        echo "url:      https://github.com/neruthes/autowflib/releases/new"
        echo "msg:      This snapshot contains $(find cdndist/awfl-cdn/fonts -name '*.css' | wc -l) font definitions and $(find cdndist/awfl-cdn/fonts -name '*.woff2' | wc -l) WOFF artifacts."
        echo "files:"
        for i in pkgdist/*; do
            realpath $i
        done
        ;;
    cdn)
        rsync -av --mkpath distdir/ cdndist/awfl-cdn/
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
        distdir_families="$(ls distdir/fonts/*/*/*.css | cut -d/ -f4 | sort)"
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
        cd $REPODIR/wwwdist && tar -cf $REPODIR/pkgdist/wwwdist.tar .
        cd $REPODIR/cdndist && tar --xz -cf $REPODIR/pkgdist/cdn-mirror.tar.xz awfl-cdn
        cd $REPODIR
        tar --xz -cf $REPODIR/pkgdist/definitions.tar.xz $REPODIR/fonts
        cd $REPODIR/.testdir && tar -pxvf $REPODIR/pkgdist/cdn-mirror.tar.xz
        du -xh $REPODIR/pkgdist/*
        cd $REPODIR
        [[ -e pkgdist/cdn-mirror.sqfs ]] && rm pkgdist/cdn-mirror.sqfs
        mksquashfs cdndist pkgdist/cdn-mirror.sqfs -comp zstd -b 1M -one-file-system -Xcompression-level 22 -noappend
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
    '')
        bash $0 wwwdist pkgdist pkgdist/wwwdist.tar cf
        git add .
        git commit -m "Automatic deploy command: $(TZ=UTC date -Is | cut -c1-19 | sed 's/T/ /')"
        git push
        ;;
    *)
        echo "[ERROR] No rule to make '$1'. Stop."
        ;;
esac
