# Provide comprehensive summary of submitted reads (aligned and unaligned)
# Reads SR_from_read_group, writes to stdout the following, one line per 
# submitted_aligned_reads/submitted_unaligned_reads ("SR"):
#   sample_name, case, disease, experimental_strategy, sample_type, samples, filename, filesize, data_format, UUID, md5sum, reference
# where 
#   sample_name is an ad hoc name for this file, generated for convenience and consistency
#   experimental_strategy is one of WGS, WXS, RNA-Seq
#   sample_type is one of "Primary Tumor", "Blood Derived Normal", "Primary Tumor", or "Primary Blood Derived Cancer - Bone Marrow"
#   samples is ;-separated list of all sample names associated with this SR
#   data_format is either BAM for FASTQ
#   reference is hg19 for all BAMs here (will be different in harmonized data).  RNA-Seq and miRNA-Seq (FASTQ) have NA as reference

# Usage: merge_submitted_reads.sh CASES outfn
# where CASES is filename of list of cases and their disease
# and outfn is the filename of the merged SR file


if [ "$#" -ne 2 ]; then
    echo Error: Wrong number of arguments
    echo Usage: merge_submitted_reads.sh CASES outfn
    exit 1
fi

# Utility function to generate unique, human-readable sample name for downstream processing convenience.
# Sample names generated look like,
# * C3N-00858.WXS.N
# * C3N-00858.WGS.T
# * C3N-00858.RNA-Seq.R1.T
# * C3N-00858.RNA-Seq.R2.T

# Create sample name from case, experimental_strategy, and sample_type abbreviation
# In the case of RNA-Seq, we extract the read number (R1 or R2) from the file name - this is empirical, and may change with different data types
function get_SN {
    CASE=$1
    STL=$2
    ES=$3
    FN=$4
    DF=$5

# N:   Blood Derived Normal
# B:   Buccal Cell Normal
# Tbm: Primary Blood Derived Cancer - Bone Marrow
# Tpb: Primary Blood Derived Cancer - Peripheral Blood
# T:   Primary Tumor
# A:   Solid Tissue Normal


    if [ "$STL" == "Blood Derived Normal" ]; then
        ST="N"
    elif [ "$STL" == "Solid Tissue Normal" ]; then
        ST="A"
    elif [ "$STL" == "Primary Tumor" ]; then
        ST="T"
    elif [ "$STL" == "Buccal Cell Normal" ]; then
        ST="B"
    elif [ "$STL" == "Primary Blood Derived Cancer - Bone Marrow" ]; then
        ST="Tbm"
    elif [ "$STL" == "Primary Blood Derived Cancer - Peripheral Blood" ]; then
        ST="Tpb"
    else
        >&2 echo Error: Unknown sample type: $STL
        exit 1
    fi

#    if [ $ES == "RNA-Seq" ] && [ $DF == "FASTQ" ]; then
    if [ $DF == "FASTQ" ]; then
    # Identify R1, R2 by matching for _R1_ or _R2_ in filename.  This only works for FASTQs.
    # RNA-Seq filename 170830_UNC31-K00269_0078_AHLCVMBBXX_AGTCAA_S18_L006_R1_001.fastq.gz

        if [[ $FN == *"_R1_"* ]]; then
            RN="R1"
        elif [[ $FN == *"_R2_"* ]]; then
            RN="R2"
        else
            >&2 echo "Unknown filename format (cannot find _R1_ or _R2_): $FN"
            exit 1
        fi
        ES="$ES.$RN"
    fi

    SN="$CASE.$ES.$ST"
    echo $SN
}

function process_case {
    CASE=$1
    DISEASE=$2

    SAMP_FN="dat/$CASE/sample_from_case.$CASE.dat"
    SR_FN="dat/$CASE/SR_from_read_group.$CASE.dat"

    # test for cases with no samples, print to stderr and return
    if [ ! -s $SAMP_FN ]; then

    >&2 echo Warning: $SAMP_FN is empty

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
                # >&2 echo Continuing
                exit 1
            fi
            SAMP_TYPE=$ST
        done < <(grep $ID $SR_FN | cut -f 1)  # loop over all samples 

        ES=$(grep $ID $SR_FN | cut -f 2 | head -n1)
        FN=$(grep $ID $SR_FN | cut -f 5 | head -n1)
        FS=$(grep $ID $SR_FN | cut -f 6 | head -n1)
        DF=$(grep $ID $SR_FN | cut -f 4 | head -n1)
        MD=$(grep $ID $SR_FN | cut -f 8 | head -n1)

        SN=$(get_SN $CASE "$SAMP_TYPE" $ES $FN $DF)

        if [ $DF == "FASTQ" ]; then
            REF="NA"
        else
            REF="hg19"
        fi

        if [ "$SAMP_TYPE" == "Blood Derived Normal" ]; then
            STS="blood_normal"
        elif [ "$SAMP_TYPE" == "Solid Tissue Normal" ]; then
            STS="tissue_normal"
        elif [ "$SAMP_TYPE" == "Primary Tumor" ]; then
            STS="tumor"
        elif [ "$SAMP_TYPE" == "Buccal Cell Normal" ]; then
            STS="buccal_normal"
        elif [ "$SAMP_TYPE" == "Primary Blood Derived Cancer - Bone Marrow" ]; then
            STS="tumor_bone_marrow"
        elif [ "$SAMP_TYPE" == "Primary Blood Derived Cancer - Peripheral Blood" ]; then
            STS="tumor_peripheral_blood"
        else
            >&2 echo Error: Unknown sample type: $SAMP_TYPE
            exit 1
        fi

        printf "$SN\t$CASE\t$DISEASE\t$ES\t$STS\t$SAMPS\t$FN\t$FS\t$DF\t$ID\t$MD\t$REF\n"

    done < <(cut -f 7 $SR_FN | sort -u)
}


CASES=$1
OUT=$2

printf "# sample_name\tcase\tdisease\texperimental_strategy\tsample_type\tsamples\tfilename\tfilesize\tdata_format\tUUID\tMD5\treference\n" > $OUT

while read L; do

[[ $L = \#* ]] && continue  # Skip commented out entries

    CASE=$(echo "$L" | cut -f 1 )
    DIS=$(echo "$L" | cut -f 2 )

    >&2 echo Processing $CASE \($DIS\)

    process_case $CASE $DIS >> $OUT

done < $CASES
