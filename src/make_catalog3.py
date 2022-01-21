# Matthew Wyczalkowski
# m.wyczalkowski@wustl.edu
# Washington University School of Medicine

import pandas as pd
import argparse, sys, os, binascii

def read_aliquots(alq_fn):
    alq_header=('case', 'sample_submitter_id', 'sample_id', 'sample_type', 'aliquot_submitter_id', 'aliquot_id', 'analyte_type', 'aliquot_annotation')
    # force aliquot_annotation to be type str - doesn't seem to work?
    type_arg = {'aliquot_annotation': 'str'}
    aliquots = pd.read_csv(aq_fn, sep="\t", names=alq_header, dtype=type_arg)
    return(aliquots)

def read_reads_file(reads_fn):
    header_list=["case", "aliquot_submitter_id", "assumed_reference", "experimental_strategy", "data_format", "file_name", "file_size", "uuid", "md5sum"]
    rf = pd.read_csv(sr_fn, sep="\t", names=header_list)
    return(rf)

# get one column, data_variety, for each row of rf
def get_data_variety(rf):
    # Data Variety
    # NA by default
    # For RNA-Seq BAMs, evaluate filename for specific strings: "genomic", "transcriptome", and "chimeric"
    # These strings are then the data_variety value
    dv = pd.Series("NA", index=rf.index)

    RNA_BAM_ix = ((rf['data_format']=='BAM') & (rf['experimental_strategy']=="RNA-Seq"))
    genomic_ix = (RNA_BAM_ix & rf['file_name'].str.contains("genomic"))
    transcriptome_ix = (RNA_BAM_ix & rf['file_name'].str.contains("transcriptome"))
    chimeric_ix = (RNA_BAM_ix & rf['file_name'].str.contains("chimeric"))
    dv[genomic_ix]="genomic"
    dv[transcriptome_ix]="transcriptome"
    dv[chimeric_ix]="chimeric"

    # do something similar for all FASTQs, marking data_variety as R1 or R2 based on pattern match to filename.
    # Value of Rx if not matched (this happens with non-CPTAC3 data)
    RNA_FQ_ix = (rf['data_format']=='FASTQ')
    dv[RNA_FQ_ix]="Rx"    # default is unmatched
    dv[(RNA_FQ_ix & rf['file_name'].str.contains("_R1_"))]="R1"
    dv[(RNA_FQ_ix & rf['file_name'].str.contains("_R2_"))]="R2"

    return dv

# An Aliquot Tag is a string associated with an aliquot which may be appended to dataset names
# It consists of two parts: an annotation code and an aliquot hash, separated by '_'
# An annotation code is meant to be a three-letter identifier of an aliquot annotation, for
#    instance indicating that the aliquot is marked as "duplicate" (annotaton code "DUP")
#    If an annotation does not exist, default annotation code is NAN
#    If an annotation exists but code is not known, default annotation code is ALQ
#    Otherwise, annotation code is performed by the dictionary passed, annotations (not impelmented)
# Aliquot has is a CRC checksum string based on aliquot_submitter_id, used to create a unique name
#    compact representation of aliquot name.  Details about CRC checksums:
#    See https://stackoverflow.com/questions/44804668/how-to-calculate-crc32-checksum-from-a-string-on-linux-bash

def get_aliquot_tag(aliquots):
    def get_hash(text):
        return format(binascii.crc32(text.encode("utf8")), "x")
    alq_hash=aliquots[["aliquot_submitter_id"]].squeeze().map(get_hash)

    alq_tag = pd.Series("NAN", index=aliquots.index)
    alq_tag.loc[aliquots[["aliquot_annotation"]].notna().squeeze()]="ALQ"

    # Depending on specific values of aliquot_annotation, in consultation with
    # annotations dictionary (not implemented), different annotation codes can be used
    return(alq_tag + "_" + alq_hash)

