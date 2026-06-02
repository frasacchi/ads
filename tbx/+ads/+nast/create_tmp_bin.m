function BinFolder = create_tmp_bin(BinFolder)
arguments
    BinFolder string = '';
end
% create a random string of 5 characters
if strcmp(BinFolder,'') 
    % make sure only valid charcters in random string
    vals = [48:57,65:90,97:122];
    % keep generating folders until it doesn't already exist
    while true
        idx = char(vals(randi([1 length(vals)],1,3)));
        BinFolder = ['bin_',idx];
        % create directory
        if ~isfolder(BinFolder)
            break
        end
    end
else
    if isfolder(BinFolder)
        rmdir(BinFolder,'s');
    end
end
% make the folder
mkdir(BinFolder)
mkdir(fullfile(BinFolder,'bin'))
mkdir(fullfile(BinFolder,'Source'))
mkdir(fullfile(BinFolder,'Source','Model'))
end

