# Get details about submitted_aligned_reads and submitted_aligned_reads from read_group data
# For a given case, process read_group_from_case file.  Write SR_from_read_group

if [ "$#" -ne 1 ]; then
    echo Error: Wrong number of arguments
    echo Usage: get_submitted_reads.sh CASE 
    exit
fi

CASE=$1
if [ -z $GDC_TOKEN ]; then
    >&2 GDC_TOKEN environment variable not defined.  Quitting.
    exit 1
fi

function SAR_from_read_group {
    RG=$1 # E.g C3L-00004-31
    cat <<EOF
{
    submitted_aligned_reads(with_path_to: {type: "read_group", submitter_id:"$RG"})
    { 
        experimental_strategy
        data_category
        data_format
        id
        file_name
        file_size
        md5sum 
    }
}
EOF
}

function SUR_from_read_group {
    RG=$1 # E.g C3L-00004-31
    cat <<EOF
{
    submitted_unaligned_reads(with_path_to: {type: "read_group", submitter_id:"$RG"})
    { 
        experimental_strategy
        data_category
        data_format
        id
        file_name
        file_size
        md5sum 
    }
}
EOF
}

if [ -z $QUERYGDC_HOME ]; then
    QUERYGDC_HOME="./queryGDC"
    >&2 echo QUERYGDC_HOME not set, using default ./queryGDC
fi
QUERYGDC="$QUERYGDC_HOME/queryGDC"


DAT="dat/$CASE/read_group_from_case.$CASE.dat"
OUTD="dat/$CASE"
mkdir -p $OUTD
OUT="$OUTD/SR_from_read_group.$CASE.dat"
OUTTMP="$OUT.tmp"

rm -f $OUT $OUTTMP

>&2 echo Reading $DAT

while read L; do
# sample line
# C3L-00004-31	HFTVKBBXX161029.7.RP-1303.CPT0000140163.bam	WXS	CPT0000140163.WholeGenome.RP-1303.bam

    SAMPLE=$(echo "$L" | cut -f 1)
    RG=$(echo "$L" | cut -f 2)
    LIB=$(echo "$L" | cut -f 3)

    if [ $LIB == "WGS" ] || [ $LIB == "WXS" ]; then 

        Q=$(SAR_from_read_group $RG)
        >&2 echo QUERY: $Q

        R=$(echo $Q | $QUERYGDC -r -v -)

        echo $R | jq -r '.data.submitted_aligned_reads[] | "\(.experimental_strategy)\t\(.data_category)\t\(.data_format)\t\(.file_name)\t\(.file_size)\t\(.id)\t\(.md5sum)"' | sed "s/^/$SAMPLE\t/" >> $OUTTMP

    elif [ $LIB == "RNA-Seq" ] || [ $LIB == "miRNA-Seq" ]; then   # Assuming miRNA-Seq can be treated the same way

        Q=$(SUR_from_read_group $RG)
        >&2 echo QUERY: $Q
        R=$(echo $Q | $QUERYGDC -r -v -)

        echo $R | jq -r '.data.submitted_unaligned_reads[] | "\(.experimental_strategy)\t\(.data_category)\t\(.data_format)\t\(.file_name)\t\(.file_size)\t\(.id)\t\(.md5sum)"' | sed "s/^/$SAMPLE\t/" >> $OUTTMP

    else 

        >&2 echo WARNING: Unknown Library Strategy $LIB

    fi
    printf "\n"

done < $DAT

sort -u $OUTTMP > $OUT

echo Written to $OUT \( temp file $OUTTMP \)
printf "\n"