# merge all sample_submitter_id's which are used for the same aliquot_submitter_id
# group aliquots by aliquot_submitter_id, creating a comma-separated list of sample_submitter_id values (named specimen_ids)
def get_specimen_ids(aliquots):
    # Below, collapse aliquot by aliquot_submitter_id, and turn specimen_ids into comma-separated list
    # Example value of alq_sid:
    # aliquot_submitter_id    specimen_ids
    # 0   CPT0000160003   C3L-00016-01,C3L-00016-04
    # 1   CPT0000160009   C3L-00016-01,C3L-00016-04
    # 2   CPT0000560002   C3L-00016-31
    # https://stackoverflow.com/questions/27298178/concatenate-strings-from-several-rows-using-pandas-groupby

    si = pd.Series(aliquots["aliquot_submitter_id"])
    alq_sid = aliquots.groupby(['aliquot_submitter_id'], as_index = False).agg({'sample_submitter_id': lambda x: ','.join(set(x))})
    alq_sid = alq_sid.rename(columns={'sample_submitter_id': 'specimen_ids'})

    # rf.merge(alq_sid, on='aliquot_submitter_id').head()
    return(alq_sid)

def get_short_sample_code(aliquots):
    short_sample_map = [
        ["Blood Derived Normal", "N"],
        ["Solid Tissue Normal", "A"],
        ["Primary Tumor", "T"],
        ["Tumor", "T"],
        ["Buccal Cell Normal" , "Nbc"],
        ["Primary Blood Derived Cancer - Bone Marrow" , "Tbm"],
        ["Primary Blood Derived Cancer - Peripheral Blood" , "Tpb"],
        ["Recurrent Tumor" , "R"]
    ]
    sst = pd.DataFrame(short_sample_map, columns = ['sample_type', 'short_sample_code'])
    return aliquots.merge(sst, on="sample_type")['short_sample_code']


def generate_catalog(read_data, aliquots):

    # process read_data
    # Add "data_variety" column to read_data
    dv = get_data_variety(rf)
    read_data.assign(data_variety=dv.values)

    # remap experimental strategies "Targeted Sequencing" to "Targeted", and "Methylation Array" to "MethArray"
    # will want to save original name in metadata - TODO
    read_data.loc[(read_data["experimental_strategy"]=="Targeted Sequencing"), "experimental_strategy"]="Targeted"
    read_data.loc[(read_data["experimental_strategy"]=="Methylation Array"), "experimental_strategy"]="MethArray"


    # Now update aliquots
    # Add "aliquot_tag" column to aliquots
    aliquot_tag = get_aliquot_tag(aliquots) 
    aliquots = aliquots.assign(aliquot_tag=aliquot_tag.values)

    # this now has column specimen_ids as a comma-separated lists of all aliquot_submitter_id values
    sids = get_specimen_ids(aliquots)
    aliquots = aliquots.merge(sids, on="aliquot_submitter_id")

    ssc=get_short_sample_code(aliquots)
    aliquots.assign(short_sample_code=ssc)

    # Finally merge aliquot info with reads
    read_data_aliquots = read_data.merge(aliquots, on='aliquot_submitter_id')

    # Sample name is composed of:
    # case . experimental_strategy [. data_variety] . short_sample_code . reference
    dataset_name = read_data_aliquots['case'] +.+ read_data_aliquots['experimental_strategy'] +.+ read_data_aliquots['data_variety'] +.+ read_data_aliquots['short_sample_code'] 

    read_data_aliquots.assign(dataset_name=dataset_name)
    return(read_data_aliquots)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Processes reads files to create a catalog3 view of each entry")
    parser.add_argument("reads_fn", help="Harmonized or Submitted Reads file")
    parser.add_argument("-o", "--output", dest="outfn", help="Output file name")
    parser.add_argument("-Q", "--aliquots", dest="aliquots_fn", required=True, help="Aliquots file")
    parser.add_argument("-D", "--disease", dest="disease", default="DISEASE", help="Disease code")
    parser.add_argument("-P", "--project", dest="project", default="PROJECT", help="Project name")
    parser.add_argument("-A", "--annotation", dest="annotation_fn", help="Annotation table")
    parser.add_argument("-d", "--debug", action="store_true", help="Print debugging information to stderr")
    parser.add_argument("-n", "--no-header", action="store_true", help="Do not print header")

    args = parser.parse_args()

#    aliquots = pd.read_csv(args.aliquots_fn, sep="\t")


    aliquots=read_aliquots(args.aliquots_fn)

    read_data = get_read_data(args.reads_fn)
    catalog_data = generate_catalog(read_data, aliquots)

    write_catalog(catalog_data)


