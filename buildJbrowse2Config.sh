#!/bin/bash
################################################################################
##
##  buildJBrowseConfig.sh <build_number> [<files_dir>]
##
##  Writes a JBrowse2 config file (json) based on existing tracks and
##  assemblies (fasta and gff) generated by the workflow.  Build number
##  argument should be numeric.  Optional files dir points to the web services
##  files root and defaults to /var/www/Common/apiSiteFilesMirror/webServices
##  if not specified.  Output file is named config.json and is written to PWD.
##
################################################################################

if [ "$#" != "1" ] && [ "$#" != "2" ]; then
  printf "\nUSAGE: buildJBrowseConfig.sh <build_number> [<files_dir>]\n\n"
  exit 1
fi

build="$1"
filesDir="$2"

# default files dir if not specified
if [ "$filesDir" == "" ]; then
  filesDir="/var/www/Common/apiSiteFilesMirror/webServices"
fi

outFile=$(pwd)/config.json

cd "$filesDir"

printf '{"configuration":{},"connections":[],"defaultSession":{"name":"New Session"},"assemblies":[' > $outFile

# requires $comma $name $trackId $fastaPath $faiPath
assemblyTemplate='%s{
  "name":"%s",
  "sequence": {
    "type": "ReferenceSequenceTrack",
    "trackId": "%s",
    "adapter": {
      "type": "IndexedFastaAdapter",
      "fastaLocation": {
        "uri": "%s",
        "locationType": "UriLocation"
      },
      "faiLocation": {
        "uri": "%s",
        "locationType": "UriLocation"
      }
    }
  }
}'

comma=
for faiPath in $(ls ./*/build-${build}/*/fasta/genome.fasta.fai | grep -v "^\./EuPathDB" | grep -v "^\./VEuPathDB"); do
  echo "Processing $faiPath"
  fastaPath=$(echo $faiPath | sed 's/\.fai//')
  namePath=$(echo $fastaPath | sed 's/\.fasta//')
  name=$(echo $namePath | sed 's|/| |g' | awk '{ print $2 "-" $3 "_" $4 "_Genome" }' | sed 's/build-//')
  trackId="${name}-ReferenceSequenceTrack"
  printf "$assemblyTemplate" "$comma" $name $trackId $fastaPath $faiPath >> $outFile
  comma=","
done

printf '],"tracks":[' >> $outFile

# requires $comma $trackId $name $gzPath $tbiPath $assemblyName
trackTemplate='%s{
  "type": "FeatureTrack",
  "trackId": "%s",
  "name": "%s",
  "adapter": {
    "type": "Gff3TabixAdapter",
    "gffGzLocation": {
      "uri": "%s",
      "locationType": "UriLocation"
    },
    "index": {
      "location": {
        "uri": "%s",
        "locationType": "UriLocation"
      },
      "indexType": "TBI"
    }
  },
  "assemblyNames": [
    "%s"
  ]
}'

comma=
for tbiPath in $(ls ./*/build-${build}/*/nrProteinsToGenomeAlign/result.sorted.gff.gz.tbi | grep -v "^\./EuPathDB" | grep -v "^\./VEuPathDB"); do
  echo "Processing $tbiPath"
  gzPath=$(echo $tbiPath | sed 's/\.tbi//')
  nameBase=$(echo $gzPath | sed 's/[\.\/]/ /g' | awk '{ print $1 "-" $2 "_" $3 }' | sed 's/build-//')
  name=sorted_${nameBase}.gff      # also trackId
  assemblyName=${nameBase}_Genome
  printf "$trackTemplate" "$comma" $name $name $gzPath $tbiPath $assemblyName >> $outFile
  comma=","
done

for tbiPath in $(ls ./*/build-${build}/*/gff/annotated_transcripts.gff.gz.tbi | grep -v "^\./EuPathDB" | grep -v "^\./VEuPathDB"); do
  echo "Processing $tbiPath"
  gzPath=$(echo $tbiPath | sed 's/\.tbi//')
  nameBase=$(echo $gzPath | sed 's/[\./]/ /g' | awk '{ print $1 "-" $2 "_" $3 }' | sed 's/build-//')
  name=annotated_${nameBase}.gff   # also trackId
  assemblyName=${nameBase}_Genome
  printf "$trackTemplate" "$comma" $name $name $gzPath $tbiPath $assemblyName >> $outFile
  comma=","
done

printf ']}' >> $outFile
echo "Done."
