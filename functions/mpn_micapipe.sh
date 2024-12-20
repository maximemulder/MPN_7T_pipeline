#!/bin/bash
#
# ---------------------------------------------------------------------------------
# Run the micapipe MPN on BIC-SGE with a singularity container
# Using a singularity image of micapipe v0.2.3: https://hub.docker.com/r/micalab/micapipe/tags
# ---------------------------------------------------------------------------------

# Subject ID
sub=$1
# Session
ses=$2

# micapipe version
version=v0.2.3

# 2.  Singularity image
img_singularity=/data/mica1/01_programs/micapipe-v0.2.0/micapipe_"${version}".sif

# 3. micapipe command
# Local variables
bids=/data_/mica3/BIDS_Q1K/rawdata
fs_lic=/data_/mica1/01_programs/freesurfer-7.3.2/license.txt
out=/data_/mica3/BIDS_Q1K/derivatives
threads=30
tmpDir=/data_/mica2/tmpDir

# Create command string
command="singularity run --writable-tmpfs --containall -B ${bids}:/bids -B ${out}:/out -B ${tmpDir}:/tmp -B ${fs_lic}:/opt/licence.txt ${img_singularity}"

# Run pipeline FULL
${command} \
-bids /bids -out /out -fs_licence /opt/licence.txt -threads ${threads} -sub ${sub} -ses ${ses} \
-proc_structural -uni -T1wStr UNIT1,inv-1_MP2RAGE,inv-2_MP2RAGE -proc_surf -post_structural \
-proc_dwi \
-dwi_main /bids/${sub}/${ses}/dwi/${sub}_${ses}_acq-multib38_dir-AP_dwi.nii.gz,/bids/${sub}/${ses}/dwi/${sub}_${ses}_acq-multib70_dir-AP_dwi.nii.gz -regSynth \
-dwi_rpe /bids/${sub}/${ses}/dwi/${sub}_${ses}_acq-b0_dir-PA_dwi.nii.gz \
-GD -proc_func \
-mainScanStr task-cross_echo-1_bold,task-cross_echo-2_bold,task-cross_echo-3_bold \
-func_pe /bids/${sub}/${ses}/fmap/${sub}_${ses}_dir-AP_epi.nii.gz \
-func_rpe /bids/${sub}/${ses}/fmap/${sub}_${ses}_dir-PA_epi.nii.gz \
-SC -tracts 40M \
-MPC -microstructural_img /bids/${sub}/${ses}/anat/${sub}_${ses}_T1map.nii.gz \
 -microstructural_reg FALSE -mpc_acq T1map

 # Run task-cross fmri
 ${command} \
 -bids /bids -out /out -fs_licence /opt/licence.txt -threads ${threads} -sub ${sub} -ses ${ses} \
 -proc_func -regSynth \
 -mainScanStr task-cross_echo-1_bold,task-cross_echo-2_bold,task-cross_echo-3_bold \
 -func_pe /bids/${sub}/${ses}/fmap/${sub}_${ses}_dir-AP_epi.nii.gz \
 -func_rpe /bids/${sub}/${ses}/fmap/${sub}_${ses}_dir-PA_epi.nii.gz

# Run task-cloudy fmri
${command} \
-bids /bids -out /out -fs_licence /opt/licence.txt -threads ${threads} -sub ${sub} -ses ${ses} \
-proc_func -regSynth \
-mainScanStr task-cloudy_echo-1_bold,task-cloudy_echo-2_bold,task-cloudy_echo-3_bold \
-func_pe /bids/${sub}/${ses}/fmap/${sub}_${ses}_dir-AP_epi.nii.gz \
-func_rpe /bids/${sub}/${ses}/fmap/${sub}_${ses}_dir-PA_epi.nii.gz -QC_subj

# Run group QC
${command} -bids /bids -out /out -fs_licence /opt/licence.txt -threads ${threads} -QC
