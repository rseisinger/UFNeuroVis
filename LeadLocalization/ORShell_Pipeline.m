%% Clear environment and close figures
clear; clc; close all;

%% set the environment
UFNeuroVis_setEnv;

%% Step 0: Setups
Patient_DIR = uigetdir('','Please select the subject Folder');
if isnumeric(Patient_DIR) 
    error('No folder selected');
else
    ORShell_MRI = dir([Patient_DIR,filesep,'mr']);
    if isempty(ORShell_MRI)
        error('Incorrect Patient Directory');
    end
end
fprintf('Change directory to patient directory...');
cd(Patient_DIR);
fprintf('Done\n\n');

Processed_DIR = [Patient_DIR,filesep,'Processed'];
mkdir(Processed_DIR);

%% Step 1: Convert Knwon Image from UF VTK format to NifTi format
if exist('mr','file') && ~exist([Processed_DIR,filesep,'anat_t1.nii'],'file')
    preop_T1 = UFVTK2NifTi('mr');
	save_nii(preop_T1,[Processed_DIR,filesep,'anat_t1.nii']);
end

if exist('ct','file') && ~exist([Processed_DIR,filesep,'preop_ct.nii'],'file')
    postop_CT = UFVTK2NifTi('ct');
	save_nii(postop_CT,[Processed_DIR,filesep,'preop_ct.nii']);
end

if exist('ct.postop','file') && ~exist([Processed_DIR,filesep,'postop_ct.nii'],'file')
    postop_CT = UFVTK2NifTi('ct.postop');
	save_nii(postop_CT,[Processed_DIR,filesep,'postop_ct.nii']);
end

if exist('mr2','file') && ~exist([Processed_DIR,filesep,'anat_t2.nii'],'file')
    preop_T2 = UFVTK2NifTi('mr2');
	save_nii(preop_T2,[Processed_DIR,filesep,'anat_t2.nii']);
end

%% Step 2: Upsampling MRI and Potential Image Processing (Optional for now)
if ~isempty(dir([Processed_DIR,filesep,'anat_t1_filtered.nii']))
	preop_T1 = loadNifTi([Processed_DIR,filesep,'anat_t1_filtered.nii']);
else
	% Up Sample to Images with 0.5mm Resolution
    preop_T1 = loadNifTi([Processed_DIR,filesep,'anat_t1.nii']);
	preop_T1_upsampled = resampleNifTi(preop_T1, [0.5 0.5 1]);
	fprintf('MRI Upsampling to 0.5mm spacing complete.\n');
	
	% Spatial Filtering
	preop_T1_filtered = spatialFilter(preop_T1_upsampled, 'diffusion');
	save_nii(preop_T1_filtered,[Processed_DIR,filesep,'anat_t1_filtered.nii']);
	preop_T1 = preop_T1_filtered;
	fprintf('MRI Spatial Filter with Diffusion Filter complete.\n');
end

%% Step 3: Transform the MRI Brain to AC-PC Coordinates
if ~isempty(dir([Processed_DIR,filesep,'anat_t1_acpc.nii'])) 
    
    %if an AC-PC already exists, see what the user wants to do, either redo
    %it or just use the current one
    option1 = 'Edit AC-PC coordinates';
    option2 = 'Use existing AC-PC transform';
    option3 = 'Cancel';
    answer = questdlg('An AC-PC transformed brain for this patient already exists. What would you like to do?',...
                      'Please Respond',...
                      option1,option2,option3,option3);
    switch answer
        case option1
            [preop_T1_acpc, transformMatrix, coordinates] = transformACPC(preop_T1);
            save_nii(preop_T1_acpc,[Processed_DIR,filesep,'anat_t1_acpc.nii']);
            preop_T1_acpc = loadNifTi([Processed_DIR,filesep,'anat_t1_acpc.nii']);
            save([Processed_DIR,filesep,'acpc_transformation.mat'],'transformMatrix');
        case option2
            clear preop_T1_upsampled preop_T1;
            preop_T1_acpc = loadNifTi([Processed_DIR,filesep,'anat_t1_acpc.nii']);
        case option3
            return;
    end
else
    [preop_T1_acpc, transformMatrix] = transformACPC(preop_T1);
    save_nii(preop_T1_acpc,[Processed_DIR,filesep,'anat_t1_acpc.nii']);
    preop_T1_acpc = loadNifTi([Processed_DIR,filesep,'anat_t1_acpc.nii']);
    save([Processed_DIR,filesep,'acpc_transformation.mat'],'transformMatrix');
end

