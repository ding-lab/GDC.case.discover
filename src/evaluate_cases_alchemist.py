import requests
import json

# from https://docs.gdc.cancer.gov/API/Users_Guide/scripts/Complex_Query.py

# token needed for AWG
token_file="/diskmnt/Projects/cptac_scratch/CPTAC3.workflow/discover/dev/20230314.REST-test/src/gdc-user-token.2023-03-21T20_12_36.970Z-AWG.txt"
with open(token_file,"r") as token:
    token_string = str(token.read().strip())

# The 'fields' parameter is passed as a comma-separated string of single names.
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

fields = ",".join(fields)

# AWG difference
#files_endpt = "https://api.gdc.cancer.gov/files"
files_endpt = "https://api.awg.gdc.cancer.gov/files"

#filters = {
#    "op":"in",
#    "content":{
#        "field":"cases.submitter_id",
#        "value":[
#            "C3L-00026",
#            "11LU013",
#            "C3N-00148",
#            "PT-Q2AG"
#        ]
#    }
#}

cases_cptac3 = [ "C3L-00026", "11LU013", "C3N-00148", "PT-Q2AG" ]
cases_alchemist = [ "ALCH-ABBG", "ALCH-ABBH", "ALCH-ABBK", "ALCH-ABBL"]
cases_ctsp_kirc = [ "CTSP-B3LA", "CTSP-B3LD", "CTSP-B3LE", "CTSP-B3LF"]



filters = {
	"op":"and",
	"content":[
	{
		"op":"in",
		"content":{
			"field":"cases.submitter_id",
			"value": cases_alchemist
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

# A POST is used, so the filter parameters can be passed directly as a Dict object.
params = {
    "filters": filters,
    "fields": fields,
    "format": "TSV",
    "size": "2000"
    }

# The parameters are passed to 'json' rather than 'params' in this case
headers = {"Content-Type": "application/json", "X-Auth-Token": token_string}
response = requests.post(files_endpt, headers = headers, json = params)

## OUTPUT METHOD 1: Write to a file.
#file = open("complex_filters.tsv", "w")
#file.write(response.text)
#file.close()

# OUTPUT METHOD 2: View on screen.
print(response.content.decode("utf-8"))
