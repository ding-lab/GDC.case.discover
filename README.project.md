Working through details here:
https://docs.gdc.cancer.gov/API/Users_Guide/Search_and_Retrieval/

Goal is to move to a REST API and away from a GraphQL-based API

This works roughly like running from command line
$ bash docker/WUDocker/start_docker.sh -I mwyczalkowski/python3_gdc:20230315 -c "/usr/local/bin/python3 /diskmnt/Projects/cptac_scratch/CPTAC3.workflow/discover/dev/20230314.REST-test/test1.py" -l .

# same
$ bash python3_gdc demo/test1.py


# Proof of concept

Querying ALCHEMIST works provided:
* files_endpt = "https://api.awg.gdc.cancer.gov/files"
* Using AWG token (not regular GDC token)

It is not clear if we are able to use the AWG token to download files from regular GDC 

# for testing
cases_cptac3 = [ "C3L-00026", "11LU013", "C3N-00148", "PT-Q2AG" ]
cases_alchemist = [ "ALCH-ABBG", "ALCH-ABBH", "ALCH-ABBK", "ALCH-ABBL"]
cases_ctsp_kirc = [ "CTSP-B3LA", "CTSP-B3LD", "CTSP-B3LE", "CTSP-B3LF"]
