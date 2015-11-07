#!/usr/bin/env bash


HERE=$(dirname $0)
INFILE="${HERE}/opt-in.core.sh"
OUTFILE="${HERE}/opt-in.embed.sh"
ARCHIVE="${HERE}/opt-in.archive.sh"
README="${HERE}/README.md"
VERSION=$(cd $HERE && git describe --abbrev=0 --tags)

if [ ! -e $INFILE ]; then
    echo "input file missing, aborting ...: ${INFILE}"
    exit 1;
fi

echo "creating embeddable snippet $(basename $OUTFILE) from $(basename $OUTFILE)"
echo "  by stripping comments and blank lines"

cat << EOF > $OUTFILE
# ----------------------------------------------------------------------
# opt-in core option parser library, (c) 2014, Mikkel Fahnøe Jørgensen
# Version: ${VERSION}, License: MIT
# ----------------------------------------------------------------------
EOF

cat $INFILE \
     | sed '/^[[:blank:]]*#.*/d' \
     | sed '/^[[:blank:]]*$/d' >> $OUTFILE

cat << EOF >> $OUTFILE 
# ------------------------- end opt-in library -------------------------
EOF

echo ""
echo "creating self extracting archive $(basename $ARCHIVE) from $(basename $INFILE)"
echo "  by stripping comments and blank lines, then gzipping, and base64 encoding"
echo "  and wrapping in self-extractor for embedded use."

ARCHIVE_BEGIN="# ------------------------ begin opt-in archive ------------------------"
ARCHIVE_END="# ------------------------- end opt-in archive -------------------------"


cat << EOF > $ARCHIVE
$ARCHIVE_BEGIN
# opt-in option pre-parser library, (c) 2014, Mikkel Fahnøe Jørgensen
# Version: ${VERSION}, License: MIT
# ----------------------------------------------------------------------
read -d '' OPTINARCHIVE << ENDOFOPTINARCHIVE
EOF
cat $INFILE \
     | sed '/^[[:blank:]]*#.*/d' \
     | sed '/^[[:blank:]]*$/d' \
     | gzip -n | base64 -b 72 >> $ARCHIVE
cat << EOF >> $ARCHIVE
ENDOFOPTINARCHIVE
. <(echo \$OPTINARCHIVE | base64 -D | gunzip); unset OPTINARCHIVE;
$ARCHIVE_END
EOF

# a variation over
# http://stackoverflow.com/a/7104422
function update_archive {
    mv $1 $1.updating &&
    # delete lines from archive start to file end, print rest
    cat $1.updating | sed -e "/$ARCHIVE_BEGIN/,\$d" > $1 &&
    # insert archive
    cat $2 >> $1 &&
    # delete lines from file start to archive end, print rest
    cat $1.updating | sed -e "1,/$ARCHIVE_END/d" >> $1 &&
    rm $1.updating
}

# Github gets confused, so it has been disabled in README
# you can use the logic to update own projects if needed
# so leaving this here.
#echo "updating archive in $(basename $README)"
#update_archive $README $ARCHIVE

exit

# test
echo "testing in-place archive update"
testfile=${HERE}/template.test 
cat <<EOF > ${testfile}
# Friends
# ------------------------ begin opt-in archive ------------------------
# HERE BE DRAGONS
# ------------------------- end opt-in archive -------------------------
# Enemies
EOF

update_archive $testfile $ARCHIVE

cat $testfile
rm $testfile
