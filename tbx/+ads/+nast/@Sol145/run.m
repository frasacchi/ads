function [res,binFolder] = run(obj,feModel,opts)
arguments
    obj
    feModel ads.fe.Component
    opts.Silent = true;
    opts.TruelySilent = false;
    opts.StopOnFatal = false;
    opts.NumAttempts = 3;
    opts.BinFolder string = '';
    opts.UseHdf5 = true;
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
% create flutter cards
flutFile = string(fullfile(pwd,binFolder,'Source','flutter.bdf'));
obj.write_flutter(flutFile);

% extract SPC IDs
if ~isempty(feModel.Constraints)
    obj.SPCs = [feModel.Constraints.ID];
else
    obj.SPCs = [];
end
%create main BDF file
bdfFile = fullfile(pwd,binFolder,'Source','sol145.bdf');
obj.write_main_bdf(bdfFile,[modelFile,flutFile]);

%% Run Analysis
attempt = 1;
while attempt<opts.NumAttempts+1
    % run NASTRAN
    current_folder = pwd;
    cd(fullfile(binFolder,'Source'))
    if ~opts.TruelySilent
        fprintf('Computing sol145 for Model %s: %.0f velocities ... ',...
        obj.Name,length(obj.V));
    end
    command = ads.nast.buildCommand('sol145.bdf',...
        cmdLineArgs=opts.cmdLineArgs,Silent=(opts.Silent || opts.TruelySilent));
    if opts.TruelySilent
        system(command);
    else     
        tic;
        system(command);
        toc;
    end
    cd(current_folder);
    %get Results
    f06_filename = fullfile(binFolder,'bin','sol145.f06');
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

if opts.UseHdf5
    h5_file = mni.result.hdf5(fullfile(binFolder,'bin','sol145.h5'));
    res = h5_file.read_flutter_summary();
    res_vec = h5_file.read_flutter_eigenvector();
else
    f06_file = mni.result.f06(fullfile(binFolder,'bin','sol145.f06'));
    res = f06_file.read_flutter();
    res_vec = f06_file.read_flutter_eigenvector();
end
%assign eigen vectors to modes if they equate
for i = 1:length(res_vec)
    [~,I] = min(abs([res.CMPLX]-res_vec(i).EigenValue));
    res(I).IDs = res_vec(i).IDs;
    res(I).EigenVector = res_vec(i).EigenVector;
end

