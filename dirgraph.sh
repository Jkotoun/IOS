#!/bin/sh
POSIXLY_CORRECT=yes

while getopts :i:n arg
do 
    case "$arg" in
        i)
        REGEX_PATTERN=$OPTARG
        ;;
        n)
        normalize=1
        ;;
        *)
        echo "invalid args" >&2
        exit 1
    esac 
done
#remove processed args
OPTIND="$((OPTIND-1))"
shift $OPTIND

#check remaining args (should be directory name)
if [ $# -eq 1 ];
then
    DIR="$1"
    if [ ! -d "$DIR" ];
    then
        echo "Non existing directory">&2
        exit 1
    fi
elif [ $# -ge 1 ];
then
    echo "invalid args">&2  
    exit 1
fi
#root dir
DIR=$(pwd)

#REGEX from user cant match root dir 
if [ "$REGEX_PATTERN" ];
then
    if echo "$DIR" | egrep -q "$REGEX_PATTERN";
    then
        echo "FILE_ERE regular expression must not match root directory"
        exit 1
    fi
fi

echo "Root directory: $DIR"