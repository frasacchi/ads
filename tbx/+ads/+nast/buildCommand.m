function command = buildCommand(runFile,opts)
arguments
    runFile
    opts.cmdLineArgs = struct.empty;
    opts.Silent = false;
end

args = struct.empty;
args(1).out = fullfile('..','bin');
args.news = 'no';
args.notify = 'no';
args.old = 'no';

for f = fieldnames(opts.cmdLineArgs)'
    args.(f{1}) = opts.cmdLineArgs.(f{1});
end

command = [ads.nast.getExe,' ',runFile];
for f = fieldnames(args)'
    command = [command, ' ',f{1},'=',args.(f{1})];
end

if opts.Silent
    command = [command,' ','1>NUL 2>NUL'];
end
end