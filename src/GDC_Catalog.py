# Matthew Wyczalkowski
# m.wyczalkowski@wustl.edu
# Washington University School of Medicine
import argparse
import json
import requests
import sys
import os
import io
import pandas as pd
import csv


# https://stackoverflow.com/questions/5574702/how-do-i-print-to-stderr-in-python
# Usage: eprint("Test")
def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

# * CPTAC data model:  case - sample - aliquots
# * TCGA data model: case - sample - portions - analytes - aliquots

# from https://docs.gdc.cancer.gov/API/Users_Guide/scripts/Complex_Query.py
def get_fields():
    fields = [
        "file_name",
        "experimental_strategy",
        "file_size",
        "md5sum",
        "data_format",
        "cases.samples.portions.analytes.aliquots.submitter_id",
        "cases.submitter_id",
        "cases.samples.sample_type",
        "cases.samples.preservation_method"
        ]
    return ",".join(fields)

# Other possible fields
# "cases.samples.aliquots.submitter_id" - Not clear if this is necessary

# cases is a list of cases, e.g.,
#   cases_cptac3 = [ "C3L-00026", "11LU013", "C3N-00148", "PT-Q2AG" ]
def get_filters_aligned_reads(cases):
    filters = {
        "op":"and",
        "content":[
        {
            "op":"in",
            "content":{
                "field":"cases.submitter_id",
                "value": cases
            }
        },
        {
            "op":"=",
            "content":{
                "field":"files.data_type",
                "value":"Aligned Reads"
            }
        }
        ]
    }
    return filters

def get_filters(cases):
    filters = {
        "op":"in",
        "content":{
            "field":"cases.submitter_id",
            "value": cases
        }
    }
    return filters

def get_POST_response(params, endpt, token_string = None):
    headers = {"Content-Type": "application/json"}
    if token_string:
        headers["X-Auth-Token"] = token_string
    response = requests.post(endpt, headers = headers, json = params)
    return response

def get_token(token_file):
    with open(token_file,"r") as token:
        token_string = str(token.read().strip())
    return token_string
# token needed for AWG
#token_file="/diskmnt/Projects/cptac_scratch/CPTAC3.workflow/discover/dev/20230314.REST-test/src/gdc-user-token.2023-03-21T20_12_36.970Z-AWG.txt"
#with open(token_file,"r") as token:
#    token_string = str(token.read().strip())


# Uses: rf columns: data_format, experimental_strategy, file_name
# Writes: rf columns: data_variety
def get_data_variety_RNA_BAM(rf):
    # For RNA-Seq BAMs, evaluate filename for specific strings: "genomic", "transcriptome", and "chimeric"
    # These strings are then the data_variety value

    RNA_BAM_ix = ((rf['data_format']=='BAM') & (rf['experimental_strategy']=="RNA-Seq"))
    genomic_ix = (RNA_BAM_ix & rf['file_name'].str.contains("genomic"))
    transcriptome_ix = (RNA_BAM_ix & rf['file_name'].str.contains("transcriptome"))
    chimeric_ix = (RNA_BAM_ix & rf['file_name'].str.contains("chimeric"))
    rf.loc[genomic_ix, "data_variety"]="genomic"
    rf.loc[transcriptome_ix, "data_variety"]="transcriptome"
    rf.loc[chimeric_ix, "data_variety"]="chimeric"
    return rf

# Parse filename for read indicator like _R1_
def get_read(fn):
     #match = re.search(r'_(R\d)_', fn)
     match = re.search(r'_(R\d)', fn)   # want to also match DLBCL11282_4198_RNAseq_R1.fastq.gz
     return match.group(1) if match else None

# Parse filename for lane indicator like _L001_
def get_lane(fn):
     match = re.search(r'_(L\d\d\d)_', fn)
     return match.group(1) if match else None

# Parse filename for sample number indicator like _S12_
def get_sample_number(fn):
     match = re.search(r'_(S\d+)_', fn)
     return match.group(1) if match else None

# Parse filename for index indicator like _I2_
def get_index(fn):
     match = re.search(r'_(I\d)_', fn)
     return match.group(1) if match else None

# append stringB to stringA with _ in between
# deals nicely if either of these are None
def nice_append(stringA, stringB):
    if stringA is None: return stringB
    if stringB is None: return stringA
    return stringA + "_" + stringB

def get_dv_string(rf_row):
    dv = nice_append(None, rf_row['sample'])
    dv = nice_append(dv, rf_row['lane'])
    dv = nice_append(dv, rf_row['read'])
    dv = nice_append(dv, rf_row['index'])
    return dv

