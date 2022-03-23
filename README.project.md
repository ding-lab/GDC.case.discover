Creating DLBCL catalog with updated list of 202 DLBCL cases.

Updated cases list generated here:
    /home/mwyczalk_test/Projects/Catalog3/GDAN.catalog/DLBCL


/home/mwyczalk_test/Projects/Catalog3/GDAN.catalog/DLBCL/DLBCL1.BamMap.storage1.tsv

With,
    $ cut -f 2 DLBCL1.BamMap.storage1.tsv | grep -v submitter_id | sort -u > /home/mwyczalk_test/Projects/Catalog3/discovery/08.DLBCL_202/dat/cases_DLBCL-202.dat

List of 202 cases.  This is an update over the 165 cases used in 04-dev.DLBCL and 06-dev.DLBCL

# Run A

Run A was mistakenly run with CPTAC3 data model.  206 datasets were discovered.  It would be useful to compare these to those
discovered with the subsequent TCGA data model run

CATALOG="dat.runA.CPTAC3-data-model/DLBCL.Catalog3.tsv"

# Run B



