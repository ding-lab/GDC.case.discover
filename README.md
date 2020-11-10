# CPTAC3 Case Discover

Query GDC to discover sequence and methylation data and write it to a catalog file

## Quick start

* Obtain token from GDC, save to file `gdc-user-token.txt`
    * make this available as global variable with, `export GDC_TOKEN=gdc-user-token.txt`
* `git clone https://github.com/ding-lab/CPTAC3.case.discover PROJECT_NAME`
* edit `1_process_all.sh`
* run `bash 1_process_all.sh`

## Updates

### Version 2.2
Flags datasets associated with heterogeneity studies based on GDC aliquot annotation note.

#### Fields added

Adding the following columns to catalog file:
    * `sample_id` - GDC sample name  
    * `sample_metadata` - Ad hoc metadata associated with this sample.  May be comma-separated list
    * `aliquot_annotation` - Annotation note associated with aliquot, from GDC 

If aliquot_annotation is as follows:
    Duplicate item: CCRCC Tumor heterogeneity study aliquot
Then sample_metadata has appended to it "heterogeneity HET-XXX" 
  * XXX is a hash ID generated with [bashids](https://github.com/benwilber/bashids)
    Input string is the aliquot name with "CPT" and any leading 0's removed
  * sample_name has "HET-XXX" added as a suffix

### Version 2.1

* Adding support for scRNA-Seq

### Version 2.0 

Catalog file has the following differences:
* Added Targeted sequencing
* Added methylation
* Added full sample type column
* Added column 10, "result_type", and shifted remaining columns to right. result_type codes for two distinct things:
    * For Methylation Array data, it is the channel
    * For RNA-Seq harmonized BAMs, it is the result type, with values of genomic, chimeric, transcriptome
* AR file renamed Catalog file

### TODO

Incorporate additional information from DCC: https://clinicalapi-cptac.esacinc.com/api/tcia/

# User's Manual

## Installation

Other packages which need to be installed:
* `python` and `json` library; these typically come installed in a developer environment.
    * TODO provide explicit instructions
* `jq` : [see here for installation instructions](https://stedolan.github.io/jq/download/).

## Usage

### Project configuration

All CPTAC3.case.discover code code can be obtained with,
``` 
git clone https://github.com/ding-lab/CPTAC3.case.discover PROJECT_NAME
```

Edit `README.project.md` to provide project-specific descriptions.  This file is typically not committed to git.

The file `1_process_all.sh` defines several locale-specific environment variables and paths, and must be edited as appropriate.

Create file `dat/cases.dat` listing all cases to be processed.

### Obtaining GDC token

All queries require a GDC authorization token, [as described
here](https://docs.gdc.cancer.gov/Data_Submission_Portal/Users_Guide/Authentication/).

* Log in to [GDC Data Submission Portal](https://portal.gdc.cancer.gov/submission/CPTAC/3/dashboard)
* Download token, and save it to some filename, e.g. `gdc-user-token.txt`.
* Update `GDC_TOKEN` in `1_process_all.sh` accordingly

# File output format

## Catalog file

Catalog file columns:

1. `sample_name` - ad hoc name for this file, generated for convenience and consistency
2. `case`
3. `disease`
4. `experimental_strategy` - WGS, WXS, RNA-Seq, miRNA-Seq, Methylation Array, Targeted Sequencing
5. `short_sample_type` - short name for `sample_type`: `blood_normal`, `tissue_normal`, `tumor`, `buccal_normal`, `tumor_bone_marrow`, `tumor_peripheral_blood`:w
6. `aliquot` - name of aliquot used
7. `filename`
8. `filesize`
9. `data_format` - BAM, FASTQ, IDAT
10. `result_type` - ad hoc value specific to sample type
    * "chimeric", "genomic", "transcriptome" for RNA-Seq BAMs, 
    * "Red" or "Green" for Methylation Array
    * "NA" otherwise
11. `UUID`
12. `MD5`
13. `reference` - assumed reference used, hg19 for submitted aligned reads, NA for submitted unaligned reads, and hg38 for harmonized reads
14. `sample_type` - sample type as reported from GDC, e.g., Blood Derived Normal, Solid Tissue Normal, Primary Tumor, and others
15. `sample_id` - GDC sample name  
16. `sample_metadata` - Ad hoc metadata associated with this sample.  May be comma-separated list
     - see updates below
17. `aliquot_annotation` - Annotation note associated with aliquot, from GDC 

Example catalog file (TODO update me):
```
# sample_name	case	disease	experimental_strategy	short_sample_type	aliquot	filename	filesize	data_format	result_type	UUID	MD5	reference	sample_type
C3L-00001.MethArray.Green.A	C3L-00001	LUAD	Methylation Array	tissue_normal	CPT0001590008	203027390118_R03C01_Grn.idat	13676226	IDAT	Green	df1ce98e-8ee2-4c56-beb4-0129824b2033	0641f2a152b850b53b2c7cc5dcf34425	NA	Solid Tissue Normal
C3L-00001.MethArray.Green.T	C3L-00001	LUAD	Methylation Array	tumor	CPT0001580165	201557560005_R01C01_Grn.idat	13676234	IDAT	Green	c41ca2cf-b388-443c-9ca6-b51e9db97b45	739e69d1e358d4bdb485a2e1c8cbc531	NA	Primary Tumor
C3L-00001.MethArray.Red.A	C3L-00001	LUAD	Methylation Array	tissue_normal	CPT0001590008	203027390118_R03C01_Red.idat	13676226	IDAT	Red	b5971ca7-ad14-4c3a-9b33-eee83bd40ae3	9e53192a72676c77abb15cd0a508dfbc	NA	Solid Tissue Normal
C3L-00001.MethArray.Red.T	C3L-00001	LUAD	Methylation Array	tumor	CPT0001580165	201557560005_R01C01_Red.idat	13676234	IDAT	Red	68f5b973-91b0-4262-8c51-b89917e3a6cd	fe8b80f50ead938d36e2661c60cbb5a3	NA	Primary Tumor
C3L-00001.miRNA-Seq.A	C3L-00001	LUAD	miRNA-Seq	tissue_normal	CPT0001590005	181108_UNC31-K00269_0163_BH23TVBBXY_TCCCGA_S46_L002_R1_001.unaln.bam	238885562	BAM	NA	18d260e2-519b-4e6d-b640-7205239ee964	c206ca7bed33f36b085c6d6fbe4a123b	NA	Solid Tissue Normal
C3L-00001.miRNA-Seq.A.hg38	C3L-00001	LUAD	miRNA-Seq	tissue_normal	CPT0001590005	1f970bbc-0c72-4494-a07c-6614fee73147_mirnaseq_gdc_realn.bam	272125302	BAM	NA	9e0ff60b-1065-44b7-9a81-f76610b1b320	53251eac83c8e042719ecd49c2bfbe58	hg38	Solid Tissue Normal
C3L-00001.miRNA-Seq.T	C3L-00001	LUAD	miRNA-Seq	tumor	CPT0001580164	181113_UNC31-K00269_0164_AH23NNBBXY_CCGTCC_S40_L002_R1_001.unaln.bam	198156013	BAM	NA	7f8959ca-2250-4099-bed2-b85fb4b1fbd2	4eb52417fd4533fe85a5c07c2dcac03d	NA	Primary Tumor
C3L-00001.miRNA-Seq.T.hg38	C3L-00001	LUAD	miRNA-Seq	tumor	CPT0001580164	5c89811b-9851-41e7-a0c2-a0e5e3090a54_mirnaseq_gdc_realn.bam	216661805	BAM	NA	61ec239b-7461-44fb-bdb5-24bfe37dc7bd	cca923dc83d2bc6598802a48fa22ca63	hg38	Primary Tumor
C3L-00001.RNA-Seq.chimeric.A.hg38	C3L-00001	LUAD	RNA-Seq	tissue_normal	CPT0001590005	c3fe6a04-ca4f-4641-a625-6f60daa810b0.rna_seq.chimeric.gdc_realn.bam	63975780	BAM	chimeric	0a848979-90c8-4de1-8f40-1ab44791d2da	4814f52743576b75c6219fe406ac2fec	hg38	Solid Tissue Normal
C3L-00001.RNA-Seq.chimeric.T.hg38	C3L-00001	LUAD	RNA-Seq	tumor	CPT0001580164	e6cf5559-4395-45ed-91ed-fe90346940d9.rna_seq.chimeric.gdc_realn.bam	70191296	BAM	chimeric	1bb5d209-fd69-4658-9e02-5ec9bc6f8c09	2cc4510b5d0f6d75113578969a7b748d	hg38	Primary Tumor
C3L-00001.RNA-Seq.genomic.A.hg38	C3L-00001	LUAD	RNA-Seq	tissue_normal	CPT0001590005	c3fe6a04-ca4f-4641-a625-6f60daa810b0.rna_seq.genomic.gdc_realn.bam	6563282785	BAM	genomic	aba2207d-40e6-42e4-bf44-31a245c286f3	951f290179852e2a422b709d83f852e6	hg38	Solid Tissue Normal
C3L-00001.RNA-Seq.genomic.T.hg38	C3L-00001	LUAD	RNA-Seq	tumor	CPT0001580164	e6cf5559-4395-45ed-91ed-fe90346940d9.rna_seq.genomic.gdc_realn.bam	7864425914	BAM	genomic	edbe96b5-464a-4d4d-8089-0f38840f1424	daa10b1cafaa2694c89bed5c054b0fb5	hg38	Primary Tumor
C3L-00001.RNA-Seq.R1.A	C3L-00001	LUAD	RNA-Seq	tissue_normal	CPT0001590005	171215_UNC32-K00270_0072_AHN3THBBXX_GAGTGG_S12_L004_R1_001.fastq.gz	3170333423	FASTQ	NA	6f1bf159-5c80-41dc-87c4-593ace9987d6	a4fe58f08f8c0e386d20ef46ffc21158	NA	Solid Tissue Normal
C3L-00001.RNA-Seq.R1.T	C3L-00001	LUAD	RNA-Seq	tumor	CPT0001580164	170802_UNC31-K00269_0072_AHK3GVBBXX_ACTTGA_S4_L006_R1_001.fastq.gz	3467940463	FASTQ	NA	8db05676-b96a-466a-bdbc-71db64e64c08	e603da80da9520f6f8f301fc50a344a3	NA	Primary Tumor
C3L-00001.RNA-Seq.R2.A	C3L-00001	LUAD	RNA-Seq	tissue_normal	CPT0001590005	171215_UNC32-K00270_0072_AHN3THBBXX_GAGTGG_S12_L004_R2_001.fastq.gz	3377969387	FASTQ	NA	a1647619-4448-4ea8-aa7e-6968fd2f61ad	33b752dd8aee17f45a4d3d22681e88ba	NA	Solid Tissue Normal
C3L-00001.RNA-Seq.R2.T	C3L-00001	LUAD	RNA-Seq	tumor	CPT0001580164	170802_UNC31-K00269_0072_AHK3GVBBXX_ACTTGA_S4_L006_R2_001.fastq.gz	3786676689	FASTQ	NA	593e3888-d805-403e-813d-c10c9a34d539	015da0c7e5c477ca695055587c288e62	NA	Primary Tumor
C3L-00001.RNA-Seq.transcriptome.A.hg38	C3L-00001	LUAD	RNA-Seq	tissue_normal	CPT0001590005	c3fe6a04-ca4f-4641-a625-6f60daa810b0.rna_seq.transcriptome.gdc_realn.bam	7079740592	BAM	transcriptome	fef1a1e6-4ecb-4e0c-bff9-ce74f945a22b	e3c9cb189ead929097911a0d687c563e	hg38	Solid Tissue Normal
C3L-00001.RNA-Seq.transcriptome.T.hg38	C3L-00001	LUAD	RNA-Seq	tumor	CPT0001580164	e6cf5559-4395-45ed-91ed-fe90346940d9.rna_seq.transcriptome.gdc_realn.bam	7236032826	BAM	transcriptome	40a169c8-ebe6-4443-b9fb-5655214ffaf3	cb0b2167424fc71af10a8916b993eb1d	hg38	Primary Tumor
C3L-00001.WGS.A	C3L-00001	LUAD	WGS	tissue_normal	CPT0001590008	CPT0001590008.WholeGenome.RP-1303.bam	59764413161	BAM	NA	34d01163-72b1-4008-8bd7-33380906edff	a66d553a599cd431ec3b6108fd4d8464	hg19	Solid Tissue Normal
C3L-00001.WGS.A.hg38	C3L-00001	LUAD	WGS	tissue_normal	CPT0001590008	51f174e6-1be7-4819-9339-b95193c935bd_wgs_gdc_realn.bam	86803129008	BAM	NA	7f516c95-70be-4add-9af9-19d6428edd44	5ae2b5f7db2e0ce311cdd5020c3d2d66	hg38	Solid Tissue Normal
C3L-00001.WGS.N	C3L-00001	LUAD	WGS	blood_normal	CPT0000150163	CPT0000150163.WholeGenome.RP-1303.bam	138602354329	BAM	NA	caa607a4-b0c5-4b5d-ba51-1e648a8e264a	42997e95d6df30d25c082c29e826cf6f	hg19	Blood Derived Normal
C3L-00001.WGS.N.hg38	C3L-00001	LUAD	WGS	blood_normal	CPT0000150163	2595f8ca-ef17-4bf0-984d-27caaa8ee608_gdc_realn.bam	202924825766	BAM	NA	1d301dc5-ebb2-47e0-9a9f-e31ed41b4542	ad13fed3116916005024c89f12992913	hg38	Blood Derived Normal
C3L-00001.WGS.T	C3L-00001	LUAD	WGS	tumor	CPT0001580165	CPT0001580165.WholeGenome.RP-1303.bam	138347401746	BAM	NA	800c4053-2b67-4e66-bb97-474458635c21	20de25c08f2eb037f22fa2ad7379f58f	hg19	Primary Tumor
C3L-00001.WGS.T.hg38	C3L-00001	LUAD	WGS	tumor	CPT0001580165	1cc7a20f-b05e-4661-95ec-399b3080a02b_gdc_realn.bam	200258660209	BAM	NA	b919a0f4-c85d-4fe0-9947-2b8cb9b9a2b4	8bfbc3d69159ab8efe370237b5610e85	hg38	Primary Tumor
C3L-00001.WXS.A	C3L-00001	LUAD	WXS	tissue_normal	CPT0001590008	CPT0001590008.WholeExome.RP-1303.bam	40403928360	BAM	NA	6b61189d-0f3a-4b51-b988-1f063d107114	07a06c00b92ac282699591656789cf4f	hg19	Solid Tissue Normal
C3L-00001.WXS.A.hg38	C3L-00001	LUAD	WXS	tissue_normal	CPT0001590008	51f174e6-1be7-4819-9339-b95193c935bd_wxs_gdc_realn.bam	55218252573	BAM	NA	a4163684-cf9c-466f-ac3f-5a591ce9e9b9	d2634c52fb298bc6f92644c6f5008391	hg38	Solid Tissue Normal
C3L-00001.WXS.N	C3L-00001	LUAD	WXS	blood_normal	CPT0000150163	CPT0000150163.WholeExome.RP-1303.bam	27988092058	BAM	NA	f6a3f2f8-657d-48b3-9762-1ec60c50bd93	02b1b0ebbdc2e30306646ac254dc313c	hg19	Blood Derived Normal
C3L-00001.WXS.N.hg38	C3L-00001	LUAD	WXS	blood_normal	CPT0000150163	2595f8ca-ef17-4bf0-984d-27caaa8ee608_gdc_realn.bam	39542030390	BAM	NA	df589c6d-37e7-4878-9453-ded1a3ca5e17	9fc32e83356b9db8f1ec0cbf202d7891	hg38	Blood Derived Normal
C3L-00001.WXS.T	C3L-00001	LUAD	WXS	tumor	CPT0001580165	CPT0001580165.WholeExome.RP-1303.bam	31774252273	BAM	NA	9048a65c-2312-4cae-bea6-d31a1c53bd39	b763a7bfde97cd1bb53673a2cd48452e	hg19	Primary Tumor
C3L-00001.WXS.T.hg38	C3L-00001	LUAD	WXS	tumor	CPT0001580165	1cc7a20f-b05e-4661-95ec-399b3080a02b_gdc_realn.bam	43659332939	BAM	NA	a0e38199-402a-4ae1-b00d-ec9c67dd51df	537a4ba9f2f23ebb270e63d696ca6819	hg38	Primary Tumor
```

### Sample names

Sample names are ad hoc names we generate for convenience.  Examples include,
* C3N-00858.WXS.N
* C3N-00858.WXS.N.hg38
* C3N-00858.WGS.T
* C3N-00858.RNA-Seq.R1.T
* C3N-00858.RNA-Seq.R2.T
* C3N-00858.MethArray.Red.N
* C3N-00858.MethArray.Green.N
* C3N-00858.RNA-Seq.chimeric.T.hg38
* C3N-00858.RNA-Seq.transcriptome.T.hg38
* C3N-00858.RNA-Seq.genomic.T.hg38

See Heterogeneity Studies below.

TODO: add examples about heterogeneity

### Sample types

The `sample_type` column lists GDC sample types.  We abbreviate these names in the sample name and `short_sample_type` column respectively as,
* Blood Derived Normal: N, blood_normal
* Buccal Cell Normal: Nbc, buccal_normal
* Primary Tumor, Tumor: T, tumor
* Primary Blood Derived Cancer - Bone Marrow: Tbm, tumor_bone_marrow
* Primary Blood Derived Cancer - Peripheral Blood: Tpb, tumor_peripheral_blood
* Solid Tissue Normal: A, tissue_normal


## Heterogeneity Studies

If aliquot_annotation is as follows:
```
    Duplicate item: CCRCC Tumor heterogeneity study aliquot
```
Then sample_metadata has appended to it "heterogeneity het-XXX" 
  * XXX is a hash ID generated with [bashids](https://github.com/benwilber/bashids)
    Input string is the aliquot name with "CPT" and any leading 0's removed
  * sample_name has "het-XXX" added as a suffix


## Demographics

The following clinical information is recorded in the file `dat/PROJECT.Demographics.dat` for each case:

    * case
    * disease
    * ethnicity
    * gender
    * race
    * days to birth

## Catalog Summary Files

Catalog summary files provide a one-line representation of data available for a given case on GDC.  Following case and disease, each column represents 
a particular data type, and one-letter codes T, N, A indicate availability of tumor, blood normal, and tissue adjacent normal samples, respectively.
Repeated codes indicate repeated data files.

### Example
```
C3L-00001   LUAD        WGS.hg19 T N A      WXS.hg19 T N A      RNA.fq TT  AA       miRNA.fq T  A       WGS.hg38 T N A      WXS.hg38 T N A      RNA.hg38 TTT  AAA       miRNA.hg38 T  A     MethArray TT  AA
```
This line indicates that LUAD case C3L-00001 has tumor, blood normal, and adjacent normal samples for WGS and WXS data as submitted (hg19);
tumor and adjacent normal RNA-Seq data (TT, AA because FASTQ data comes in pairs); and tumor and adjacent miRNA data in FASTQ format.  All
these are available as harmonized hg38 WGS and WXS, and harmonized hg38 RNA-Seq chimeric, genomic, and transcriptome BAMs are available
for tumor and adjacent normal.  Methylation array data for tumor and tissue adjacent also available (Green and Red channel for each).

## Exon target capture info

The intermediate files `cases/*/read_groups.dat` capture the `target_capture_kit_target_region` field of each read group, which is used for exome analysis.  Currently the
only value observed (apart from null and "Not Applicable") is,
```
http://support.illumina.com/content/dam/illumina-support/documents/documentation/chemistry_documentation/samplepreps_nextera/nexterarapidcapture/nexterarapidcapture_exome_targetedregions_v1.2.bed
```

# Processing details

## Workflow

Processing workflow and hierarchy proceeds as,
* `1_process_all.sh`
    * All project-specific definitions take place here
    * Calls `src/process_multi_cases.sh`, which 
        * Iterates over cases file
        * Calls `src/process_case.sh` for each case
        * `src/process_case.sh`  Calls the following:
            * `src/get_aliquots.sh`
            * `src/get_read_groups.sh`
            * `src/get_harmonized_reads.sh`
            * `src/get_methylation_array.sh`
            * `src/make_catalog.sh`
            * `src/get_demographics.sh`
        * Collects catalog files to write project catalog file
        * Collects demographics files to write project demographics file

[queryGDC documentation](README.queryGDC.md) includes additional information about GDC queries
and other useful links.

# Support 

Please contact Matt Wyczalkowski <m.wyczalkowski@wustl.edu> for with questions and bug reports.
