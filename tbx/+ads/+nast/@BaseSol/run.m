function run(obj,BinFolder,opts)
    arguments
        obj ads.nast.BaseSol
        BinFolder string
        opts.StopOnFatal = true;
        opts.NumAttempts = 1;
        opts.cmdLineArgs struct = struct.empty;
        opts.BDFName = obj.Name;
    end
    %% Run Analysis
attempt = 1;
bdfname = opts.BDFName;
while attempt<opts.NumAttempts+1
    Log.trace(['Computing ',bdfname],LogSubLevel.High);
    % run NASTRAN
    current_folder = pwd;
    cd(fullfile(BinFolder,'Source'))
    % create command
    command = ads.nast.buildCommand([bdfname,'.bdf'],...
        cmdLineArgs=opts.cmdLineArgs,Silent=true);
    % save the command to a bat file for repeat execution
    writelines(command,[bdfname,'.bat']);
    % execute the command
    Log.trace(['Nastran Started at: ',datestr(now, 'HH:MM:SS')],LogSubLevel.Mid);
    tic;
    system(command);
    t = toc;
    Log.trace(['Nastran completed in ',num2str(t),' seconds'],LogSubLevel.High);
    cd(current_folder);

    %get Results
    f06_filename = fullfile(BinFolder,'bin',[bdfname,'.f06']);
    f06_file = mni.result.f06(f06_filename);
    if f06_file.isEmpty
        if opts.StopOnFatal
            error('ADS:Nastran','Fatal error detected in f06 file %s',f06_filename)
        else
            attempt = attempt + 1;
            Log.warn(sprintf('%s is empty on attempt %.0f',f06_filename,attempt));
            continue           
        end
    elseif f06_file.isfatal
        if opts.StopOnFatal
            error('ADS:Nastran','Fatal error detected in f06 file %s',f06_filename)
        else
            attempt = attempt + 1;
            Log.warn(sprintf('Fatal error detected on attempt %.0f in f06 file %s',attempt,f06_filename));
            continue
        end
    else
        break % successful run
    end
end
if attempt > opts.NumAttempts
    if opts.StopOnFatal
        Log.error(sprintf('Failed after %.0f attempts %s',opts.NumAttempts,f06_filename));
        error('ADS:Nastran','Failed after %.0f attempts %s',opts.NumAttempts,f06_filename);
    else
        Log.warn(sprintf('Failed after %.0f attempts %s',opts.NumAttempts,f06_filename));
    end
end