%% Step 4: Coregister the Post-operative CT Scan to T1 MRI in AC-PC Coordinate
if ~isempty(dir([Processed_DIR,filesep,'rpostop_ct.nii']))
    coregistered_CT = loadNifTi([Processed_DIR,filesep,'rpostop_ct.nii']);
else
    postop_CT = loadNifTi([Processed_DIR,filesep,'postop_ct.nii']);
    [coregistered_CT, tform] = coregisterMRI(preop_T1_acpc, postop_CT);
    save([Processed_DIR,filesep,'ct-t1_transformation.mat'],'tform');
    save_nii(coregistered_CT,[Processed_DIR,filesep,'rpostop_ct.nii']);
end

%% Step 5: Check coregistration.
% If the coregistration doesn't look good. Mark it and report to your
% mentor. (This is highly unlikely event unless the brain is highly
% shifted).

% If coregistration is not good, see line 26 to 29 in "coregisterMRI"
% function. Change max iteration to a larger number. 
checkCoregistration(preop_T1_acpc, coregistered_CT);

%% Step 6: Lead Localization
leadLocalization(preop_T1_acpc, coregistered_CT, Processed_DIR);

%% Step 7: Normalization (What is normalization? Never heard of it)
preop_T1_acpc = loadNifTi([Processed_DIR,filesep,'anat_t1_acpc.nii']);
BovaAtlasFitter(preop_T1_acpc,Processed_DIR,NEURO_VIS_PATH);

%% Step 8: reverse normalize atlases
bovaFits = dir([Processed_DIR,filesep,'BOVAFit*']);
bovaFits.folder = [Processed_DIR,filesep];
if ~isempty(bovaFits)
    bovaFit = bovaFits(1);
    BovaTransform = load(fullfile(bovaFit.folder,bovaFit.name));
    
    % Transform Left Lead if Left Atlas Morph Exist
    if isfield(BovaTransform,'Left')
        leftLeads = dir([Processed_DIR,filesep,'LEAD_Left*.mat']);
        for n = 1:length(leftLeads)
            leadInfo = load([Processed_DIR,filesep,leftLeads(n).name]);
            T = computeTransformMatrix(BovaTransform.Left.Translation,BovaTransform.Left.Scale,BovaTransform.Left.Rotation);
            m = matfile([Processed_DIR,filesep,'BOVA_',leftLeads(n).name],'Writable',true);
            m.Side = leadInfo.Side;
            m.Type = leadInfo.Type;
            m.nContacts = leadInfo.nContacts;
            newDistal = [leadInfo.Distal, 1] / T;
            m.Distal = newDistal(1:3);
            newProximal = [leadInfo.Proximal, 1] / T;
            m.Proximal = newProximal(1:3);
        end
    end
    
    % Transform Right Lead if Right Atlas Morph Exist
    if isfield(BovaTransform,'Right')
        rightLeads = dir([Processed_DIR,filesep,'LEAD_Right*.mat']);
        for n = 1:length(rightLeads)
            leadInfo = load([Processed_DIR,filesep,rightLeads(n).name]);
            T = computeTransformMatrix(BovaTransform.Right.Translation,BovaTransform.Right.Scale,BovaTransform.Right.Rotation);
            m = matfile([Processed_DIR,filesep,'BOVA_',rightLeads(n).name],'Writable',true);
            m.Side = leadInfo.Side;
            m.Type = leadInfo.Type;
            m.nContacts = leadInfo.nContacts;
            newDistal = [leadInfo.Distal, 1] / T;
            m.Distal = newDistal(1:3);
            newProximal = [leadInfo.Proximal, 1] / T;
            m.Proximal = newProximal(1:3);
        end
    end
end




%% EXTRA 1: Use UF Transform Matrix during OR Planning

preop_T1 = loadNifTi([Processed_DIR,filesep,'anat_t1.nii']);
preop_T2 = loadNifTi([[Processed_DIR,filesep,'anat_t2.nii']]);
T = readFuseMatrix('mr.xfrm');
T = inv(T);
T(:,4) = round(T(:,4));
tform = affine3d(T);
preop_T1_planning = niftiWarp(preop_T1, tform);

T = readFuseMatrix('mr2.xfrm');
T = inv(T);
T(:,4) = round(T(:,4));
tform = affine3d(T);
preop_T2_planning = niftiWarp(preop_T2, tform);

save_nii(preop_T1_planning,[Processed_DIR,filesep,'ranat_t1_planning.nii']);
save_nii(preop_T2_planning,[Processed_DIR,filesep,'ranat_t2_planning.nii']);
checkCoregistration(preop_T1_planning, preop_T2_planning);