function [exe_path,nast_ver] = getExe(Override) %get.NastranExe
    % getExe Get Nastran Exe path
    %
    % If 'NastranExe' has not been initialized then use 'getpref'.
    arguments
        Override logical = false
    end
    
    if ispref('ADS_Nastran', 'nastran_exe') && ~Override
        exe_path = getpref('ADS_Nastran', 'nastran_exe');
        nast_ver = getpref('ADS_Nastran', 'nastran_ver');
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
        exe_path = ['"',fullfile(path,name),'"'];
        %Update the preferences
        setpref('ADS_Nastran', 'nastran_exe', exe_path);
        %get the version
        [~,out]=system([exe_path,' news']);
        tok = regexp(out,'Welcome to MSC Nastran (\d*\.\d?)','tokens');
        nast_ver = tok{1}{1};
        setpref('ADS_Nastran', 'nastran_ver', nast_ver);        
    end
end
