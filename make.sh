#!/bin/bash

source .env
source .localenv

REPODIR="$PWD"



if [[ ! -z "$2" ]]; then
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

paral="$(which paral)"

case $1 in
    _all)
        for TARGET_ID in fonts/*/*; do
            $paral bash src/fbuild.sh $TARGET_ID
        done
        ;;
    css)
        for TARGET_ID in fonts/*/*; do
            $paral bash src/fbuild.sh $TARGET_ID css_generate
        done
        ;;
    fonts/*)
        if [[ -e $1/info ]]; then
            id="$(basename $1)"
            TARGET_ID="$(dirname $1)/$id"
            ( bash src/fbuild.sh $TARGET_ID full | tee buildlog.txt && id="$id" bash $0 thumbnail )
        fi
        ;;
    fonts-relay/*)
        if [[ -e $1/info ]]; then
            id="$(basename $1)"
            TARGET_ID="$(dirname $1)/$id"
            (bash src/relay.sh $TARGET_ID full || exit 1) | tee buildlog.txt
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
        convert -size 3000x1500 xc:white -font "@$fileID.ttf" -pointsize 100 -fill black -annotate +100+100 "$family" -trim -bordercolor "#FFF" +repage -resize x80 $REPODIR/.testdir/thumbnail.$id/$id.png
        cd $REPODIR
        mkdir -p wwwsrc/fontname-thumbnail/${id:0:1}
        cp .testdir/thumbnail.$id/$id.png wwwsrc/fontname-thumbnail/${id:0:1}/$id.png
        rm -r .testdir/thumbnail.$id
        ;;
    tag)
        tagname="snapshot-$(TZ=UTC date +%Y%m%d)"
        echo "$ git tag $tagname && git push origin $tagname"
        echo "url:      https://github.com/neruthes/autowflib/releases/new"
        echo "msg:      This snapshot contains $(find distdir/fonts -name '*.css' | wc -l) font families and $(find distdir/fonts -name '*.woff2' | wc -l) WOFF2 artifacts."
        echo "files:"
        for i in pkgdist/*; do
            realpath $i
        done
        ;;
    cdn)
        rsync -av --mkpath distdir/ cdndist/awfl-cdn/
        ;;
    cf)
        wrangler pages publish wwwdist-real --project-name=autowflib --commit-dirty=true --branch=main          # Main website project
        wrangler pages publish cdndist --project-name=autowflibcdn --commit-dirty=true --branch=main            # Offcial CDN mirror
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
            info_file="$(ls */*/$id/info | head -n1)"
            type="$(cut -d/ -f1 <<< "$info_file")"
            cat="$(cut -d/ -f2 <<< "$info_file")"
            minikv_prefix="$(grep '^minikv=' "$info_file" | cut -d'"' -f2)"
            minikv="type=$type"
            echo "@family|$id|$(grep '^family=' */$cat/$id/info | head -n1 | cut -d= -f2 | tr -d \'\")|$cat|$minikv_prefix&$minikv" | sed 's/|&/|/' >> $outfn
            echo "@list|$(ls distdir/fonts/$cat/$id | grep 'woff2$' | tr '\n' '|')" >> $outfn
        done
        sed -i 's/|$//g' $outfn
        # cat $outfn
        ;;
    w | wwwdist | wwwdist/)
        ### 'wwwdist-real': Cloudflare Pages
        ### 'wwwdist': Local debugging
        bash $0 www_catalog                                 # Generate data catalog for index page
        cat distdir/css/*.css > wwwsrc/full.css             # Make the all-in-one CSS
        rsync -a --delete wwwsrc/ wwwdist/                  # Reset wwwdist by loading wwwsrc
        rsync -a wwwextra/ wwwdist/                         # Load wwwextra
        du -xhd2 wwwdist | tail -n1                         # How large is wwwdist now?
        if [[ $USER == neruthes ]]; then
            echo "[INFO] Remember to upload the tarball before pushing to GitHub master:"
            echo "    $  ./make.sh cdn cf pkgdist && cfoss pkgdist/wwwdist.tar && u"
        fi
        rsync -a --mkpath --delete cdndist/awfl-cdn/ wwwdist/awfl-cdn/          # Load CDN dir for debugging
        rsync -a --mkpath --delete wwwdist/ wwwdist-real/                       # Generate output dir for Cloudflare Pages
        rm -r wwwdist-real/awfl-cdn/                                            # Remove CDN dir from CF dir
        ;;
    p | pkgdist | pkgdist/)
        cd $REPODIR/wwwdist-real && tar -cf $REPODIR/pkgdist/wwwdist.tar .
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
        if [[ "$FORCE_UPLOAD" != y ]]; then
            if [[ "$last_push_time" -gt "$file_change_time" ]] && [[ $last_push_time -gt 10000 ]]; then
                delta_sec=$((last_push_time-file_change_time))
                delta_min=$((delta_sec/60))
                # echo "[INFO] The file '$1' was already uploaded ($(date --date=@$last_push_time '+%F'), $delta_min min after change). Set FORCE_UPLOAD=y to ignore date."
                exit 0
            fi
        fi
        smallfn="$(cut -d/ -f2- <<< "$1")"
        wrangler r2 object put "autowflibcdn/$smallfn" --file "$1" && db_insert "$1"
        ;;
    r2)
        [[ ! -z "$(which paral)" ]] && paral=paral
        for i in $(find cdndist/awfl-cdn -type f); do
            $paral bash $0 $i
        done
        ;;
    initdb)
        rm wwwextra/r2uploadtime.db
        echo "create table FnTimeMap(fn TEXT PRIMARY KEY, time INT)" | sqlite3 wwwextra/r2uploadtime.db
        ;;
    '')
        bash $0 wwwdist pkgdist cdn cf
        cfoss pkgdist/wwwdist.tar
        bash $0 r2
        git add .
        [[ -z "$msg" ]] && msg="Automatic deploy command: $(TZ=UTC date -Is | cut -c1-19 | sed 's/T/ /')"
        git commit -m "$msg"
        git push
        ;;
    *)
        echo "[ERROR] No rule to make '$1'. Stop."
        ;;
esac