# Creates a convenient name like S19_L005_R1 which incorporates illumina sample, lane, read, and index values
# https://support.illumina.com/help/BaseSpace_OLH_009008/Content/Source/Informatics/BS/NamingConvention_FASTQ-files-swBS.htm
# writes to rf['data_variety'] directly
# We also observe and support extracting R1, R2 from filenames like DLBCL11282_4198_RNAseq_R1.fastq.gz

# Uses rf columns: data_format, alignment
# writes columns: read, lane, sample, index, data_variety
def get_data_variety_FASTQ(rf):
    FQ_ix = rf['data_format']=='FASTQ'

    # The following will also process unaligned BAMs.  Not clear if these exist in REST API
#    BM_ix = rf['data_format']=='BAM' 
#    UA_ix = rf['alignment']=='submitted_unaligned'
#    target_ix = FQ_ix | (BM_ix & UA_ix)

    target_ix = FQ_ix

    if not target_ix.empty:
        rf.loc[target_ix, 'read'] = rf.loc[target_ix].apply(lambda row: get_read(row['file_name']), axis=1)
        rf.loc[target_ix, 'lane'] = rf.loc[target_ix].apply(lambda row: get_lane(row['file_name']), axis=1)
        rf.loc[target_ix, 'sample'] = rf.loc[target_ix].apply(lambda row: get_sample_number(row['file_name']), axis=1)
        rf.loc[target_ix, 'index'] = rf.loc[target_ix].apply(lambda row: get_index(row['file_name']), axis=1)
        rf.loc[target_ix, 'data_variety'] = rf.loc[target_ix].apply(lambda row: get_dv_string(row), axis=1)
    return rf

# This is possible source of fatal errors when there is a new sample_type
# it would be good to move these definitions out of script and into a configuration file 
# Returns response with column 'sample_code' added
# TODO: sample_code should be F if preservation_method is FFPE
def get_sample_code(response):
    sample_map = [
# N: Blood Derived Normal
        ["Blood Derived Normal", "N"],
# A:   Solid Tissue Normal
        ["Solid Tissue Normal", "A"],
# T:   Primary Tumor or Tumor
        ["Primary Tumor", "T"],
        ["Tumor", "T"],
        ['Additional - New Primary', "T"],
# Nbc:   Buccal Cell Normal
        ["Buccal Cell Normal" , "Nbc"],
# Tbm: Primary Blood Derived Cancer - Bone Marrow
        ["Primary Blood Derived Cancer - Bone Marrow" , "Tbm"],
# Tpb: Primary Blood Derived Cancer - Peripheral Blood
        ["Primary Blood Derived Cancer - Peripheral Blood" , "Tpb"],
# R:   Recurrent Tumor
        ["Recurrent Tumor" , "R"],
# S: Slides - this is new and weird but adding this along with code to detect such situations in the future
        ["Slides" , "S"],
# F: "FFPE scrolls" and "FFPE Recurrent" 
        ["FFPE Scrolls", "F"],
        ["FFPE Recurrent", "F"],
# M: Metastatic
        ["Metastatic", "M"],
        ["Additional Metastatic", "M"],
# Tc: 'Human Tumor Original Cells'
        ["Human Tumor Original Cells", "Tc"],
# V: 'Saliva'
        ["Saliva", "V"],
# these from HCMI
        ["Neoplasms of Uncertain and Unknown Behavior", "X"],
        ["Next Generation Cancer Model", "L"],
        ["Post neo-adjuvant therapy", "P"]
    ]

    sst = pd.DataFrame(sample_map, columns = ['sample_type', 'sample_code'])
    merged = response.merge(sst, on="sample_type", how="left")
    if merged['sample_code'].isnull().values.any():
        m=merged['sample_code'].isnull()
        msg="Unknown sample type: {}".format(merged.loc[m, "sample_type"].unique())
        raise ValueError(msg)
    return merged

def get_dataset_name(response):
    # Dataset name is composed of:
    # case . experimental_strategy_ds [. data_variety ] . sample_code 

#    # whit experimental strategies shortened: "Targeted_Sequencing" to "Targeted", and "Methylation_Array" to "MethArray"
#    # for the purpose of creating dataset name
#    response["experimental_strategy_ds"] = response["experimental_strategy"]
#    response.loc[(response["experimental_strategy_ds"]=="Targeted_Sequencing"), "experimental_strategy_ds"]="Targeted"
#    response.loc[(response["experimental_strategy_ds"]=="Methylation_Array"), "experimental_strategy_ds"]="MethArray"

#    # https://stackoverflow.com/questions/48083074/conditional-concatenation-based-on-string-value-in-column
#    # Conditionally add aliquot tag where aliquot annotation exists
#    response['labeled_case'] = response['case'] 
#    m = response['aliquot_annotation'].notna()
#    response.loc[m, 'labeled_case'] += ('.' + response.loc[m, 'aliquot_tag'])

    # include data variety field (e.g., R1) only if non-trivial
    response['data_variety_tag'] = ''
    m = response['data_variety'].notna() 
    response.loc[m, 'data_variety_tag'] = '.' + response.loc[m,'data_variety'] 
    response.loc[response['data_variety_tag'] == '.', "data_variety_tag"] = ""

