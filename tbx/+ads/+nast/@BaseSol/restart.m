function restart(obj,BinFolder,cards,opts)
arguments
    obj ads.nast.Sol144
    BinFolder string
    cards mni.printing.cards.BaseCard = mni.printing.cards.BaseCard.empty;
    opts.StopOnFatal = false;
    opts.NumAttempts = 3;
    opts.cmdLineArgs struct = struct.empty;
end
%% create BDFs
if ~isdir(BinFolder)
    error('ADS:Nastran','The provided BinFolder does not exist: %s',BinFolder)
end

% create restart file
filename = fullfile(BinFolder,'Source','restart.bdf');
fid = fopen(filename,"w");
mni.printing.bdf.writeFileStamp(fid);
mni.printing.bdf.writeHeading(fid,'This file contains the cards to restart the solution');
println(fid,'RESTART, VERSION=1, KEEP');
obj.write_case_control(fid);
mni.printing.bdf.writeHeading(fid,'Begin Bulk');
println(fid,'BEGIN BULK');
for i = 1:length(cards)
    cards(i).writeToFile(fid);
end
fclose(fid);

%% Run Analysis
obj.run(BinFolder,StopOnFatal=opts.StopOnFatal,NumAttempts=opts.NumAttempts,cmdLineArgs=opts.cmdLineArgs,BDFName='restart');
end

