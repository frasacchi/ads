function v = get_version()
    path = fileparts(mfilename('fullpath'));
    ver_path = fullfile(path,'..','..','version.txt');
    fid = fopen(ver_path,'r');
    v = fgetl(fid);
    fclose(fid);
end

