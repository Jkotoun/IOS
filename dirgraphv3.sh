#!/bin/sh
POSIXLY_CORRECT=yes
#print hash for each file
print_size()
{
    hash_count=$1
    while [ "$hash_count" -gt 0 ]
    do
        printf "#"
        hash_count="$((hash_count-1))"
    done
}

#loop over files and dirs
#$1 = min size in bytes
#$2 = max size in bytes
#$3 = REGEX pattern to ignore matches files
filesize_count()
{
    if [ "$3" ]; then
        if [ "$1" -eq 0 ]; then #cant use -size 0+ (doesn't count files with 0bytes size, -1 changes to "less than byte")
            printf "%s" "$(find "$DIR" -type f -size -"$2"c 2>/dev/null | grep -Evc "$3")"
        elif [ "$2" = "inf" ];then
            printf "%s"  "$(find "$DIR" -type f -size +"$(($1-1))"c 2>/dev/null | grep -Evc "$3" )"
        else
            printf "%s" "$(find "$DIR" -type f -size +"$(($1-1))"c -size -"$2"c 2>/dev/null | grep -Evc "$3")"
        fi
    else
        if [ "$1" -eq 0 ]; then
            printf "%s"  "$(find "$DIR" -type f -size -"$2"c 2>/dev/null | wc -l)"
        elif [ "$2" = "inf" ];then
            printf "%s" "$(find "$DIR" -type f -size +"$(($1-1))"c 2>/dev/null | wc -l)"
        else
            printf "%s" "$(find "$DIR" -type f -size +"$(($1-1))"c -size -"$2"c 2>/dev/null | wc -l)"
        fi
    fi
}

#process args
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

#default root dir
DIR=$(pwd)

#remove processed args
OPTIND="$((OPTIND-1))"
shift $OPTIND

#check remaining args (should be directory name)
if [ $# -eq 1 ];
then
    DIR="$1" #set root dir as arg
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

#REGEX from user shouldn't match root dir 
if [ "$REGEX_PATTERN" ];
then
    if echo "$DIR" | grep -Eq "$REGEX_PATTERN";
    then
        echo "FILE_ERE regular expression must not match root directory" >&2
        exit 1
    fi
fi
#file and dir count - with or without regex
if [ "$REGEX_PATTERN" ]; then
    filecount=$(find "$DIR" -type f 2>/dev/null | grep -Evc "$REGEX_PATTERN")
    dircount=$(find "$DIR" -type d 2>/dev/null| grep -Evc "$REGEX_PATTERN")
else
    filecount=$(find "$DIR" -type f 2>/dev/null|wc -l)
    dircount=$(find "$DIR" -type d 2>/dev/null |wc -l)
fi

#count of files by size categories
L100B=$(filesize_count "0" "100" "$REGEX_PATTERN")
L1KiB=$(filesize_count "100" "1024" "$REGEX_PATTERN")
L10KiB=$(filesize_count "1024" "10240" "$REGEX_PATTERN")
L100KiB=$(filesize_count "10240" "102400" "$REGEX_PATTERN")
L1MiB=$(filesize_count "102400" "1048576" "$REGEX_PATTERN")
L10MiB=$(filesize_count "1048576" "10485760" "$REGEX_PATTERN")
L100MiB=$(filesize_count "10485760" "104857600" "$REGEX_PATTERN")
L1GiB=$(filesize_count "104857600" "1073741824" "$REGEX_PATTERN")
GE1GiB=$(filesize_count "1073741824" "inf" "$REGEX_PATTERN")

#-n -> recalculate number of files to print
if [ "$normalize" = "1" ]; then
    if [ -t 0 ]; then #terminal available
        max="$(tput cols)"
        max=$((max-12-1)) #line maxlenght-1-category print length
    else
        max=79
    fi
    #most occured size of file
    maxfile="$L100B"
    if [ "$L1KiB" -gt "$maxfile" ]; then maxfile="$L1KiB" ;fi
    if [ "$L10KiB" -gt "$maxfile" ]; then maxfile="$L10KiB";fi 
    if [ "$L100KiB" -gt "$maxfile" ]; then maxfile="$L100KiB";fi
    if [ "$L1MiB" -gt "$maxfile" ]; then maxfile="$L1MiB";fi
    if [ "$L10MiB" -gt "$maxfile" ]; then maxfile="$L10MiB";fi
    if [ "$L100MiB" -gt "$maxfile" ]; then maxfile="$L100MiB";fi
    if [ "$L1GiB" -gt "$maxfile" ]; then maxfile="$L1GiB";fi
    if [ "$GE1GiB" -gt "$maxfile" ]; then maxfile="$GE1GiB";fi
    #max num > max length -> normalize
    if [ "$maxfile" -gt "$max" ]; then
        rate=$(echo "$maxfile/$max" | bc -l)
        L100B=$(echo "(($L100B+$rate-1)/$rate)" | bc)
        L1KiB=$(echo "(($L1KiB+$rate-1)/$rate)" | bc)
        L10KiB=$(echo "(($L10KiB+$rate-1)/$rate)" | bc)
        L100KiB=$(echo "(($L100KiB+$rate-1)/$rate)" | bc)
        L1MiB=$(echo "(($L1MiB+$rate-1)/$rate)" | bc)
        L10MiB=$(echo "(($L10MiB+$rate-1)/$rate)" | bc)
        L100MiB=$(echo "(($L100MiB+$rate-1)/$rate)" | bc)
        L1GiB=$(echo "(($L1GiB+$rate-1)/$rate)" | bc)
        GE1GiB=$(echo "(($GE1GiB+$rate-1)/$rate)" | bc)   
    fi    
fi
#print dirgraph
echo "Root directory: $DIR"
echo "Directories: $dircount"
echo "All files: $filecount"
echo "File size histogram:"
printf "  <100 B  : ";print_size "$L100B" ; printf "\\n"
printf "  <1 KiB  : ";print_size "$L1KiB" ; printf "\\n"
printf "  <10 KiB : ";print_size "$L10KiB" ; printf "\\n"
printf "  <100 KiB: ";print_size "$L100KiB" ; printf "\\n"
printf "  <1 MiB  : ";print_size "$L1MiB" ; printf "\\n"
printf "  <10 MiB : ";print_size "$L10MiB" ; printf "\\n"
printf "  <100 MiB: ";print_size "$L100MiB" ; printf "\\n"
printf "  <1 GiB  : ";print_size "$L1GiB" ; printf "\\n"
printf "  >=1 GiB : ";print_size "$GE1GiB" ; printf "\\n"