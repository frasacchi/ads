function BinFolder = build(obj,feModel,BinFolder,sol144Opts)
arguments
    obj
    feModel
    BinFolder string = '';
    sol144Opts.trimObjs = ads.nast.TrimParameter.empty;
    sol144Opts.OutputAeroMatrices logical = false;
end
obj.OutputAeroMatrices = sol144Opts.OutputAeroMatrices;

% add control surfaces to trim parameters
for i = 1:length(feModel.ControlSurfaces)
    cs = feModel.ControlSurfaces(i);
    sol144Opts.trimObjs(end+1) = ads.nast.TrimParameter(cs.Name,cs.Deflection,"Control Surface");
end
obj.trimObjs = sol144Opts.trimObjs;

% run analysis
BinFolder = build@ads.nast.BaseSol(obj,feModel,BinFolder);
end

