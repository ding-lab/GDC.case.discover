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
# -m data_model - must be "TCGA" or "CPTAC3"

# Goal is to create Catalog3 for CPTAC3.  Note that GDC has a different internal model for CPTAC3 data vs. TCGA.
# This diffrence is explored in initial TCGA work here:
#     /diskmnt/Projects/cptac_scratch/CPTAC3.workflow/discover/dev/20220105.GDAC_test/README.project.md
#
# * CPTAC3 data model:  data / sample / aliquots
# * TCGA data model: data / sample / portions / analytes / aliquots
#
# This difference is reflected in the GraphQL query "aliquot_from_case" in the get_aliquot step, and
# in the subsequent parsing.  For TCGA the parsing has been implemented in the python parser 
# `parse_aliquot_TCGA.py`.  Work here will be to implement parsing of CPTAC3-model data in the python
# parser and to make the get_aliquot.sh step be able to handle both modes.  

# It is possible there may be other data models.  For now, will pass "data_model" as a string, with
# only "CPTAC3" and "TCGA" recognized.

# In either data model, the format of the file aliquots.dat generaged by get_aliquots.sh will be the same


# For TCGA, the graphQL query we expect looks something like,
#{ sample(with_path_to: {type: "case", submitter_id: "TCGA-44-6146"}, first: 10000) {
#    submitter_id
#    id
#    sample_type
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
#{
#  "id": "2640d6dc-15c7-405f-a348-6751393dee6d",
#  "portions": [
#    {
#      "analytes": [
#        {
#          "aliquots": [
#            {
#              "annotations": [],
#              "id": "4b84798f-675b-4232-909b-5c859c87053d",
#              "submitter_id": "TCGA-44-6146-10A-01W-1804-08"
#            }
#          ],
#          "analyte_type": "Repli-G (Qiagen) DNA",
#          "id": "970debc0-faae-42f1-a86d-bcd8c45eecb2",
#          "submitter_id": "TCGA-44-6146-10A-01W"
#        }, ...

#
# For CPTAC3, it is
#    { sample(with_path_to: {type: "case", submitter_id:"$CASE"}, first:10000) {
#          submitter_id
#          id
#          sample_type
#          aliquots {
#            submitter_id
#            id
#            analyte_type
#            annotations {
#                notes
#     } } } } 
#
# QUERY: { sample(with_path_to: {type: "case", submitter_id:"C3L-00001"}, first:10000) { submitter_id id sample_type aliquots { submitter_id id analyte_type annotations { notes } } } }
# RESULT: {"data":{"sample":[{"aliquots":[{"analyte_type":"DNA","annotations":[],"id":"1cc7a20f-b05e-4661-95ec-399b3080a02b","submitter_id":"CPT0001580165"},{"analyte_type":"RNA","annotations":[],"id":"5c89811b-9851-41e7-a0c2-a0e5e3090a54","submitter_id":"CPT0001580164"}],"id":"7089c3bb-b7dc-4fb9-8e3e-d81d16877afd","sample_type":"Primary Tumor","submitter_id":"C3L-00001-02"},{"aliquots":[{"analyte_type":"DNA","annotations":[],"id":"2595f8ca-ef17-4bf0-984d-27caaa8ee608","submitter_id":"CPT0000150163"}],"id":"139ede8b-483b-4e94-a794-593aa18dda50","sample_type":"Blood Derived Normal","submitter_id":"C3L-00001-32"},{"aliquots":[{"analyte_type":"RNA","annotations":[],"id":"1f970bbc-0c72-4494-a07c-6614fee73147","submitter_id":"CPT0001590005"},{"analyte_type":"DNA","annotations":[],"id":"51f174e6-1be7-4819-9339-b95193c935bd","submitter_id":"CPT0001590008"}],"id":"3a96e351-7850-459c-896c-6444e34745b9","sample_type":"Solid Tissue Normal","submitter_id":"C3L-00001-06"}]}}
# Parsing these independently
            
def parse_YAML(infn, outfn, case, data_model):
    if infn: 
        with open(infn) as f:
            data = json.load(f)
    else:
        data = json.load( sys.stdin )

    outf = open(outfn, 'w') if outfn else sys.stdout

    header=('sample_submitter_id', 'sample_id', 'sample_type', 'aliquot_submitter_id', 'aliquot_id', 'analyte_type', 'aliquot_annotation')
    if case is not None:
        header = ('case',) + header
    print('%s' % '\t'.join(header), file=outf)

    if data_model == "TCGA":
        samples = data['data']['sample']
        for s in samples:
            sample_type = s['sample_type']
            sample_submitter_id = s['submitter_id']
            sample_id = s['id']
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

                        output_data=(sample_submitter_id, sample_id, sample_type, aliquot_submitter_id, aliquot_id, analyte_type, aliquot_annotation)
                        if case is not None:
                            output_data = (case,) + output_data
                        print('\t'.join(output_data), file=outf)
    elif data_model == "CPTAC3":
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
            for l in s['aliquots']:
                analyte_type = format(l['analyte_type'])    # sometimes analyte_type is `null`
                aliquot_id=l['id']
                aliquot_submitter_id=l['submitter_id']
                annotations=set()
                for n in l['annotations']:
                    annotations.add(n['notes'])
                aliquot_annotation=';'.join(annotations)

                output_data=(sample_submitter_id, sample_id, sample_type, aliquot_submitter_id, aliquot_id, analyte_type, aliquot_annotation)
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
    parser.add_argument("-m", "--data_model", dest="data_model", default="CPTAC3", choices={"CPTAC3", "TCGA"}, help="GDC data model associating case and aliquots")

    args = parser.parse_args()

    parse_YAML(args.infn, args.outfn, args.case, args.data_model)
