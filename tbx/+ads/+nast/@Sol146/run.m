function [binFolder] = run(obj,feModel,opts)
arguments
    obj
    feModel ads.fe.Component
    opts.Silent = true;
    opts.StopOnFatal = false;
    opts.NumAttempts = 1;
    opts.BinFolder string = '';
    opts.TruelySilent = false;
end

%% create BDFs
binFolder = ads.nast.create_tmp_bin('BinFolder',opts.BinFolder);

% set Aero properties on feModel
feModel.AeroSettings.Velocity = obj.V;
feModel.AeroSettings.RefRho = obj.rho;
% export model
modelFile = string(fullfile(pwd,binFolder,'Source','Model','model.bdf'));
feModel.Export(modelFile);
% create gust cards
gustFile = string(fullfile(pwd,binFolder,'Source','gust.bdf'));
obj.write_gust(gustFile);

% extract SPC IDs
if ~isempty(feModel.Constraints)
    obj.SPCs = [feModel.Constraints.ID];
else
    obj.SPCs = [];
end

%create main BDF file
bdfFile = fullfile(pwd,binFolder,'Source','sol146.bdf');
obj.write_main_bdf(bdfFile,[modelFile,gustFile]);

%% Run Analysis
attempt = 1;
while attempt<opts.NumAttempts+1
    % run NASTRAN
    current_folder = pwd;
    cd(fullfile(binFolder,'Source'))
    if ~opts.TruelySilent
        fprintf('Computing sol146 for Model %s: %.0f gusts ... ',...
            obj.Name,length(obj.Gusts));
    end
        nastran_exe = 'C:\MSC.Software\MSC_Nastran\2022.1\bin\nastran.exe';
        % nastran_exe = 'C:\MSC.Software\MSC_Nastran\20181\bin\nastran.exe';
        command = [nastran_exe,...
        ' ','sol146.bdf',...
        ' ',sprintf('out=..%s%s%s',filesep,'bin',filesep)];
    if opts.Silent || opts.TruelySilent
        command = [command,' ','1>NUL 2>NUL'];
    end
    if opts.TruelySilent
        system(command);
    else
        tic;
        system(command);
        toc;
    end
    cd(current_folder);
    if ~opts.StopOnFatal
        break
    end
    %get Results
    f06_filename = fullfile(binFolder,'bin','sol146.f06');
    f06_file = mni.result.f06(f06_filename);
    if f06_file.isEmpty
        attempt = attempt + 1;
        fprintf('%s is empty on attempt %.0f...\n',f06_filename,attempt)
        continue
    elseif f06_file.isfatal
        if opts.StopOnFatal
            error('Fatal error detected in f06 file %s...',f06_filename)
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
    error('Failed after %.0f attempts %s...',opts.NumAttempts,f06_filename)
end
end

