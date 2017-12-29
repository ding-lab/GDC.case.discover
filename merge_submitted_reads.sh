# Provide comprehensive summary of submitted reads (aligned and unaligned)
# Reads SR_from_read_group, writes to stdout the following, one line per 
# submitted_aligned_reads/submitted_unaligned_reads ("SR"):
#   case, disease, experimental_strategy, sample_type, samples, filename, filesize, data_format, UUID, md5sum
# where 
#   experimental_strategy is one of WGS, WXS, RNA-Seq
#   sample_type is one of "Primary Tumor", "Blood Derived Normal"
#   samples is ;-separated list of all sample names associated with this SR
#   data_format is either BAM for FASTQ


if [ "$#" -ne 2 ]; then
    echo Error: Wrong number of arguments
    echo Usage: merge_submitted_reads.sh CASE DISEASE 
    exit
fi

CASE=$1
DISEASE=$2

SAMP_FN="dat/$CASE/sample_from_case.$CASE.dat"
SR_FN="dat/$CASE/SR_from_read_group.$CASE.dat"

# test for cases with no samples, print to stderr and return
if [ ! -s $SAMP_FN ]; then

>&2 echo $SAMP_FN is empty
exit

fi


# Strategy: go over SR (submitted reads) list, and group by ID (of submitted read object)
# Fields we want, and source:
# Case, disease: passed 
# Sample: ;-separated list of samples with same ID
# Expermental_strategy - from SR
# Sample_type: lookup by Sample from "sample_from_case" file; error check to make sure they are same for all samples
# Id, filename, filesize, md5sum - from SR

# SR_from_read_group columns:
# 1. sample
# 2. experimental_strategy
# 3. data_category
# 4. data_format
# 5. file_name
# 6. file_size
# 7. id
# 8. md5sum

# sample_from_case columns:
# 1. submitter_id
# 2. id
# 3. sample_type



while read ID; do 

    SAMPS=$(grep $ID $SR_FN | cut -f 1 | tr '\n' ';' | sed 's/;$//')  # Merge all sample names associated with this ID into ;-separated string

    SAMP_TYPE="" # final value here
    # Sanity check: that all associated sample types must be the same
    while read S; do
        ST=$(grep $S $SAMP_FN | cut -f 3)
        if [ ! -z "$SAMP_TYPE" ] && [ "$SAMP_TYPE" != "$ST" ]; then
            >&2 echo ERROR: Multiple sample types for Case $CASE ID $ID \( $SAMP_TYPE and $ST \)
            exit
        fi
        SAMP_TYPE=$ST
    done < <(grep $ID $SR_FN | cut -f 1)  # loop over all samples 

    ES=$(grep $ID $SR_FN | cut -f 2 | head -n1)
    FN=$(grep $ID $SR_FN | cut -f 5 | head -n1)
    FS=$(grep $ID $SR_FN | cut -f 6 | head -n1)
    DF=$(grep $ID $SR_FN | cut -f 4 | head -n1)
    MD=$(grep $ID $SR_FN | cut -f 8 | head -n1)

    printf "$CASE\t$DISEASE\t$ES\t$SAMP_TYPE\t$SAMPS\t$FN\t$FS\t$DF\t$ID\t$MD\n"

done < <(cut -f 7 $SR_FN | sort -u)


