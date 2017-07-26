#!/bin/bash
tables='auditlog vmmaster eventlog notification networks hosts nodepos switch vm ipmi nodehm noderes'
tables="$tables discoverydata vpd hwinv mac nodetype bootparams chain hypervisor nodelist"
out=xcat_prev_state.txt
#date=`date +%y%m%d%H%M%S`
outdir=/lci/log/$date/
mkdir -p $outdir

if [[ "$1" != "" ]]; then
  out=$1
else
  out=$outdir$out
fi
prev=$out
if [ -f $out ]; then
  prev="$out-$date"
  mv $out $prev
fi

echo "Clean up xCAT tables and store previous ones in $out"
echo "xCAT tables contents:" > $out
echo >> $out
for t in $tables; do
  echo "Processing table $t"
  echo "table $t:" >> $out
  tabdump $t >> $out
  echo >> $out
  tabprune $t -a
done
