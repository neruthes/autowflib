#!/bin/bash

REPODIR="$PWD"


USER_LAST_INPUT=""


function say() {
    printf '\n'
    echo -e -n "WIZARD:  $@"
}



say "Hello! I am an interactive script. I will help you creating a new font in this repo. Are you ready to begin?\n(y/n)> "
read USER_LAST_INPUT
[[ "$USER_LAST_INPUT" == y ]] && say "Great. Let the journey begin.\n"

### Get family
say "What is the family name of the font?\n> "
read USER_LAST_INPUT
f_family="$USER_LAST_INPUT"
say "Ok. The font family name is '$f_family'\n"

f_id="${f_family,,}"
f_id="$(sed 's|[^0-9a-z]|-|g' <<< "$f_id")"
say "The unique identifier can be '$f_id'. Is that ok?\n(y/n)> "
read USER_LAST_INPUT

if [[ "$USER_LAST_INPUT" == n* ]]; then
    say "What identifier do you want to use?\n> "
    read f_id
fi




### Get other info
say "What category does it belong to? (e.g. 'sans-humanist')\n> "
read f_cat

say "A short introduction? (e.g. 'A very clean Swiss sans-serif font design by John Appleseed')\n> "
read f_about

say "What is the license? (You may only choose from GPL/OFL/MIT)\n> "
read f_license

say "Website or webpage of this font? (e.g. https://...)\n> "
read f_infopage

say "Where to download the archive? (e.g. https://...)\n> "
read f_download
download_path="/tmp/addfont-dld.$USER.$f_cat.$f_id.archive"

say "I am starting to download it to '$download_path'. Ready?\n(y/n)> "
read USER_LAST_INPUT
[[ "$USER_LAST_INPUT" == n* ]] && exit 0

if [[ -e "$download_path" ]]; then
    say "The font archive seems already downloaded. Should I download again?\n(y/n)> "
    read USER_LAST_INPUT
    [[ "$USER_LAST_INPUT" == n* ]] && return 0
    say "Starting the download job..."
    wget "$f_download" -O "$download_path" || exit 1
else
    say "Starting the download job..."
    wget "$f_download" -O "$download_path" || exit 1
fi

f_sha256="$(sha256sum "$download_path" | cut -d' ' -f1)"

say "The SHA-256 hash of the downloaded archive is '$f_sha256'. I will remember it.\n"

say "What format is that archive?\n(zip/tar)> "
read f_format
extract_root="$(sed 's|archive$|dir|' <<< "$download_path")"
mkdir -p "$extract_root"
rm -r "$extract_root"
mkdir -p "$extract_root"
case $f_format in
    zip)
        printf ''
        cd "$extract_root"
        yes A | unzip "$download_path"
        ;;
    *)
        say "Sorry, I cannot process this format yet."
        exit 0
        ;;
esac
cd "$REPODIR"

say "Have a look at the directory structure:\n"
tree "$extract_root"

say "What format will be the source of WOFF2 artifacts?\n(skip/otf/ttf)> "
read f_convert_from



################################################################
### Final output
################################################################
echo "Here is the file you want:"
echo "-----------------------------------------------"
output_file_content="id=\"$f_id\"
family=\"$f_family\"
cat=\"$f_cat\"
about=\"$f_about\"
infopage=\"$f_infopage\"
license=\"$f_license\"

download=\"$f_download\"
format=\"$f_format\"
sha256=\"$f_sha256\"

convert_from=\"$f_convert_from\"

weight_map=\"\"
"
echo "$output_file_content"
echo "-----------------------------------------------"

say "Should I write the file into disk?\n(y/n)> "
read USER_LAST_INPUT
if [[ $USER_LAST_INPUT == y* ]]; then
    file_dir_path="fonts/$f_cat/$f_id"
    mkdir -p "$file_dir_path"
    file_path="$file_dir_path/info"
    echo "$output_file_content" > "$file_path"
    say "Your file is written into '$file_path'.\n"
    say "Next, you may run './make.sh $file_dir_path' to build for the font."
fi
exit 0










### Debugging
echo "y
Math Elite
y
mono-type
A typewriter font drawn from Dennis Ritchie's thesis.
OFL
https://fontesk.com/elite-math-font/
https://fontesk.com/download/87154/
y
y
zip
ttf
y" | ./addfont.sh
