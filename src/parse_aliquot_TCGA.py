# Matthew Wyczalkowski
# m.wyczalkowski@wustl.edu
# Washington University School of Medicine

import json
import argparse, sys, os

# Inputs
# -i YAML - in specific format, document
# -o output TSV table

# The graphQL query we expect looks something like,
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
#          } } } } } }

def parse_YAML(infn, outfn, case):

    if infn: 
        with open(infn) as f:
            data = json.load(f)
    else:
        data = json.load( sys.stdin )

    outf = open(outfn, 'w') if outfn else sys.stdout

    header=('sample_submitter_id', 'sample_id', 'sample_type', 'aliquot_submitter_id', 'aliquot_id', 'analyte_type', 'aliquot_annotation')
    if case is not None:
        header = ('case',) + header
    print('# %s' % '\t'.join(header), file=outf)
    
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

    if outf is not sys.stdout:
        outf.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Parse aliquot information from YAML response")
    parser.add_argument("-d", "--debug", action="store_true", help="Print debugging information to stderr")
    parser.add_argument("-i", "--input", dest="infn", help="Input file name.  Default reads from stdin")
    parser.add_argument("-o", "--output", dest="outfn", help="Output file name.  default writes to stdout")
    parser.add_argument("-c", "--case", dest="case", help="Case name to prepend to table, for convenience")

    args = parser.parse_args()

    parse_YAML(args.infn, args.outfn, args.case)
