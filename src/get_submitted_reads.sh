# Matthew Wyczalkowski <m.wyczalkowski@wustl.edu>
# https://dinglab.wustl.edu/

read -r -d '' USAGE <<'EOF'
Query GDC to obtain information about submitted aligned and unaligned reads associated with given read groups

Usage:
  get_submitted_reads.sh [options] read_groups.dat

read_groups.dat is a file with read group information as generated by get_read_groups.sh
Writes the following columns for each submitted aligned / unaligned reads entry:
    * case
    * aliquot submitter id
    * assumed reference - this is hg19 for aligned reads and NA for unaligned reads
    * experimental strategy
    * data format
    * file name
    * file size
    * id
    * md5sum
    * state

Options:
-h: Print this help message
-v: Verbose.  May be repeated to get verbose output from queryGDC
-o OUTFN: write results to output file instead of STDOUT.  Will be overwritten if exists
-t TMPL: temp file template, with `X` replaced by random characters.  Default: /tmp/get_submitted_reads.XXXXXX
-T: do not delete temp file
-1: stop after processing one line from read_groups.dat

Require GDC_TOKEN environment variable to be defined with path to gdc-user-token.*.txt file
Note that a temporary file is written to /tmp/get_submitted_reads.XXXXXX then deleted
EOF

QUERYGDC="src/queryGDC.sh"
TMPL="/tmp/get_submitted_reads.XXXXXX"
# http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":hvo:T:t1" opt; do
  case $opt in
    h)
      echo "$USAGE"
      exit 0
      ;;
    v)  
      VERBOSE="${VERBOSE}v"
      ;;
    o)  
      OUTFN="$OPTARG"
      if [ -f $OUTFN ]; then
          >&2 echo WARNING: $OUTFN exists.  Deleting
          rm -f $OUTFN
      fi
      ;;
    t)  
      TMPL="${OPTARG}v"
      ;;
    T)  
      NO_DELETE_TMP=1
      ;;
    1)  
      ONLYONE=1
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

if [ "$#" -ne 1 ]; then
    >&2 echo Error: Wrong number of arguments
    echo "$USAGE"
    exit 1
fi
DAT=$1

if [ -z $GDC_TOKEN ]; then
    >&2 echo GDC_TOKEN environment variable not defined.  Quitting.
    exit 1
fi

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

# Get details about submitted_aligned_reads and submitted_aligned_reads from read_group data
# For a given case, process read_group_from_case file.  Write SR_from_read_group

function SAR_from_read_group {
    RGSID=$1 # E.g C3L-00004-31
    cat <<EOF
{
    submitted_aligned_reads(with_path_to: {type: "read_group", submitter_id:"$RGSID"})
    { 
        experimental_strategy
        data_format
        id
        file_name
        file_size
        md5sum 
        state
    }
}
EOF
}

function SUR_from_read_group {
    RGSID=$1 # E.g C3L-00004-31
    cat <<EOF
{
    submitted_unaligned_reads(with_path_to: {type: "read_group", submitter_id:"$RGSID"})
    { 
        experimental_strategy
        data_format
        id
        file_name
        file_size
        md5sum 
        state
    }
}
EOF
}

# tempfile creation: https://unix.stackexchange.com/questions/181937/how-create-a-temporary-file-in-shell-script
# this also suggests ways to have temp file be deleted automatically even if script crashes, not doing that now
TMPFILE=$(mktemp $TMPL)

if [ $VERBOSE ]; then
    >&2 echo Processing $DAT
    >&2 echo Writing to temp file $TMPFILE
    # If verbose flag repeated multiple times (e.g., VERBOSE="vvv"), pass the value of VERBOSE with one flag popped off (i.e., VERBOSE_ARG="vv")
    VERBOSE_ARG=${VERBOSE%?}
fi

if [ ! -e $DAT ]; then
    >&2 echo NOTE: $DAT is empty.  Continuing
    exit 0
fi

# Iterate over all read groups, which have a many-one relationship with submitted (un)aligned reads
while read L; do
#    * case
#    * aliquot submitter id
#    * read group submitter id
#    * library strategy
#    * experiment name
#    * target capture kit target region

    CASE=$(echo "$L" | cut -f 1)
    ASID=$(echo "$L" | cut -f 2)
    RGSID=$(echo "$L" | cut -f 3)
    ES=$(echo "$L" | cut -f 4)

# Submitted aligned reads:
#    WGS
#    WXS
#    Targeted Sequencing
# Submitted unaligned reads: 
#    RNA-Seq
#    miRNA-Seq
#    ATAC-Seq
#    scRNA-Seq
#    HiChIP
#    scATAC-Seq


    if [ "$ES" == "WGS" ] || [ "$ES" == "WXS" ] || [ "$ES" == "Targeted Sequencing" ]; then
        Q=$(SAR_from_read_group $RGSID)
    elif [ "$ES" == "RNA-Seq" ] || [ "$ES" == "miRNA-Seq" ] || [ "$ES" == "ATAC-Seq" ] || [ "$ES" == "scRNA-Seq" ] || [ "$ES" == "HiChIP" ] || [ "$ES" == "scATAC-Seq" ] ; then   
        Q=$(SUR_from_read_group $RGSID)
    else 
        >&2 echo ERROR: Unknown Experimental Strategy $ES
        >&2 echo CASE = $CASE   Aliquot = $ASID    Read Group = $RGSID
        exit 1
    fi

    # Query for submitted reads
    if [ $VERBOSE ]; then
        >&2 echo QUERY: $Q
    fi

    R=$(echo $Q | $QUERYGDC -r $VERBOSE_ARG -)
    test_exit_status
    if [ $VERBOSE ]; then
        >&2 echo RESULT: $R
    fi

    # Process results for submitted reads and make query for corresponding harmonized reads
    if [ "$ES" == "WGS" ] || [ "$ES" == "WXS" ] || [ "$ES" == "Targeted Sequencing" ] ; then
        SR=$(echo $R | jq -r '.data.submitted_aligned_reads[]   | "\(.experimental_strategy)\t\(.data_format)\t\(.file_name)\t\(.file_size)\t\(.id)\t\(.md5sum)\t\(.state)"' | sed "s/^/$CASE\t$ASID\tsubmitted_aligned\t/" )
        test_exit_status
    else
        SR=$(echo $R | jq -r '.data.submitted_unaligned_reads[] | "\(.experimental_strategy)\t\(.data_format)\t\(.file_name)\t\(.file_size)\t\(.id)\t\(.md5sum)\t\(.state)"' | sed "s/^/$CASE\t$ASID\tsubmitted_unaligned\t/" )
        test_exit_status
    fi
    echo "$SR" >> $TMPFILE

    if [ $ONLYONE ]; then
        >&2 echo Quitting after one
        break
    fi

done < $DAT

# Skip sorting in the event $DAT is empty
if [ -e $TMPFILE ]; then
    if [ ! -z $OUTFN ]; then
        sort -u $TMPFILE > $OUTFN
    else
        sort -u $TMPFILE 
    fi
else
    if [ ! -z $OUTFN ]; then
        >&2 echo No data.  Creating empty file $OUTFN
    fi
fi

if [ -z $NO_DELETE_TMP ]; then
    if [ $VERBOSE ]; then
        >&2 echo Deleting temp file $TMPFILE
    fi
    rm -f "$TMPFILE"
fi

if [ ! -z $OUTFN ]; then
    >&2 echo Written to $OUTFN
fi
