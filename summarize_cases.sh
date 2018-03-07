source discover.paths.sh
DAT="dat/$PROJECT.SR.dat"
rm -f $OUT

if [ "$#" -ne 2 ]; then
    echo Error: Wrong number of arguments
    echo Usage: summarize_cases.sh CASE_FILE OUTFN
    exit
fi

CASES=$1
OUT=$2

# Usage: repN X N
# will return a string consisting of character X repeated N times
# if N is 0 empty string is returned
# https://stackoverflow.com/questions/5349718/how-can-i-repeat-a-character-in-bash
function repN {
X=$1
N=$2

if [ $N == 0 ]; then
return
fi

printf "$1"'%.s' $(eval "echo {1.."$(($2))"}");

}

function summarize_case {
CASE=$1
DIS=$2

# Get counts for (tumor, normal) x (WGS, WXS, RNA-Seq)
# Columns of SR.dat
#     1	sample_name
#     2	case
#     3	disease
#     4	experimental_strategy
#     5	sample_type
#     6	samples
#     7	filename
#     8	filesize
#     9	data_format
#    10	UUID
#    11	MD5


#Primary Tumor = T
#Blood Derived Normal = N
#Solid Tissue Normal = A

# Get number of matches for each data category
WGS_T=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "WGS") && ($5 == "Primary Tumor")) print}' $DAT | wc -l)
WGS_N=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "WGS") && ($5 == "Blood Derived Normal")) print}' $DAT | wc -l)
WGS_A=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "WGS") && ($5 == "Solid Tissue Normal")) print}' $DAT | wc -l)

WXS_T=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "WXS") && ($5 == "Primary Tumor")) print}' $DAT | wc -l)
WXS_N=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "WXS") && ($5 == "Blood Derived Normal")) print}' $DAT | wc -l)
WXS_A=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "WXS") && ($5 == "Solid Tissue Normal")) print}' $DAT | wc -l)

RNA_T=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "RNA-Seq") && ($5 == "Primary Tumor")) print}' $DAT | wc -l)
RNA_N=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "RNA-Seq") && ($5 == "Blood Derived Normal")) print}' $DAT | wc -l)
RNA_A=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "RNA-Seq") && ($5 == "Solid Tissue Normal")) print}' $DAT | wc -l)

# Get string representations, given character repeated as many times as datasets 
WGS_TS=$(repN T $WGS_T)
WGS_NS=$(repN N $WGS_N)
WGS_AS=$(repN A $WGS_A)

WXS_TS=$(repN T $WXS_T)
WXS_NS=$(repN N $WXS_N)
WXS_AS=$(repN A $WXS_A)

RNA_TS=$(repN T $RNA_T)
RNA_NS=$(repN N $RNA_N)
RNA_AS=$(repN A $RNA_A)

printf "$CASE\t$DIS\tWGS $WGS_TS $WGS_NS $WGS_AS\tWXS $WXS_TS $WXS_NS $WXS_AS\tRNA $RNA_TS $RNA_NS $RNA_AS\n"

}

while read L; do

    [[ $L = \#* ]] && continue  # Skip commented out entries

    CASE=$(echo "$L" | cut -f 1 )
    DIS=$(echo "$L" | cut -f 2 )

    summarize_case $CASE $DIS >> $OUT

done < $CASES



