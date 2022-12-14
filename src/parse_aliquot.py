# Matthew Wyczalkowski
# m.wyczalkowski@wustl.edu
# Washington University School of Medicine

import json
import argparse, sys, os

# https://stackoverflow.com/questions/5574702/how-to-print-to-stderr-in-python
def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


# Inputs
# -i YAML - in specific format, document
# -o output TSV table
# -m data_model - must be "TCGA" or "CPTAC"

# Note that GDC has a different internal model for CPTAC data vs. TCGA.
# This diffrence is explored in initial TCGA work here:
#     /diskmnt/Projects/cptac_scratch/CPTAC3.workflow/discover/dev/20220105.GDAC_test/README.project.md
# Background: https://gdc.cancer.gov/developers/gdc-data-model
#
# * CPTAC data model:  case - sample - aliquots
# * TCGA data model: case - sample - portions - analytes - aliquots
#
# This difference is reflected in the GraphQL query "aliquot_from_case" in the get_aliquot step, and
# in the subsequent parsing.  For TCGA the parsing has been implemented in the python parser 
# `parse_aliquot_TCGA.py`.  Work here will be to implement parsing of CPTAC-model data in the python
# parser and to make the get_aliquot.sh step be able to handle both modes.  

# It is possible there may be other data models.  For now, will pass "data_model" as a string, with
# only "CPTAC" and "TCGA" recognized.

# In either data model, the format of the file aliquots.dat generaged by get_aliquots.sh will be the same


# For TCGA, the graphQL query we expect looks something like,
#{ sample(with_path_to: {type: "case", submitter_id: "TCGA-44-6146"}, first: 10000) {
#    submitter_id
#    id
#    sample_type
#    preservation_method
#    portions {
#      analytes {
#        submitter_id
#        id
#        analyte_type
#        aliquots {
#          submitter_id
#          id
#          annotations {
#            notes
#     } } } } } }
# with a response that looks in part like,
# {"data":{"sample":[{"id":"5a249602-cb25-4a4e-b671-8937d5f929e2","portions":[{"analytes":[{"aliquots":[{"annotations":[],"id":"d90aaa94-2fcd-4bba-a829-6fbb4a27cfd9","submitter_id":"CTSP-AD2M-NB1-A-1-0-D-A889-36"},{"annotations":[],"id":"1f636e0a-ca29-4731-a808-da2162733e7f","submitter_id":"CTSP-AD2M-NB1-A-1-0-D-A793-36"}],"analyte_type":"DNA","id":"1f892880-82c0-4f8d-bc41-951b210bf5b2","submitter_id":"CTSP-AD2M-NB1-A-1-0-D"}]}],"preservation_method":"Frozen","sample_type":"Blood Derived Normal","submitter_id":"CTSP-AD2M-NB1-A"},{"id":"4f9b4902-a42b-461a-a66d-739375e524fa","portions":[{"analytes":[{"aliquots":[{"annotations":[],"id":"45e33941-1c74-48f6-a52e-6e0923d1b49e","submitter_id":"CTSP-AD2M-TTP1-A-1-1-R-A790-41"}],"analyte_type":"RNA","id":"13934207-23d6-4236-9328-2258643740f4","submitter_id":"CTSP-AD2M-TTP1-A-1-1-R"},{"aliquots":[{"annotations":[],"id":"c5135916-ccbc-4b77-9929-f2d6303cbe73","submitter_id":"CTSP-AD2M-TTP1-A-1-1-D-A83H-48"},{"annotations":[],"id":"a51bbe3e-9458-4097-9f06-d6832d1e39fe","submitter_id":"CTSP-AD2M-TTP1-A-1-1-D-A793-36"},{"annotations":[],"id":"4c3df9ac-d8c1-411c-858b-0d55905963db","submitter_id":"CTSP-AD2M-TTP1-A-1-1-D-A889-36"}],"analyte_type":"DNA","id":"1dc2c727-07f8-472f-9194-a12bf3850446","submitter_id":"CTSP-AD2M-TTP1-A-1-1-D"}]}],"preservation_method":"Frozen","sample_type":"Primary Tumor","submitter_id":"CTSP-AD2M-TTP1-A"},{"id":"35058835-82bb-4e52-a697-24432c2622b0","portions":[{"analytes":[{"aliquots":[{"annotations":[],"id":"d4367cd0-9124-4334-a997-c74a3f2ede28","submitter_id":"CTSP-AD2M-TTP1-G-1-0-D-A793-36"},{"annotations":[],"id":"68688612-8907-4708-b53c-8eedce8b603f","submitter_id":"CTSP-AD2M-TTP1-G-1-0-D-A889-36"},{"annotations":[],"id":"f0ae529c-7407-4cbc-8f13-fa2e5c6a71f8","submitter_id":"CTSP-AD2M-TTP1-G-1-0-D-A83I-48"}],"analyte_type":"DNA","id":"5438ffc4-4ba7-458b-9b42-96f315194abc","submitter_id":"CTSP-AD2M-TTP1-G-1-0-D"},{"aliquots":[{"annotations":[],"id":"22f2364d-fcf7-4a71-91b1-4b93f3c011df","submitter_id":"CTSP-AD2M-TTP1-G-1-0-R-A78Y-41"}],"analyte_type":"RNA","id":"9dcd8be0-cc3e-400e-a8f3-2f04b14f69ec","submitter_id":"CTSP-AD2M-TTP1-G-1-0-R"}]}],"preservation_method":"FFPE","sample_type":"Primary Tumor","submitter_id":"CTSP-AD2M-TTP1-G"}]}}

