Development of methylation discovery

## Useful links
graphiQL https://portal.gdc.cancer.gov/submission/graphiql
GDC Data Model: https://gdc.cancer.gov/developers/gdc-data-model/gdc-data-model-components
Data dictionary viewer: https://docs.gdc.cancer.gov/Data_Dictionary/viewer/

## Plan
Plan: need to get Raw Methylation Array details based on aliquot
Details about raw_methylation_array:
    https://docs.gdc.cancer.gov/Data_Dictionary/viewer/#?view=table-definition-view&id=raw_methylation_array

Details we need, from denali:/home/mwyczalk_test/Projects/CPTAC3/import.Y2/methylation.20191022/make_AR.sh
  (above is a script for making methylation AR file from Mathangi manifest)

### Sample names
    # Sample name is a convenience string which looks like,
    # C3N-00858.MethArray.Red.N
    # C3N-00858.MethArray.Green.N
    # based on https://github.com/ding-lab/CPTAC3.case.discover/blob/master/merge_submitted_reads.sh
    # where suffix is N for Type (column 3) = "Normal DNA" and "Germline DNA", T for Type = "Tumor DNA"
    # and Red/Grn correspond to Red, Green channels, resp.

So the one additional piece of info we need is the channel, which has values Red or Green

## Implementation details

As a reminder, from process_case.sh, discovery proceeds like:
1.  get_sample.sh 
        Query: `sample(with_path_to: {type: "case", submitter_id:"$CASE"}, first:100)`
        Writes sample_from_case.$CASE.dat
TODO: this should query aliquots

2. get_read_groups.sh
        Query: `read_group(with_path_to: {type: "sample", submitter_id:"$SAMPLE"}, first:10000)`
        Writes read_group_from_case.$CASE.dat

3. get_submitted_reads.sh 
    Queries:
        submitted_aligned_reads(with_path_to: {type: "read_group", submitter_id:"$RG"})
        submitted_unaligned_reads(with_path_to: {type: "read_group", submitter_id:"$RG"})
    Writes SR_from_read_group.$CASE.dat.tmp and SR_from_read_group.$CASE.dat
        (the latter is a collapsed version of the former)

4. TODO: make a get_methylation_array.sh script which,
    a. gets all aliquots associated with all samples
    b. gets all methylation data associated with all aliquots

NOTE: it may be necessary to change the samples column in the AR file to have the aliquot name, which seems to be more standard than sample names

5. merge_submitted_reads.sh
    Loops over all cases in CPTAC3.cases.dat
        Loops over all unique IDs in SR_from_read_group


## Testing

Use this as a test dataset:
```
C3N-03182.MethArray.Green.T C3N-03182   GBM MethArray   tumor   CPT0206560009   203219650047_R04C01_Grn.idat    13676206    IDAT    91573271-bea7-463d-94be-a149503cdab0    97052dbe9d2de0e9885c6d329180cf4b
C3N-03182.MethArray.Red.T   C3N-03182   GBM MethArray   tumor   CPT0206560009   203219650047_R04C01_Red.idat    13676206    IDAT    caa8a7c4-c750-4a9e-a886-891e4ddf4abf    f47749faef72c5bf6505d066dedf708c
```

### igraphQL queries:

Get samples:
```
{ sample(with_path_to: {type: "case", submitter_id:"C3N-03182"}, first:100) { submitter_id id sample_type } }
{
  "data": {
    "sample": [
      {
        "id": "4126426c-203d-4cd4-ba17-0ef76440cf87",
        "sample_type": "Primary Tumor",
        "submitter_id": "C3N-03182-02"
      },
      {
        "id": "09013eee-b102-4b01-bb9f-d022cdf1048d",
        "sample_type": "Blood Derived Normal",
        "submitter_id": "C3N-03182-71"
      }
    ]
  }
}
```

get read groups
```
    {
        read_group(with_path_to: {type: "sample", submitter_id:"C3N-03182-02"}, first:10000)
        {
            submitter_id
            library_strategy
            experiment_name
            target_capture_kit_target_region
        }
    }


{
  "data": {
    "read_group": [
      {
        "experiment_name": "CPT0206560009.WholeGenome.RP-1303.bam",
        "library_strategy": "WGS",
        "submitter_id": "HNLGFCCXY181018.7.RP-1303.CPT0206560009.bam",
        "target_capture_kit_target_region": null
      },
...
```

get aliquot from case (this is new)
```
    {
        aliquot(with_path_to: {type: "case", submitter_id:"C3N-03182"}, first:10000)
        {
            submitter_id
            id
            analyte_type
        }
    }
{
  "data": {
    "aliquot": [
      {
        "analyte_type": "DNA",
        "id": "dc765b05-ce52-46f4-a45c-200e98c13c17",
        "submitter_id": "CPT0206560009"
      },
      {
        "analyte_type": "DNA",
        "id": "169a9157-ea3d-4d12-896d-093c39862823",
        "submitter_id": "CPT0206610002"
      },
      {
        "analyte_type": "RNA",
        "id": "dfe44706-7cfd-4717-b360-6264b2dd71e9",
        "submitter_id": "CPT0206560006"
      }
    ]
  }
}
```

