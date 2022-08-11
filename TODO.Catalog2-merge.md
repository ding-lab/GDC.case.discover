It would be good to merge "v2" style catalog creation with v3 style,
so that discovery needs to take place just once.  Right now the code
has support for this at a lower level, but upper level scripts make this
difficult (e.g., hard coded catalog output filename).

To make this work, need to run discovery and catalog scripts independently.
Specifically, discovery creates per-case aliquot, read group, etc. data

Catalog2 creation creates per-case catalog2 files, and then merges them to create final v2 catalog
Catalog3 creation creates per-case catalog3 files, and creates final v3 catalog

Continue this work on branch TCGA.  Make sure latest revisions are brought over from
v2 branch
