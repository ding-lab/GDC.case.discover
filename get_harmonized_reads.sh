# Read SR file, process it to obtain corresponding harmonized Aligned Reads, and write out HAR file
#
# Usage: get_harmonized_reads.sh SR.dat HAR.dat
# Read SR.dat and write to HAR.dat
#
# Retain only WGS and WXS data 
# HAR file has the same format as SR file, but with updated fields
#
# Example SR file:
#     sample_name   case    disease experimental_strategy   sample_type samples filename    filesize    data_format UUID    MD5 Reference
#     11LU013.WXS.N   11LU013 LUAD    WXS Blood Derived Normal    c7788b82-8190-4784-ab76-0d1185  CPT0040210002.WholeExome.RP-1303.bam    32888241174 BAM 29f82e93-1da2-4c11-9cdb-5ee1aaf05549    0dcb3aa42e3fc50136ff87a763478695  hg19
#
# Fields marked with * are replaced in the HAR (harmonized aligned reads) file
#     1    sample_name    * (.hg38 is appended)
#     2    case
#     3    disease
#     4    experimental_strategy
#     5    sample_type
#     6    samples
#     7    filename    * 
#     8    filesize    * 
#     9    data_format    * 
#    10    UUID        * 
#    11    MD5        * 


if [ "$#" -ne 2 ]; then
    echo Error: Wrong number of arguments
    echo Usage: get_harmonized_reads.sh SR.dat HAR.dat
    exit
fi

SR=$1
OUT=$2
if [ -z $GDC_TOKEN ]; then
    >&2 GDC_TOKEN environment variable not defined.  Quitting.
    exit 1
fi

function HAR_from_SAR {
    ID=$1 # ID of SAR (submitted aligned read), e.g., 29f82e93-1da2-4c11-9cdb-5ee1aaf05549
    cat <<EOF
{
    aligned_reads(with_path_to: {type: "submitted_aligned_reads", id:"$ID"})
    { 
        id
        file_name
        file_size
        data_format
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

>&2 echo Reading $SR, writing to $OUT

printf "# harmonized_sample_name\tcase\tdisease\texperimental_strategy\tsample_type\tsamples\tfilename\tfilesize\tdata_format\tUUID\tMD5\tReference\n" > $OUT

#     sample_name   case    disease experimental_strategy   sample_type samples filename    filesize    data_format UUID    MD5
while read L; do
# Example SR file:
#     sample_name   case    disease experimental_strategy   sample_type samples filename    filesize    data_format UUID    MD5
#     11LU013.WXS.N   11LU013 LUAD    WXS Blood Derived Normal    c7788b82-8190-4784-ab76-0d1185  CPT0040210002.WholeExome.RP-1303.bam    32888241174 BAM 29f82e93-1da2-4c11-9cdb-5ee1aaf05549    0dcb3aa42e3fc50136ff87a763478695

    [[ $L = \#* ]] && continue    # skip headers

    SN=$(echo "$L" | cut -f 1)
    CASE=$(echo "$L" | cut -f 2)
    DIS=$(echo "$L" | cut -f 3)
    ES=$(echo "$L" | cut -f 4)
    ST=$(echo "$L" | cut -f 5)
    SAMP=$(echo "$L" | cut -f 6)
    ID19=$(echo "$L" | cut -f 10)
    REF="hg38"

#     1    sample_name    * (.hg38 is appended)
#     2    case
#     3    disease
#     4    experimental_strategy
#     5    sample_type
#     6    samples
#     7    filename    * 
#     8    filesize    * 
#     9    data_format    * 
#    10    UUID        * 
#    11    MD5        * 

    if [ $ES == "WGS" ] || [ $ES == "WXS" ]; then 
        Q=$(HAR_from_SAR $ID19)
        >&2 echo QUERY: $Q
        R=$(echo $Q | $QUERYGDC -r -v -)
        
        # Test to see if query result is empty
        DAR=$(echo $R | jq -r '.data.aligned_reads[]')
        if [[ -z "$DAR" ]]; then
            >&2 echo $SN returns no results
        else
            >&2 echo $SN has results, processing...  # 1:UUID 2:FN 3:FS 4:DF 5:MD5
            echo $R | jq -r '.data.aligned_reads[] | "\(.id)\t\(.file_name)\t\(.file_size)\t\(.data_format)\t\(.md5sum)"' | \
                awk -v sn="$SN" -v c="$CASE" -v dis="$DIS" -v es="$ES" -v st="$ST" -v samp="$SAMP" -v ref="$REF" 'BEGIN{FS="\t"; OFS="\t"}{print sn".hg38", c, dis, es, st, samp, $2, $3, $4, $1, $5, ref}' >> $OUT
        fi
    elif [ $ES == "RNA-Seq" ] || [ $ES == "miRNA-Seq" ]; then 
        >&2 echo Not processing RNA-Seq $SN
    else 
# Fatal error if unknown ES
        >&2 echo ERROR: Unknown Experimental Strategy $ES    
        exit 1
    fi

done < $SR

>&2 echo Written to $OUT 