get raw_methylation_array - this is new
```
    {
        raw_methylation_array(with_path_to: {type: "aliquot", submitter_id:"CPT0206560009"}, first:10000)
        {
            submitter_id
            id
            channel
            file_name
            file_size
        }
    }
{
  "data": {
    "raw_methylation_array": [
      {
        "channel": "Green",
        "file_name": "203219650047_R04C01_Grn.idat",
        "file_size": 13676206,
        "id": "91573271-bea7-463d-94be-a149503cdab0",
        "submitter_id": "CPT0206560009.203219650047_R04C01_Grn.idat"
      },
      {
        "channel": "Red",
        "file_name": "203219650047_R04C01_Red.idat",
        "file_size": 13676206,
        "id": "caa8a7c4-c750-4a9e-a886-891e4ddf4abf",
        "submitter_id": "CPT0206560009.203219650047_R04C01_Red.idat"
      }
    ]
  }
}
```

NEXT: use above information to query for methylation array info

We want to get sample and aliquot information in one go.  We can do this with a query like,
```
    { sample(with_path_to: {type: "case", submitter_id:"C3N-03182"}, first:100) { 
      submitter_id 
      id 
      sample_type 
        aliquots {submitter_id, id, analyte_type}
    } 
```

which returns
```
{
  "data": {
    "sample": [
      {
        "aliquots": [
          {
            "analyte_type": "DNA",
            "id": "dc765b05-ce52-46f4-a45c-200e98c13c17",
            "submitter_id": "CPT0206560009"
          },
          {
            "analyte_type": "RNA",
            "id": "dfe44706-7cfd-4717-b360-6264b2dd71e9",
            "submitter_id": "CPT0206560006"
          }
        ],
        "id": "4126426c-203d-4cd4-ba17-0ef76440cf87",
        "sample_type": "Primary Tumor",
        "submitter_id": "C3N-03182-02"
      },
      {
        "aliquots": [
          {
            "analyte_type": "DNA",
            "id": "169a9157-ea3d-4d12-896d-093c39862823",
            "submitter_id": "CPT0206610002"
          }
        ],
        "id": "09013eee-b102-4b01-bb9f-d022cdf1048d",
        "sample_type": "Blood Derived Normal",
        "submitter_id": "C3N-03182-71"
      }
    ]
  }
}
```
Question is, how to use jq to parse this out?  See ./json-test.
This works in part:
```
cat sample_aliquot.json | jq -r '.data.sample[] | "\(.submitter_id)\t\(.id)\t\(.sample_type)"'
C3N-03182-02    4126426c-203d-4cd4-ba17-0ef76440cf87    Primary Tumor
C3N-03182-71    09013eee-b102-4b01-bb9f-d022cdf1048d    Blood Derived Normal
```

This seems to work...
```
cat sample_aliquot.json | jq -r '.data.sample[] | "\(.submitter_id)\t\(.id)\t\(.sample_type)\t\(.aliquots[].submitter_id)"'
C3N-03182-02    4126426c-203d-4cd4-ba17-0ef76440cf87    Primary Tumor   CPT0206560009
C3N-03182-02    4126426c-203d-4cd4-ba17-0ef76440cf87    Primary Tumor   CPT0206560006
C3N-03182-71    09013eee-b102-4b01-bb9f-d022cdf1048d    Blood Derived Normal    CPT0206610002
```
However, getting additional fields from aliquots seems to yield extra lines / cross product of results

cat sample_aliquot.json | jq -r '.data.sample[] | "\(.submitter_id)\t\(.id)\t\(.sample_type)\t\(.aliquots[] | [.submitter_id, .analyte_type] )"'
C3N-03182-02    4126426c-203d-4cd4-ba17-0ef76440cf87    Primary Tumor   ["CPT0206560009","DNA"]
C3N-03182-02    4126426c-203d-4cd4-ba17-0ef76440cf87    Primary Tumor   ["CPT0206560006","RNA"]
C3N-03182-71    09013eee-b102-4b01-bb9f-d022cdf1048d    Blood Derived Normal    ["CPT0206610002","DNA"]

This is ugly but it works:
```
$ cat sample_aliquot.json | jq -r '.data.sample[] | "\(.submitter_id)\t\(.id)\t\(.sample_type)\t\(.aliquots[] | [.submitter_id, .id, .analyte_type]  )"' | tr -d '\"' | tr ',' '\t' | tr -d '[]'
C3N-03182-02    4126426c-203d-4cd4-ba17-0ef76440cf87    Primary Tumor   CPT0206560009   dc765b05-ce52-46f4-a45c-200e98c13c17    DNA
C3N-03182-02    4126426c-203d-4cd4-ba17-0ef76440cf87    Primary Tumor   CPT0206560006   dfe44706-7cfd-4717-b360-6264b2dd71e9    RNA
C3N-03182-71    09013eee-b102-4b01-bb9f-d022cdf1048d    Blood Derived Normal    CPT0206610002   169a9157-ea3d-4d12-896d-093c39862823    DNA
```


bash CPTAC3.case.discover/get_submitted_reads.sh -o aligned_reads.C3L-00001.dat read_groups.dat
