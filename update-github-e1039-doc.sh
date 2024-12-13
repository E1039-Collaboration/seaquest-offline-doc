#!/bin/bash
## Script to update the Doxygen document in e1039-doc.
## Use crontab to run this script regularly:
##   */10 * * * * /path/to/update-github-e1039-doc.sh

DIR_PROG=$(dirname $(readlink -f $0))
BN_PROG=$(basename $0 .sh)
DIR_WORK=/dev/shm/$USER/$BN_PROG
FN_LOG=$DIR_WORK/log-update.txt

if [ $(hostname -s) != 'spinquestgpvm01' ] ; then
    echo "Usable only on 'spinquestana1'.  Abort."
    exit
fi
if [ $USER != 'kenichi' ] ; then
    echo "Usable only by 'kenichi' at present.  Abort."
    exit
fi

mkdir -p $DIR_WORK

{ ## Redirect to log file

echo "Program directory = $DIR_PROG"

##
## Clone or update e1039-analysis
##
cd $DIR_WORK
ANA_UPD=yes
if [ ! -d e1039-analysis ] ; then
    git clone git@github.com:E1039-Collaboration/e1039-analysis.git
else
    cd e1039-analysis
    MSG="$(git pull)"
    test "$MSG" = 'Already up-to-date.' && ANA_UPD=no
fi
echo "e1039-analysis updated = $ANA_UPD"

##
## Clone or update e1039-core
##
cd $DIR_WORK
CORE_CLONED=no
CORE_UPD=no
declare -a LIST_CORE_BR_ALL=()
declare -a LIST_CORE_BR_UPD=()
if [ ! -d e1039-core ] ; then
    git clone git@github.com:E1039-Collaboration/e1039-core.git
    CORE_CLONED=yes
fi
cd e1039-core
git fetch -p origin
for BR_ORG in 'origin/master' $(git branch -r | grep 'origin/doc_20') ; do
    BR_LOC=${BR_ORG#'origin/'}
    #echo "  e1039-core branch:  $BR_LOC $BR_ORG"
    git checkout -q $BR_LOC
    MSG="$(git merge $BR_ORG)"
    if [ $CORE_CLONED = 'yes' -o "$MSG" != 'Already up-to-date.' ] ; then
	LIST_CORE_BR_UPD+=($BR_LOC)
	CORE_UPD=yes
    fi
    LIST_CORE_BR_ALL+=($BR_LOC)
done
echo "e1039-core updated = $CORE_UPD"
echo "      all branches = ${LIST_CORE_BR_ALL[*]}"
echo "  updated branches = ${LIST_CORE_BR_UPD[*]}"

##
## Decide for which branches the document is updated
##
if [ $ANA_UPD = 'yes' ] ; then declare -a LIST_CORE_BR=(${LIST_CORE_BR_ALL[*]})
else                           declare -a LIST_CORE_BR=(${LIST_CORE_BR_UPD[*]})
fi
echo "Target e1039-core branches = ${LIST_CORE_BR[*]}"
if [ ${#LIST_CORE_BR[*]} -eq 0 ] ; then
    echo "No branch of e1039-core nor e1039-analysis was updated.  Exit."
    exit
fi

##
## Update the contents of e1039-doc:gh-pages
##
cd $DIR_WORK
if [ ! -d e1039-doc ] ; then
    git clone git@github.com:E1039-Collaboration/e1039-doc.git
fi
cd e1039-doc
git checkout -q gh-pages
rm -f Doxyfile Doxygen_Assist
ln -s $DIR_PROG/Doxyfile
ln -s $DIR_PROG/Doxygen_Assist

for BR in ${LIST_CORE_BR[*]} ; do
    echo "  Branch: $BR"
    cd $DIR_WORK/e1039-core
    git checkout -q $BR
    cd $DIR_WORK/e1039-doc
    test -d $BR && rm -rf $BR
    mkdir -p $BR
    ( cat Doxyfile ; echo "HTML_OUTPUT = $BR" ) | doxygen - &>../log-doxygen-$BR.txt
done

TS="$(date '+%F %H:%M:%S')"

{ ## Create the index page.
    echo "# Class Reference for E1039 Core & Analysis Software"
    for BR in ${LIST_CORE_BR_ALL[*]} ; do
	echo "## [Version \"$BR\"]($BR/)"
    done
    echo "Last updated at $TS."
} >$DIR_WORK/e1039-doc/README.md

cd $DIR_WORK/e1039-doc
{ ## Redirect to log file
    git add --all README.md ${LIST_CORE_BR[*]}
    git commit --message "$TS"
    git push origin gh-pages
} &>../log-git-add.txt

echo "End."

} &>$FN_LOG
