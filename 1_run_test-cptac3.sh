PY="src/GDC_Catalog.py"
#CASES="C3L-00026 11LU013 C3N-00148 PT-Q2AG" 
CASES="C3L-00026"

OUT="test.out"
ARGS="-o $OUT"

bash python3_gdc $PY $ARGS $CASES


