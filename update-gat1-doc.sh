#!/bin/bash
## Script to create/update the Doxygen document on e906-gat1.

DIR_PROG=$(dirname $(readlink -f $0))

if [ $(hostname -s) != 'e906-gat1' ] ; then
    echo "Usable only on 'e906-gat1'.  Abort."
    exit
fi

DIR_CORE=~/e1039/git/e1039-core
DIR_ANA=~/e1039/git/e1039-analysis
DO_FORCE=no
OPTIND=1
while getopts ":c:a:CAf" OPT ; do
    case $OPT in
        c ) DIR_CORE=$OPTARG ;;
        a ) DIR_ANA=$OPTARG ;;
        C ) DIR_CORE= ;;
        A ) DIR_ANA= ;;
        f ) DO_FORCE=yes ;;
    esac
done
shift $((OPTIND - 1))

DIR_OUT=/var/www/html/e1039/doxygen/$USER
echo "DIR_CORE = $DIR_CORE"
echo "DIR_ANA  = $DIR_ANA"
echo "DIR_OUT  = $DIR_OUT"
echo "DO_FORCE = $DO_FORCE"
echo

if [ $DO_FORCE != yes ] ; then
    echo -n "Good to go? (y/N): "
    read YN
    test "X$YN" != 'Xy' -a "X$YN" != 'Xyes' && echo "Abort." && exit
fi

rm -rf $DIR_OUT

{ # To doxygen
    cat $DIR_PROG/Doxyfile
    echo "INPUT = $DIR_PROG/Doxygen_Assist $DIR_CORE $DIR_ANA"
    echo "HTML_OUTPUT = $DIR_OUT"
    echo 'EXCLUDE_SYMLINKS = YES'
    echo 'EXCLUDE_PATTERNS = */build/* */scratch/*'
} | doxygen -

echo
echo "End."
