#!/bin/bash

# Matthew Wyczalkowski <m.wyczalkowski@wustl.edu>
# https://dinglab.wustl.edu/

# We are looping over two lists: aligned_reads and methyulation_array, and using aliquots.dat to provide additional information
# also add ad hoc suffixes as necessary, defined by aliquot or UUID

read -r -d '' USAGE <<'EOF'
Write a comprehensive summary of aligned reads and methylation array from GDC.  v2.2

Usage:
  make_catalog.sh [options] CASE DISEASE

Options:
-h: Print this help message
-v: Verbose.  May be repeated to get verbose output from queryGDC.sh
-Q ALIQUOTS_FN: aliquots file as generated by get_aliquots.sh.  Required
-R SUBMITTED_FN: submitted reads file as generated by get_submitted_reads.sh
-H HARMONIZED_FN: harmonized reads file as generated by get_harmonized_reads.sh
-M METHYL_FN: methylation array file as generated by get_methylation_array.sh
-o OUTFN: write results to output file instead of STDOUT.  Will be overwritten if exists
-N: do not write header
-s SUFFIX_LIST: data file for appending suffix to sample names

Writes Catalog file with the following columns:
    * sample_name - ad hoc name for this file, generated for convenience and consistency
    * case
    * disease
    * experimental_strategy - WGS, WXS, RNA-Seq, miRNA-Seq, Methylation Array, Targeted Sequencing
    * short_sample_type - short name for sample_type: blood_normal, tissue_normal, tumor, buccal_normal, tumor_bone_marrow, tumor_peripheral_blood
    * aliquot - name of aliquot used
    * filename
    * filesize
    * data_format - BAM, FASTQ, IDAT
    * result_type - "chimeric", "genomic", "transcriptome" in case of RNA-Seq BAMs, "Red" or "Green" for Methylation Array, NA otherwise
    * UUID
    * MD5
    * reference - assumed reference used, hg19 for submitted aligned reads, NA for submitted unaligned reads, and hg38 for harmonized reads
    * sample_type - sample type as reported from GDC, e.g., Blood Derived Normal, Solid Tissue Normal, Primary Tumor, and others
    * sample_id - GDC sample name  (NEW v2.2)
    * sample_metadata - Ad hoc metadata associated with this sample (NEW v2.2).  May be comma-separated list
    * aliquot_annotation - Annotation note associated with aliquot, from GDC (NEW v2.2)

SUFFIX_LIST is a TSV file used to add suffixes based on matches to UUID,
aliquot, and experimental strategy.  Input TSV file format is one of the
following:
  a) uuid, suffix
  b) aliquot, experimental_strategy, suffix
     * The wildcard * will be used to indicate all experimental strategies
multiple matches will give multiple sequential suffixes

EOF

# http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":hvQ:R:H:M:o:Ns:" opt; do
  case $opt in
    h)
      echo "$USAGE"
      exit 0
      ;;
    v)  
      VERBOSE="${VERBOSE}v"
      ;;
    Q)  
      ALIQUOTS_FN="$OPTARG"
      ;;
    R)  
      SUBMITTED_FN="$OPTARG"
      ;;
    H)  
      HARMONIZED_FN="$OPTARG"
      ;;
    M)  
      METHYL_FN="$OPTARG"
      ;;
    N)  
      NO_HEADER=1
      ;;
    o)  
      OUTFN="$OPTARG"
      if [ -f $OUTFN ]; then
          >&2 echo WARNING: $OUTFN exists.  Deleting
          rm -f $OUTFN
      fi
      ;;
    s)  
      SUFFIX_LIST="$OPTARG"
      if [ ! -s $SUFFIX_LIST ]; then
        >&2 echo ERROR: SUFFIX_LIST $SUFFIX_LIST does not exist or is empty
        exit 1
      fi
      ;;
    \?)
      >&2 echo "Invalid option: -$OPTARG"
      echo "$USAGE"
      exit 1
      ;;
    :)
      >&2 echo "Option -$OPTARG requires an argument."
      echo "$USAGE"
      exit 1
      ;;
  esac
done
shift $((OPTIND-1))

if [ "$#" -ne 2 ]; then
    >&2 echo Error: Wrong number of arguments
    echo "$USAGE"
    exit 1
fi
PASSED_CASE=$1
DISEASE=$2

