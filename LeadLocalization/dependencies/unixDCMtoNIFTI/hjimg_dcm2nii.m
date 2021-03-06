function hjimg_dcm2nii(Patient_DIR, NifTi_DIR, is_merge_exp)
    % matlab wrapper to call the DICOM to NifTi converter based on Unix tools
    % It sorts through DICOM images without looking at the DICOMDIR, 
    % reconstructing the info from the DICOM headers present in each image
    % options:
    % -is_merge_exp: (default true) merging exposure (some centers may use varying exposure during CT)
    %
    % Enrico Opri 2018

    if ~exist('is_merge_exp','var')
        %merging exposure (some centers may use varying exposure during CT)
        is_merge_exp=true;
    end
    
    if ~any(strcmp(Patient_DIR(end),{'\','/'}))
        Patient_DIR = [Patient_DIR,''];
    end
    if ~any(strcmp(NifTi_DIR(end),{'\','/'}))
        NifTi_DIR = [NifTi_DIR,'/'];
    end

    
    if isempty(getenv('NEURO_VIS_PATH_UNIX'))
        NEURO_VIS_PATH_UNIX = getenv('NEURO_VIS_PATH');
    else
        NEURO_VIS_PATH_UNIX = getenv('NEURO_VIS_PATH_UNIX');
    end
    
    if ~any(strcmp(NEURO_VIS_PATH_UNIX(end),{'\','/'}))
        NEURO_VIS_PATH_UNIX = [NEURO_VIS_PATH_UNIX,'/'];
    end
    
    %hjimg__dcmsort = ['"',NEURO_VIS_PATH_UNIX,'dependencies/unixDCMtoNIFTI/hjimg__dcmsort"'];
    %hjimg__convert_tonii = ['"',NEURO_VIS_PATH_UNIX,'dependencies/unixDCMtoNIFTI/hjimg__convert_tonii"'];
    hjimg__dcmsort = [NEURO_VIS_PATH_UNIX,'dependencies/unixDCMtoNIFTI/hjimg__dcmsort'];
    if is_merge_exp
        hjimg__convert_tonii = [NEURO_VIS_PATH_UNIX,'dependencies/unixDCMtoNIFTI/hjimg__convert_tonii_mergeexp'];
    else
        hjimg__convert_tonii = [NEURO_VIS_PATH_UNIX,'dependencies/unixDCMtoNIFTI/hjimg__convert_tonii'];
    end
    
    tempfolder1=hfullfile(fileparts(fileparts(NifTi_DIR)),'DICOMSORT/','-unix');

    %creating temp folder to store sorted DICOMs
    %mkdir(tempfolder1);
    
    %sort DICOM folders
    cmd1=[hjimg__dcmsort ' -D ' Patient_DIR ' -o ' tempfolder1];
    if isunix
        system(cmd1);
    else
        %use unix subsystem
        system(['wsl ' cmd1]);
    end
    
    %creating temp folder to store NIFTI files
    %mkdir(NifTi_DIR);
    
    %convert DICOM to NIFTI
    cmd1=[hjimg__convert_tonii ' ' NifTi_DIR ' ' tempfolder1];
    if isunix
        system(cmd1);
    else
        %use unix subsystem
        system(['wsl ' cmd1]);
    end
end