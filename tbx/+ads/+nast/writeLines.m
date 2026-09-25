function writeLines(fid,lines)
%WRITELINES Write each line of a string array (e.g. extra case control).
lines = string(lines);
for i = 1:length(lines)
    fprintf(fid,'%s\n',lines(i));
end
end