# Called after running scripts to catch fatal (exit 1) errors
# works with piped calls ( S1 | S2 | S3 > OUT )
function test_exit_status {
    # Evaluate return value for chain of pipes; see https://stackoverflow.com/questions/90418/exit-shell-script-based-on-process-exit-code
    # exit code 137 is fatal error signal 9: http://tldp.org/LDP/abs/html/exitcodes.html

    rcs=${PIPESTATUS[*]};
    for rc in ${rcs}; do
        if [[ $rc != 0 ]]; then
            >&2 echo Fatal error.  Exiting
            exit $rc;
        fi;
    done
}

function confirm {
    FN=$1
    WARN=$2
    if [ ! -s $FN ]; then
        if [ -z $WARN ]; then
            >&2 echo ERROR: $FN does not exist or is empty
            exit 1
        else
            >&2 echo WARNING: $FN does not exist or is empty.  Continuing
        fi
    fi
}

# sample code, short name: sample type name
# N, blood_normal:   Blood Derived Normal
# Nbc, buccal_normal:   Buccal Cell Normal
# T, tumor:   Primary Tumor or Tumor
# Tbm, tumor_bone_marrow: Primary Blood Derived Cancer - Bone Marrow
# Tpb, tumor_peripheral_blood: Primary Blood Derived Cancer - Peripheral Blood
# A, tissue_normal:   Solid Tissue Normal

# Note: Buccal Cell Normal appears only in AML in conjuction with Tbm, Tbp.  Assume this is a "type" of normal

# Returns short code as above for given sample type name
function get_sample_code {
    STL="$1"

    if [ "$STL" == "Blood Derived Normal" ]; then
        ST="N"
    elif [ "$STL" == "Solid Tissue Normal" ]; then
        ST="A"
    elif [ "$STL" == "Primary Tumor" ] || [ "$STL" == "Tumor" ]; then
        ST="T"
    elif [ "$STL" == "Buccal Cell Normal" ]; then
        ST="Nbc"
    elif [ "$STL" == "Primary Blood Derived Cancer - Bone Marrow" ]; then
        ST="Tbm"
    elif [ "$STL" == "Primary Blood Derived Cancer - Peripheral Blood" ]; then
        ST="Tpb"
    else
        >&2 echo Error: Unknown sample type: $STL
        exit 1
    fi
    echo $ST
}

function get_sample_short_name {
    SAMPLE_TYPE="$1"
    if [ "$SAMPLE_TYPE" == "Blood Derived Normal" ]; then
        STS="blood_normal"
    elif [ "$SAMPLE_TYPE" == "Solid Tissue Normal" ]; then
        STS="tissue_normal"
    elif [ "$SAMPLE_TYPE" == "Primary Tumor" ] || [ "$SAMPLE_TYPE" == "Tumor" ]; then
        STS="tumor"
    elif [ "$SAMPLE_TYPE" == "Buccal Cell Normal" ]; then
        STS="buccal_normal"
    elif [ "$SAMPLE_TYPE" == "Primary Blood Derived Cancer - Bone Marrow" ]; then
        STS="tumor_bone_marrow"
    elif [ "$SAMPLE_TYPE" == "Primary Blood Derived Cancer - Peripheral Blood" ]; then
        STS="tumor_peripheral_blood"
    else
        >&2 echo Error: Unknown sample type: $SAMPLE_TYPE
        exit 1
    fi
    echo $STS
}

# sample names can get suffixes to be specified based on
# * UUID
# * Aliquot + Experimental Strategy
#   * The wildcard * will be used to indicate all experimental strategies
# Input TSV file format:
#   a) uuid, suffix
#   b) aliquot, experimental_strategy, suffix
# multiple matches will give multiple sequential suffixes, with uuid matches first

function get_SN_suffix {
# Example lines in suffix list
# CPT0170510019	WGS .high_cov
# CPT0170510019	* .core
# ea59f382-26e3-4548-9e50-757fdfaf8ecd .random
# 
# Idea is we try to match UUID then aliquot name to an entry in suffix list, and if there is a match,
# return the suffix, which is then appended to sample name
    SUFFIX_FN=$1
    UUID=$2
    ALIQUOT_NAME=$3
    ES=$4

    if [ -z $ES ]; then
        >&2 echo ERROR: provide experimental strategy
        exit 1
    fi

    confirm $SUFFIX_FN
    UM1=$(awk -v id=$UUID '{if ($1 == id) print $2}' $SUFFIX_FN )
    UM2=$(awk -v id=$ALIQUOT_NAME -v es=$ES '{if (($1 == id) && (( $2 == es ) || ( $2 == "*"))) print $3}' $SUFFIX_FN | tr -d '\n')
    UM=$(echo ${UM1}${UM2} | tr -d '\n')
    echo $UM
}

