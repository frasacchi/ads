function val = getExe(obj) %get.NastranExe
    % getExe Get Nastran Exe path
    %
    % If 'NastranExe' has not been initialized then use 'getpref'.
    
    if ispref('ADS_Nastran', 'nastran_exe')
        val = getpref('ADS_Nastran', 'nastran_exe');
    else
        %Ask the user
        [name, path] = uigetfile({'*.exe', 'Executable File (*.exe)'}, ...
            ['Select the MSC.Nastran executable file ', ...
            '(e.g. \...\nastran.exe)']);
        %Check the output
        if isnumeric(name) || isnumeric(path)
            warndlg(['Unable to run analysis as the '  , ...
                'path to the MSC.Nastran executable '  , ...
                'has not been set. Update your user '  , ...
                'preferences and re-run the analysis.'], ...
                'Warning - Unable to run analysis', 'modal');
            return
        end
        %Check the path for spaces - Enclose with ""
        folders = strsplit(path, filesep);
        idx = cellfun(@(x) any(strfind(x, ' ')), folders);
        folders(idx) = cellfun(@(x) ['"', x, '"'], folders(idx), 'Unif', false);
        path = strjoin(folders, filesep);
        val = fullfile(path, name);
        %Update the preferences
        setpref('ADS_Nastran', 'nastran_exe', val);
    end
end
