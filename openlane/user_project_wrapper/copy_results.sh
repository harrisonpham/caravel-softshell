#!/bin/bash
# SPDX-FileCopyrightText: (c) 2020 Harrison Pham <harrison@harrisonpham.com>
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -ex

IN_PATH="$(realpath "$1")"
OUT_PATH="$(realpath ../..)"
ARTIFACT="user_project_wrapper"

# echo "Copying results from '${IN_PATH}' to '${OUT_PATH}'"

cp -pf "${IN_PATH}/results/routing/${ARTIFACT}.def" "${OUT_PATH}/def/${ARTIFACT}.def"
cp -pf "${IN_PATH}/results/magic/${ARTIFACT}.gds" "${OUT_PATH}/gds/${ARTIFACT}.gds"
cp -pf "${IN_PATH}/results/magic/${ARTIFACT}.lef" "${OUT_PATH}/lef/${ARTIFACT}.lef"
cp -pf "${IN_PATH}/results/magic/${ARTIFACT}.mag" "${OUT_PATH}/mag/${ARTIFACT}.mag"
cp -pf "${IN_PATH}/results/lvs/${ARTIFACT}.lvs.powered.v" "${OUT_PATH}/verilog/gl/${ARTIFACT}.v"
cp -pf "${IN_PATH}/results/magic/${ARTIFACT}.spice" "${OUT_PATH}/spi/lvs/${ARTIFACT}.spice"

# echo "Copying summary"
# cp -pf "${IN_PATH}/reports/final_summary_report.csv" "${OUT_PATH}/openlane/${ARTIFACT}/"

echo "Removing old results folder and logs / reports"
mkdir -p "${OUT_PATH}/openlane/${ARTIFACT}/results"
rm -rf "${OUT_PATH}/openlane/${ARTIFACT}/results/*"
(cd "${IN_PATH}" &&
 find . -iregex '.*\.\(rpt\|txt\|log\|tcl\|csv\|drc\)' \
 -exec cp -pv --parents {} "${OUT_PATH}/openlane/${ARTIFACT}/results/" ';')

# Compress known large log files
gzip -9 "${OUT_PATH}/openlane/${ARTIFACT}/results/reports/routing/antenna.rpt"

echo "Done"