# Utility function to generate unique, human-readable sample name for downstream processing convenience.
# Sample names generated look like,
# * C3N-00858.WXS.N
# * C3N-00858.WXS.N.hg38
# * C3N-00858.WGS.T
# * C3N-00858.RNA-Seq.R1.T
# * C3N-00858.RNA-Seq.R2.T
# * C3N-00858.MethArray.Red.N
# * C3N-00858.MethArray.Green.N
# * C3N-00858.RNA-Seq.chimeric.T.hg38
# * C3N-00858.RNA-Seq.transcriptome.T.hg38
# * C3N-00858.RNA-Seq.genomic.T.hg38

# hg38 suffix added if reference code is hg38

# Create sample name from case, experimental_strategy, and sample_type abbreviation
# In the case of RNA-Seq, we extract the read number (R1 or R2) from the file name - this is empirical, and may change with different data types
# For the purpose of the name, experimental strategy "Targeted Sequencing" is renamed as "Targeted" and "Methylation Array" as "MethArray"
# RESULT_TYPE codes for two distinct things:
#   * For Methylation Array data, it is the channel
#   * For RNA-Seq harmonized BAMs, it is the result type, with values of genomic, chimeric, transcriptome
function get_SN {
    CASE=$1
    STL=$2
    ES=$3
    FN=$4
    DF=$5
    REF=$6
    RESULT_TYPE=$7

    ST=$(get_sample_code "$STL")
    test_exit_status

    if [ "$ES" == "Targeted Sequencing" ]; then
        LES="Targeted"
    elif [ "$ES" == "Methylation Array" ]; then
        LES="MethArray"
    else
        LES=$ES
    fi

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
        LES="$LES.$RN"
    elif [ $DF == "IDAT" ]; then
        LES="$LES.$RESULT_TYPE"
    elif [ $DF == "BAM" ] && [ $ES == "RNA-Seq" ]; then
        LES="$LES.$RESULT_TYPE"
    fi

    SN="$CASE.$LES.$ST"
    if [ $REF == "hg38" ]; then
        SN="${SN}.hg38"
    fi

    echo $SN
}

# get sample type associated with aliquot from ALIQUOTS_FN.  Confirm that all aliquots have exactly one sample type
# columns of aliquots fn
#    * case
#    * sample submitter id
#    * sample id
#    * sample type
#    * aliquot submitter id
#    * aliquot id
#    * analyte_type
#    * aliquot_annotation 
function get_sample_type {
    ALIQUOT_NAME=$1
    ALIQUOTS_FN=$2

    SAMPLE_TYPE=$(grep $ALIQUOT_NAME $ALIQUOTS_FN | cut -f 4 | sort -u)
    MATCH_COUNT=$(echo -n "$SAMPLE_TYPE" | grep -c '^')
    if [ $MATCH_COUNT == 0 ]; then
        >&2 echo ERROR: Sample type for aliquot $ALIQUOT_NAME not found in $ALIQUOTS_FN
        exit 1
    elif [ $MATCH_COUNT != 1 ]; then
        >&2 echo ERROR: Multiple sample types for aliquot $ALIQUOT_NAME in $ALIQUOTS_FN
        exit 1
    fi
    echo "$SAMPLE_TYPE"
}

# get sample ID associated with aliquot from ALIQUOTS_FN.  If there are multiple, return "," separated list
function get_sample_IDs {
    ALIQUOT_NAME=$1
    ALIQUOTS_FN=$2

    SAMPLE_ID=$(grep $ALIQUOT_NAME $ALIQUOTS_FN | cut -f 2 | sort -u)
    MATCH_COUNT=$(echo -n "$SAMPLE_TYPE" | grep -c '^')
    if [ $MATCH_COUNT == 0 ]; then
        >&2 echo ERROR: Sample ID for aliquot $ALIQUOT_NAME not found in $ALIQUOTS_FN
        exit 1
    fi
    SAMPLE_ID=$(echo -n "$SAMPLE_ID" | tr '\n' ',')
    echo "$SAMPLE_ID"
}

# get aliquot annotation associated with aliquot from ALIQUOTS_FN.  Error if multiple different annotations
function get_aliquot_annotation {
    ALIQUOT_NAME=$1
    ALIQUOTS_FN=$2

    ANNOS=$(grep $ALIQUOT_NAME $ALIQUOTS_FN | cut -f 8 | sort -u)
    MATCH_COUNT=$(echo -n "$ANNOS" | grep -c '^')

    if [ $MATCH_COUNT -gt 1 ]; then
        >&2 echo ERROR: Aliquot $ALIQUOT_NAME in $ALIQUOTS_FN has multiple distinct notes:
        >&2 echo $ANNOS
        exit 1
    fi
    echo "$ANNOS"
}

