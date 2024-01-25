function [model,res_modeshape,res_freq] = sol103(bin_folder,modeshape_num,opts)
arguments
    bin_folder
    modeshape_num
    opts.Animate logical = false;
    opts.model = [];
end
    close all
    if isempty(opts.model)
        model = mni.import_matran(fullfile(bin_folder,'Source','sol103.bdf'));
    else
        model = opts.model;
    end
    model.draw;

    % get modal data
    f06 = mni.result.f06(fullfile(bin_folder,'bin','sol103.f06'));
    res_modeshape = f06.read_modeshapes;
    res_freq = f06.read_modes;
    %% apply deformation result
    [~,i] = ismember(model.GRID.GID,res_modeshape.GID(modeshape_num,:));
    model.GRID.Deformation = [res_modeshape.T1(modeshape_num,i);...
        res_modeshape.T2(modeshape_num,i);res_modeshape.T3(modeshape_num,i)];

    model.update()
    if opts.Animate
        model.animate('Period',0.5,'Cycles',5,'Scale',0.2) 
    end
end