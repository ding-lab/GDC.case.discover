# Matthew Wyczalkowski
# m.wyczalkowski@wustl.edu
# Washington University School of Medicine

import pandas as pd
import argparse, sys, os

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

# "reads" corresponds to each line in the reads file
def process_reads(reads_fn, aliquots, annotation):
    header_list=["case", "aliquot_submitter_id", "assumed_reference", "experimental_strategy", "data_format", "file_name", "file_size", "uuid", "md5sum"]
    df = pd.read_csv(reads_fn, sep="\t", names=header_list)

    # Data variety
    if 



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

    aliquots = pd.read_csv(args.aliquots_fn, sep="\t")
#    annotation = pd.read_csv(args.annotation_fn, sep="\t")
    annotation = False # not implemented yet
    print(aliquots)

    catalog_data = process_reads(args.reads_fn, aliquots, annotation)
    write_catalog3(catalog_data)


    print(df)

#    parse_YAML(args.infn, args.outfn, args.case)
