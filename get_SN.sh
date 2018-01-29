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

    if [ "$STL" == "Blood Derived Normal" ]; then
        ST="N"
    elif [ "$STL" == "Primary Tumor" ]; then
        ST="T"
    else
        >&2 echo Error: Unknown sample type: $STL
        exit
    fi

    if [ $ES == "RNA-Seq" ] && [ $DF == "FASTQ" ]; then
    # Identify R1, R2 by matching for _R1_ or _R2_ in filename.  This only works for FASTQs.
    # RNA-Seq filename 170830_UNC31-K00269_0078_AHLCVMBBXX_AGTCAA_S18_L006_R1_001.fastq.gz

        if [[ $FN == *"_R1_"* ]]; then
            RN="R1"
        elif [[ $FN == *"_R2_"* ]]; then
            RN="R2"
        else
            >&2 echo "Unknown filename format (cannot find _R1_ or _R2_): $FN"
            exit
        fi
        ES="$ES.$RN"
    fi

    SN="$CASE.$ES.$ST"
    echo $SN
}
