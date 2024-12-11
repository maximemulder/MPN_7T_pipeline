#!/bin/bash
#
# ---------------------------------------------------------------------------------
# dicoms_sorted to BIDS v.2.0.0
# ---------------------------------------------------------------------------------

Col="38;5;83m" # Color code
#---------------- FUNCTION: HELP ----------------#
help() {
echo -e "\033[38;5;141m
Usage:    $(basename $0)\033[0m  \033[38;5;197m-in\033[0m <DICOMS_directory> \033[38;5;197m-id\033[0m <control_01> \033[38;5;197m-bids\033[0m <BIDS directory path>\n
\t\t\033[38;5;197m-in\033[0m 	Input directory with the subject's DICOMS directories (FULL PATH)
\t\t\033[38;5;197m-id\033[0m 	Subject identification for the new BIDS directory
\t\t\t  -id CAN be different than -in DICOMS directory
\t\t\033[38;5;197m-ses\033[0m 	flag to specify the session number (DEFAULT is 'ses-pre')
\t\t\033[38;5;197m-bids\033[0m 	Path to BIDS directory ( . or FULL PATH)

\t\t\033[38;5;197m-force\033[0m 	flag that will overwrite the directory

Check output with: http://bids-standard.github.io/bids-validator/

NOTE: This script REQUIRES dcm2niix to work: https://github.com/rordenlab/dcm2niix

RRC
McGill University, MNI, MICA-lab, November 2024
raul.rodriguezcrcues@mcgill.ca
"
}

cmd() {
    # Prepare the command for logging
    local str="$(whoami) @ $(uname -n) $(date)"
    local l_command=""
    local logfile=""
    for arg in "$@"; do
        case "$arg" in
            -fake|-no_stderr) ;; # Ignore -fake and -no_stderr
            -log) logfile="$2"; shift ;; # Capture logfile and skip to next argument
            *) l_command+="${arg} " ;; # Append arguments to the command
        esac
        shift
    done

    # Print the command with timestamp
    [[ ${quiet} != TRUE ]] && echo -e "\033[38;5;118m\n${str}:\ncommand: \033[38;5;122m${l_command}  \033[0m"

    # Execute the command if not in test mode
    [[ -z "$TEST" ]] && eval "$l_command"
}

# Print error message in red
Error() {
    echo -e "\033[38;5;9m\n-------------------------------------------------------------\n\n[ ERROR ]..... $1\n-------------------------------------------------------------\033[0m\n"
}

# Print warning message with black background and yellow text
Warn() {
    echo -e "\033[48;5;0;38;5;214m\n[ WARNING ]..... $1 \033[0m\n"
}

# Print informational message in blue
Info() {
    local Col="38;5;75m" # Color code
    [[ ${quiet} != TRUE ]] && echo -e "\033[$Col\n[ INFO ]..... $1 \033[0m"
}

# Source print functions
dir_functions=$(dirname $(realpath "$0"))

#------------------------------------------------------------------------------#
#			ARGUMENTS
# Number of inputs
if [ "$#" -gt 10 ]; then Error "Too may arguments"; help; exit 0; fi
# Create VARIABLES
for arg in "$@"
do
  case "$arg" in
  -h|-help)
    help
    exit 1
  ;;
  -in)
   SUBJ_DIR=$2
   shift;shift
  ;;
  -id)
   Subj=${2/sub-/}
   shift;shift
  ;;
  -force)
   force=TRUE
   shift;shift
  ;;
  -bids)
   BIDS_DIR=$2
   shift;shift
  ;;
  -ses)
   SES=$2
   shift;shift
  ;;
   esac
done

# argument check out & WARNINGS
arg=($SUBJ_DIR $Subj $BIDS_DIR)
if [ "${#arg[@]}" -lt 3 ]; then help
Error "One or more mandatory arguments are missing:
         -id    $Subj
         -in    $SUBJ_DIR
         -bids  $BIDS_DIR"
exit 0; fi

# Add the real path to the directories
SUBJ_DIR=$(realpath "$SUBJ_DIR")
BIDS_DIR=$(realpath "$BIDS_DIR")

# Sequence names and variables (ses is for default "ses-pre")
if [ -z ${SES} ]; then
  id="sub-${Subj}_"
  SES="SINGLE"
  BIDS="${BIDS_DIR}/sub-${Subj}"
else
  SES="ses-${SES/ses-/}";
  id="sub-${Subj}_${SES}_"
  BIDS="${BIDS_DIR}/sub-${Subj}/${SES}"
fi

echo -e "\n\033[38;5;141m
-------------------------------------------------------------
        DICOM to BIDS - Subject $Subj - Session $SES
-------------------------------------------------------------\033[0m"

# argument check out & WARNINGS
if [ "${#arg[@]}" -eq 0 ]; then help; exit 0; fi
if [[ -z $(which dcm2niix) ]]; then Error "dcm2niix NOT found"; exit 0; else Info "dcm2niix was found and is ready to work."; fi

# Check mandatory inputs: -id
arg=("$Subj")
if [ "${#arg[@]}" -lt 1 ]; then Error "Subject id is missing: $Subj"; help; exit 0; fi
if [[ "$Subj" =~ ['!@#$%^&*()_+'] ]]; then Error "Subject id shouldn't contain special characters:\n\t\t\t['!@#\$%^&*()_+']"; exit 0; fi

# check mandatory inputs: -bids
if [[ -z "$BIDS_DIR" ]]; then Error "BIDS directory is empty"; exit 0; fi

# check mandatory inputs: -in Is $SUBJ_DIR found?
if [ ! -d "${SUBJ_DIR}" ]; then Error "Subject DICOMS directory doesn't exist: \n\t ${Subj}"; exit 0; fi

# overwrite BIDS-SUBJECT
if [[ "${force}" == TRUE ]]; then rm -rf "${BIDS}"; fi
# if [ -d ${BIDS} ]; then Error "Output directory already exist, use -force to overwrite it. \n\t    ${BIDS}\t    "; exit 0; fi

# Save actual path
here=$(pwd)

# -----------------------------------------------------------------------------------------------
# New BIDS-naming, follow the BIDS specification:
# https://bids-specification.readthedocs.io/en/stable/04-modality-specific-files/01-magnetic-resonance-imaging-data.html
orig=(
    "*anat-T1w_acq_mprage_0.8mm_CSptx"
    "*fmap-b1_tra_p2"
    "*fmap-fmri_acq-mbep2d_SE_19mm_dir-AP"
    "*fmap-fmri_acq-mbep2d_SE_19mm_dir-PA"
    "*func-cloudy_acq-ep2d_MJC_19mm"
    "*func-cross_acq-ep2d_MJC_19mm"
    "*anat-T1w_acq-mp2rage_0.7mm_CSptx_INV1"
    "*anat-T1w_acq-mp2rage_0.7mm_CSptx_INV2"
    "*anat-T1w_acq-mp2rage_0.7mm_CSptx_T1_Images"
    "*anat-T1w_acq-mp2rage_0.7mm_CSptx_UNI_Images"
    "*anat-T1w_acq-mp2rage_0.7mm_CSptx_UNI-DEN"
)

bids=(
    T1w
    acq-anat_TB1TFL
    dir-AP_epi
    dir-PA_epi
    task-cloudy_bold
    task-cross_bold
    inv-1_MP2RAGE
    inv-2_MP2RAGE
    T1map
    UNIT1
    acq-DEN_UNIT1
)

origDWI=(
  "*dwi_acq_b0_PA"
  "*dwi_acq_b0_PA_SBRef"
  "*dwi_acq_multib_38dir_AP_acc9"
  "*dwi_acq_multib_38dir_AP_acc9_SBRef"
  "*dwi_acq_multib_70dir_AP_acc9"
  "*dwi_acq_multib_70dir_AP_acc9_SBRef"
)

bidsDWI=(
  acq-b0_dir-PA_dwi
  acq-b0_dir-PA_sbref
  acq-multib38_dir-AP_sbref
  acq-multib38_dir-AP_dwi
  acq-multib70_dir-AP_sbref
  acq-multib70_dir-AP_dwi
)

#-----------------------------------------------------------------------------------------------
#Create BIDS/subj_dir
cmd mkdir -p "$BIDS"/{anat,func,dwi,fmap}
if [ ! -d "$BIDS" ]; then Error "Could not create subject BIDS directory, check permissions \n\t     ${BIDS}\t    "; exit 0; fi

# dicomx to Nifti with BIDS Naming
cmd cd $SUBJ_DIR
# Warning lenght
n=$((${#orig[@]} - 1))
for ((k=0; k<=n; k++)); do
  N=$(ls -d ${orig[k]} | wc -l)
  if [ "$N" -eq 0 ]; then
    Warn "No directories were found with the following name: ${orig[k]}"
  elif [ "$N" -gt 1 ]; then
    Names=($(ls -d ${orig[k]}))
    for ((i = 1; i <= N; i++)); do
       nii=$(echo ${Names[((i-2))]} | awk -F '_' '{print $1 "_" $2}')
       nom="${id}${bids[k]}"
       dcm=$(echo ${nom##*_})
       nom=$(echo "${nom/$dcm/}run-${i}_${dcm}")
       cmd dcm2niix -z y -b y -o "$BIDS" -f "$nom" ${nii}${orig[k]}
    done
  elif [ "$N" -eq 1 ]; then
     cmd dcm2niix -z y -b y -o "$BIDS" -f ${id}${bids[k]} ${orig[k]}
  fi
done

# move files to their corresponding directory
# Moving files to their correct directory location
if ls "$BIDS"/*MP2RAGE* 1> /dev/null 2>&1; then cmd mv "$BIDS"/*MP2RAGE* "$BIDS"/anat; fi
if ls "$BIDS"/*UNIT1* 1> /dev/null 2>&1; then cmd mv "$BIDS"/*UNIT1* "$BIDS"/anat; fi
if ls "$BIDS"/*bold* 1> /dev/null 2>&1; then cmd mv "$BIDS"/*bold* "$BIDS"/func; fi
if ls "$BIDS"/*T1* 1> /dev/null 2>&1; then cmd mv "$BIDS"/*T1* "$BIDS"/anat; fi
if ls "$BIDS"/*T2* 1> /dev/null 2>&1; then cmd mv "$BIDS"/*T2* "$BIDS"/anat; fi
if ls "$BIDS"/*fieldmap* 1> /dev/null 2>&1; then cmd mv "$BIDS"/*fieldmap* "$BIDS"/fmap; fi
if ls "$BIDS"/*TB1TFL* 1> /dev/null 2>&1; then cmd mv "$BIDS"/*TB1TFL* "$BIDS"/fmap; fi

# Rename echos: echo-1_bold.nii.gz
for i in {1..3}; do
    str="bold_e${i}"
    for f in ${BIDS}/func/*${str}*; do
        mv $f ${f/${str}/echo-${i}_bold}
    done
done

# REPLACE "_sbref_ph" with "part-phase_bold"
for func in $(ls "$BIDS"/func/*"bold_ph"*); do mv ${func} ${func/bold_ph/part-phase_bold}; done

# REMOVE the run-?
for func in $(ls "$BIDS"/func/*"_run-"*); do mv ${func} ${func/_run-?/}; done

Info "Remove MP2RAGE bval and bvecs"
rm "$BIDS"/anat/*MP2RAGE.bv*

Info "Organize TB1TFL acquisitions"
TB1TFL=(acq-famp_run-1_TB1TFL acq-anat_run-1_TB1TFL acq-famp_run-2_TB1TFL acq-anat_run-2_TB1TFL)
for i in {1..4}; do
  for b1 in $(ls "$BIDS"/fmap/*"acq-anat_run-${i}_TB1TFL"*); do
  mv ${b1} ${b1/acq-anat_run-${i}_TB1TFL/${TB1TFL[$((i-1))]}};
  done
done

# -----------------------------------------------------------------------------------------------
Info "DWI acquisitions"
# -----------------------------------------------------------------------------------------------
# Loop through the directories of DWI acquisitions
n=$((${#origDWI[@]} - 1))
for ((k=0; k<=n; k++)); do
  N=$(ls -d ${origDWI[k]} 2>/dev/null | wc -l) # make it quiet
  if [ "$N" -eq 0 ]; then
    Warn "No directories were found with the following name: ${origDWI[k]}"
  elif [ "$N" -gt 1 ]; then
    Names=($(ls -d ${origDWI[k]} 2>/dev/null))
    for ((i = 0; i < N; i++)); do
      nii=$(echo ${Names[i]} | awk -F '_' '{print $1 "_" $2}')
      nom=${id}${bidsDWI[k]}
      dcm=$(echo ${nom##*_})
      nom=$(echo ${nom/$dcm/}run-$((i+1))_${dcm})
      cmd dcm2niix -z y -b y -o "$BIDS" -f "$nom" "${nii}${origDWI[k]}"
    done
  elif [ "$N" -eq 1 ]; then
     cmd dcm2niix -z y -b y -o "$BIDS" -f "${id}${bidsDWI[k]}" "${origDWI[k]}"
  fi
done

cmd cd "$BIDS"
for n in $(ls *bval); do Dir=0
  for i in $(cat $n); do if [[ "$i" == 0.00 ]] || [[ "$i" == 0 ]]; then Dir=$((Dir+1)); else Dir=$((Dir+1)); fi; done
  for j in ${n/bval/}*; do mv "$j" dwi/${j/NUM/$Dir}; done
done

# Moving files to their correct directory location
if ls "$BIDS"/*b0* 1> /dev/null 2>&1; then cmd mv "$BIDS"/*b0* "$BIDS"/dwi; fi
if ls "$BIDS"/*sbref* 1> /dev/null 2>&1; then cmd mv "$BIDS"/*sbref* "$BIDS"/dwi; fi
if ls "$BIDS"/*epi* 1> /dev/null 2>&1; then cmd mv "$BIDS"/*epi* "$BIDS"/fmap; fi
if ls "$BIDS"/*angio* 1> /dev/null 2>&1; then cmd mv "$BIDS"/*angio* "$BIDS"/anat; fi
if ls "$BIDS"/*MTR* 1> /dev/null 2>&1; then cmd mv "$BIDS"/*MTR* "$BIDS"/anat; fi
if ls "$BIDS"/anat/*ROI* 1> /dev/null 2>&1; then cmd rm "$BIDS"/anat/*ROI*; fi

Info "REMOVE run-1 string from new 7T DWI acquisition"
for dwi in $(ls "$BIDS"/dwi/*"acq-"*"_dir-"*"_run-1_dwi"*); do mv $dwi ${dwi/run-1_/}; done

Info "REPLACE run-2 string to  from new 7T DWI acquisition"
for dwi in $(ls "$BIDS"/dwi/*"acq-"*"_dir-"*"_run-2_dwi"*); do mv $dwi ${dwi/run-2_/part-phase_}; done

Info "REPLACE \"_sbref_ph\" with \"_part-phase_sbref\""
for dwi in $(ls "$BIDS"/dwi/*"_sbref_ph"*); do mv $dwi ${dwi/_sbref_ph/_part-phase_sbref}; done

# -----------------------------------------------------------------------------------------------
# Add Units to the phase files
for file in "$BIDS"/*/*phase*json; do
  # Add the key "Units": "arbitrary" to the JSON file
  jq '. + {"Units": "arbitrary"}' "$file" > tmp.$$.json && mv tmp.$$.json "$file"
done

# -----------------------------------------------------------------------------------------------
# QC, count the number of Niftis (json) per subject
dat=$(stat ${BIDS} | awk 'NR==6 {print $2}')
anat=$(ls -R ${BIDS}/anat | grep gz | wc -l)
dwi=$(ls -R ${BIDS}/dwi | grep gz | wc -l)
func=$(ls -R ${BIDS}/func | grep gz | wc -l)
fmap=$(ls -R ${BIDS}/fmap | grep gz | wc -l)

# check mandatory inputs: -in Is $SUBJ_DIR found?
tsv_file="$BIDS_DIR"/participants_7t2bids.tsv
# Check if file exist
if [ ! -f "$tsv_file" ]; then echo -e "sub\tses\date\tdicoms\tN.anat\tN.dwi\tN.func\tN.fmap" > "$tsv_file"; fi
# Add information about subject
echo -e "${Subj}\t${SES/ses-/}\t${dat}\t${SUBJ_DIR}\t${anat}\t${dwi}\t${func}\t${fmap}" >> "$tsv_file"

# -----------------------------------------------------------------------------------------------
# Gitignore file
bidsignore="$BIDS_DIR"/.bidsignore
# Check if file exist
if [ ! -f "$bidsignore" ]; then echo -e "participants_7t2bids.tsv\nbids_validator_output.txt" > "$bidsignore"; fi

# -----------------------------------------------------------------------------------------------
# Add the new subject to the participants.tsv file
participants_tsv="$BIDS_DIR"/participants.tsv
# Check if file exist
if [ ! -f "$participants_tsv" ]; then echo -e "participant_id\tsession_id\tsite\tgroup" > "$participants_tsv"; fi
# Add information about subject
echo -e "sub-${Subj}\t${SES/ses-/}\tMontreal_SiemmensTerra7T\tHealthy" >> "$participants_tsv"

# -----------------------------------------------------------------------------------------------
# Get the repository path
gitrepo=$(dirname $(dirname $(realpath "$0")))

# Copy json files to the BIDS directory
if [ ! -f "$BIDS_DIR"/participants.json ]; then cp -v "$gitrepo"/participants.json "$BIDS_DIR"/participants.json; fi
if [ ! -f "$BIDS_DIR"/task-cross_bold.json ]; then cp -v "$gitrepo"/task-cross_bold.json "$BIDS_DIR"/task-cross_bold.json; fi
if [ ! -f "$BIDS_DIR"/task-cloudy_bold.json ]; then cp -v "$gitrepo"/task-cloudy_bold.json "$BIDS_DIR"/task-cloudy_bold.json; fi

# Copy the data_set_description.json file to the BIDS directory
if [ ! -f "$BIDS_DIR"/dataset_description.json ]; then cp -v "$gitrepo"/dataset_description.json "$BIDS_DIR"/dataset_description.json; fi

# Copy the data_set_description.json file to the BIDS directory
if [ ! -f "$BIDS_DIR"/CITATION.cff ]; then cp -v "$gitrepo"/CITATION.cff "$BIDS_DIR"/CITATION.cff; fi

# Create README
echo -e "This dataset was provided by the Montreal Paris Neurobanque initiative.\n\nIf you reference this dataset in your publications, please acknowledge its authors." > "$BIDS_DIR"/README

# -----------------------------------------------------------------------------------------------
# Go back to initial directory
cd "$here"

Info "Remember to validate your BIDS directory:
      http://bids-standard.github.io/bids-validator/"
