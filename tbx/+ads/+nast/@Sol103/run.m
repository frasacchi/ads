function [data,binFolder] = run(obj,feModel,opts)
arguments
    obj
    feModel ads.fe.Component
    opts.Silent = true;
    opts.StopOnFatal = false;
    opts.NumAttempts = 3;
    opts.BinFolder string = '';
    opts.IncludeEigenVec = true;
    opts.createBat = false;
    opts.cmdLineArgs struct = struct.empty;
end

%% create BDFs
binFolder = ads.nast.create_tmp_bin('BinFolder',opts.BinFolder);

%update boundary condition
if ~isempty(obj.CoM) 
    if obj.isFree
        obj.CoM.ComponentNumbers = ads.nast.inv_dof(obj.DoFs);
        obj.CoM.SupportNumbers = obj.DoFs;
    else
        obj.CoM.ComponentNumbers = 123456;
        obj.CoM.SupportNumbers = [];
    end
end

% export model
modelFile = string(fullfile(pwd,binFolder,'Source','Model','model.bdf'));
feModel.Export(modelFile);

% extract SPC IDs
if ~isempty(feModel.Constraints)
    obj.SPCs = [feModel.Constraints.ID];
else
    obj.SPCs = [];
end
%create main BDF file
bdfFile = fullfile(pwd,binFolder,'Source','sol103.bdf');
obj.write_main_bdf(bdfFile,[modelFile]);

% write the batch file if we were asked
if opts.createBat
    obj.writeJobSubmissionBat(binFolder);
end

%% Run Analysis
attempt = 1;
while attempt<opts.NumAttempts+1
    % run NASTRAN
    current_folder = pwd;
    cd(fullfile(binFolder,'Source'))
    fprintf('Computing sol103 for Model %s ... ',obj.Name);
    command = ads.nast.buildCommand('sol103.bdf',...
        cmdLineArgs=opts.cmdLineArgs,Silent=opts.Silent);
    tic;
    system(command);
    toc;
    cd(current_folder);
    %get Results
    f06_filename = fullfile(binFolder,'bin','sol103.f06');
    f06_file = mni.result.f06(f06_filename);
    if f06_file.isEmpty
        attempt = attempt + 1;
        fprintf('%s is empty on attempt %.0f...\n',f06_filename,attempt)
        continue
    elseif f06_file.isfatal
        if opts.StopOnFatal
            error('ADS:Nastran','Fatal error detected in f06 file %s...',f06_filename)
        else
            attempt = attempt + 1;
            fprintf('Fatal error detected on attempt %.0f in f06 file %s... \n',attempt,f06_filename)
            continue
        end
    else
        break
    end
end
if attempt > opts.NumAttempts
    fprintf('Failed after %.0f attempts %s... STOPPING\n',opts.NumAttempts,f06_filename)
    error('ADS:Nastran','Failed after %.0f attempts %s...',opts.NumAttempts,f06_filename)
end
h5_file = mni.result.hdf5(fullfile(binFolder,'bin','sol103.h5'));
if opts.IncludeEigenVec
    data = h5_file.read_modeshapes();
else
    data = h5_file.read_modes();
end
end

