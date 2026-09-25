function names = writeParams(fid,defaults,overrides)
%WRITEPARAMS Write PARAM cards from a cell array {Name,Type,Value;...}.
%   A field of the struct overrides replaces the default value (e.g.
%   overrides.WTMASS = 0.00259); empty values are skipped. Returns the names
%   written (pass them to ads.nast.writeExtraParams).
arguments
    fid
    defaults cell
    overrides struct = struct()
end
names = strings(0,1);
for i = 1:size(defaults,1)
    name = defaults{i,1};
    val = defaults{i,3};
    if isfield(overrides,name)
        val = overrides.(name);
    end
    if ~isempty(val)
        writeParam(fid,name,defaults{i,2},val);
        names(end+1,1) = name;
    end
end
end

function writeParam(fid,name,type,val)
% a two element numeric value is written as V1,V2 (e.g. complex PARAMs)
if type == 's'
    v1 = char(val);
    v2 = [];
else
    val = double(val);
    v1 = val(1);
    v2 = val(2:end);
end
mni.printing.cards.PARAM(char(name),type,v1,v2).writeToFile(fid);
end