#    response['alignment_tag'] = ""
#    response.loc[response['alignment'] == 'harmonized', "alignment_tag"] = ".hg38"

    dataset_name = response['case'] +'.'+ response['experimental_strategy'] + response['data_variety_tag'] +'.'+ response['sample_code'] 
    response = response.assign(dataset_name=dataset_name)
    
    return response

# This is based on work in old_src/make_catalog3.py.  That code has additional details like aliquot tags and such
def generate_catalog(response):
    # process read_data
    # Add "data_variety" column to read_data
    response['data_variety'] = ""
    response = get_data_variety_RNA_BAM(response)
    response = get_data_variety_FASTQ(response)

    response = get_sample_code(response)

    response = get_dataset_name(response)

#    # Rename column names a little
#    response = response.rename(columns={'md5sum': 'md5', 'file_name': 'filename', 'file_size': 'filesize', \
#        'sample_type': 'gdc_sample_type', 'sample_type_short': 'sample_type'})

#    # Generate metadata as JSON string
#    catalog_data['metadata'] = catalog_data.apply(lambda row: get_metadata_json(row), axis=1)

    return(response)

# returns data frame consisting of GDC REST API response
def get_query_response(url, cases=None, cases_fn=None, token=None):
    post_kwarg = {}
    if args.token:
        post_kwarg["token_string"] = args.token

    files_endpt = args.url+"files"

    if args.cases_fn:
        with open(args.cases_fn) as file:
            cases = [line.rstrip() for line in file]
    else:
        cases = args.cases

    filters = get_filters_aligned_reads(cases)
    fields = get_fields()

    if args.debug:
        eprint("files_endpt = " + files_endpt)
        eprint("filters = " + str(filters))
        eprint("fields = " + str(fields))

    # A POST is used, so the filter parameters can be passed directly as a Dict object.
    params = {
        "filters": filters,
        "fields": fields,
        "format": "TSV",
        "size": args.size 
        }

    response = get_POST_response(params, files_endpt, post_kwarg)
    if response.text.isspace():
        eprint("Response is empty.  Qutting")
        sys.exit()

    df = pd.read_csv(io.StringIO(response.content.decode("utf-8")), sep="\t")
    return df


# usage:
# python3 GDC_Catalog.py [case1 [case2 ...]]
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Query GDC to create catalog file")
    parser.add_argument("-d", "--debug", action="store_true", help="Print debugging information to stderr")
    parser.add_argument("-o", "--output", default="stdout", help="Output catalog file name")
    parser.add_argument("-i", "--cases_fn", help="Read cases from input file.  Format: one case per line")
    parser.add_argument("-t", "--token", help="Read token from file and pass as argument in query")
    parser.add_argument("-e", "--url", default="https://api.gdc.cancer.gov/", help="Define query endpoint url")
    parser.add_argument("-s", "--size", default="2000", help="Size limit to POST query")
    parser.add_argument("-C", "--columns", choices=["full", "import"], default="full", help="Column definitions")
    parser.add_argument("cases", nargs='*', help="List of one or more cases.  Ignored if -i defined")

    args = parser.parse_args()
    if args.debug:
        eprint("args = " + str(args))


    response = get_query_response(args.url, args.cases, args.cases_fn, args.token)
    rename_dict={'cases.0.samples.0.portions.0.analytes.0.aliquots.0.submitter_id': 'aliquot', 
                 'cases.0.samples.0.preservation_method': 'preservation_method',
                 'cases.0.samples.0.sample_type': 'sample_type',
                 'cases.0.submitter_id':'case'}
    response = response.rename(columns=rename_dict)

    # Add columns: data_variety, sample_code, dataset_name
    catalog = generate_catalog(response)

    if args.columns == "full":
        col_defs = ["dataset_name", "case", "sample_type", "data_format", "experimental_strategy", "preservation_method", "aliquot", "file_name", "file_size", "id", "md5sum"]
        sort_col = "case"
    elif args.columns == "import":
        col_defs = ["dataset_name", "id", "file_name", "data_format", "file_size"]
        sort_col = "id"
    else: 
        assert False    # Should not get here, unknown arguments caught by choices

    catalog = catalog[col_defs]
    catalog = catalog.sort_values(sort_col)

    if args.output == "stdout":
        print(catalog)   # not sure how useful this is
    else:
        catalog.to_csv(args.output, sep="\t", quoting=csv.QUOTE_NONE, index=False)
        eprint("Written to "+args.output)



