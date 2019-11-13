# Background

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

### Transient errors

On occasion, we see the following error:
```
result="<html><head><title>Hold up there!</title></head><body><center><h1>Hold up there!</h1><p>You are posting too quickly. Wait for few moments and try again.</p></body></html>"
```

A test for this response was implemented in queryGDC, and results in waiting 5 seconds before trying again

# Useful links:

* [Definition of GraphQL language](http://facebook.github.io/graphql/October2016/#sec-Overview)
* [Tutorial about GraphQL queries](http://graphql.org/learn/queries/)
* [graphQL documentation at GDC](https://docs.gdc.cancer.gov/API/Users_Guide/Submission/#querying-submitted-data-using-graphql)
* [GDC Data Model](https://gdc.cancer.gov/developers/gdc-data-model/gdc-data-model-components)
* [GraphiQL](https://portal.gdc.cancer.gov/submission/graphiql) A graphical interface for the GDC GraphQL
