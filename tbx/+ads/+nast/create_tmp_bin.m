function binFolder = create_tmp_bin(opts)
arguments
    opts.binFolder string = '';
end
binFolder = opts.binFolder;
% create a random string of 5 characters
if binFolder == "" 
    % make sure only valid charcters in random string
    vals = [48:57,65:90,97:122];
    % keep generating folders until it doesn't already exist
    while true
        idx = char(vals(randi([1 length(vals)],1,3)));
        binFolder = ['bin_',idx];
        % create directory
        if ~isfolder(binFolder)
            break
        end
    end
else
    if isfolder(binFolder)
        rmdir(binFolder,'s');
    end
end
% make the folder
mkdir(binFolder)
mkdir(fullfile(binFolder,'bin'))
mkdir(fullfile(binFolder,'Source'))
mkdir(fullfile(binFolder,'Source','Model'))
end