function process_reads {
    RFN=$1              # Reads filename, i.e., submitted or harmonized reads file
    ALIQUOTS_FN=$2
    PASSED_CASE=$3      # Sanity check - make sure looking at right dataset
    DISEASE=$4

# columns of RFN
#    * case
#    * aliquot submitter id
#    * assumed reference 
#    * experimental strategy
#    * data format
#    * file name
#    * file size
#    * id
#    * md5sum

    # Loop over all lines in input file RFN and write catalog entry for each
    while read L; do

        if [ "$L" == "" ]; then
            continue
        fi
        CASE=$(echo "$L" | cut -f 1 )
        ALIQUOT_NAME=$(echo "$L" | cut -f 2)
        REF=$(echo "$L" | cut -f 3)
        ES=$(echo "$L" | cut -f 4)
        DF=$(echo "$L" | cut -f 5)
        FN=$(echo "$L" | cut -f 6)
        FS=$(echo "$L" | cut -f 7)
        ID=$(echo "$L" | cut -f 8)
        MD5=$(echo "$L" | cut -f 9)

        if [ $CASE != $PASSED_CASE ]; then
            >&2 echo ERROR: CASE mismatch: passed $PASSED_CASE , $RFN = $CASE
            exit 1
        fi

        # Get result type for harmonized RNA-Seq BAMs: genomic, chimeric, transcriptome
        #   example: 73746f82-9ea4-45ac-87d8-bf0e3dc0c2fe.rna_seq.transcriptome.gdc_realn.bam
        RESULT_TYPE="NA"
        if [ $ES == "RNA-Seq" ] && [ $DF == "BAM" ]; then
            if [[ $FN == *"transcriptome"* ]]; then
                RESULT_TYPE="transcriptome"; 
            elif [[ $FN == *"genomic"* ]]; then
                RESULT_TYPE="genomic"; 
            elif [[ $FN == *"chimeric"* ]]; then
                RESULT_TYPE="chimeric"; 
            else
                >&2 echo ERROR: Unknown result type in RNA-Seq BAM $FN
                exit 1
            fi
        fi

        SAMPLE_TYPE=$(get_sample_type $ALIQUOT_NAME $ALIQUOTS_FN)
        test_exit_status

        SAMPLE_ID=$(get_sample_IDs $ALIQUOT_NAME $ALIQUOTS_FN)
        test_exit_status

        SAMPLE_METADATA=""      # TODO

        ALIQUOT_ANNOTATION=$(get_aliquot_annotation $ALIQUOT_NAME $ALIQUOTS_FN)
        test_exit_status

        SN=$(get_SN $CASE "$SAMPLE_TYPE" $ES $FN $DF $REF $RESULT_TYPE)
        test_exit_status

        # if SUFFIX_LIST is defined, ad hoc suffix is added to sample name based on match to UUID or aliquot name 
        if [ ! -z $SUFFIX_LIST ]; then
            SUFFIX=$(get_SN_suffix $SUFFIX_LIST $ID $ALIQUOT_NAME $ES)
            test_exit_status
            SN="${SN}$SUFFIX"
        fi

        STS=$(get_sample_short_name "$SAMPLE_TYPE")
        test_exit_status

        #printf "$SN\t$CASE\t$DISEASE\t$ES\t$STS\t$ALIQUOT_NAME\t$FN\t$FS\t$DF\t$RESULT_TYPE\t$ID\t$MD5\t$REF\t$SAMPLE_TYPE\n"
        printf "$SN\t$CASE\t$DISEASE\t$ES\t$STS\t$ALIQUOT_NAME\t$FN\t$FS\t$DF\t$CHANNEL\t$ID\t$MD5\t$REF\t$SAMPLE_TYPE\t$SAMPLE_ID\t$SAMPLE_METADATA\t$ALIQUOT_ANNOTATION\n"
    done < $RFN
}

