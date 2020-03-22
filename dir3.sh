#!/bin/sh
POSIXLY_CORRECT=yes
exitcode=0
print_size()
{
    hash_count=$1
    while [ "$hash_count" -gt 0 ]
    do
        printf "#"
        hash_count="$((hash_count-1))"
    done
}
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
#default root dir
DIR=$(pwd)
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

#REGEX from user cant match root dir 
if [ "$REGEX_PATTERN" ];
then
    if echo "$(basename "${DIR}")" | grep -Eq "$REGEX_PATTERN";
    then
        echo "FILE_ERE regular expression must not match root directory" >&2
        exit 1
    fi
fi
#variables init
filecount=0
dircount=0
L100B=0
L1KiB=0
L10KiB=0
L100KiB=0
L1MiB=0
L10MiB=0
L100MiB=0
L1GiB=0
GE1GiB=0
#recursively explores folders and files
# $1 = destination dir
explore_dir()
{
    for f in eval echo $1
    do
    
        if [ "$REGEX_PATTERN" ];then
            if echo "$(basename "${f}")"| grep -Eq "$REGEX_PATTERN";then
        continue
    fi
    fi
    if [ -f "$f" ]; then
        if [ ! -r "$f" ];then
         exitcode=1
            continue  
        fi
        filecount=$((filecount+1))
        size=$(wc -c <"$f")
        if [ "$size" -lt 100 ];then          #<100B
            L100B="$((L100B+1))" 
        elif [ "$size" -lt 1024 ];then       #<1KiB
            L1KiB="$((L1KiB+1))"
        elif [ "$size" -lt 10240 ];then      #<10KiB
            L10KiB="$((L10KiB+1))"
        elif [ "$size" -lt 102400 ];then     #<100KiB
            L100KiB="$((L100KiB+1))"
        elif [ "$size" -lt 1048576 ];then    #<1MiB
            L1MiB="$((L1MiB+1))"
        elif [ "$size" -lt 10485760 ];then   #<10MiB
            L10MiB="$((L10MiB+1))"
        elif [ "$size" -lt 104857600 ];then  #<100MiB
            L100MiB="$((L100MiB+1))"
        elif [ "$size" -lt 1073741824 ];then #<1GiB
            L1GiB="$((L1GiB+1))"
        else                                 #>=1GiB
            GE1GiB="$((GE1GiB+1))"
        fi
    elif [ -d "$f" ]; then
        dircount=$((dircount+1))
        explore_dir ""$f"/*"
    fi
    done 
}
#call function for recursive search through folders
explore_dir $DIR

if [ "$normalize" = "1" ]; then
    #boga="$(tput cols)"
    if [ -t 0 ]; then
        max="$(tput cols)"
        max=$((max-12-1)) ##line maxlenght-1-category print length
    else
        max=79
    fi
    #most occured size of file
    maxfile="$L100B"
    if [ $L1KiB -gt $maxfile ]; then maxfile=$L1KiB ;fi
    if [ $L10KiB -gt $maxfile ]; then maxfile=$L10KiB;fi 
    if [ $L100KiB -gt $maxfile ]; then maxfile=$L100KiB;fi
    if [ $L1MiB -gt $maxfile ]; then maxfile=$L1MiB;fi
    if [ $L10MiB -gt $maxfile ]; then maxfile=$L10MiB;fi
    if [ $L100MiB -gt $maxfile ]; then maxfile=$L100MiB;fi
    if [ $L1GiB -gt $maxfile ]; then maxfile=$L1GiB;fi
    if [ $GE1GiB -gt $maxfile ]; then maxfile=$GE1GiB;fi
    #max hashed doesnt fit line - normalize
    if [ $maxfile -gt $max ]; then
        rate=`echo "$maxfile/$max" | bc -l`
        L100B=`echo "(($L100B+$rate-1)/$rate)" | bc`
        L1KiB=`echo "(($L1KiB+$rate-1)/$rate)" | bc`
        L10KiB=`echo "(($L10KiB+$rate-1)/$rate)" | bc`
        L100KiB=`echo "(($L100KiB+$rate-1)/$rate)" | bc`
        L1MiB=`echo "(($L1MiB+$rate-1)/$rate)" | bc`
        L10MiB=`echo "(($L10MiB+$rate-1)/$rate)" | bc`
        L100MiB=`echo "(($L100MiB+$rate-1)/$rate)" | bc`
        L1GiB=`echo "(($L1GiB+$rate-1)/$rate)" | bc`
        GE1GiB=`echo "(($GE1GiB+$rate-1)/$rate)" | bc`   
    fi
    
fi
echo "Root directory: $DIR"
echo "Directories: $dircount"
echo "All files: $filecount"
echo "File size histogram:"
printf "  <100 B  : ";print_size $L100B ; printf "\n"
printf "  <1 KiB  : ";print_size $L1KiB ; printf "\n"
printf "  <10 KiB : ";print_size $L10KiB ; printf "\n"
printf "  <100 KiB: ";print_size $L100KiB ; printf "\n"
printf "  <1 MiB  : ";print_size $L1MiB ; printf "\n"
printf "  <10 MiB : ";print_size $L10MiB ; printf "\n"
printf "  <100 MiB: ";print_size $L100MiB ; printf "\n"
printf "  <1 GiB  : ";print_size $L1GiB ; printf "\n"
printf "  >=1 GiB : ";print_size $GE1GiB ; printf "\n"
if [ ! $exitcode -eq 0 ]; then
    echo "Access to some files denied">&2
    exit $exitcode
fi