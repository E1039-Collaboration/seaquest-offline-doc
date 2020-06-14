#!/bin/bash
## Script to update the Doxygen document in e1039-doc.
## Use crontab to run this script regularly:
##   */10 * * * * /path/to/update-github-e1039-doc.sh

PROG_BASE=$(basename $0 .sh)
DIR_WORK=/dev/shm/$USER/$PROG_BASE
FN_LOG=$DIR_WORK/log-update.txt

if [ $(hostname -s) != 'spinquestana1' ] ; then
    echo "Usable only on 'spinquestana1'.  Abort."
    exit
fi
if [ $USER != 'kenichi' ] ; then
    echo "Usable only by 'kenichi' at present.  Abort."
    exit
fi

mkdir -p $DIR_WORK

{ ## Redirect to log file

##
## Clone e1039-doc
##
cd $DIR_WORK
if [ ! -d e1039-doc ] ; then
    git clone git@github.com:E1039-Collaboration/e1039-doc.git
fi
cd e1039-doc
git checkout gh-pages

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
git fetch origin
for BR_ORG in 'origin/master' $(git branch -r | grep 'origin/doc_20') ; do
    BR_LOC=${BR_ORG#'origin/'}
    echo "  e1039-core branch:  $BR_LOC $BR_ORG"
    git checkout $BR_LOC
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
## Update the documents
##
for BR in ${LIST_CORE_BR[*]} ; do
    echo "  Branch: $BR"
    cd $DIR_WORK/e1039-core
    git checkout $BR
    cd $DIR_WORK/e1039-doc
    test -d docs/$BR && rm -rf docs/$BR
    mkdir -p docs/$BR
    ( cat Doxyfile ; echo "HTML_OUTPUT = docs/$BR" ) | doxygen - &>../log-doxygen-$BR.txt
done

TS="$(date '+%F %H:%M:%S')"

{ ## Create the index page.
    for BR in ${LIST_CORE_BR_ALL[*]} ; do
	echo "## [Version \"$BR\"]($BR/)"
    done
    echo "Last updated at $TS."
    
} >$DIR_WORK/e1039-doc/docs/README.md

cd $DIR_WORK/e1039-doc
git add --all docs &>../log-git-add.txt
git commit --message "$TS"
git push origin gh-pages

} &>$FN_LOG
