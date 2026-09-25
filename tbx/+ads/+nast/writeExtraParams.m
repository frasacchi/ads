function writeExtraParams(fid,params,written)
%WRITEEXTRAPARAMS Write the PARAMs of the struct params not in written.
%   The type follows the value: char/string 's', integer class (e.g.
%   int32) 'i', otherwise 'r'; a two element numeric value gives V1,V2.
arguments
    fid
    params struct
    written string = strings(0,1)
end
names = setdiff(string(fieldnames(params)),written,'stable');
if ~isempty(names)
    mni.printing.bdf.writeComment(fid,'Extra Parameters')
end
for i = 1:length(names)
    val = params.(names(i));
    if ischar(val) || isstring(val)
        ads.nast.writeParams(fid,{char(names(i)),'s',val});
    elseif isinteger(val)
        ads.nast.writeParams(fid,{char(names(i)),'i',val});
    else
        ads.nast.writeParams(fid,{char(names(i)),'r',val});
    end
end
end
