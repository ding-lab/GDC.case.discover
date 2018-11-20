source discover.paths.sh
DAT="dat/$PROJECT.SR.dat"
rm -f $OUT

if [ "$#" -ne 3 ]; then
    echo Error: Wrong number of arguments
    echo Usage: summarize_cases.sh CASE_FILE SR_FILE OUTFN
    exit
fi

CASES=$1
DAT=$2
OUT=$3

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

# Get counts for (tumor, normal, tissue) x (WGS.hg19, WXS.hg19, WGS.hg38, WXS.hg38, RNA-Seq, miRNA-Seq)
# Columns of SR.dat
#     1  sample_name
#     2  case
#     3  disease
#     4  experimental_strategy
#     5  sample_type
#     6  samples
#     7  filename
#     8  filesize
#     9  data_format
#    10  UUID
#    11  MD5
#    12  reference

# values of sample_type we are evaluating:
# blood_normal = N
# tissue_normal = A
# tumor = T

# Get number of matches for each data category
WGS19_T=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "WGS") && ($5 == "tumor") && ($12 == "hg19")) print}' $DAT | wc -l)
WGS19_N=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "WGS") && ($5 == "blood_normal") && ($12 == "hg19")) print}' $DAT | wc -l)
WGS19_A=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "WGS") && ($5 == "tissue_normal") && ($12 == "hg19")) print}' $DAT | wc -l)

WXS19_T=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "WXS") && ($5 == "tumor") && ($12 == "hg19")) print}' $DAT | wc -l)
WXS19_N=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "WXS") && ($5 == "blood_normal") && ($12 == "hg19")) print}' $DAT | wc -l)
WXS19_A=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "WXS") && ($5 == "tissue_normal") && ($12 == "hg19")) print}' $DAT | wc -l)

WGS38_T=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "WGS") && ($5 == "tumor") && ($12 == "hg38")) print}' $DAT | wc -l)
WGS38_N=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "WGS") && ($5 == "blood_normal") && ($12 == "hg38")) print}' $DAT | wc -l)
WGS38_A=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "WGS") && ($5 == "tissue_normal") && ($12 == "hg38")) print}' $DAT | wc -l)

WXS38_T=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "WXS") && ($5 == "tumor") && ($12 == "hg38")) print}' $DAT | wc -l)
WXS38_N=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "WXS") && ($5 == "blood_normal") && ($12 == "hg38")) print}' $DAT | wc -l)
WXS38_A=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "WXS") && ($5 == "tissue_normal") && ($12 == "hg38")) print}' $DAT | wc -l)

RNA_T=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "RNA-Seq") && ($5 == "tumor")) print}' $DAT | wc -l)
RNA_N=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "RNA-Seq") && ($5 == "blood_normal")) print}' $DAT | wc -l)
RNA_A=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "RNA-Seq") && ($5 == "tissue_normal")) print}' $DAT | wc -l)

MIRNA_T=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "miRNA-Seq") && ($5 == "tumor")) print}' $DAT | wc -l)
MIRNA_N=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "miRNA-Seq") && ($5 == "blood_normal")) print}' $DAT | wc -l)
MIRNA_A=$(awk -v c=$CASE 'BEGIN{FS="\t";OFS="\t"}{if ( ($2 == c) && ($4 == "miRNA-Seq") && ($5 == "tissue_normal")) print}' $DAT | wc -l)

# Get string representations, given character repeated as many times as datasets 
WGS19_TS=$(repN T $WGS19_T)
WGS19_NS=$(repN N $WGS19_N)
WGS19_AS=$(repN A $WGS19_A)

WXS19_TS=$(repN T $WXS19_T)
WXS19_NS=$(repN N $WXS19_N)
WXS19_AS=$(repN A $WXS19_A)

WGS38_TS=$(repN T $WGS38_T)
WGS38_NS=$(repN N $WGS38_N)
WGS38_AS=$(repN A $WGS38_A)

WXS38_TS=$(repN T $WXS38_T)
WXS38_NS=$(repN N $WXS38_N)
WXS38_AS=$(repN A $WXS38_A)

RNA_TS=$(repN T $RNA_T)
RNA_NS=$(repN N $RNA_N)
RNA_AS=$(repN A $RNA_A)

MIRNA_TS=$(repN T $MIRNA_T)
MIRNA_NS=$(repN N $MIRNA_N)
MIRNA_AS=$(repN A $MIRNA_A)

printf "$CASE\t$DIS\tWGS.hg19 $WGS19_TS $WGS19_NS $WGS19_AS\tWXS.hg19 $WXS19_TS $WXS19_NS $WXS19_AS\tWGS.hg38 $WGS38_TS $WGS38_NS $WGS38_AS\tWXS.hg38 $WXS38_TS $WXS38_NS $WXS38_AS\tRNA $RNA_TS $RNA_NS $RNA_AS\tmiRNA $MIRNA_TS $MIRNA_NS $MIRNA_AS\n"

}

while read L; do

    [[ $L = \#* ]] && continue  # Skip commented out entries

    CASE=$(echo "$L" | cut -f 1 )
    DIS=$(echo "$L" | cut -f 2 )

    >&2 echo Processing $CASE

    summarize_case $CASE $DIS >> $OUT

done < $CASES



