#
# Copyright © 2021, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# getWarehouse.sh
# - Download needed information to deploy Viya with a local warehouse repository.
# - Extract the list of images from the SAS Deployment Assets
#
# Historie:
#   v1.0   12 Jan. 2022 - M. Heidemann - SAS Institute GmbH - Init
#   v1.1   24 June 2022 - M. Heidemann - SAS Institute GmbH - Add curlOpts, remove --insecure
#

# $1 - DeploymentData
# $2 - Certificates
# $3 - output

if [ "$1" == "" ] || [ "$2" == "" ] || [ "$3" == "" ]
then
  printf '\e[31m%s\e[0m' " # Error - one or more missing parameters"
  printf "\n # ./getWarehouse.sh SASViyaV4_<OrderNr>_0_<CadenceName>_<CadenceVersion>_<CadenceRelease>_deploymentAssets_<Timestamp>.tgz SASViyaV4_<OrderNr>_certs.zip  <outputDir>"
  printf "\n #"
  printf "\n # e.g.: ./getWarehouse.sh SASViyaV4_XXXXXXXX_0_stable_2021.1.6_20211110.1636540775484_deploymentAssets_2021-11-11T081342.tgz SASViyaV4_XXXXXX_certs.zip . \n"
  exit 1
fi

# Input parameter
SASDeploymentAssetFile=$1  # SAS Deployment Assets
SASCertificate=$2          # SAS Certificate
targetDir=$3               # Output directory

unzipCmd=unzip

cadence_name=$(basename ${SASDeploymentAssetFile} | cut -d'_' -f 4)
cadence_version=$(basename ${SASDeploymentAssetFile} | cut -d'_' -f 5)
cadence_release=$(basename ${SASDeploymentAssetFile} | cut -d'_' -f 6)

warehousePath="${targetDir}/warehouse_${cadence_name}_${cadence_version}_${cadence_release}"
certPath="${warehousePath}/certs"
cadencesPath="${warehousePath}/cadences"
relPath="${warehousePath}/rel/${cadence_name}"
lodPath="${warehousePath}/lod/${cadence_name}/${cadence_version}"

curlCertString="--cert ${certPath}/entitlement-certificates/entitlement_certificate.pem --cacert ${certPath}/ca-certificates/SAS_CA_Certificate.pem"
curlUrl=https://ses.sas.com/ses
curlOpts="-v"

function gwPrint () {
  printf "$1 \n"
} 

if [ -d "${warehousePath}" ]
then
  gwPrint "Remove ${warehousePath}"
  rm -Rf "${warehousePath}"
fi

gwPrint "Create empty ${warehousePath}"
mkdir -p "${certPath}"
mkdir -p "${cadencesPath}"
mkdir -p "${relPath}"
mkdir -p "${lodPath}"

gwPrint "Extract certificates"
${unzipCmd} -q "${SASCertificate}" -d "${certPath}"

gwPrint "Get entitlements"
curl ${curlOpts} ${curlUrl}/entitlements.json ${curlCertString} -o ${warehousePath}/entitlements.json >/dev/null 2>&1
gwPrint "Get shipped.mc"
curl ${curlOpts} ${curlUrl}/cadences/shipped.mc ${curlCertString} -o ${cadencesPath}/shipped.mc >/dev/null 2>&1
gwPrint "Get rel"
curl ${curlOpts} ${curlUrl}/rel/${cadence_name}/${cadence_version} ${curlCertString} -o ${relPath}/${cadence_version} >/dev/null 2>&1
gwPrint "Get lod"
curl ${curlOpts} ${curlUrl}/lod/${cadence_name}/${cadence_version}/${cadence_release} ${curlCertString} -o ${lodPath}/${cadence_release} >/dev/null 2>&1

gwPrint "Get cadence and list of images"
tar --wildcards -C ${warehousePath} -xzf "${SASDeploymentAssetFile}" 'sas-bases/.orchestration/images.yaml' 'sas-bases/.orchestration/cadence.yaml'
mv "${warehousePath}/sas-bases/.orchestration/images.yaml" "${warehousePath}"
mv "${warehousePath}/sas-bases/.orchestration/cadence.yaml" "${warehousePath}"
rm -Rf "${warehousePath}/sas-bases"

gwPrint "Finished"
