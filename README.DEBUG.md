posthoc analysis indicates that some entries do not have valid metadata strings.
For instance,

$ examine_row ./logs_CPTAC/outputs/C3L-00006/submitted_reads.catalog3.dat 14
     1  dataset_name    C3L-00006.RNA-Seq.T
     2  case    C3L-00006
     3  disease UCEC
     4  experimental_strategy   RNA-Seq
     5  sample_type tumor
     6  specimen_name   CPT0349370001
     7  filename    20210714_P1_F5_WB7988_plate1_S65_R1_001.fastq.gz
     8  filesize    5552900008
     9  data_format FASTQ
    10  data_variety
    11  alignment   unaligned
    12  project CPTAC3
    13  uuid    cdee2b7c-feac-42d4-9138-3f79952769ea
    14  md5 6233ac946dc6a8cb34fb65b817f41489
    15  metadata

This can be reproduced with this command:
    /diskmnt/Projects/Users/mwyczalk/miniconda3/bin/python src/make_catalog3.py -D UCEC -P CPTAC3 -Q ./logs_CPTAC/outputs/C3L-00006/aliquots.dat -o ./logs_CPTAC/outputs/C3L-00006/submitted_reads.catalog3.dat ./logs_CPTAC/outputs/C3L-00006/submitted_reads.dat


