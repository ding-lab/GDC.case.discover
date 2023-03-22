# Matthew Wyczalkowski
# m.wyczalkowski@wustl.edu
# Washington University School of Medicine
import argparse
import json
import requests
import sys

# https://stackoverflow.com/questions/5574702/how-do-i-print-to-stderr-in-python
# Usage: eprint("Test")
def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

# from https://docs.gdc.cancer.gov/API/Users_Guide/scripts/Complex_Query.py
def get_fields():
    fields = [
        "file_id",
        "file_name",
        "cases.submitter_id",
        "cases.case_id",
        "data_category",
        "data_type",
        "cases.samples.tumor_descriptor",
        "cases.samples.tissue_type",
        "cases.samples.sample_type",
        "cases.samples.submitter_id",
        "cases.samples.sample_id",
        "analysis.workflow_type",
        "cases.project.project_id",
        "cases.samples.portions.analytes.aliquots.aliquot_id",
        "cases.samples.portions.analytes.aliquots.submitter_id"
        ]
    return ",".join(fields)

# cases is a list of cases, e.g.,
#   cases_cptac3 = [ "C3L-00026", "11LU013", "C3N-00148", "PT-Q2AG" ]
def get_filters(cases):
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


# usage:
# python3 GDC_Catalog.py [case1 [case2 ...]]

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Query GDC to create catalog file")
    parser.add_argument("-d", "--debug", action="store_true", help="Print debugging information to stderr")
    parser.add_argument("-o", "--output", default="stdout", help="Output catalog file name")
    parser.add_argument("-i", "--input", help="Read cases from input file.  Format: one case per line")
    parser.add_argument("-t", "--token", help="Read token from file and pass as argument in query")
    parser.add_argument("-e", "--url", default="https://api.gdc.cancer.gov/", help="Define query endpoint url")
    parser.add_argument("-s", "--size", default="2000", help="Size limit to POST query")
    parser.add_argument("-f", "--response_format", default="TSV", help="Format of POST response")
    parser.add_argument("cases", nargs='*', help="List of one or more cases")

    args = parser.parse_args()
    if args.debug:
        eprint("args = " + str(args))


    post_kwarg = {}
    if args.token:
        post_kwarg["token_string"] = args.token

    files_endpt = args.url+"files"
    filters = get_filters(args.cases)
    fields = get_fields()

    if args.debug:
        eprint("files_endpt = " + files_endpt)
        eprint("filters = " + str(files_endpt))
        eprint("fields = " + str(fields))

    # A POST is used, so the filter parameters can be passed directly as a Dict object.
    params = {
        "filters": filters,
        "fields": fields,
        "format": args.response_format,
        "size": args.size 
        }


    response = get_POST_response(params, files_endpt, post_kwarg)

    if args.output == "stdout":
        print(response.content.decode("utf-8"))

    else:
        file = open(args.output, "w")
        file.write(response.text)
        file.close()
        eprint("Written to " + args.output)

