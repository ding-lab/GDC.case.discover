# Background

Documentation is outdated

Simple command line tool to perform graphGL queries for NCI Genomics Data
Commons.  Given a "bare GraphQL" query ([as described
here](https://docs.gdc.cancer.gov/API/Users_Guide/Submission/#querying-submitted-data-using-graphql)),
this script constructs and passes a JSON query, and writes out the response.

# Basic Usage

1. [Obtain GDC authentication token](https://docs.gdc.cancer.gov/Data_Submission_Portal/Users_Guide/Authentication/).  Save this to `token.txt`.
2. Construct GraphQL query, such as,

```
{
  case (project_id: "TCGA-ALCH", first: 0) {
    id
    submitter_id

  }
  _case_count (project_id: "TCGA-ALCH")
}
```
Save this to `query.json`.

3. Perform query with,

```
   queryGDC -t token.txt query.json
```

## `queryGDC` usage
```
Execute given GraphQL file as a query to GDC
Usage: queryGDC [options] query.json

-t token.txt: define token on command line.  Mandatory
-v: print diagnostic information to stderr
-r: repeat query in case of errors until succeeds.  Meant to deal with timeout errors.
-d: dry run.  Print query but do not execute

token.txt contains GDC authentication token (see https://docs.gdc.cancer.gov/Data_Submission_Portal/Users_Guide/Authentication/ )
query.json contains "bare queryGL" script (see https://docs.gdc.cancer.gov/API/Users_Guide/Submission/#querying-submitted-data-using-graphql )
      queryGDC token.txt -
  will read query from STDIN
```

# Case Discover

`case.discover` directory contains several scripts for discovering and summarizing all SR (`submitted_aligned_reads` and `submitted_unaligned_reads`)
associated with a given case.  These scripts are,

1. `get_sample.sh`: Get information about all samples for a given case
2. `get_read_groups.sh`: Get information about all read groups for a given case (using sample information)
3. `get_submitted_reads.sh`: Get information about SR for a given case (using `read_group` information)
4. `merge_submitted_reads.sh`: Summarize SR information, writing the following for every unique submitted read file, ` case, disease, experimental_strategy, sample_type, samples, filename, filesize, datatype, UUID, md5sum `

These scripts were developed for CPTAC3 Genomic project but should be of
general use.  Note that these scripts are relatively slow, particularly step 3,
which performs a query for every `read_group` in a given case, much of which is
duplicate.

## Example Usage

1. `bash get_sample.sh C3L-00004 token.txt`
    Writes sample information to `dat/C3L-00004/sample_from_case.C3L-00004.dat`
2. `bash get_read_groups.sh C3L-00004 token.txt`
    Writes read_group information to `dat/C3L-00004/read_group_from_case.C3L-00004.dat`
3. `get_submitted_reads.sh C3L-00004 token.txt`
    Writes details about submitted_aligned_reads and submitted_unaligned_reads to `dat/C3L-00004/SR_from_read_group.C3L-00004.dat`
4. `merge_submitted_reads.sh C3L-00004 CCRC`
    Writes a summary table for all unique submitted reads.  Disease field (e.g., `CCRC`) is for convenience only

# Installation

* `queryGDC` requires `python` and the `json` library; these typically come installed in a developer environment.
* `case.discover` scripts rely on `jq` for parsing; [see here for installation instructions](https://stedolan.github.io/jq/download/).

# Useful links:

* [Definition of GraphQL language](http://facebook.github.io/graphql/October2016/#sec-Overview)
* [Tutorial about GraphQL queries](http://graphql.org/learn/queries/)
* [graphQL documentation at GDC](https://docs.gdc.cancer.gov/API/Users_Guide/Submission/#querying-submitted-data-using-graphql)
* [GDC Data Model](https://gdc.cancer.gov/developers/gdc-data-model/gdc-data-model-components)
* [GraphiQL](https://portal.gdc.cancer.gov/submission/graphiql) A graphical interface for the GDC GraphQL