function process_methylation_array {
    MAFN=$1
    ALIQUOTS_FN=$2
    PASSED_CASE=$3
    DISEASE=$4
# columns of MAFN / methylation array 
#    1 case
#    2 aliquot submitter id
#    3 assumed reference = NA 
#    4 submitter id
#    5 id
#    6 channel
#    7 file name
#    8 file size
#    9 data_format
#   10 experimental strategy
#   11 md5sum

    # Loop over all lines in input file MAFN and write catalog entry for each
    while read L; do
        CASE=$(echo "$L" | cut -f 1 )
        ALIQUOT_NAME=$(echo "$L" | cut -f 2)
        REF=$(echo "$L" | cut -f 3)
        ID=$(echo "$L" | cut -f 5)
        CHANNEL=$(echo "$L" | cut -f 6)
        FN=$(echo "$L" | cut -f 7)
        FS=$(echo "$L" | cut -f 8)
        DF=$(echo "$L" | cut -f 9)
        ES=$(echo "$L" | cut -f 10)
        MD5=$(echo "$L" | cut -f 11)

        if [ ! "$ES" == "Methylation Array" ]; then
            >&2 echo ERROR: Unexpected experimental strategy: $ES
            exit 1
        fi

        if [ $CASE != $PASSED_CASE ]; then
            >&2 echo ERROR: CASE mismatch: passed $PASSED_CASE , $RFN = $CASE
            exit 1
        fi

        SAMPLE_TYPE=$(get_sample_type $ALIQUOT_NAME $ALIQUOTS_FN)
        test_exit_status

        SAMPLE_ID=$(get_sample_IDs $ALIQUOT_NAME $ALIQUOTS_FN)
        test_exit_status

        SAMPLE_METADATA="NONE YET"

        ALIQUOT_ANNOTATION=$(get_aliquot_annotation $ALIQUOT_NAME $ALIQUOTS_FN)
        test_exit_status

        SN=$(get_SN $CASE "$SAMPLE_TYPE" "$ES" $FN $DF $REF $CHANNEL)
        test_exit_status

        # ad hoc suffix is added based on UUID or aliquot name if SUFFIX_LIST is defined
        if [ ! -z $SUFFIX_LIST ]; then
            SUFFIX=$(get_SN_suffix $SUFFIX_LIST $ID $ALIQUOT_NAME $ES)
            test_exit_status
            SN="${SN}$SUFFIX"
        fi

        STS=$(get_sample_short_name "$SAMPLE_TYPE")

        printf "$SN\t$CASE\t$DISEASE\t$ES\t$STS\t$ALIQUOT_NAME\t$FN\t$FS\t$DF\t$CHANNEL\t$ID\t$MD5\t$REF\t$SAMPLE_TYPE\t$SAMPLE_ID\t$SAMPLE_METADATA\t$ALIQUOT_ANNOTATION\n"
    done < $MAFN
}

confirm $ALIQUOTS_FN

if [ -z $NO_HEADER ]; then
    OUTLINE=$(printf "# sample_name\tcase\tdisease\texperimental_strategy\tshort_sample_type\taliquot\tfilename\tfilesize\tdata_format\tresult_type\tUUID\tMD5\treference\tsample_type\tsample_id\tsample_metadata\taliquot_annotation\n")
    if [ ! -z $OUTFN ]; then
        echo "$OUTLINE" >> $OUTFN
    else
        echo "$OUTLINE"
    fi
fi

# confirm that aliquot data exists
# then, process submitted reads, harmonized reads, and/or methylation data
# Note that arguments may be passed even if file is blank (because not in GDC)

if [ ! -z $SUBMITTED_FN ] && [ -s $SUBMITTED_FN ]; then
    confirm $SUBMITTED_FN
    LINES=$(process_reads $SUBMITTED_FN $ALIQUOTS_FN $PASSED_CASE $DISEASE)
    test_exit_status
    if [ ! -z $OUTFN ]; then
        echo "$LINES" >> $OUTFN
    else
        echo "$LINES"
    fi
fi

if [ ! -z $HARMONIZED_FN ] && [ -s $HARMONIZED_FN ]; then
    confirm $HARMONIZED_FN
    LINES=$(process_reads $HARMONIZED_FN $ALIQUOTS_FN $PASSED_CASE $DISEASE)
    test_exit_status
    if [ ! -z $OUTFN ]; then
        echo "$LINES" >> $OUTFN
    else
        echo "$LINES"
    fi
fi

if [ ! -z $METHYL_FN ] && [ -s $METHYL_FN ]; then
    confirm $METHYL_FN
    LINES=$(process_methylation_array $METHYL_FN $ALIQUOTS_FN $PASSED_CASE $DISEASE)
    test_exit_status
    if [ ! -z $OUTFN ]; then
        echo "$LINES" >> $OUTFN
    else
        echo "$LINES"
    fi
fi

if [ ! -z $OUTFN ]; then
    >&2 echo Written to $OUTFN
fi