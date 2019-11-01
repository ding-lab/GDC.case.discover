# Project overview

*TODO* Provide description of workflow.  Add discussion of harmonized aligned reads.

See README.project.md for per-project information.  Details here are intended to be general.

The [discover.CPTAC3.b1](https://github.com/ding-lab/discover.CPTAC3.b1) project obtains information about 
BAM and FASTQ files associated with a given set of cases from the GDC. It is specific to a specific batch of CPTAC3 cases, but
is designed to easily extend to other GDC case sets.

`discover.CPTAC3.b1` consists of simple wrapper scripts which delegate the bulk of processing to additional libraries:

* [CPTAC3.case.discover](https://github.com/ding-lab/CPTAC3.case.discover) contains the core logic to obtain
GDC data associated with given cases
* [query.GDC](https://github.com/ding-lab/queryGDC) is a command line client for Genomic Data Commons graphGL queries

These above libraries provide additional documentation and technical background.


# Installation

All code to obtain data for CPTAC3 Batch 1 cases, including the additional libraries, can be obtained with,
``` 
git clone --recursive https://github.com/ding-lab/discover.CPTAC3.b1.git 
```

## Dependencies

All these scripts run in a Linux or OS X environment.  `queryGDC` requires
`python` and the `json` library. Both typically come installed in a developer
environment.

`CPTAC3.case.discover` scripts rely on `jq` for parsing; [see here for installation instructions](https://stedolan.github.io/jq/download/).

## Token

All queries require a GDC authorization token, [as described
here](https://docs.gdc.cancer.gov/Data_Submission_Portal/Users_Guide/Authentication/).

* Log in to [GDC Data Submission Portal](https://portal.gdc.cancer.gov/submission/CPTAC/3/dashboard)
* Download token, and save it to some filename, e.g. `gdc-user-token.txt`.
* Update `GDC_TOKEN` in `discover.paths.sh` accordingly

# Configuration

Since `discover.CPTAC3.b1` is specific to a particular set of cases in a particular local environment, the code needs to be
modified as appropriate.  It is useful to create a branch of the workflow and rename this directory appropriately:
```
cd ..
mv discover.CPTAC3.b1 my_new_project
cd my_new_project
git checkout -b my_new_project 
```

## Configure `discover.paths.sh`

The file `discover.paths.sh` defines several locale-specific environment variables and paths, and must be edited as appropriate.

1. Define `PROJECT` as `my_new_project`
2. Define `GDC_TOKEN` as the full path to the downloaded `gdc-user-token.txt`

## Define cases of interest

Script here obtain information about all Submitted Aligned Reads (BAM files) and Submitted Unaligned Reads (FASTQ files)
associated with a set of cases (e.g., UCEC case `C3L-00006`).  These cases, and the diseases associated with them, are defined
in the file `1_make_case_list.sh`, which must be edited as appropriate.

*TODO*: Right now, scripts assume that only UCEC and CCRC cases are being investigated.  In the future this can be generalized; for now, 
steps 1-7 must be edited to point to the correct disease files; such edits should be self-explanatory.  Only files in `discover.CPTAC3.b1`
(not in `CPTAC3.case.discover` or `query.GDC`) need to be edited.

# Run Scripts

All scripts are run in numerical order.  [CPTAC3.case.discover](https://github.com/ding-lab/CPTAC3.case.discover) has more detailed 
description of the nature of these scripts.

## Harmonized dat

Describe harmonized data. Requires separate set of processing.

Ading RNA?

Note that we are no longer assuming Submitted Aligned Reads are hg19; rather, we will refer to them as reference = "asub" (as submitted)

Final file containing SR data and HAR data is named AR (Aligned Reads)

### Future work

* processing should take place all the way through for one case

## SR file

The principal output is written to the file `dat/my_new_project.SR.dat` (e.g., `dat/CPTAC3.b2.SR.dat`).  This file provides a comprehensive summary of submitted reads (aligned and unaligned)
with the columns,
```
   sample_name, case, disease, experimental_strategy, sample_type, samples, filename, filesize, data_format, UUID, md5sum
```
where

* `sample_name` is a unique name generated for convenience
* `experimental_strategy` is one of WGS, WXS, RNA-Seq
* `sample_type` is one of "Primary Tumor", "Blood Derived Normal"
* `samples` is `;`-separated list of all sample names associated with this SR
* `data_format` is either BAM for FASTQ

Example output for one case, `C3L-00004`:

```
# sample_name   case    disease experimental_strategy   sample_type samples filename    filesize    data_format UUID    MD5
C3L-00004.RNA-Seq.R1.T  C3L-00004   CCRC    RNA-Seq Primary Tumor   C3L-00004-01    170802_UNC31-K00269_0072_AHK3GVBBXX_GATCAG_S14_L004_R1_001.fastq.gz 3583768830  FASTQ   287dfdf2-9db1-4216-bffb-1b0a91d91a18    938ee1cce13b5fb162d745e2728b4a76
C3L-00004.WGS.N C3L-00004   CCRC    WGS Blood Derived Normal    C3L-00004-31    CPT0000140163.WholeGenome.RP-1303.bam   137026519152    BAM 59f284e7-cffa-4891-a76c-60dd8e46a01d    c4f2f69bffed177e9412ba8559a37ecf
C3L-00004.RNA-Seq.R1.N  C3L-00004   CCRC    RNA-Seq Solid Tissue Normal C3L-00004-06    171208_UNC32-K00270_0071_BHN7K5BBXX_GAGTGG_S57_L008_R1_001.fastq.gz 3956827023  FASTQ   804bc1fd-f191-4415-985f-7572e367ccbb    b645b63047f98ea399ccc89e945ffdb4
C3L-00004.RNA-Seq.R2.T  C3L-00004   CCRC    RNA-Seq Primary Tumor   C3L-00004-01    170802_UNC31-K00269_0072_AHK3GVBBXX_GATCAG_S14_L004_R2_001.fastq.gz 4011873670  FASTQ   b9e72d51-f52d-43b0-99fa-25c184f27a92    82f5aca80e5debf65d53c3ff985cfa2b
C3L-00004.WXS.T C3L-00004   CCRC    WXS Primary Tumor   C3L-00004-01    CPT0001540165.WholeExome.RP-1303.bam    39445446486 BAM baaf9523-3d3c-4c8a-979c-af8b86a1bc6d    98014f0fd20d3fffe8d13d46a275c4e9
C3L-00004.WGS.T C3L-00004   CCRC    WGS Primary Tumor   C3L-00004-01    CPT0001540165.WholeGenome.RP-1303.bam   146090178289    BAM c336c120-966a-4ec0-9fc7-6d5c856bbc22    12e1fcaf3dd836872c2f665d08b37423
C3L-00004.WXS.N C3L-00004   CCRC    WXS Blood Derived Normal    C3L-00004-31    CPT0000140163.WholeExome.RP-1303.bam    29198662220 BAM e933d585-96d2-4ab6-89b1-2b542d07fa9e    4501fc3aeaa7c9b7533dcf9d8c9970ec
C3L-00004.RNA-Seq.R2.N  C3L-00004   CCRC    RNA-Seq Solid Tissue Normal C3L-00004-06    171208_UNC32-K00270_0071_BHN7K5BBXX_GAGTGG_S57_L008_R2_001.fastq.gz 4122366105  FASTQ   eb0369b6-5af2-4066-a2b3-41f4d4a93719    4c3078869f5081425ce645dc23dcaeea
```

## Nomenclature:

Blood Derived Normal = N  (this is the principal normal used in batches 1,2)
Primary Tumor        = T    
Solid Tissue Normal  = A  (A for Adjacent Normal)
Primary Blood Derived Cancer - Bone Marrow = M

* Update me * this is out of date


## Demographics

The following clinical information is recoreded in the file `dat/CPTAC3.b2.Demographics.dat` for each case:

* `ethnicity`
* `gender`
* `race`
* `days_to_birth`

## Exon target capture info

The intermediate files `read_group_from_case` capture the `target_capture_kit_target_region` field of each read group, which is used for exome analysis.  Currently the
only value observed (apart from null and N/A) is 
```
http://support.illumina.com/content/dam/illumina-support/documents/documentation/chemistry_documentation/samplepreps_nextera/nexterarapidcapture/nexterarapidcapture_exome_targetedregions_v1.2.bed
```
This can be evaluated with,
```
cat dat/*/read_group_from_case.*.dat  | cut -f 5 | sort -u
```


# Support 

Please contact Matt Wyczalkowski <m.wyczalkowski@wustl.edu> for with questions and bug reports.
