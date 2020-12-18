#!/bin/bash

set -x

IN_PATH="./$1"
OUT_PATH="../.."
ARTIFACT="user_proj_example"

echo "Copying results from '${IN_PATH}' to '${OUT_PATH}'"

cp -pf "${IN_PATH}/results/routing/${ARTIFACT}.def" "${OUT_PATH}/def/${ARTIFACT}.def"
cp -pf "${IN_PATH}/results/magic/${ARTIFACT}.gds" "${OUT_PATH}/gds/${ARTIFACT}.gds"
cp -pf "${IN_PATH}/results/magic/${ARTIFACT}.lef" "${OUT_PATH}/lef/${ARTIFACT}.lef"
cp -pf "${IN_PATH}/results/magic/${ARTIFACT}.mag" "${OUT_PATH}/mag/${ARTIFACT}.mag"
cp -pf "${IN_PATH}/results/lvs/${ARTIFACT}.lvs.powered.v" "${OUT_PATH}/verilog/gl/${ARTIFACT}.v"
cp -pf "${IN_PATH}/results/magic/${ARTIFACT}.spice" "${OUT_PATH}/spi/lvs/${ARTIFACT}.spice"

echo "Copying summary"
cp -pf "${IN_PATH}/reports/final_summary_report.csv" "${OUT_PATH}/openlane/${ARTIFACT}/"

# echo "Removing old results folder and copying all results..."
# rm -rf "${OUT_PATH}/runs/${ARTIFACT}/*"
# cp -prf "${IN_PATH}/*" "${OUT_PATH}/openlane/${ARTIFACT}/runs/${ARTIFACT}"

echo "Done"
