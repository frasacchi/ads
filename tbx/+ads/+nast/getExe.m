function val = getExe(Override) %get.NastranExe
    % getExe Get Nastran Exe path
    %
    % If 'NastranExe' has not been initialized then use 'getpref'.
    arguments
        Override logical = false
    end
    
    if ispref('ADS_Nastran', 'nastran_exe') && ~Override
        val = getpref('ADS_Nastran', 'nastran_exe');
    else
        %Ask the user
        [name, path] = uigetfile({'*.exe', 'Nastran Executable File (nastran.exe)'}, ...
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
        % Enclose with "" incase of spaces
        val = ['"',fullfile(path,name),'"'];
        %Update the preferences
        setpref('ADS_Nastran', 'nastran_exe', val);
    end
end