#
# For CPTAC, it is
#    { sample(with_path_to: {type: "case", submitter_id:"$CASE"}, first:10000) {
#          submitter_id
#          id
#          sample_type
#          preservation_method
#          aliquots {
#            submitter_id
#            id
#            analyte_type
#            annotations {
#                notes
#     } } } } 
#
#RESULT: {"data":{"sample":[{"aliquots":[],"id":"5a249602-cb25-4a4e-b671-8937d5f929e2","preservation_method":"Frozen","sample_type":"Blood Derived Normal","submitter_id":"CTSP-AD2M-NB1-A"},{"aliquots":[],"id":"4f9b4902-a42b-461a-a66d-739375e524fa","preservation_method":"Frozen","sample_type":"Primary Tumor","submitter_id":"CTSP-AD2M-TTP1-A"},{"aliquots":[],"id":"35058835-82bb-4e52-a697-24432c2622b0","preservation_method":"FFPE","sample_type":"Primary Tumor","submitter_id":"CTSP-AD2M-TTP1-G"}]}}

# Parsing these independently
            
def parse_YAML(infn, outfn, case, data_model):
    if infn: 
        with open(infn) as f:
            data = json.load(f)
    else:
        data = json.load( sys.stdin )

    outf = open(outfn, 'w') if outfn else sys.stdout

    header=('sample_submitter_id', 'sample_id', 'sample_type', 'preservation_method', 'aliquot_submitter_id', 'aliquot_id', 'analyte_type', 'aliquot_annotation')
    if case is not None:
        header = ('case',) + header
    print('%s' % '\t'.join(header), file=outf)

    if data_model == "TCGA":
        samples = data['data']['sample']
        for s in samples:
            sample_type = s['sample_type']
            sample_submitter_id = s['submitter_id']
            sample_id = s['id']
            sample_preservation_method = s['preservation_method']
            for p in s['portions']:
                for a in p['analytes']:
                    analyte_type = a['analyte_type']
                    for l in a['aliquots']:
                        aliquot_id=l['id']
                        aliquot_submitter_id=l['submitter_id']
                        annotations=set()
                        for n in l['annotations']:
                            annotations.add(n['notes'])
                        aliquot_annotation=';'.join(annotations)

                        output_data=(sample_submitter_id, sample_id, sample_type, sample_preservation_method, aliquot_submitter_id, aliquot_id, analyte_type, aliquot_annotation)
                        if case is not None:
                            output_data = (case,) + output_data
                        print('\t'.join(output_data), file=outf)
    elif data_model == "CPTAC":
#{
#  "data": {
#    "sample": [
#      {
#        "aliquots": [
#          {
#            "analyte_type": "DNA",
#            "annotations": [],
#            "id": "1cc7a20f-b05e-4661-95ec-399b3080a02b",
#            "submitter_id": "CPT0001580165"
#          }, ...
#        "id": "3a96e351-7850-459c-896c-6444e34745b9",
#        "sample_type": "Solid Tissue Normal",
#        "submitter_id": "C3L-00001-06"
#   ...}
        samples = data['data']['sample']
        for s in samples:
            sample_type = s['sample_type']
            sample_submitter_id = s['submitter_id']
            sample_id = s['id']
            sample_preservation_method = s['preservation_method']
            for l in s['aliquots']:
                analyte_type = format(l['analyte_type'])    # sometimes analyte_type is `null`
                aliquot_id=l['id']
                aliquot_submitter_id=l['submitter_id']
                annotations=set()
                for n in l['annotations']:
                    annotations.add(n['notes'])
                aliquot_annotation=';'.join(annotations)

                output_data=(sample_submitter_id, sample_id, sample_type, sample_preservation_method, aliquot_submitter_id, aliquot_id, analyte_type, aliquot_annotation)
                if case is not None:
                    output_data = (case,) + output_data
                print('\t'.join(output_data), file=outf)
    else:
        assert False    # should never get here because argparse has limited permitted values


    if outf is not sys.stdout:
        outf.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Parse aliquot information from YAML response")
    parser.add_argument("-d", "--debug", action="store_true", help="Print debugging information to stderr")
    parser.add_argument("-i", "--input", dest="infn", help="Input file name.  Default reads from stdin")
    parser.add_argument("-o", "--output", dest="outfn", help="Output file name.  default writes to stdout")
    parser.add_argument("-c", "--case", dest="case", help="Case name to prepend to table, for convenience")
    parser.add_argument("-m", "--data_model", dest="data_model", default="CPTAC", choices={"CPTAC", "TCGA"}, help="GDC data model associating case and aliquots")

    args = parser.parse_args()

    parse_YAML(args.infn, args.outfn, args.case, args.data_model)
