# GDC Case Discover

GDC Case Discovery is an update to the CPTAC3-specific implementation, CPTAC3 Case Discover.
* Uses python-based JSON parser
* Revised aliquot annotation parsing
* Generates Catalog files in the [PE-CGS format](https://docs.google.com/document/d/1PI8YaMb_QtS26qKBdlp703OQYGhb3E9z184IahkGr14/edit#)

Query GDC to discover sequence and methylation data and write it to a catalog file

## Quick start

* Obtain token from GDC, save to file `gdc-user-token.txt`
    * make this available as global variable with, `export GDC_TOKEN=gdc-user-token.txt`
* `git clone --recurse-submodules https://github.com/ding-lab/CPTAC3.case.discover PROJECT_NAME`
* edit `1_process_all.sh`
* run `bash 1_process_all.sh`

## Updates

### Version 2.3

Updates to `sample_metadata` field, which is now a space-separated list of KEY=VALUE pairs.
Metadata may come from GDC annotation or ad hoc "suffix lists".

### Version 2.2
Flags datasets associated with heterogeneity studies based on GDC aliquot annotation note.

#### Fields added

Adding the following columns to catalog file:
* `sample_id` - GDC sample name  
* `sample_metadata` - Ad hoc metadata associated with this sample.  May be comma-separated list
* `aliquot_annotation` - Annotation note associated with aliquot, from GDC 

Also, `sample_name` has additional element based on aliquot_annotation. Details below.

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

Note that [`bashids`](https://github.com/benwilber/bashids) is also used, but this is installed during `git clone` as a submodule.

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

Example catalog file:
```
# sample_name	case	disease	experimental_strategy	short_sample_type	aliquot	filename	filesize	data_format	result_type	UUID	MD5	reference	sample_type
C3L-00103.MethArray.Green.T	C3L-00103	CCRCC	Methylation Array	tumor	CPT0000640008	202184990069_R01C01_Grn.idat	13676226	IDAT	Green	e5910ae5-bb8f-46c6-a1e8-b8da04dcbbc6	5bc97fd5c55b0cae9549144093da10f3	NA	Primary Tumor	C3L-00103-02	  	
C3L-00103.MethArray.Green.T.HET_oymKX	C3L-00103	CCRCC	Methylation Array	tumor	CPT0000630006	204372030070_R01C01_Grn.idat	13677900	IDAT	Green	c8b1652b-e7b5-48ae-bdd2-930be43ddaf9	3a95d2249f7abb2d7edc36fdd2a0c5b3	NA	Primary Tumor	C3L-00103-01	 heterogeneity HET_oymKX	Duplicate item: CCRCC Tumor heterogeneity study aliquot
C3L-00103.MethArray.Green.T.HET_oyo53	C3L-00103	CCRCC	Methylation Array	tumor	CPT0000650006	204367490030_R02C01_Grn.idat	13677885	IDAT	Green	1c3e5948-a555-47cc-821c-6ba3f483cda1	1726b54053742517a8a435761183e849	NA	Primary Tumor	C3L-00103-03	 heterogeneity HET_oyo53	Duplicate item: CCRCC Tumor heterogeneity study aliquot
C3L-00103.MethArray.Red.T	C3L-00103	CCRCC	Methylation Array	tumor	CPT0000640008	202184990069_R01C01_Red.idat	13676226	IDAT	Red	a7436b52-d702-4260-a6fc-a81ff78e3bf0	21245f965c48b097a942e65360685903	NA	Primary Tumor	C3L-00103-02	  	
C3L-00103.MethArray.Red.T.HET_oymKX	C3L-00103	CCRCC	Methylation Array	tumor	CPT0000630006	204372030070_R01C01_Red.idat	13677900	IDAT	Red	b3d1ac80-1afe-4638-a9a5-7565d3d2cf3b	1b398689a7e891ca17e98ce19160a3c2	NA	Primary Tumor	C3L-00103-01	 heterogeneity HET_oymKX	Duplicate item: CCRCC Tumor heterogeneity study aliquot
C3L-00103.MethArray.Red.T.HET_oyo53	C3L-00103	CCRCC	Methylation Array	tumor	CPT0000650006	204367490030_R02C01_Red.idat	13677885	IDAT	Red	236d7ab1-b6c7-466f-b39a-296ef1f3aa74	5785ed159188887f3851d3b2031e3cc2	NA	Primary Tumor	C3L-00103-03	 heterogeneity HET_oyo53	Duplicate item: CCRCC Tumor heterogeneity study aliquot
C3L-00103.miRNA-Seq.A	C3L-00103	CCRCC	miRNA-Seq	tissue_normal	CPT0000660006	181108_UNC31-K00269_0163_BH23TVBBXY_CACCGG_S30_L004_R1_001.unaln.bam	233112878	BAM	NA	61ea1844-e06e-4fb4-87ce-8d14e25427d3	3667e6e5270f59888ffe11b885cf6228	NA	Solid Tissue Normal	C3L-00103-06	  	
C3L-00103.miRNA-Seq.A.hg38	C3L-00103	CCRCC	miRNA-Seq	tissue_normal	CPT0000660006	975c97b1-d946-4d40-8e1b-627fa5b359e4_mirnaseq_gdc_realn.bam	259414329	BAM	NA	2becc6b3-ad3b-4e52-b0c0-5281fc22275c	f0820ecb779d58437b702611f4cdddf4	hg38	Solid Tissue Normal	C3L-00103-06	  	
C3L-00103.miRNA-Seq.T	C3L-00103	CCRCC	miRNA-Seq	tumor	CPT0000640005	181113_UNC31-K00269_0164_AH23NNBBXY_TCATTC_S21_L003_R1_001.unaln.bam	181353878	BAM	NA	7326dbe9-1164-434b-a9f2-fc1a2a954d32	6f461eb7149390a4d29d005f8ee4e168	NA	Primary Tumor	C3L-00103-02	  	
C3L-00103.miRNA-Seq.T.HET_qZq3G	C3L-00103	CCRCC	miRNA-Seq	tumor	CPT0000650008	200526_UNC32-K00270_0248_BHH7WFBBXY_GTTTCG_S34_L002_R1_001.unaln.bam	261660434	BAM	NA	73d38500-a837-4cf8-80f8-8e61a7b49a51	ad297c8c923db7437f27b05bf2f25ec0	NA	Primary Tumor	C3L-00103-03	 heterogeneity HET_qZq3G	Duplicate item: CCRCC Tumor heterogeneity study aliquot
C3L-00103.miRNA-Seq.T.HET_qZq3G.hg38	C3L-00103	CCRCC	miRNA-Seq	tumor	CPT0000650008	827db034-8884-434e-b7a2-02e3ada31709_mirnaseq_gdc_realn.bam	297445843	BAM	NA	399cee47-430f-4e12-987a-756b8023b6bd	2702ef33f20b37932762147bdaa1511a	hg38	Primary Tumor	C3L-00103-03	 heterogeneity HET_qZq3G	Duplicate item: CCRCC Tumor heterogeneity study aliquot
C3L-00103.miRNA-Seq.T.hg38	C3L-00103	CCRCC	miRNA-Seq	tumor	CPT0000640005	ac4fb97a-7871-49d7-a46c-28033dff66af_mirnaseq_gdc_realn.bam	207346466	BAM	NA	93fe19d1-56af-4f1b-8a4a-af3201a20654	71b06296a692b4e8885f316645cfe559	hg38	Primary Tumor	C3L-00103-02	  	
C3L-00103.RNA-Seq.chimeric.A.hg38	C3L-00103	CCRCC	RNA-Seq	tissue_normal	CPT0000660006	87f8ea6a-d7ff-4d20-841b-8a3cdb9f5ba0.rna_seq.chimeric.gdc_realn.bam	76606338	BAM	chimeric	81ccd415-ba01-474f-a2bb-b286dbd5bac3	6e8cbf0c19250580de231c4b27b2ad83	hg38	Solid Tissue Normal	C3L-00103-06	  	
C3L-00103.RNA-Seq.chimeric.T.HET_qZq3G.hg38	C3L-00103	CCRCC	RNA-Seq	tumor	CPT0000650008	0ffcbe82-d3f0-414b-bfc4-59a3e1a0195b.rna_seq.chimeric.gdc_realn.bam	68680581	BAM	chimeric	19e1b80f-7000-4794-b180-881fabf2c287	796716558235bb0f16e750a36a54c7ee	hg38	Primary Tumor	C3L-00103-03	 heterogeneity HET_qZq3G	Duplicate item: CCRCC Tumor heterogeneity study aliquot
C3L-00103.RNA-Seq.chimeric.T.HET_r9p5p.hg38	C3L-00103	CCRCC	RNA-Seq	tumor	CPT0000630009	4551e242-a249-448d-88ed-ff84158f85a3.rna_seq.chimeric.gdc_realn.bam	175132318	BAM	chimeric	356db3fb-f074-4aa7-b493-f4748f2fe1f6	faab99b4167e08fd211b79c5d16cb078	hg38	Primary Tumor	C3L-00103-01	 heterogeneity HET_r9p5p	Duplicate item: CCRCC Tumor heterogeneity study aliquot
C3L-00103.RNA-Seq.chimeric.T.hg38	C3L-00103	CCRCC	RNA-Seq	tumor	CPT0000640005	08659a8b-e74c-45e8-ac69-72d2866db59f.rna_seq.chimeric.gdc_realn.bam	98673163	BAM	chimeric	75da3059-9bcf-43e2-a4cb-ccd166cd9950	4782ad4f0a5ace14a569ded97d85c316	hg38	Primary Tumor	C3L-00103-02	  	
C3L-00103.RNA-Seq.genomic.A.hg38	C3L-00103	CCRCC	RNA-Seq	tissue_normal	CPT0000660006	87f8ea6a-d7ff-4d20-841b-8a3cdb9f5ba0.rna_seq.genomic.gdc_realn.bam	7553438191	BAM	genomic	b405a565-e045-4547-a333-75c44b4b7505	bc215bc4c36f539375cfdff4010fe908	hg38	Solid Tissue Normal	C3L-00103-06	  	
C3L-00103.RNA-Seq.genomic.T.HET_qZq3G.hg38	C3L-00103	CCRCC	RNA-Seq	tumor	CPT0000650008	0ffcbe82-d3f0-414b-bfc4-59a3e1a0195b.rna_seq.genomic.gdc_realn.bam	7896910397	BAM	genomic	18286f10-e92d-47c6-b0d9-6d947d57d67f	a25ce238254082887190dfa708291c2c	hg38	Primary Tumor	C3L-00103-03	 heterogeneity HET_qZq3G	Duplicate item: CCRCC Tumor heterogeneity study aliquot
C3L-00103.RNA-Seq.genomic.T.HET_r9p5p.hg38	C3L-00103	CCRCC	RNA-Seq	tumor	CPT0000630009	4551e242-a249-448d-88ed-ff84158f85a3.rna_seq.genomic.gdc_realn.bam	11769989864	BAM	genomic	a8742879-06ab-47ef-9ed2-bf7b9fd59d79	2ce1e571048cd665d096f2c22f95cea4	hg38	Primary Tumor	C3L-00103-01	 heterogeneity HET_r9p5p	Duplicate item: CCRCC Tumor heterogeneity study aliquot
C3L-00103.RNA-Seq.genomic.T.hg38	C3L-00103	CCRCC	RNA-Seq	tumor	CPT0000640005	08659a8b-e74c-45e8-ac69-72d2866db59f.rna_seq.genomic.gdc_realn.bam	9215302719	BAM	genomic	6d0d76bc-abb6-4458-86db-4613092dc1c0	873cac1511fc69a25691793b815e49b9	hg38	Primary Tumor	C3L-00103-02	  	
C3L-00103.RNA-Seq.R1.A	C3L-00103	CCRCC	RNA-Seq	tissue_normal	CPT0000660006	171208_UNC32-K00270_0071_BHN7K5BBXX_GCCAAT_S56_L007_R1_001.fastq.gz	3754354855	FASTQ	NA	7583c79b-d6d8-4669-b558-0aba2ba67054	bf840fc5bdff84842dce0e0b4fcb06cc	NA	Solid Tissue Normal	C3L-00103-06	  	
C3L-00103.RNA-Seq.R1.T	C3L-00103	CCRCC	RNA-Seq	tumor	CPT0000640005	170818_UNC32-K00270_0050_AHL2FHBBXX_CCGTCC_S7_L002_R1_001.fastq.gz	4211540733	FASTQ	NA	0432802d-9155-45bd-90b8-8472a758eaa1	bd8f9e5aaa9f273eb3809656319ab627	NA	Primary Tumor	C3L-00103-02	  	
C3L-00103.RNA-Seq.R1.T.HET_qZq3G	C3L-00103	CCRCC	RNA-Seq	tumor	CPT0000650008	200519_UNC31-K00269_0280_BHHKGNBBXY_GCCACAGG-CATGCCAT_S19_L005_R1_001.fastq.gz	3714824575	FASTQ	NA	4c0823f5-5c3b-4dff-9ae1-40a8210c1fc3	90f1b27ac35446f74e735895beabe104	NA	Primary Tumor	C3L-00103-03	 heterogeneity HET_qZq3G	Duplicate item: CCRCC Tumor heterogeneity study aliquot
C3L-00103.RNA-Seq.R1.T.HET_r9p5p	C3L-00103	CCRCC	RNA-Seq	tumor	CPT0000630009	200518_UNC32-K00270_0247_AHH573BBXY_CCGCGGTT-AGCGCTAG_S29_L004_R1_001.fastq.gz	5570232704	FASTQ	NA	7dbef68a-aff2-402b-9665-24668fab5908	e8ebfe940dbeb0bb503f4e77fa52aabf	NA	Primary Tumor	C3L-00103-01	 heterogeneity HET_r9p5p	Duplicate item: CCRCC Tumor heterogeneity study aliquot
C3L-00103.RNA-Seq.R2.A	C3L-00103	CCRCC	RNA-Seq	tissue_normal	CPT0000660006	171208_UNC32-K00270_0071_BHN7K5BBXX_GCCAAT_S56_L007_R2_001.fastq.gz	4014415458	FASTQ	NA	de108ae0-884f-4c53-a4ab-40681988ef5c	709f0274b47d76dce3281d7bd07dadb3	NA	Solid Tissue Normal	C3L-00103-06	  	
C3L-00103.RNA-Seq.R2.T	C3L-00103	CCRCC	RNA-Seq	tumor	CPT0000640005	170818_UNC32-K00270_0050_AHL2FHBBXX_CCGTCC_S7_L002_R2_001.fastq.gz	4462888273	FASTQ	NA	a37d45d8-1c52-4fd2-906f-d70282c859ec	7a58098bfcbf3697639cd568dd0d3b8e	NA	Primary Tumor	C3L-00103-02	  	
C3L-00103.RNA-Seq.R2.T.HET_qZq3G	C3L-00103	CCRCC	RNA-Seq	tumor	CPT0000650008	200519_UNC31-K00269_0280_BHHKGNBBXY_GCCACAGG-CATGCCAT_S19_L005_R2_001.fastq.gz	4342999494	FASTQ	NA	fad68f1e-fa0e-4d25-a822-600c8a10afbb	61c15974438a5117c6d1c536bb60d3b8	NA	Primary Tumor	C3L-00103-03	 heterogeneity HET_qZq3G	Duplicate item: CCRCC Tumor heterogeneity study aliquot
C3L-00103.RNA-Seq.R2.T.HET_r9p5p	C3L-00103	CCRCC	RNA-Seq	tumor	CPT0000630009	200518_UNC32-K00270_0247_AHH573BBXY_CCGCGGTT-AGCGCTAG_S29_L004_R2_001.fastq.gz	6449461194	FASTQ	NA	7f6794c3-542b-481f-9bfe-dd4781ec781c	2a7d5c3fbce2fb1963a8e8aeca20b1ea	NA	Primary Tumor	C3L-00103-01	 heterogeneity HET_r9p5p	Duplicate item: CCRCC Tumor heterogeneity study aliquot
C3L-00103.RNA-Seq.transcriptome.A.hg38	C3L-00103	CCRCC	RNA-Seq	tissue_normal	CPT0000660006	87f8ea6a-d7ff-4d20-841b-8a3cdb9f5ba0.rna_seq.transcriptome.gdc_realn.bam	7721976782	BAM	transcriptome	cad2152f-3869-4086-964c-bb1b337d8caf	833128e44300f33577126a2b7cfeeb8c	hg38	Solid Tissue Normal	C3L-00103-06	  	
C3L-00103.RNA-Seq.transcriptome.T.HET_qZq3G.hg38	C3L-00103	CCRCC	RNA-Seq	tumor	CPT0000650008	0ffcbe82-d3f0-414b-bfc4-59a3e1a0195b.rna_seq.transcriptome.gdc_realn.bam	8537401533	BAM	transcriptome	abdca823-2cb9-4b3d-80c4-b01b94df77f1	5419e0768fa982221efc1a28dc28e57c	hg38	Primary Tumor	C3L-00103-03	 heterogeneity HET_qZq3G	Duplicate item: CCRCC Tumor heterogeneity study aliquot
C3L-00103.RNA-Seq.transcriptome.T.HET_r9p5p.hg38	C3L-00103	CCRCC	RNA-Seq	tumor	CPT0000630009	4551e242-a249-448d-88ed-ff84158f85a3.rna_seq.transcriptome.gdc_realn.bam	13109095254	BAM	transcriptome	b6980dd3-187c-4f30-8491-d19159204922	89bcb841eb5004557df7110b440d96d2	hg38	Primary Tumor	C3L-00103-01	 heterogeneity HET_r9p5p	Duplicate item: CCRCC Tumor heterogeneity study aliquot
C3L-00103.RNA-Seq.transcriptome.T.hg38	C3L-00103	CCRCC	RNA-Seq	tumor	CPT0000640005	08659a8b-e74c-45e8-ac69-72d2866db59f.rna_seq.transcriptome.gdc_realn.bam	9257223492	BAM	transcriptome	611c9dc0-ff71-46bf-b6d4-c2016c8916f0	bc2f714cc8053c8cfddacd206d4bcdf1	hg38	Primary Tumor	C3L-00103-02	  	
C3L-00103.WGS.A	C3L-00103	CCRCC	WGS	tissue_normal	CPT0000660009	CPT0000660009.WholeGenome.RP-1303.bam	54363989068	BAM	NA	b9e66dbc-c399-4024-acdf-8491a493dfe9	309ac08e7b1b007766d90b45ed14046a	hg19	Solid Tissue Normal	C3L-00103-06	  	
C3L-00103.WGS.A.hg38	C3L-00103	CCRCC	WGS	tissue_normal	CPT0000660009	5e34b40b-83f7-4eb1-b42e-ffde801a6a4c_wgs_gdc_realn.bam	79788034613	BAM	NA	2bb97d5f-bcf6-4ecb-89ab-3f2f9a7f0e64	6d0d680149f94817d5d4c98adf73cabd	hg38	Solid Tissue Normal	C3L-00103-06	  	
C3L-00103.WGS.N	C3L-00103	CCRCC	WGS	blood_normal	CPT0003850002	CPT0003850002.WholeGenome.RP-1303.bam	79382126911	BAM	NA	290f5cee-c397-4dbc-bfdc-b9a0aaedea27	56f18e3eebae4b6f82dbeb7705552cba	hg19	Blood Derived Normal	C3L-00103-31	  	
C3L-00103.WGS.N.hg38	C3L-00103	CCRCC	WGS	blood_normal	CPT0003850002	b35e7696-f8f2-4fdb-a2e7-e6b4842a4674_gdc_realn.bam	117135673578	BAM	NA	62957d62-cf92-4457-84e0-a0c74dffd73f	28e06b003272f3f30da4ee6c4b77ca90	hg38	Blood Derived Normal	C3L-00103-31	  	
C3L-00103.WGS.T	C3L-00103	CCRCC	WGS	tumor	CPT0000640008	CPT0000640008.WholeGenome.RP-1303.bam	68572746909	BAM	NA	5a5e9f3e-2631-4ff2-8009-48d549d98114	c13f21092db0150c9542c4cccc37233a	hg19	Primary Tumor	C3L-00103-02	  	
C3L-00103.WGS.T.HET_oymKX	C3L-00103	CCRCC	WGS	tumor	CPT0000630006	CPT0000630006.WholeGenome.RP-2158.bam	26175355835	BAM	NA	3155a7a2-6a20-4050-801c-2f63bb959f8b	f36f440d866e41d8c2bd98bd76dd9ac6	hg19	Primary Tumor	C3L-00103-01	 heterogeneity HET_oymKX	Duplicate item: CCRCC Tumor heterogeneity study aliquot
C3L-00103.WGS.T.HET_oyo53	C3L-00103	CCRCC	WGS	tumor	CPT0000650006	CPT0000650006.WholeGenome.RP-2158.bam	32733454062	BAM	NA	0441718a-d113-4eb6-8882-8f054940c50a	05329f422ca1e63a932e185b419b1867	hg19	Primary Tumor	C3L-00103-03	 heterogeneity HET_oyo53	Duplicate item: CCRCC Tumor heterogeneity study aliquot
C3L-00103.WGS.T.hg38	C3L-00103	CCRCC	WGS	tumor	CPT0000640008	c5a3c455-b1f3-4125-a6f5-401385ab2720_gdc_realn.bam	101056769537	BAM	NA	1bc9301e-0f79-401d-9a81-e96a5675005e	4cdabbeecd850714fcfe287fb21c372e	hg38	Primary Tumor	C3L-00103-02	  	
C3L-00103.WXS.A	C3L-00103	CCRCC	WXS	tissue_normal	CPT0000660009	CPT0000660009.WholeExome.RP-1303.bam	38364823448	BAM	NA	f5d342bd-ba86-47a5-9f9c-0c9fe650d3cf	5d908d47ce9e26716bef237e85cd4866	hg19	Solid Tissue Normal	C3L-00103-06	  	
C3L-00103.WXS.A.hg38	C3L-00103	CCRCC	WXS	tissue_normal	CPT0000660009	5e34b40b-83f7-4eb1-b42e-ffde801a6a4c_wxs_gdc_realn.bam	52639862514	BAM	NA	1bcb4996-7610-4417-b648-bd9c7a34427e	23bf88201fad4be34640708442b749f9	hg38	Solid Tissue Normal	C3L-00103-06	  	
C3L-00103.WXS.N	C3L-00103	CCRCC	WXS	blood_normal	CPT0003850002	CPT0003850002.WholeExome.RP-1303.bam	22186536977	BAM	NA	a5553301-99b3-478a-906f-2ae2158f9522	68a5a6707680b74140822cc1abb0eb70	hg19	Blood Derived Normal	C3L-00103-31	  	
C3L-00103.WXS.N.hg38	C3L-00103	CCRCC	WXS	blood_normal	CPT0003850002	b35e7696-f8f2-4fdb-a2e7-e6b4842a4674_gdc_realn.bam	30381554017	BAM	NA	be832dc4-0367-4d5a-aa34-b0dfafecaa92	66d2fa61d62c4898aea096bbde65ff95	hg38	Blood Derived Normal	C3L-00103-31	  	
C3L-00103.WXS.T	C3L-00103	CCRCC	WXS	tumor	CPT0000640008	CPT0000640008.WholeExome.RP-1303.bam	24599619481	BAM	NA	327cded6-b729-4655-b620-b0dbb32912e7	9a557c35c9b7d0b0a0eb44d8e9846743	hg19	Primary Tumor	C3L-00103-02	  	
C3L-00103.WXS.T.HET_oymKX	C3L-00103	CCRCC	WXS	tumor	CPT0000630006	CPT0000630006.WholeExome.RP-1303.bam	24686273415	BAM	NA	deadd118-a5ab-4f01-abbb-601a5892aec4	9c91ecdf23540ffc63b0ffe03bafd76f	hg19	Primary Tumor	C3L-00103-01	 heterogeneity HET_oymKX	Duplicate item: CCRCC Tumor heterogeneity study aliquot
C3L-00103.WXS.T.HET_oyo53	C3L-00103	CCRCC	WXS	tumor	CPT0000650006	CPT0000650006.WholeExome.RP-1303.bam	28893546665	BAM	NA	eb8ef027-b6fa-40b8-a8fc-4a90b6fdc308	45170d8708140c7c2fc47b629544d186	hg19	Primary Tumor	C3L-00103-03	 heterogeneity HET_oyo53	Duplicate item: CCRCC Tumor heterogeneity study aliquot
C3L-00103.WXS.T.hg38	C3L-00103	CCRCC	WXS	tumor	CPT0000640008	c5a3c455-b1f3-4125-a6f5-401385ab2720_gdc_realn.bam	33390644310	BAM	NA	01c91555-2c8b-462a-9814-236ea632e22f	a7c494fad70fb0ca406291eaca330976	hg38	Primary Tumor	C3L-00103-02	  	
```

### Sample names

Sample names are ad hoc names we generate for convenience.  They indicate the case, experimental strategy, 
sample type, whether data are harmonized (`hg38`) and any aliquot annotation codes.  Examples include,
```
C3L-00103.MethArray.Green.T
C3L-00103.MethArray.Red.T
C3L-00103.miRNA-Seq.A
C3L-00103.miRNA-Seq.A.hg38
C3L-00103.miRNA-Seq.T
C3L-00103.miRNA-Seq.T.HET_qZq3G
C3L-00103.miRNA-Seq.T.HET_qZq3G.hg38
C3L-00103.RNA-Seq.chimeric.T.hg38
C3L-00103.RNA-Seq.genomic.A.hg38
C3L-00103.RNA-Seq.R1.A
C3L-00103.RNA-Seq.R2.A
C3L-00103.RNA-Seq.transcriptome.T.HET_qZq3G.hg38
C3L-00103.WGS.N
C3L-00103.WGS.N.hg38
C3L-00103.WGS.T
C3L-00103.WGS.T.HET_oymKX
C3L-00103.WXS.T.hg38
```

See Heterogeneity Studies below for information about labels like `HET_qZq3G`.

### Sample types

The `sample_type` column lists GDC sample types.  We abbreviate these names in the sample name and `short_sample_type` column respectively as,
* Blood Derived Normal: N, blood_normal
* Buccal Cell Normal: Nbc, buccal_normal
* Primary Tumor, Tumor: T, tumor
* Primary Blood Derived Cancer - Bone Marrow: Tbm, tumor_bone_marrow
* Primary Blood Derived Cancer - Peripheral Blood: Tpb, tumor_peripheral_blood
* Solid Tissue Normal: A, tissue_normal
* Recurrent Tumor: R, recurrent_tumor

## Heterogeneity Studies and duplicates

GDC provides annotations associated with aliquots which contain additional
context regarding cases with multiple tumor samples.  This information is
stored in the field `aliquot_annotation` and is used to generate a convenient
label used in the sample metadata and sample name fields.

If `aliquot_annotation` is defined for a given data file, we generate sample
label consisting of a label prefix followed by an ID code.  For CPTAC3, an example sample
label may be `HET_qZq3G`, where the prefix `HET` indicates heterogeneity and
the ID code is `qZq3G`.  This code is hash ID generated with
[bashids](https://github.com/benwilber/bashids), where the input numerical
string is obtained from the aliquot name (`CPT0000650008`) with "CPT" and any
leading 0's removed.  The sample label used for the `sample_name` and
`sample_metadata` fields

Table below lists all known GDC aliquot annotations, and 
the prefix used to generate the sample label.

| Aliquot annotation | Label prefix |
| ------------------ | ------------ |
| Additional DNA Distribution - Additional aliquot | ADD
| BioTEXT_RNA | BIOTEXT 
| Duplicate item: Additional DNA for PDA Deep Sequencing | DEEP | 
| Duplicate item: Additional DNA requested | ADNA
| Duplicate item: Additional RNA requested | ARNA
| Duplicate item: CCRCC Tumor heterogeneity study | HET | 
| Duplicate Item: CHOP GBM Duplicate Primary Tumor DNA Aliquot | ADNA
| Duplicate Item: CHOP GBM Duplicate Primary Tumor RNA Aliquot | ADNA
| Duplicate Item: CHOP GBM Duplicate Recurrent Tumor DNA Aliquot | ADNA
| Duplicate Item: CHOP GBM Duplicate Recurrent Tumor RNA Aliquot | ADNA
| Duplicate item: No new shipment/material. DNA aliquot resubmission for Broad post-harmonization sequencing and sample type mismatch correction. | RDNA
| Duplicate item: PDA BIOTEXT DNA | BIOTEXT
| Duplicate item: PDA Pilot - bulk-derived DNA | BULK
| Duplicate item: PDA Pilot - core-derived DNA | CORE
| Duplicate item: Replacement DNA Distribution - original aliquot failed | RDNA
| Duplicate item: Replacement RNA Aliquot | RRNA 
| Duplicate item: Replacement RNA Distribution - original aliquot failed | RRNA
| Duplicate item: UCEC BioTEXT Pilot | BIOTEXT
| Duplicate item: UCEC LMD Heterogeneity Pilot | LMD
| Original DNA Aliquot | ODNA
| Replacement DNA Aliquot | RDNA
| This entity was not yet authorized to be released by the submitters | UNAV
| unknown | UNK | 

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
